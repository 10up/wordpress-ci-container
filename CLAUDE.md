# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Keep this file current.** Any change to the Dockerfile, build/CI scripts, workflow matrix, env-var contract, or tests must be reflected here in the same change.

## What this repo is

Source for the `10up/wordpress-ci` Docker images: one Debian-based PHP image per PHP version, bundling the tooling WordPress CI/CD pipelines need (composer, nvm/node, wp-cli, ClamAV, kubectl, docker-cli, terminus, gh, glab, awscli/ansible via pip, etc.). There is no application code. The deliverables are the image and the helper scripts it ships in `/custom-scripts`.

## Commands

```bash
# Build locally (PHP_IMG is required, there is no default)
docker build --build-arg PHP_IMG=php:8.3-bookworm --build-arg COMPOSER_VERSION=2 -t wordpress-ci:local .

# Try a script inside the image against the current dir
docker run --rm -v "$PWD":/work -w /work wordpress-ci:local virus-scan

# Tests (host-side, no Docker; fake binaries/functions on PATH or NVM_DIR)
bash tests/test-virus-scan.sh
bash tests/test-install-node.sh

# Lint shell (all current findings are info-level)
shellcheck scripts/* build/*.sh entrypoint.sh tests/*.sh
```

`tests/test-virus-scan.sh` hardcodes `mktemp -d /private/tmp/...`, so it only runs on macOS as written. `tests/test-install-node.sh` uses `${TMPDIR:-/tmp}` and is portable. CI does not run the tests or shellcheck. The only CI job is the image build.

## Architecture

**Image build (`Dockerfile`)**, in this order: apt packages (incl. `clamav-daemon`), then `freshclam` early so the virus DB is baked in (running it later in the file hit bugs), locale, PHP ini (`memory_limit=-1`) and extensions (`opentelemetry` only on PHP ≥ 8.1), nvm in `/tmp/.nvm` + the latest `NODE_LTS_COUNT` (default 3) Node LTS lines via `build/install-node.sh`, pip `requirements.txt` (uses `PIP_BREAK_SYSTEM_PACKAGES=1` for bookworm), composer, wp-cli, then docker-cli/kubectl/terminus/gh/glab, which are always the latest release and unpinned. Finally `scripts/*` go to `/custom-scripts` (on `PATH`), plus `BASH_ENV=/root/.bashrc` so non-interactive CI shells load nvm and the `wp` alias.

- `build/install-composer.sh` installs `composer1-bin`, `composer2-bin`, and a default `composer` chosen by the `COMPOSER_VERSION` build arg.
- `build/install-wpcli.sh` installs `/usr/local/bin/wp-cli.phar`. `wp` exists only as a `.bashrc` alias (`php wp-cli.phar --allow-root`), not as a binary. Bash doesn't expand aliases in non-interactive shells, so `bash -c 'wp ...'` fails with "command not found" even though `BASH_ENV` loads `.bashrc`.
- `build/install-node.sh [count]` installs nvm's relative aliases oldest first: `lts/-2`, `lts/-1`, then `lts/*`. It resolves them at build time, so the weekly no-cache rebuild rolls the set forward automatically when a new line goes LTS (versions get dropped the same way). It rejects a count that isn't a positive integer. Keeping 3 is a deliberate choice, even when the oldest line is past EOL (e.g. Node 20 until 26 goes LTS). The Dockerfile then runs `nvm alias default 'lts/*'`. Pipelines switch with `nvm use <major>` or run `nvm install <v>` for anything else.

**Runtime (`entrypoint.sh`, POSIX sh)**: sources nvm, then applies optional env vars: `PRIVATE_KEY`/`PUBLIC_KEY` go to `/root/.ssh/id_rsa{,.pub}`, `TERMINUS_TOKEN` runs a terminus login, `GIT_USER_NAME`/`GIT_USER_EMAIL` set git global config, `COMPOSER_CONFIG` runs `composer config -g`, and `BUILD_CACHE_DIR` points the composer and npm caches at `$BUILD_CACHE_DIR/.composer-cache` and `$BUILD_CACHE_DIR/node_modules_cache` (for GitLab: `${CI_PROJECT_DIR}`). It then prints tool versions and `exec "$@"`. The version printout still calls grunt/gulp/bower/yarn, which were removed from the image, so those lines print "not found". This is harmless because the script has no `set -e`.

