# AGENTS.md

## Git and branch workflow

Follow this workflow for every code change unless I explicitly say otherwise.

### Before starting work

- Never work directly on `main` or `master`.
- First check the current branch and working tree:
  - `git status --short`
  - `git branch --show-current`
- If there are uncommitted user changes, stop and ask before touching them.
- Sync the default branch before creating a feature branch:
  - `git fetch origin`
  - `git checkout main`
  - `git pull --ff-only origin main`
- Create one short-lived branch per task.

### Branch naming

Use clear branch names:

- `feat/<short-description>` for features
- `fix/<short-description>` for bug fixes
- `chore/<short-description>` for maintenance
- `docs/<short-description>` for documentation
- `refactor/<short-description>` for refactoring

Examples:

- `feat/google-signin`
- `fix/calorie-sync-error`
- `docs/privacy-policy-update`

### During work

- Keep changes focused on the requested task.
- Do not mix unrelated refactoring with feature work.
- Prefer small, coherent commits.
- Use conventional commit messages where practical:
  - `feat: add Google sign-in`
  - `fix: handle expired auth token`
  - `docs: update privacy policy`
- Run relevant checks before finishing:
  - lint
  - tests
  - type checks
  - build, if applicable

### Finishing work

When implementation is complete:

1. Show a concise summary of changed files.
2. Show commands/checks that were run.
3. Commit the changes.
4. Push the feature branch.
5. Create a pull request into `main`.
6. Do not merge the pull request unless I explicitly say: `merge this PR`.

### Merging

Only merge after explicit approval.

When I say `merge this PR`:

1. Confirm the current PR status.
2. Ensure checks are passing.
3. Merge using squash merge unless I specify otherwise.
4. Delete the local and remote feature branch after merge.
5. Checkout `main`.
6. Pull latest `main`.
7. Confirm the branch was deleted.

Preferred merge command:

```bash
gh pr merge --squash --delete-branch