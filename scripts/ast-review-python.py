#!/usr/bin/env python3
"""
Kit — Python AST Code Review
Zero dependencies — uses only Python 3 stdlib.
Mirrors ast-review.ts output format (table, verdict, exit codes).

Usage:
  python3 ast-review-python.py [--changed-only] [--path DIR]

Exit codes:
  0 — No CRITICAL issues (may have WARNINGs)
  1 — Has CRITICAL issues
  2 — Runtime error (config/file loading)
"""

import ast
import json
import os
import re
import sys
from pathlib import Path


# ── Colors ──
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
CYAN = "\033[0;36m"
BOLD = "\033[1m"
DIM = "\033[2m"
NC = "\033[0m"


# ── Finding dataclass ──
class Finding:
    __slots__ = ("file", "line", "severity", "confidence", "issue", "fix")

    def __init__(self, file, line, severity, confidence, issue, fix):
        self.file = file
        self.line = line
        self.severity = severity
        self.confidence = confidence
        self.issue = issue
        self.fix = fix


# ── Config ──
EXCLUDE_DIRS = {
    "__pycache__", "venv", ".venv", "env", ".env", "node_modules",
    ".git", "dist", "build", ".tox", ".mypy_cache", ".pytest_cache",
    "migrations", "site-packages", ".eggs",
}
EXCLUDE_FILES = re.compile(r"(^test_|_test\.py$|^conftest\.py$)")

SECRET_PATTERNS = [
    (re.compile(r"""(sk_live_|sk_test_|pk_live_|pk_test_)[A-Za-z0-9]{10,}"""), "Stripe key"),
    (re.compile(r"""(api[_-]?key|apikey|secret[_-]?key|auth[_-]?token|access[_-]?token)\s*=\s*["'][A-Za-z0-9_\-]{8,}["']""", re.I), "Hardcoded secret"),
    (re.compile(r"""Bearer\s+[A-Za-z0-9_\-\.]{20,}"""), "Hardcoded Bearer token"),
    (re.compile(r"""-----BEGIN (RSA |EC )?PRIVATE KEY-----"""), "Private key in source"),
    (re.compile(r"""(ghp_|gho_|ghu_|ghs_|ghr_)[A-Za-z0-9_]{36,}"""), "GitHub token"),
    (re.compile(r"""AKIA[0-9A-Z]{16}"""), "AWS access key"),
    (re.compile(r"""xox[bporas]-[0-9]{10,}-[A-Za-z0-9]{10,}"""), "Slack token"),
]

# Django/Flask auth decorators
AUTH_DECORATORS = {
    "login_required", "permission_required", "user_passes_test",
    "staff_member_required", "jwt_required", "auth_required",
    "requires_auth", "authenticated", "permissions_required",
    "api_view",  # DRF requires explicit permission classes
}


def find_project_root():
    """Walk up to find .git directory."""
    d = Path.cwd()
    while d != d.parent:
        if (d / ".git").is_dir():
            return d
        d = d.parent
    return Path.cwd()


def read_manifest(root):
    """Read manifest YAML (simple line-based parser, no PyYAML needed)."""
    candidates = [
        root / "saascode-kit" / "manifest.yaml",
        root / ".saascode" / "manifest.yaml",
        root / "manifest.yaml",
        root / "saascode-kit.yaml",
    ]
    manifest = None
    for c in candidates:
        if c.is_file():
            manifest = c
            break
    if not manifest:
        return {}

    result = {}
    current_section = ""
    with open(manifest) as f:
        for line in f:
            stripped = line.rstrip()
            if not stripped or stripped.startswith("#"):
                continue
            indent = len(line) - len(line.lstrip())
            key_val = stripped.strip()
            if ":" not in key_val:
                continue
            key, _, val = key_val.partition(":")
            key = key.strip()
            val = val.strip().strip('"').strip("'")
            # Remove inline comments
            if "  #" in val:
                val = val[:val.index("  #")].strip()
            if indent == 0:
                current_section = key
                if val:
                    result[key] = val
            elif indent >= 2 and current_section:
                full_key = f"{current_section}.{key}"
                if val:
                    result[full_key] = val
    return result


