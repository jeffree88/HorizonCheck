#!/usr/bin/env python3
"""Audit shipped quest metadata for runtime-only fields.

Historical pass bookkeeping belongs in release notes/tools, not in Lua records
loaded by HorizonCheck.  This keeps runtime metadata compact and prevents old
pass markers from being mistaken for behavior-bearing fields.
"""
from pathlib import Path
import re
import sys

FORBIDDEN = re.compile(
    r'\b(?:catalog_completion_pass\d*|catalog_large_pass\d*|'
    r'check_reqs_pass\d*|quality_source_pass\d*)\s*='
)

def main() -> int:
    root = Path(__file__).resolve().parents[1]
    total = 0
    for path in sorted((root / 'data').glob('quest_metadata*.lua')):
        for line_no, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
            if FORBIDDEN.search(line):
                print(f'{path}:{line_no}: obsolete build-history flag in runtime metadata')
                total += 1
    if total:
        print(f'FAIL: {total} obsolete runtime marker line(s) found')
        return 1
    print('PASS: no obsolete build-history flags in runtime quest metadata')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
