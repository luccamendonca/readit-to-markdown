# file-output Specification

## Purpose

Define how `readit` resolves the output directory, names the output file, and writes the final `.md` to disk. The naming convention enables chronological sorting and slug-based search inside Obsidian or any file browser.

## Requirements

### Requirement: Output directory comes from flag or env var

`readit` SHALL resolve the output directory from these sources, in this priority order:

1. `--dir <path>` command-line flag
2. `READIT_DIR` environment variable

If neither is set (or both resolve to the empty string), `readit` SHALL exit with code `1` and the error message `error: no output dir: pass --dir or set $READIT_DIR`.

#### Scenario: Flag takes precedence over env var
- **WHEN** `--dir /tmp/a` is passed AND `READIT_DIR=/tmp/b` is set
- **THEN** the output directory SHALL be `/tmp/a`

#### Scenario: Env var is used when flag is absent
- **WHEN** `--dir` is not passed AND `READIT_DIR=/tmp/b` is set
- **THEN** the output directory SHALL be `/tmp/b`

#### Scenario: Missing config aborts the run
- **WHEN** `--dir` is not passed AND `READIT_DIR` is unset or empty
- **THEN** `readit` SHALL exit with code `1`
- **AND** SHALL fire an error desktop notification unless suppressed
- **AND** MUST NOT read the clipboard

### Requirement: Path expansion handles ~ and shell-escape leaks

The resolved path SHALL be normalized before use:

1. Leaked shell escapes (`\<space>`, `\<tab>`, `\\`) SHALL be unescaped first.
2. A leading `~/` SHALL be expanded to the user's home directory.

#### Scenario: Tilde expansion
- **WHEN** the resolved value starts with `~/`
- **THEN** `~/` SHALL be replaced with the result of `os.UserHomeDir()` followed by a path separator

#### Scenario: Backslash-space tolerance
- **WHEN** the resolved value contains `\ ` (a literal backslash followed by space)
- **THEN** the backslash SHALL be stripped so the path becomes `<a> <b>` (a single space)
- **AND** this SHALL apply before tilde expansion

#### Scenario: Other backslashes are preserved
- **WHEN** the resolved value contains a backslash that is not followed by space, tab, or another backslash
- **THEN** the backslash SHALL be preserved verbatim (Windows path compatibility)

### Requirement: Output directory is created on demand

`readit` SHALL ensure the output directory exists before writing.

#### Scenario: Missing directory is created recursively
- **WHEN** the resolved output directory does not exist
- **THEN** `readit` SHALL create it (and any missing parents) with mode `0755`

#### Scenario: mkdir failure aborts the run
- **WHEN** the directory cannot be created (permission denied, parent is a file, etc.)
- **THEN** `readit` SHALL exit with code `1`
- **AND** SHALL print `error: mkdir <path>: <reason>` to stderr
- **AND** SHALL fire an error desktop notification unless suppressed

### Requirement: Filename follows YYYY-MM-DD_<slug>.md

The output filename SHALL be exactly `<YYYY-MM-DD>_<slug>.md`, where:

- `<YYYY-MM-DD>` is the local-time date at the moment `readit` runs (NOT the article's publish date)
- `<slug>` is derived from the article `title` per the slugification rules below

#### Scenario: Date is local-time today
- **WHEN** `readit` runs on `2026-04-26` in the user's local timezone
- **THEN** every file written during that run SHALL begin with `2026-04-26_`
- **AND** the filename date SHALL NOT use the article's `og:published_time` even when present

### Requirement: Slug derivation is deterministic

The slug SHALL be derived from the resolved `title` by:

1. Lowercasing the entire string.
2. Replacing every run of one or more characters not in `[a-z0-9]` with a single `-`.
3. Trimming leading and trailing `-`.
4. Truncating to at most 80 bytes, then re-trimming any trailing `-`.

If the resulting slug is empty, the filename SHALL use slug `untitled`.

#### Scenario: Title with punctuation produces a clean slug
- **WHEN** `title` is `"Minions: Stripe's one-shot, end-to-end coding agents"`
- **THEN** the slug SHALL be `minions-stripe-s-one-shot-end-to-end-coding-agents`

#### Scenario: Empty title falls back to "untitled"
- **WHEN** `title` resolves to an empty string OR a string composed only of non-alphanumeric characters
- **THEN** the filename SHALL be `<YYYY-MM-DD>_untitled.md`

#### Scenario: Long title is truncated at 80 bytes
- **WHEN** the slugified title exceeds 80 bytes
- **THEN** the slug SHALL be cut to 80 bytes
- **AND** any trailing `-` left by the cut SHALL be trimmed

### Requirement: Write is atomic-from-the-caller's-perspective and verbose

`readit` SHALL write the file via a single `os.WriteFile` call with mode `0644`. After a successful write, the absolute path of the written file SHALL be printed to stdout on its own line.

#### Scenario: Successful write prints path to stdout
- **WHEN** the file is written without error
- **THEN** stdout SHALL contain exactly one line: the absolute path of the file
- **AND** stderr SHALL contain only the `fetching <url>` line (and any informational warnings)

#### Scenario: Existing file is overwritten
- **WHEN** a file with the same `YYYY-MM-DD_<slug>.md` name already exists in the output dir
- **THEN** `readit` SHALL overwrite it without prompting
- **AND** MUST NOT append a numeric suffix or back up the previous file

#### Scenario: Write failure aborts the run
- **WHEN** `os.WriteFile` returns an error
- **THEN** `readit` SHALL exit with code `1`
- **AND** SHALL print `error: write <path>: <reason>` to stderr
- **AND** SHALL fire an error desktop notification unless suppressed