def collect_py_files(root, backend_path, changed_only=False):
    """Collect Python files to scan."""
    search_dir = root / backend_path if (root / backend_path).is_dir() else root
    files = []

    if changed_only:
        import subprocess
        try:
            result = subprocess.run(
                ["git", "diff", "--name-only", "HEAD"],
                capture_output=True, text=True, cwd=str(root)
            )
            for f in result.stdout.strip().split("\n"):
                if f.endswith(".py"):
                    p = root / f
                    if p.is_file():
                        files.append(p)
            return files
        except Exception:
            pass  # Fall through to full scan

    for dirpath, dirnames, filenames in os.walk(str(search_dir)):
        # Prune excluded directories
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
        for fn in filenames:
            if fn.endswith(".py") and not EXCLUDE_FILES.search(fn):
                files.append(Path(dirpath) / fn)
    return files


def check_missing_auth(tree, filepath, rel_path, findings):
    """Check for view functions missing auth decorators."""
    for node in ast.walk(tree):
        if not isinstance(node, ast.FunctionDef):
            continue
        # Heuristic: function name suggests a view
        name = node.name
        is_view = any(kw in name for kw in ("view", "get", "post", "put", "delete", "patch", "list", "create", "update", "destroy", "retrieve"))
        # Also check for response-returning patterns
        if not is_view:
            continue
        # Check decorators
        decorator_names = set()
        for dec in node.decorator_list:
            if isinstance(dec, ast.Name):
                decorator_names.add(dec.id)
            elif isinstance(dec, ast.Attribute):
                decorator_names.add(dec.attr)
            elif isinstance(dec, ast.Call):
                if isinstance(dec.func, ast.Name):
                    decorator_names.add(dec.func.id)
                elif isinstance(dec.func, ast.Attribute):
                    decorator_names.add(dec.func.attr)
        if not decorator_names.intersection(AUTH_DECORATORS):
            findings.append(Finding(
                file=rel_path,
                line=node.lineno,
                severity="CRITICAL",
                confidence=85,
                issue=f"Function '{name}' appears to be a view but has no auth decorator",
                fix="Add @login_required, @permission_required, or equivalent auth decorator",
            ))


def check_bare_except(tree, filepath, rel_path, findings):
    """Check for bare except: blocks."""
    for node in ast.walk(tree):
        if isinstance(node, ast.ExceptHandler) and node.type is None:
            findings.append(Finding(
                file=rel_path,
                line=node.lineno,
                severity="WARNING",
                confidence=90,
                issue="Bare except: block catches all exceptions including SystemExit/KeyboardInterrupt",
                fix="Use 'except Exception:' or catch specific exception types",
            ))


def check_print_statements(tree, filepath, rel_path, findings):
    """Check for print() calls in production code, aggregate if >3/file."""
    prints = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            func = node.func
            if isinstance(func, ast.Name) and func.id == "print":
                prints.append(node.lineno)
    if len(prints) > 3:
        findings.append(Finding(
            file=rel_path,
            line=prints[0],
            severity="WARNING",
            confidence=80,
            issue=f"{len(prints)} print() statements found in production code",
            fix="Replace with logging module (import logging; logger = logging.getLogger(__name__))",
        ))
    else:
        for lineno in prints:
            findings.append(Finding(
                file=rel_path,
                line=lineno,
                severity="WARNING",
                confidence=75,
                issue="print() statement in production code",
                fix="Replace with logging.info() or logging.debug()",
            ))


def check_eval_exec(tree, filepath, rel_path, findings):
    """Check for eval() and exec() calls."""
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            func = node.func
            if isinstance(func, ast.Name) and func.id in ("eval", "exec"):
                findings.append(Finding(
                    file=rel_path,
                    line=node.lineno,
                    severity="CRITICAL",
                    confidence=95,
                    issue=f"{func.id}() can execute arbitrary code — code injection risk",
                    fix=f"Replace {func.id}() with safe alternatives (ast.literal_eval, importlib, etc.)",
                ))


