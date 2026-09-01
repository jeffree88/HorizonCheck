#!/usr/bin/env python3
"""Lightweight syntax-shape audit for shipped HorizonCheck runtime Lua files.

This is not a full Lua compiler. It catches the release-breaking mistakes that
have historically mattered for HorizonCheck: unterminated strings/comments,
unbalanced (), [] or {}, and unmatched function/if/do/repeat blocks.
"""
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


def strip_strings_and_comments(text: str) -> tuple[str, str]:
    out: list[str] = []
    i = 0
    state = "code"
    quote = ""
    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""
        if state == "code":
            if ch == "-" and nxt == "-":
                if text[i + 2 : i + 4] == "[[":
                    state = "long_comment"
                    out.extend("    ")
                    i += 4
                else:
                    state = "line_comment"
                    out.extend("  ")
                    i += 2
            elif ch in ("'", '"'):
                quote = ch
                state = "string"
                out.append(" ")
                i += 1
            elif ch == "[" and nxt == "[":
                state = "long_string"
                out.extend("  ")
                i += 2
            else:
                out.append(ch)
                i += 1
        elif state == "string":
            if ch == "\\":
                out.extend("  ")
                i += 2
            else:
                if ch == quote:
                    state = "code"
                out.append("\n" if ch == "\n" else " ")
                i += 1
        elif state == "line_comment":
            if ch == "\n":
                state = "code"
                out.append("\n")
            else:
                out.append(" ")
            i += 1
        elif state in ("long_comment", "long_string"):
            if ch == "]" and nxt == "]":
                state = "code"
                out.extend("  ")
                i += 2
            else:
                out.append("\n" if ch == "\n" else " ")
                i += 1
    return "".join(out), state


def audit(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8", errors="replace")
    code, state = strip_strings_and_comments(text)
    issues: list[str] = []
    if state != "code":
        issues.append(f"unterminated {state.replace('_', ' ')}")

    for left, right in (("(", ")"), ("[", "]"), ("{", "}")):
        balance = 0
        for ch in code:
            if ch == left:
                balance += 1
            elif ch == right:
                balance -= 1
                if balance < 0:
                    issues.append(f"unexpected {right}")
                    break
        if balance > 0:
            issues.append(f"{balance} unmatched {left}")

    words = re.findall(r"\b(?:function|if|do|repeat|end|until)\b", code)
    balance = 0
    for word in words:
        if word in ("function", "if", "do", "repeat"):
            balance += 1
        else:
            balance -= 1
            if balance < 0:
                issues.append(f"unexpected block closer: {word}")
                break
    if balance > 0:
        issues.append(f"{balance} unmatched Lua block opener(s)")
    return issues


def main() -> int:
    paths = [ROOT / "horizoncheck.lua", *sorted((ROOT / "modules").glob("*.lua"))]
    failures = 0
    for path in paths:
        issues = audit(path)
        if issues:
            failures += len(issues)
            print(f"FAIL: {path.relative_to(ROOT)}: " + "; ".join(issues))
    if failures:
        return 1
    print(f"PASS: runtime Lua structure audit clean ({len(paths)} files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
