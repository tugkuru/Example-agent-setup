#!/bin/bash
# Before-tool-call safety gate (Claude Code PreToolUse; the opencode plugin calls it with the same input)
# Blocks: dangerous shell commands, secret-file reads/writes/searches, force-push, etc.
#
# Input:  hook JSON on stdin, e.g. {"tool_name": "Bash", "tool_input": {"command": "..."}}
# Output: exit 0 allows the call. Exit 2 blocks it; the message on stderr goes back to the agent.

INPUT=$(cat)

# This gate parses tool input with jq to decide what to block. Without jq every
# field would be empty, no rule would match, and the gate would fall through to
# "allow" — failing open. Since we can't vouch for safety without it, fail closed.
if ! command -v jq >/dev/null 2>&1; then
  echo "Blocked: safety-gate requires 'jq' to evaluate tool input, but jq was not found. Install jq (e.g. 'brew install jq') to proceed." >&2
  exit 2
fi

TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
if [ -z "$TOOL" ]; then
  echo "Blocked: safety-gate could not parse the tool input (invalid JSON or missing tool_name)." >&2
  exit 2
fi

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
NOTEBOOK=$(echo "$INPUT" | jq -r '.tool_input.notebook_path // empty')
GLOB_PATH=$(echo "$INPUT" | jq -r '.tool_input.path // empty')
PATTERN=$(echo "$INPUT" | jq -r '.tool_input.pattern // empty')
WRITE_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
EDIT_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty')
GREP_GLOB=$(echo "$INPUT" | jq -r '.tool_input.glob // empty')

normalize_path() {
  local p="${1//\\//}"
  printf '%s' "$p" | tr '[:upper:]' '[:lower:]'
}

# ---- Protected file patterns (match path or filename) ----
# Allow .env.example and .env.sample (schema files, no real secrets)
is_protected_file() {
  is_protected_path "$(normalize_path "$1")"
}

# Same check for a path already passed through normalize_path. Pure bash (no subprocesses),
# as the shell check below calls it for every word of a command.
is_protected_path() {
  local f="$1" name
  [ -z "$f" ] && return 1
  name="${f%/}"
  name="${name##*/}"

  # Explicit allowlist first
  case "$name" in
    .env.example|.env.sample|.env.template|env.example) return 1 ;;
  esac

  # Match common secret files
  case "$name" in
    .env|.env.*|*.env|*.pem|*.key|*.p12|*.pfx|*.ppk|*.jks|*.keystore|id_rsa|id_rsa.pub|id_ed25519|credentials|credentials.json|secrets.json|secrets.yaml|secrets.yml|.pgpass|.git-credentials|.bash_history|.zsh_history)
      return 0 ;;
  esac

  case "/$f/" in
    */.ssh/*|*/secrets/*|*/.kube/*|*/.docker/config.json/) return 0 ;;
  esac

  return 1
}

# ---- File-targeting tools: Read, Edit, Write, MultiEdit, NotebookEdit ----
# Also covers Grep/Glob when path points directly at a protected file
for path_check in "$FILE" "$NOTEBOOK" "$GLOB_PATH"; do
  if is_protected_file "$path_check"; then
    echo "Blocked: '$path_check' is a protected secret file. Use .env.example for schema reference, or ask the user to share specific values." >&2
    exit 2
  fi
done

# ---- Write/Edit: detect hardcoded credentials in content ----
CRED_RE='(API_KEY|SECRET|TOKEN|PASSWORD|PASSWD)[[:space:]]*[=:][[:space:]]*["'"'"'][A-Za-z0-9_/+=-]{16,}["'"'"']'
for content_check in "$WRITE_CONTENT" "$EDIT_CONTENT"; do
  [ -z "$content_check" ] && continue
  if echo "$content_check" | grep -qiE "$CRED_RE"; then
    echo "Blocked: content appears to contain a hardcoded credential. Use environment variables or secret references instead." >&2
    exit 2
  fi
done