def check_sql_injection(tree, filepath, rel_path, findings):
    """Detect f-strings as args to .execute(), .raw(), .extra()."""
    dangerous_methods = {"execute", "raw", "extra", "executemany"}

    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        # Check for method calls like cursor.execute(f"...")
        func = node.func
        method_name = None
        if isinstance(func, ast.Attribute) and func.attr in dangerous_methods:
            method_name = func.attr
        if not method_name:
            continue
        # Check if first arg is an f-string or string concatenation
        if node.args:
            arg = node.args[0]
            if isinstance(arg, ast.JoinedStr):
                findings.append(Finding(
                    file=rel_path,
                    line=node.lineno,
                    severity="CRITICAL",
                    confidence=95,
                    issue=f"SQL injection: f-string passed to .{method_name}()",
                    fix="Use parameterized queries: cursor.execute('SELECT ... WHERE id = %s', [user_id])",
                ))
            elif isinstance(arg, ast.BinOp) and isinstance(arg.op, (ast.Add, ast.Mod)):
                findings.append(Finding(
                    file=rel_path,
                    line=node.lineno,
                    severity="CRITICAL",
                    confidence=90,
                    issue=f"SQL injection: string concatenation/format in .{method_name}()",
                    fix="Use parameterized queries instead of string concatenation",
                ))


def check_hardcoded_secrets(filepath, rel_path, findings):
    """Regex scan source lines for hardcoded secrets."""
    try:
        with open(filepath) as f:
            lines = f.readlines()
    except Exception:
        return

    for i, line in enumerate(lines, 1):
        # Skip comments
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        for pattern, label in SECRET_PATTERNS:
            if pattern.search(line):
                findings.append(Finding(
                    file=rel_path,
                    line=i,
                    severity="CRITICAL",
                    confidence=90,
                    issue=f"Hardcoded secret detected: {label}",
                    fix="Move to environment variable or secrets manager",
                ))
                break  # One finding per line


def check_missing_type_hints(tree, filepath, rel_path, findings):
    """Check public functions missing return type hints."""
    for node in ast.iter_child_nodes(tree):
        if isinstance(node, ast.ClassDef):
            for item in ast.iter_child_nodes(node):
                if isinstance(item, ast.FunctionDef) and not item.name.startswith("_"):
                    if item.returns is None:
                        findings.append(Finding(
                            file=rel_path,
                            line=item.lineno,
                            severity="WARNING",
                            confidence=70,
                            issue=f"Public method '{item.name}' has no return type hint",
                            fix=f"Add return type: def {item.name}(...) -> ReturnType:",
                        ))
        elif isinstance(node, ast.FunctionDef) and not node.name.startswith("_"):
            if node.returns is None:
                findings.append(Finding(
                    file=rel_path,
                    line=node.lineno,
                    severity="WARNING",
                    confidence=70,
                    issue=f"Public function '{node.name}' has no return type hint",
                    fix=f"Add return type: def {node.name}(...) -> ReturnType:",
                ))


def check_empty_except_body(tree, filepath, rel_path, findings):
    """Check for except blocks with only 'pass' and no comment."""
    try:
        with open(filepath) as f:
            source_lines = f.readlines()
    except Exception:
        return

    for node in ast.walk(tree):
        if not isinstance(node, ast.ExceptHandler):
            continue
        body = node.body
        if len(body) == 1 and isinstance(body[0], ast.Pass):
            # Check if there's a comment on the pass line
            line_idx = body[0].lineno - 1
            if line_idx < len(source_lines):
                line_text = source_lines[line_idx]
                if "#" not in line_text:
                    findings.append(Finding(
                        file=rel_path,
                        line=node.lineno,
                        severity="WARNING",
                        confidence=85,
                        issue="Empty except block silently swallows errors",
                        fix="Add error logging, re-raise, or add a comment explaining why",
                    ))


def analyze_file(filepath, root, findings):
    """Run all checks on a single Python file."""
    rel_path = str(filepath.relative_to(root))

    try:
        with open(filepath) as f:
            source = f.read()
    except Exception as e:
        print(f"  {YELLOW}Warning: Could not read {rel_path}: {e}{NC}", file=sys.stderr)
        return False

    try:
        tree = ast.parse(source, filename=str(filepath))
    except SyntaxError as e:
        print(f"  {YELLOW}Warning: Syntax error in {rel_path}: {e}{NC}", file=sys.stderr)
        return False

    check_missing_auth(tree, filepath, rel_path, findings)
    check_bare_except(tree, filepath, rel_path, findings)
    check_empty_except_body(tree, filepath, rel_path, findings)
    check_print_statements(tree, filepath, rel_path, findings)
    check_eval_exec(tree, filepath, rel_path, findings)
    check_sql_injection(tree, filepath, rel_path, findings)
    check_hardcoded_secrets(filepath, rel_path, findings)
    check_missing_type_hints(tree, filepath, rel_path, findings)
    return True