**CI scripts (`scripts/`, extensionless, copied to `/custom-scripts`)**:
- `all-scripts` *sources* (does not execute) every top-level `/custom-scripts/*.sh` (user-added), then `php-syntax`, then `virus-scan`, all under `set -euo pipefail`. Because they are sourced, an `exit` in any of them ends the whole run, and `virus-scan` always exits. It must stay last.
- `php-syntax` runs `php -l` in parallel (`xargs -P10`) on every `*.php` outside `vendor/`. Output goes to stdout only when `IS_DEBUG_ENABLED=true`.
- `virus-scan` starts a private, temporary `clamd` (generated config in a `mktemp` dir, `LogClean yes`, excludes `.composer-cache` and `node_modules_cache`), waits up to 30s for `--ping`, runs `clamdscan --multiscan "$PWD"`, then kills the daemon and removes the temp dir via an EXIT trap. The scanned-file count comes from the **daemon log** (`: OK` / ` FOUND` lines), because clamdscan's report on a directory doesn't give a per-file count. `: OK` lines are filtered out of the printed report. **Exit contract:** 1 only when an infection is found. Every scanner or daemon failure exits 0 (fail-open, so a broken scanner never blocks a deploy). `CLAMAV_DB_DIR` and `TMPDIR` can be overridden; the tests rely on both.
- `slack-message` posts a Slack attachment via webhook. `-u` and `-m` are required (see the README for all flags).

**Tests** follow one pattern: fake the external tool, run the real script, then assert exit codes and the calls or output that were recorded.
- `test-virus-scan.sh` stubs `clamd`/`clamdscan` as bash scripts driven by `FAKE_SCAN_EXIT` (0 clean, 1 infected, 2 scan error, 3 no summary) and `FAKE_START_MODE`. It checks the generated `clamd.conf`, the output, and that the daemon was stopped. Changes to virus-scan output or config need matching test updates.
- `test-install-node.sh` points `NVM_DIR` at a fake `nvm.sh` that defines recording `nvm`/`npm` functions (`FAKE_FAIL_VERSION` makes one install fail). It checks install order, the count handling, and that the script stops at the first failed install.

## Release / CI (`.github/workflows/build.yaml`)

- Runs on every push to any branch, plus a weekly rebuild (Sun 04:00 UTC) to pick up security updates. Builds are always `no-cache: true`, wrapped in a 3-attempt retry.
- The matrix is `base_container`. Each entry needs a matching "Set PHP X settings" step that sets `BUILD_TAGS` and `COMPOSER_VERSION`. PHP 7.4 uses Composer 1 and also owns the `latest` tag. All others use Composer 2. 7.4 and 8.0 use `-bullseye` images, because `php:7.4-bookworm` and `php:8.0-bookworm` don't exist. 8.1–8.4 use `-bookworm`.
- **7.4 and 8.0 builds currently fail.** Debian bullseye support ended on Aug 31, 2026. `deb.debian.org` still lists `bullseye-security` packages, but the `.deb` files return 404, so the first `apt-get install` exits with code 100. The matrix has `fail-fast: false` set **temporarily**, so 8.1–8.4 finish and report their own results instead of being cancelled. Expect 7.4 and 8.0 to show red until they're dropped (pending a team decision). Remove `fail-fast: false` again once testing is done.
- Images push to Docker Hub only from `trunk`. Branch builds only validate. Adding a PHP version means adding a matrix entry plus a settings step (the README has the template).

## Known doc drift

The README lists `azure-cli` (not installed), and spells glab as "glap". `.bowerrc` is a leftover and isn't used by the build.
