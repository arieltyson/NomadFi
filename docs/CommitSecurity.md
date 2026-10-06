# Commit security checks

Install Python 3 and Gitleaks 8.30.0 or newer, then enable the repository hook:

```sh
brew install gitleaks
bash scripts/install-hooks.sh
```

The local pre-commit hook normalizes staged localization catalogs without
staging other edits. It then scans the complete staged versions of added,
modified, copied, and renamed files. Unstaged edits and ignored files are
not copied into the scan. Deletions are allowed so private data can be
removed. No scan data is sent to an external service.

The check combines Gitleaks' built-in credential rules with Plaid-specific
rules, a checksum check for possible payment-card numbers, and labeled
bank-account/routing and government identifiers. It also blocks private
paths even if force-added: environment files (except `.env.example`),
`Secrets/`, validation evidence, owner-only documents, private-key files,
database files, and logs. `.env.example` still undergoes content scanning.

Findings show file, line, and rule only. Detected values and matching lines
are not printed. Scans use a temporary directory removed on normal exit;
Gitleaks reports stay in memory. Missing tools, scanner errors, symlinks,
submodules, or files exceeding 25 MiB block the commit rather than silently
skipping inspection. Scanning runs after localization normalization so it
checks the content that will actually be committed.

## Resolving a blocked commit

Remove the private value from the staged file, replace it with a clear
placeholder or environment lookup, and stage the corrected version.
Keep live credentials in ignored local files. Use generated synthetic
values for tests; complete test card numbers are deliberately flagged too.
For a false positive, review the rule and add a narrowly scoped regression
test before changing it. There is no blanket test-directory exemption,
inline `gitleaks:allow` bypass, or `.gitleaksignore` suppression in this hook.
Never solve a warning by adding the real secret to an allowlist.

Run the scan and regression tests explicitly with:

```sh
python3 scripts/check-staged-security.py
python3 -B -m unittest discover -s scripts -p 'test_commit_security.py' -v
```

These checks cannot identify every private fact, recognize personal
financial narratives, or read information inside screenshots/PDFs. Review
those manually. They do not audit existing Git history, revoke leaked
credentials, or provide server-side enforcement. Local hooks must be
installed per checkout and can be bypassed by Git's `--no-verify` option.
Keep `.gitleaks.toml` and these scripts under review like other security code.

Xcode's **Settings → Editing → Automatically generate string catalog
comments** should remain off. This is a per-user Xcode preference; the
hook strips generated comments as a fallback for other contributors.