# ---- Glob/Grep: check pattern, path, and glob file-filter for secret references ----
# Grep's pattern is a regex for file contents, not a path; only Glob's pattern names files.
# credentials/secrets match as file or folder name only, so CredentialsService.java stays searchable.
GLOB_PATTERN=""
[ "$TOOL" = "Glob" ] && GLOB_PATTERN="$PATTERN"
for candidate in "$GLOB_PATTERN" "$GLOB_PATH" "$GREP_GLOB"; do
  [ -z "$candidate" ] && continue
  case "$(normalize_path "$candidate")" in
    *.env|*.env.*|*.pem|*.key|*id_rsa*|*credentials|*credentials.*|*secrets|*secrets.*|*secrets/*)
      # Allow the .example / .sample variants
      case "$(normalize_path "$candidate")" in
        *.env.example|*.env.sample|*.env.template) continue ;;
      esac
      echo "Blocked: search pattern/path '$candidate' targets secret files." >&2
      exit 2
      ;;
  esac
done

# ---- Grep: block content-mode searches for credential names without a file restriction ----
# Catches e.g. Grep(pattern="API_KEY", output_mode="content") with no path/glob — which would
# return matching lines from secrets.yaml and similar files across the whole project.
if [ "$TOOL" = "Grep" ]; then
  OUTPUT_MODE=$(echo "$INPUT" | jq -r '.tool_input.output_mode // "files_with_matches"')
  if [ "$OUTPUT_MODE" = "content" ]; then
    if echo "$PATTERN" | grep -qiE '(API_KEY|SECRET|TOKEN|PASSWORD|PASSWD|PRIVATE_KEY|CREDENTIAL)'; then
      echo "Blocked: searching for '$PATTERN' with content output may expose secrets from protected files. Use files_with_matches output_mode instead." >&2
      exit 2
    fi
  fi
fi

# ---- Bash/PowerShell: dangerous commands + secret-file exfiltration via shell ----
# All command patterns are matched case-insensitively (grep -i), as PowerShell is case-insensitive.
if { [ "$TOOL" = "Bash" ] || [ "$TOOL" = "PowerShell" ]; } && [ -n "$CMD" ]; then
  # PowerShell recursive force-delete (Remove-Item and its aliases, parameters in any order or abbreviated)
  if [ "$TOOL" = "PowerShell" ] \
    && echo "$CMD" | grep -qiE '(^|[[:space:];|&({])(remove-item|rm|ri|del|erase|rd|rmdir)[[:space:]]' \
    && echo "$CMD" | grep -qiE '[[:space:]]-r[a-z]*([[:space:]:;|)}]|$)' \
    && echo "$CMD" | grep -qiE '[[:space:]]-fo[a-z]*([[:space:]:;|)}]|$)'; then
    echo "Blocked: recursive force-delete (Remove-Item -Recurse -Force). Delete specific paths without -Force, or ask the user." >&2
    exit 2
  fi

  # Destructive operations
  for danger_re in 'rm[[:space:]]+-rf?[[:space:]]+/' \
                   'rm[[:space:]]+-rf?[[:space:]]+~' \
                   'rm[[:space:]]+-rf?[[:space:]]+\*' \
                   'git[[:space:]]+push[[:space:]]+.*--force' \
                   'git[[:space:]]+push[[:space:]]+.*-f([[:space:]]|$)' \
                   'git[[:space:]]+push[[:space:]]+.*[[:space:]]\+[^[:space:]]' \
                   'rm[[:space:]]+(-rf?|-fr|-r[[:space:]]+-f)[[:space:]]+\.{1,2}/?([[:space:]]|;|&|$)' \
                   'git[[:space:]]+reset[[:space:]]+--hard' \
                   'git[[:space:]]+.*--no-verify' \
                   'DROP[[:space:]]+TABLE' \
                   'DROP[[:space:]]+DATABASE' \
                   'TRUNCATE[[:space:]]+TABLE' \
                   'rm[[:space:]]+-fr[[:space:]]+/' \
                   'rm[[:space:]]+-fr[[:space:]]+~' \
                   'rm[[:space:]]+-fr[[:space:]]+\*' \
                   'rm[[:space:]]+-r[[:space:]]+-f[[:space:]]+/' \
                   'rm[[:space:]]+-r[[:space:]]+-f[[:space:]]+~' \
                   'rm[[:space:]]+-r[[:space:]]+-f[[:space:]]+\*' \
                   ':\(\)\{[[:space:]]*:\|:&[[:space:]]*\};:' \
                   'mkfs\.' \
                   'dd[[:space:]]+if=.*of=/dev/[sh]d' \
                   'curl[[:space:]]+.*\|[[:space:]]*(ba)?sh' \
                   'wget[[:space:]]+.*\|[[:space:]]*(ba)?sh' \
                   'chmod[[:space:]]+-R[[:space:]]+777' \
                   'git[[:space:]]+add[[:space:]]+(\.([[:space:]]|$)|-A([[:space:]]|$)|--all([[:space:]]|$))'
  do
    if echo "$CMD" | grep -qiE "$danger_re"; then
      echo "Blocked: command matches forbidden pattern ($danger_re). Suggest a safer alternative." >&2
      exit 2
    fi
  done

  # Secret-file exfiltration via shell (cat .env, source .env, cat ~/.ssh/id_rsa, Get-Content .env, etc.)
  # Each segment between ; | & and newlines that runs a reader command has every word checked with
  # is_protected_path, so the shell is held to the same file list as Read/Edit (.env.example stays allowed).
  # The command is normalized once up front, so the loop itself starts no subprocesses.
  READERS=" cat less more head tail grep rg awk sed source . xxd od strings get-content gc type select-string sls copy-item copy cp "
  SEGMENTS=$(normalize_path "$CMD" | tr ';|&' '\n\n\n' | sed -E "s/[(){}<>\"'\`]/ /g")
  set -f  # words like * must not expand to file names
  while IFS= read -r segment; do
    words=( $segment )
    has_reader=false
    for w in "${words[@]}"; do
      case "$READERS" in *" ${w##*/} "*) has_reader=true ;; esac  # /bin/cat counts as cat
    done
    $has_reader || continue
    for w in "${words[@]}"; do
      if is_protected_path "$w"; then
        echo "Blocked: command would expose secrets from protected file '$w'. Use .env.example or ask the user." >&2
        exit 2
      fi
    done
  done <<< "$SEGMENTS"
  set +f
fi

exit 0
