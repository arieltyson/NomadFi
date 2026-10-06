import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent
SCANNER = ROOT / "scripts/check-staged-security.py"
NORMALIZER = ROOT / "scripts/normalize-staged-localizations.py"
spec = importlib.util.spec_from_file_location("security", SCANNER)
security = importlib.util.module_from_spec(spec)
spec.loader.exec_module(security)


def synthetic_token():
    return "access-" + "production-" + "12345678-1234-1234-1234-123456789abc"


class PolicyTests(unittest.TestCase):
    def test_card_checksum_and_boundaries(self):
        card = "4242" * 4
        self.assertTrue(security.luhn(card))
        self.assertFalse(security.luhn(card[:-1] + "3"))
        self.assertFalse(security.luhn("0" * 16))
        for text in [card, " ".join(["4242"] * 4), "-".join(["4242"] * 4)]:
            self.assertEqual(security.financial_findings(text.encode()), [(1, "possible-payment-card")])
        self.assertEqual(security.financial_findings(("https://example.com/" + card).encode()), [])
        self.assertEqual(security.financial_findings(("hash" + card + "abc").encode()), [])

    def test_private_paths_and_example_exception(self):
        for path in [".env", "nested/.env.production.local", "production.env", "Secrets/config.json",
                     "docs/ARIEL.md", "docs/financekit-application.md",
                     "docs/research/PlaidValidationEvidence/run.md", "trace.log",
                     "default.store", "bank.sqlite", "default.store-wal", "identity.p12", ".ssh/id_ed25519"]:
            with self.subTest(path=path):
                self.assertTrue(security.private_path(path))
        for path in ["tools/.env.example", "app.swift", "SharedSettings/Debug.xcconfig"]:
            self.assertFalse(security.private_path(path))

    def test_labeled_identifier(self):
        value = b'account_number = "' + b"12345" + b'6789"'
        self.assertEqual(security.financial_findings(value), [(1, "financial-or-government-identifier")])
        self.assertEqual(security.financial_findings(b'account_number = "<your account number>"'), [])


class StagedScanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        security.dependencies()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="nomadfi-hook-test-")
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.git("init", "-q")
        self.git("config", "user.name", "Hook Test")
        self.git("config", "user.email", "hook-test@example.invalid")
        self.git("config", "core.hooksPath", str(self.repo / "unused-hooks"))

    def git(self, *args):
        return subprocess.run(["git", *args], cwd=self.repo, capture_output=True, check=True).stdout

    def stage(self, name, value):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value)
        self.git("add", "--", name)

    def scan(self, env=None):
        return subprocess.run([sys.executable, str(SCANNER)], cwd=self.repo,
                              env=env, capture_output=True, text=True)

    def assert_blocked_without_value(self, result, value):
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertNotIn(value, result.stdout + result.stderr)

    def test_clean_initial_commit_and_placeholders(self):
        self.stage("README.md", "No sensitive values here.\n")
        self.stage(".env.example", "PLAID_SECRET=your_plaid_secret_here\n")
        self.assertEqual(self.scan().returncode, 0)

    def test_staged_secret_is_blocked_even_if_working_copy_is_clean(self):
        secret = synthetic_token()
        self.stage("config.txt", secret)
        (self.repo / "config.txt").write_text("clean unstaged edit")
        result = self.scan()
        self.assert_blocked_without_value(result, secret)
        self.assertIn("nomadfi-plaid-token", result.stderr)

    def test_unstaged_secret_does_not_enter_snapshot(self):
        self.stage("config.txt", "clean staged content")
        (self.repo / "config.txt").write_text(synthetic_token())
        self.assertEqual(self.scan().returncode, 0)

    def test_provider_key_is_caught_by_default_rules(self):
        secret = "gh" + "p_" + "AbCdEf0123456789" * 2 + "abcd"
        self.stage("source.swift", 'let token = "' + secret + '"')
        self.assert_blocked_without_value(self.scan(), secret)

    def test_file_extension_cannot_bypass_credential_scan(self):
        for name in ["artwork.svg", "package-lock.json", ".gitleaks.toml"]:
            with self.subTest(name=name):
                self.stage(name, synthetic_token())
                result = self.scan()
                self.assert_blocked_without_value(result, synthetic_token())
                self.assertIn(name, result.stderr)

    def test_paths_with_spaces_and_newlines(self):
        self.stage("odd name\nsource.txt", synthetic_token())
        result = self.scan()
        self.assert_blocked_without_value(result, synthetic_token())
        self.assertIn("odd name\\nsource.txt", result.stderr)

    def test_plaid_hex_credentials_and_broker_secret(self):
        for label, length in [("PLAID_CLIENT_ID", 24), ("PLAID_SECRET", 30),
                              ("PLAID_BROKER_SHARED_SECRET", 64)]:
            with self.subTest(label=label):
                secret = ("abcdef0123456789" * 4)[:length]
                self.stage("config.txt", label + "=" + secret)
                self.assert_blocked_without_value(self.scan(), secret)

    def test_private_key(self):
        marker = "-----BEGIN " + "RSA PRIVATE KEY-----"
        self.stage("source.txt", marker + "\n" + "AbCd" * 100 + "\n-----END RSA PRIVATE KEY-----")
        self.assert_blocked_without_value(self.scan(), marker)

    def test_card_and_identifier_are_redacted(self):
        card = "4242" * 4
        self.stage("bank.txt", "card: " + card)
        self.assert_blocked_without_value(self.scan(), card)
        self.assertIn("possible-payment-card", self.scan().stderr)

    def test_force_added_private_file_is_blocked(self):
        self.stage(".gitignore", ".env*\n")
        (self.repo / ".env.production.local").write_text("not even a secret")
        self.git("add", "-f", ".env.production.local")
        result = self.scan()
        self.assertEqual(result.returncode, 1)
        self.assertIn("private-file", result.stderr)

    def test_renamed_blob_is_scanned(self):
        self.stage("old.txt", synthetic_token())
        self.git("commit", "-qm", "fixture")
        self.git("mv", "old.txt", "renamed.txt")
        self.assert_blocked_without_value(self.scan(), synthetic_token())

    def test_deleting_sensitive_file_is_allowed(self):
        self.stage(".env", synthetic_token())
        self.git("commit", "-qm", "fixture")
        self.git("rm", ".env")
        self.assertEqual(self.scan().returncode, 0)

    def test_inline_allow_comment_cannot_hide_secret(self):
        self.stage("source.txt", synthetic_token() + " # gitleaks:allow")
        self.assert_blocked_without_value(self.scan(), synthetic_token())

    def test_missing_scanner_fails_closed(self):
        self.stage("source.txt", "safe")
        binaries = self.repo / "bin"
        binaries.mkdir()
        (binaries / "git").symlink_to(shutil.which("git"))
        env = dict(os.environ, PATH=str(binaries))
        result = self.scan(env)
        self.assertEqual(result.returncode, 2)
        self.assertIn("Gitleaks is required", result.stderr)

    def test_scanner_failure_does_not_echo_its_output(self):
        self.stage("source.txt", "safe")
        binaries = self.repo / "bin"
        binaries.mkdir()
        scanner = binaries / "gitleaks"
        scanner.write_text('#!/bin/sh\nif [ "$1" = version ]; then echo 8.30.1; exit 0; fi\necho PRIVATE_OUTPUT; exit 2\n')
        scanner.chmod(0o755)
        result = self.scan(dict(os.environ, PATH=str(binaries) + os.pathsep + os.environ["PATH"]))
        self.assertEqual(result.returncode, 2)
        self.assertNotIn("PRIVATE_OUTPUT", result.stdout + result.stderr)

    def test_large_file_is_blocked(self):
        path = self.repo / "large.txt"
        with path.open("wb") as file:
            file.truncate(security.MAX_FILE_BYTES + 1)
        self.git("add", "large.txt")
        self.assertIn("file-exceeds-25-MiB", self.scan().stderr)

    def test_symlink_is_blocked_without_following_it(self):
        (self.repo / "link").symlink_to("/outside/repository")
        self.git("add", "link")
        self.assertIn("unscannable-symlink", self.scan().stderr)

    def test_catalog_normalization_preserves_partial_staging(self):
        catalog = '{\n  "strings" : {\n    "Hello" : {\n      "comment" : "Generated",\n      "isCommentAutoGenerated" : true\n    }\n  }\n}\n'
        self.stage("Localizable.xcstrings", catalog)
        worktree = catalog.replace("Hello", "Unstaged label")
        (self.repo / "Localizable.xcstrings").write_text(worktree)
        subprocess.run([sys.executable, str(NORMALIZER)], cwd=self.repo, check=True)
        staged = json.loads(self.git("show", ":Localizable.xcstrings"))
        self.assertEqual(staged, {"strings": {"Hello": {}}})
        self.assertEqual((self.repo / "Localizable.xcstrings").read_text(), worktree)

    def test_fully_staged_catalog_stays_clean_after_normalization(self):
        catalog = '{\n  "strings" : {\n    "Hello" : {\n      "comment" : "Generated",\n      "isCommentAutoGenerated" : true\n    }\n  }\n}\n'
        self.stage("Localizable.xcstrings", catalog)
        subprocess.run([sys.executable, str(NORMALIZER)], cwd=self.repo, check=True)
        self.assertEqual((self.repo / "Localizable.xcstrings").read_bytes(),
                         self.git("show", ":Localizable.xcstrings"))

    def test_real_hook_blocks_commit(self):
        shutil.copytree(ROOT / "scripts", self.repo / "scripts", ignore=shutil.ignore_patterns("__pycache__"))
        shutil.copytree(ROOT / ".githooks", self.repo / ".githooks")
        shutil.copy(ROOT / ".gitleaks.toml", self.repo / ".gitleaks.toml")
        self.git("config", "core.hooksPath", ".githooks")
        self.stage("bank.txt", synthetic_token())
        result = subprocess.run(["git", "commit", "-qm", "must fail"], cwd=self.repo,
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn(synthetic_token(), result.stdout + result.stderr)
        head = subprocess.run(["git", "rev-parse", "--verify", "HEAD"], cwd=self.repo, capture_output=True)
        self.assertNotEqual(head.returncode, 0)


if __name__ == "__main__":
    unittest.main()
