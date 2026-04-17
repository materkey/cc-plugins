---
name: go
description: After finishing the task — run end-to-end tests → execute /simplify → create a PR
---

You have just finished implementing the requested changes.

Now perform these final steps:

1. **End-to-End Verification**
   - Thoroughly test the entire functionality you built.
   - Backend / API: start the server and run all relevant tests via bash/terminal.
   - Frontend / web: use browser tools, Computer Use, or the Chromium extension to verify UI and behavior.
   - CLI tools / scripts: test the commands directly.
   - Fix any bugs or issues you discover before moving on.

2. **Simplify the Code**
   - Run the `/simplify` skill to clean up, refactor, remove redundancy, and improve overall code quality.

3. **Create a Pull Request**
   - Stage all changes.
   - Write a clear, descriptive commit message.
   - Push the changes.
   - Create a well-formatted Pull Request (use `gh` CLI if available, or Claude Code's built-in git tools).

This `/go` skill should be the **final command** you run at the end of almost every significant task.
