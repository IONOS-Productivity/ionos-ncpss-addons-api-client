<!--
SPDX-FileCopyrightText: 2026 STRATO GmbH
SPDX-License-Identifier: AGPL-3.0-or-later
-->
# AGENTS.md

This file provides guidance to AI Agents when working with code in this repository.

## What this repo is

An OpenAPI-generated PHP client library for the IONOS Nextcloud PSS Addon API. The source of truth is `openapi.json` (OpenAPI 3.1.0 spec). Everything in `lib/`, `test/`, and `docs/` is generated — edit the spec or the generator templates, then regenerate.

## Key commands

```bash
# Regenerate client from OpenAPI spec (clean → generate → cs:fix)
make php

# Regenerate only (no clean, no style fix)
make generate_php_client

# Apply code style fixes
make cs_fix
# or
composer cs:fix

# Check code style without modifying
composer cs:check

# Run unit tests
composer test:unit

# Static analysis (Psalm)
composer psalm

# PHP syntax lint
composer lint
```

Run a single test file:
```bash
./vendor/bin/phpunit test/Api/MailConfigurationAPIApiTest.php
```

## Architecture

```
lib/             Generated PHP client (Api/, Model/, support classes)
test/            Generated PHPUnit tests
docs/            Generated Markdown documentation
openapi-generator/
  php_lang.yaml  Generator config (namespace, package name, conventions)
  templates/php/ Custom Mustache templates that override generator defaults
openapi.json   OpenAPI spec — the single source of truth
```

The generator is `openapi-generator-cli` v7.14.0 (Node.js, see `openapitools.json` and `package.json`). Generator config is at `openapi-generator/php_lang.yaml`; custom template overrides live in `openapi-generator/templates/php/`.

Namespace: `IONOS\NextcloudPSS\AddonsAPI\Client`
Composer package: `ionos-productivity/ionos-ncpss-addons-api-client`
Minimum PHP: 8.1

## Workflow for changes

- **API changes**: modify `openapi.json`, then run `make php`. Do not hand-edit `lib/` or `test/` — they will be overwritten.
- **Code generation behavior changes**: modify templates in `openapi-generator/templates/php/` or `openapi-generator/php_lang.yaml`, then run `make php`.
- **Style rules**: edit `.php-cs-fixer.dist.php`.
- **Static analysis config**: edit `psalm.xml`.

## Updating the API from a remote server

`pull_api_definition.sh` fetches the OpenAPI spec from a running server, sanitizes it,
regenerates the PHP client, and creates a commit — all interactively.

```bash
# Standard usage
API_SPEC_HOST=hostname:port make update

# Skip SSL certificate validation (e.g. QA environments with self-signed certs)
ALLOW_INSECURE_SSL=1 API_SPEC_HOST=hostname:port make update
```

The script will:
1. Compare local, origin, and remote API versions
2. Create a feature branch (`feat/api-update-{version}-{timestamp}`)
3. Download and sanitize the spec (replaces the real host with `API_HOST`)
4. Offer to regenerate the PHP client (`make php`)
5. Stage relevant files and create a signed conventional commit
6. Offer to push the branch

After the PR is merged, tag the released version:

```bash
make tag
```

This creates and pushes an annotated git tag named after the API version in `openapi.json`.

## Commit messages

Format: `<type>(<scope>): <description>` — scope is optional.

Allowed types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `build`, `ci`

Rules:
- One logical change per commit (atomic)
- Explain *why*, not just *what*
- PR titles follow the same format

**Before committing**: plan the full commit sequence upfront — list each intended commit (message + files it stages) before making any of them.

**Untracked files**: never stage a file that is not already tracked by git without asking the user first. Untracked files may be personal scratch files (e.g. `MK.md`) that must not enter the commit history.

**Sign-off required**: every commit must include a `Signed-off-by` trailer. Use `git commit --signoff` (or `-s`).

Enforced by CI (`block-unconventional-commits.yml`) on all PRs.

## License headers

All new files must include an SPDX header with the current year.

PHP:
```php
/**
 * SPDX-FileCopyrightText: <YEAR> STRATO GmbH
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
```

Makefile / YAML / shell / config:
```
# SPDX-FileCopyrightText: <YEAR> STRATO GmbH
# SPDX-License-Identifier: AGPL-3.0-or-later
```

HTML / XML / Markdown:
```html
<!--
SPDX-FileCopyrightText: <YEAR> STRATO GmbH
SPDX-License-Identifier: AGPL-3.0-or-later
-->
```

Enforced by CI (`reuse.yml`) on all PRs.

## CI

GitHub Actions checks run on all PRs:

| Workflow | What it checks |
|----------|---------------|
| `phpunit.yml` | PHPUnit tests on PHP 8.1, 8.2, 8.3 (also runs daily) |
| `lint-php.yml` | PHP syntax on PHP 8.1–8.5 |
| `lint-php-cs.yml` | Code style via PHP-CS-Fixer (`composer cs:check`) |
| `psalm-matrix.yml` | Psalm static analysis on PHP 8.1, 8.2, 8.3 (also runs daily) |
| `block-unconventional-commits.yml` | Conventional Commits format |
| `fixup.yml` | Blocks `fixup!` / `squash!` commits |
| `reuse.yml` | SPDX license compliance |
