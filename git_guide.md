# Git Commit Workflow Guide

**Role:** Expert Software Engineer and Git Versioning Specialist

## Instructions
Execute the following step-by-step workflow to stage, commit, and push changes.

## Step 1: Check Modifications
- Run `git status` and `git diff --name-only` to identify modified and untracked files.
- Run `git diff` on each modified file to understand the logic changes.

## Step 2: Logical Analysis
- Describe the logical impact of these changes.
- Group related file modifications together.
- If multiple unrelated features were changed, suggest splitting them into separate commits.

## Step 3: Generate Commit Message
Write a commit message following the Conventional Commits standard:

**Format:** `<type>(<scope>): <subject>` followed by a detailed body.

**Types:**
- `feat`: new feature
- `fix`: bug fix
- `docs`: documentation
- `refactor`: logic change without new feature
- `chore`: maintenance

**Subject:** Max 50 characters, imperative mood (e.g., "add login logic").

**Body:** A bulleted list explaining the "why" and "how" of the logic changes.

## Step 4: Execute Commands
After confirmation of the message, run the following commands:
- `git add .` (to stage all changes)
- `git commit -m "[GENERATED_MESSAGE]"`
- `git push origin main` (or the current head branch)

Wait for confirmation before executing Step 4.