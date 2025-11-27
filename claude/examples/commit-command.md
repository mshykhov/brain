# Commit Command

Location: `~/.claude/commands/commit.md`

```markdown
---
allowed-tools:
  - Bash(git add:*)
  - Bash(git status:*)
  - Bash(git commit:*)
  - Bash(git diff:*)
  - Bash(git log:*)
argument-hint: "[message] | --no-verify | --amend"
description: Create well-formatted commits with conventional commit format
---

# Smart Git Commit

Create well-formatted commit: $ARGUMENTS

## Current Repository State

- Git status: !git status --porcelain
- Current branch: !git branch --show-current
- Staged changes: !git diff --cached --stat
- Unstaged changes: !git diff --stat
- Recent commits: !git log --oneline -5

## What This Command Does

1. Checks which files are staged with git status
2. If 0 files are staged, automatically adds all modified and new files with git add
3. Performs a git diff to understand what changes are being committed
4. Analyzes the diff to determine if multiple distinct logical changes are present
5. If multiple distinct changes are detected, suggests breaking the commit into multiple smaller commits
6. For each commit (or the single commit if not split), creates a commit message using conventional commit format

## Best Practices for Commits

- **Verify before committing**: Ensure your code works correctly before creating a commit
- **Atomic commits**: Each commit should contain related changes that serve a single purpose
- **Split large changes**: If changes touch multiple concerns, split them into separate commits
- **Conventional commit format**: Use the format <type>: <description> where type is one of:
  - feat: A new feature
  - fix: A bug fix
  - docs: Documentation changes
  - style: Code style changes (formatting, etc)
  - refactor: Code changes that neither fix bugs nor add features
  - perf: Performance improvements
  - test: Adding or fixing tests
  - chore: Changes to the build process, tools, etc.
  - ci: CI/CD improvements
  - revert: Reverting changes
  - wip: Work in progress
  - build: Changes to build system or dependencies
  - security: Security fixes
- **Present tense, imperative mood**: Write commit messages as commands (e.g., "add feature" not "added feature")
- **Concise first line**: Keep the first line under 72 characters
- **No emoji**: Use only text-based conventional commit prefixes

## Commit Type Guidelines

- **feat**: A new feature for the user
- **fix**: A bug fix
- **docs**: Documentation only changes
- **style**: Changes that do not affect the meaning of the code (formatting, missing semi-colons, etc)
- **refactor**: A code change that neither fixes a bug nor adds a feature
- **perf**: A code change that improves performance
- **test**: Adding missing tests or correcting existing tests
- **build**: Changes that affect the build system or external dependencies
- **ci**: Changes to CI configuration files and scripts
- **chore**: Other changes that don't modify src or test files
- **revert**: Reverts a previous commit
- **wip**: Work in progress (temporary commits that will be squashed)
- **security**: Security improvements or vulnerability fixes

## Guidelines for Splitting Commits

When analyzing the diff, consider splitting commits based on these criteria:

1. **Different concerns**: Changes to unrelated parts of the codebase
2. **Different types of changes**: Mixing features, fixes, refactoring, etc.
3. **File patterns**: Changes to different types of files (e.g., source code vs documentation)
4. **Logical grouping**: Changes that would be easier to understand or review separately
5. **Size**: Very large changes that would be clearer if broken down

## Examples

Good commit messages:
- feat: add user authentication system
- fix: resolve memory leak in rendering process
- docs: update API documentation with new endpoints
- refactor: simplify error handling logic in parser

## Command Options

- **--no-verify**: Pass --no-verify flag to git commit (skips git hooks)
- **--amend**: Amend the previous commit instead of creating a new one

## Important Notes

- If specific files are already staged, the command will only commit those files
- If no files are staged, it will automatically stage all modified and new files
- The commit message will be constructed based on the changes detected
- Before committing, the command will review the diff to identify if multiple commits would be more appropriate
- If suggesting multiple commits, it will help you stage and commit the changes separately
- Always reviews the commit diff to ensure the message matches the changes
- Works with any programming language and project type
```
