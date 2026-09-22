# GLOBAL RULES FOR AGENTS

## Communication

- Communicate with the user in whatever language they use.
- All code (variables, functions, classes, etc.) MUST be written in English.
- All code comments MUST be written in English.

## Comments Policy

- Avoid comments. Code should be self-explanatory.
- If a comment is absolutely necessary, keep it minimal — one line max.

## Git Safety

- NEVER work outside the current branch.
- NEVER merge branches or perform destructive repo actions without explicit user confirmation.
- NEVER push to remote unless the user specifically requests it.
- Everything stays LOCAL unless the user explicitly says otherwise.
- If the current branch is `main` or `master`, WARN the user before making any changes. The user may authorize working on it, but always ask first.
- Commit messages MUST be title-only. Do NOT add a description body.

## Browser Annotations

- When a turn is a browser annotation (it says so and references the `browser-annotation` skill), load that skill and use the element metadata (component path, data-testid/id/role, ancestors, nearest region, text) to locate and change the corresponding code. Confirm the element exists before editing.
