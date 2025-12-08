<!--
SPDX-FileCopyrightText: 2025 STRATO GmbH
SPDX-License-Identifier: AGPL-3.0-or-later
-->
# Copilot Instructions

> **Note**: This file contains project-wide Copilot instructions that apply to all developers.
> You can create a personal `.github/copilot-instructions.local.md` file for your own preferences
> (this file is gitignored and won't be committed). Personal instructions complement these project instructions.

## Project Context

This repository contains development tools, documentation, and container scripts for HiDrive Next (Nextcloud-based solution). The project uses:

- **Container Runtime**: Podman (preferred) / Docker
- **Languages**: Bash, Python, PHP, JavaScript/Vue.js (in Nextcloud submodules)
- **Services**: Nextcloud, Keycloak, MinIO, Collabora, Imaginary, and supporting services
- **Build System**: Make, container builds

## Code Quality Standards

### License Headers

All code files **must** include a SPDX license header with the current CURRENT_YEAR.

> **Note**: Replace `<CURRENT_YEAR>` in the examples below with the current CURRENT_YEAR when creating new files.

#### Shell Scripts (*.sh, run scripts)

```bash
#!/usr/bin/env bash

#
# SPDX-FileCopyrightText: <CURRENT_YEAR> STRATO GmbH
# SPDX-License-Identifier: AGPL-3.0-or-later
#
```

#### Python Scripts (*.py)

```python
#!/usr/bin/env python3

#
# SPDX-FileCopyrightText: <CURRENT_YEAR> STRATO GmbH
# SPDX-License-Identifier: AGPL-3.0-or-later
#
```

#### PHP and JavaScript files

```php
/**
 * SPDX-FileCopyrightText: <CURRENT_YEAR> STRATO GmbH
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
```

#### Vue files

```html
<!--
  - SPDX-FileCopyrightText: <CURRENT_YEAR> STRATO GmbH
  - SPDX-License-Identifier: AGPL-3.0-or-later
-->
```

#### Makefiles and Configuration Files

```makefile
# SPDX-FileCopyrightText: <CURRENT_YEAR> STRATO GmbH
# SPDX-License-Identifier: AGPL-3.0-or-later
```

### Shell Scripts

Shell scripts must meet the same quality standards as other code:

- **Always use `#!/usr/bin/env bash`** as the shebang (not `/bin/bash` or `/bin/sh`)
  > This improves portability across different systems, as `bash` may not always be located in `/bin/`.
- **Run `shellcheck`** on all shell scripts before committing to catch issues and ensure POSIX compliance
- Use **double quotes** for variables to prevent word splitting: `"${variable}"`
- Use **long-form options** when available for better readability: `--verbose` instead of `-v`
- Add **descriptive comments** for complex logic
- Use **functions** for repeated code blocks
- Handle **errors appropriately** with proper exit codes
- Include **usage/help** messages for user-facing scripts

### Documentation

- Keep documentation **up-to-date** with code changes
- Use **clear, concise language**
- Provide **examples** for complex workflows
- Document **dependencies and prerequisites**
- Include **troubleshooting** sections where relevant
- Follow **Markdown** best practices

### Makefiles

- Use **`.PHONY`** for non-file targets
- Include **help targets** with `##` comments for self-documentation
- Use **meaningful target names**
- Add **comments** for complex recipes
- Keep targets **focused and atomic**

## Git Workflow

### Commit Messages

- **MUST** use [Conventional Commits](https://www.conventionalcommits.org/) format
- Structure: `<type>(<scope>): <description>`
- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `build`, `ci`
- Examples:
  - `feat(keycloak): add user provisioning script`
  - `fix(container): resolve entrypoint permission issue`
  - `docs(readme): update setup instructions for MinIO`
  - `refactor(scripts): extract common functions to library`
  - `chore(shellcheck): fix SC2086 in check_release.sh`

### Commit Guidelines

- **Create atomic commits**: One logical change per commit
  - Fixing different shellcheck issues = separate commits per issue
  - Changing quotes from double to single = one commit
  - Adding a feature = one commit (but separate from unrelated fixes)
- **Only commit relevant changes**: No accidental debugging code, temp files, or unrelated modifications
- **Verify commit success**: Always check that `git commit` completed successfully
- **Write descriptive messages**: Explain *why*, not just *what*
- **Group related changes**: If modifying multiple files for one feature, that's one commit

### Code Review

- Reference any related issues or PRs in commit messages
- Keep commits reviewable (not too large)
- Ensure all tests pass before committing
- Run relevant quality checks (`shellcheck`, linters, etc.) before committing

### Pull Requests

When creating Pull Requests to merge into the **master** branch:

- **Use descriptive PR titles** following the Conventional Commits format: `<type>(<scope>): <description>` (scope is optional, e.g., `feat(auth): add OAuth2 support` or `fix: correct typo in README`)
- **Provide a clear description** that includes:
  - What changes are being made and why
  - Any breaking changes or important considerations
  - Related issue numbers (e.g., "Fixes #123" or "Relates to #456")
  - Testing steps or verification instructions
- **Ensure all checks pass**:
  - All commits follow Conventional Commits format
  - Code quality checks pass (shellcheck, linters, etc.)
  - No failing tests
  - License headers are present in all new files
- **Keep PRs focused**: One feature or fix per PR when possible
- **Request reviews** from appropriate team members
- **Address review feedback** promptly and professionally
- **Squash commits** if the PR history contains many small fixup commits (discuss with team)
- **Update documentation** if the PR changes user-facing features or APIs
- **Test in development environment** before requesting final review

## Environment and Paths

- **Never hardcode absolute paths** in scripts (except for well-known system paths)
- Use **relative paths** from script location when possible
- Reference the **docs-and-tools path** via Makefile variables or script detection
- Support both **local development** and **container environments**
- Use **environment variables** for configuration (see `.env` pattern)
- Keep **secrets in `.env.secret`**, never commit them

## Container Best Practices

- Prefer **Podman** over Docker in examples and scripts
- Use **descriptive container names**: `nc-dev-container`, `minio`, `nextcloud-dev`
- Make scripts **idempotent** where possible
- Support **both interactive and non-interactive** execution modes
