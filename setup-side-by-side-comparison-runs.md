# Comparison runs with and without the agent setup

Prerequisite: the task description is in `ticket.md` (untracked) in the root of the original repository.

Tip: let an AI fill in the commands with the names from your own setup using the following prompt:

```
Copy setup-side-by-side-comparison-runs.md to setup-side-by-side-comparison-runs-commands.md.
In the copy, replace all placeholders (<...>) with the actual values of my setup.
Get missing values from the repository (e.g. git remote -v) or ask me.
Change nothing else in the instructions.
```

## 1. Create a snapshot with the setup (before removing the setup)

```
git checkout <source-branch>
git checkout --orphan workshop-with-setup <source-branch>   # Commit without history, setup included
git commit -m "Workshop base (with setup)"
```

## 2. Create an isolated clone with the setup

```
git clone --no-local --single-branch --branch workshop-with-setup <source-repo> <with-setup-clone>
cd <with-setup-clone>
cp <source-repo>/ticket.md .
git remote remove origin
git switch -c feature/with-setup
```

## 3. Remove the setup and create the baseline

Back in the original repository:

```
git checkout <source-branch>
git checkout -b <baseline-branch>
git rm -r CLAUDE.md AGENTS.md .claude          # Remove the agent setup; adjust to your actual setup files (e.g. .opencode/, opencode.json)
git commit -m "Remove agent config for workshop baseline"
git push --set-upstream origin <baseline-branch>
git tag workshop-base <baseline-branch>
git push origin workshop-base
git checkout --orphan workshop-no-setup <baseline-branch>   # Commit without history, without setup
git commit -m "Workshop base (no setup)"
```

## 4. Create an isolated clone without the setup

```
git clone --no-local --single-branch --branch workshop-no-setup <source-repo> <no-setup-clone>
cd <no-setup-clone>
cp <source-repo>/ticket.md .
git remote remove origin
git switch -c feature/no-setup
```

Note: make sure no global agent configuration is loaded (e.g. `~/.config/opencode/`, `~/.claude/CLAUDE.md`, `~/.claude/skills`). Among other options, it can be turned off with the `OPENCODE_DISABLE_CLAUDE_CODE*` environment variables (see the opencode docs).

## 5. Reconnect to Git for the comparison after implementing

In each clone (`<x>` = `no-setup` or `with-setup`):

```
git add -A
git commit -m "Implementation (<x>)"
git remote add origin <remote-url>
git fetch origin <baseline-branch>
git rebase --onto origin/<baseline-branch> workshop-<x> feature/<x>   # Back onto the real history
git push -u origin feature/<x>
```

Both feature branches are now based on `<baseline-branch>` and can be compared directly.

## 6. Compare the implementations

### Code comparison
Open one PR per feature branch against `<baseline-branch>` (not against `main`).
Look at both side by side.

### LLM-as-a-judge
Prepare in the original repository (the baseline contains no agent setup):

```
git fetch origin
git checkout <baseline-branch>
```

Then run in a new session:

```
Compare two implementations of ticket.md. Both are based on <baseline-branch>:
- A: git diff origin/<baseline-branch>...origin/feature/no-setup
- B: git diff origin/<baseline-branch>...origin/feature/with-setup

Write a short report (max. 1 page):
1. Requirements from ticket.md: met / not met, for A and B each
2. Key differences (design, tests, error handling)
3. Conclusion: strengths and weaknesses of each implementation

Back every statement with file:line. No statements without evidence in the diff.
```

## 7. Clean up

After the workshop: decline both PRs, then in the original repository:

```
git push origin --delete feature/no-setup feature/with-setup <baseline-branch>
git push origin --delete refs/tags/workshop-base
git tag -d workshop-base
git checkout <source-branch>
git branch -D <baseline-branch> workshop-with-setup workshop-no-setup
```

Then delete both clone folders.
