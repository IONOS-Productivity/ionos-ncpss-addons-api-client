<!--
SPDX-FileCopyrightText: 2025 STRATO GmbH
SPDX-License-Identifier: AGPL-3.0-or-later
-->
# Copilot Instructions - Multiple Files

## Overview

This project supports multiple levels of Copilot instructions:

1. **Project-wide** (`.github/copilot-instructions.md`) - Checked into git, applies to all developers
2. **Personal** (`.github/copilot-instructions.local.md`) - Gitignored, for individual developer preferences

## How It Works

GitHub Copilot can read instruction files from multiple sources and may combine their contents:

- **Project instructions** define standards everyone must follow (code style, commit format, etc.)
- **Personal instructions** add your individual preferences and context
- Both files are read and applied together

## Creating Your Personal Instructions

1. Copy the template:
   ```bash
   cp .github/copilot-instructions.local.md.example .github/copilot-instructions.local.md
   ```

2. Edit `.github/copilot-instructions.local.md` with your preferences

3. The file is gitignored automatically - it won't be committed

## What to Put in Personal Instructions

### ✅ Good Uses

- **Personal workflow preferences**: "I prefer verbose logging during development"
- **Learning context**: "I'm new to OIDC, explain security concepts"
- **Editor-specific**: "I use vim keybindings"
- **Current focus**: "I'm working on the Keycloak integration"
- **Communication style**: "Be concise" or "Show detailed examples"
- **Personal code style preferences** (that don't contradict project standards)

### ❌ Don't Put in Personal Instructions

- **Project requirements** (those belong in the main file)
- **Code standards** that contradict project guidelines
- **Sensitive information** (credentials, API keys, etc.)
- **Team-wide preferences** (propose them for the main file instead)

## Examples

### Example 1: Developer Learning OIDC

```markdown
# Personal Copilot Instructions

## Context
- I'm learning about OIDC and Keycloak
- Explain security concepts when they come up
- Prefer showing the "why" behind authentication decisions

## Preferences
- Use step-by-step explanations for complex flows
- Show sequence diagrams for authentication flows when relevant
```

### Example 2: Experienced Developer, Prefers Conciseness

```markdown
# Personal Copilot Instructions

## Communication
- Be concise, I prefer brief explanations
- Skip basic explanations of common patterns
- Focus on edge cases and gotchas

## Code Style
- Prefer functional programming patterns in Python
- Always suggest type hints
```

### Example 3: Working on Specific Feature

```markdown
# Personal Copilot Instructions

## Current Work
- Focusing on MinIO integration
- Working on the container/dev-setup scripts
- Testing Podman compatibility

## Preferences
- When suggesting shell commands, always include error handling
- Prefer defensive programming in bash scripts
```

## Benefits

### For Individual Developers
- Customize Copilot to your learning style
- Add context about what you're working on
- Set preferences without affecting others

### For the Team
- Keep project instructions clean and focused on standards
- Allow flexibility for individual workflows
- Reduce conflicts between different developer preferences

## File Location

```
.github/
├── copilot-instructions.md                  # Project-wide (committed)
├── copilot-instructions.local.md            # Your personal file (gitignored)
└── copilot-instructions.local.md.example    # Template (committed)
```

## Troubleshooting

### Copilot not using my personal instructions?

1. Check the file is named correctly: `.github/copilot-instructions.local.md`
2. Restart your IDE/editor
3. Try regenerating a suggestion to see if it applies

### Want to share a useful pattern?

If you find a pattern in your personal instructions that would benefit the team:
1. Propose it for the main `copilot-instructions.md` file
2. Create a PR with your suggestion
3. Discuss with the team

### Conflicts between files?

Personal instructions should **complement**, not **contradict** project instructions:
- ✅ "When I ask for help, show detailed examples" (personal preference)
- ❌ "Use single quotes for strings" (contradicts project standard if project uses double quotes)

## Related Files

- `.github/copilot-instructions.md` - Project-wide instructions
- `.github/git-commit-instructions.md` - Git-specific instructions (also applies project-wide)
- `.gitignore` - Includes `.github/copilot-instructions.local.md`