def print_table(findings):
    """Print findings as a markdown table matching ast-review.ts format."""
    print()
    print(f"| {'#':>3} | File:Line | Severity | Confidence | Issue | Fix |")
    print(f"|{'---':>4}|----------|----------|------------|-------|-----|")
    for i, f in enumerate(findings, 1):
        sev_color = RED if f.severity == "CRITICAL" else YELLOW
        print(
            f"| {i:>3} | {f.file}:{f.line} "
            f"| {sev_color}{f.severity}{NC} "
            f"| {f.confidence}% "
            f"| {f.issue} "
            f"| {f.fix} |"
        )
    print()


def main():
    # Parse args
    changed_only = "--changed-only" in sys.argv
    custom_path = None
    for i, arg in enumerate(sys.argv[1:], 1):
        if arg == "--path" and i < len(sys.argv) - 1:
            custom_path = sys.argv[i + 1]

    root = find_project_root()
    manifest = read_manifest(root)

    backend_path = manifest.get("paths.backend", ".")
    project_name = manifest.get("project.name", "Python Project")
    framework = manifest.get("stack.backend.framework", "generic")

    if custom_path:
        backend_path = custom_path

    print()
    print(f"{BOLD}AST Code Review{NC}")
    print("=" * 40)
    print(f"  Project: {project_name} ({framework})")
    print(f"  Language: Python")
    print(f"  Path: {backend_path}")
    print()

    # Collect files
    print(f"[1/3] Collecting Python files...")
    py_files = collect_py_files(root, backend_path, changed_only)
    print(f"  Scanning {len(py_files)} source files")
    print()

    if not py_files:
        print(f"  {YELLOW}No Python files found to scan.{NC}")
        print()
        print(f"{BOLD}VERDICT:{NC} {GREEN}APPROVE{NC} — No files to review")
        return 0

    # Analyze
    print(f"[2/3] Analyzing Python source...")
    findings = []
    clean_files = []
    scanned = 0

    for filepath in py_files:
        before = len(findings)
        ok = analyze_file(filepath, root, findings)
        if ok:
            scanned += 1
            if len(findings) == before:
                clean_files.append(str(filepath.relative_to(root)))

    # Sort findings: CRITICAL first, then by file
    findings.sort(key=lambda f: (0 if f.severity == "CRITICAL" else 1, f.file, f.line))

    print(f"[3/3] Generating report...")
    print()

    # Print table
    if findings:
        print_table(findings)

    # Summary
    critical_count = sum(1 for f in findings if f.severity == "CRITICAL")
    warning_count = sum(1 for f in findings if f.severity == "WARNING")

    print("=" * 40)
    print(f"  Files scanned:  {scanned}")
    print(f"  Findings:       {RED}{critical_count} critical{NC}, {YELLOW}{warning_count} warnings{NC}")
    print()

    # Clean files (max 20)
    if clean_files:
        print("Clean files (no issues):")
        for cf in clean_files[:20]:
            print(f"  {GREEN}\u2713{NC} {cf}")
        if len(clean_files) > 20:
            print(f"  ... and {len(clean_files) - 20} more")
        print()

    # Verdict
    if critical_count > 0:
        print(f"{BOLD}VERDICT:{NC} {RED}REQUEST CHANGES{NC} \u2014 {critical_count} critical issues found")
        return 1
    elif warning_count > 0:
        print(f"{BOLD}VERDICT:{NC} {YELLOW}COMMENT{NC} \u2014 {warning_count} warnings to consider")
        return 0
    else:
        print(f"{BOLD}VERDICT:{NC} {GREEN}APPROVE{NC} \u2014 No issues detected")
        return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        print(f"{RED}Runtime error: {e}{NC}", file=sys.stderr)
        sys.exit(2)
