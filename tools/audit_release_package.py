#!/usr/bin/env python3
"""Audit a HorizonCheck release tree for development artifacts and version drift."""
from pathlib import Path
import argparse
import re
import sys

ROOT = Path(__file__).resolve().parents[1]

ROOT_FILE_PATTERNS = (
    'horizoncheck_capture_*',
    'horizoncheck_mission_packets_*',
    'horizoncheck_learning_*.log',
    'horizoncheck_guided_*.txt',
    'horizoncheck_release_health_*.txt',
    'horizoncheck_audit_*.log',
    'horizoncheck_packets.log',
    'horizoncheck_state*',
    'tools_build_catalog.tmp',
)

BANNED_DIRS = (
    ROOT / 'catalog' / 'reports',
    ROOT / 'tools' / '__pycache__',
)

BANNED_FILES = (
    ROOT / 'tools' / 'quest_catalog_quality_audit.csv',
)


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument('--expected-version', default=None)
    return p.parse_args()


def read_runtime_versions():
    path = ROOT / 'horizoncheck.lua'
    text = path.read_text(encoding='utf-8')
    addon = re.search(r"addon\.version\s*=\s*'([^']+)'", text)
    hc = re.search(r"\bversion\s*=\s*'([^']+)'", text)
    header = re.search(r'^-- HorizonCheck v([^\s]+)', text, re.M)
    return (
        addon.group(1) if addon else None,
        hc.group(1) if hc else None,
        header.group(1) if header else None,
    )


def audit_runtime_diagnostics():
    errors = []
    quest_text = (ROOT / 'modules' / 'quests.lua').read_text(encoding='utf-8')
    source_block = re.search(
        r"local source_verified.*?Verified source provenance: %d/%d",
        quest_text,
        re.S,
    )
    if source_block is None or 'catalog_source_verified(det)' not in source_block.group(0):
        errors.append('Source audit diagnostic is not driven by catalog_source_verified(det)')

    runtime_text = (ROOT / 'horizoncheck.lua').read_text(encoding='utf-8')
    if re.search(r"HC\.msg\('v\d+\.\d+\.\d+ loaded", runtime_text):
        errors.append('startup notification contains a hardcoded version string')
    return errors


def main():
    args = parse_args()
    bad = []
    for pattern in ROOT_FILE_PATTERNS:
        bad.extend(p for p in ROOT.glob(pattern) if p.is_file())
    for d in BANNED_DIRS:
        if d.exists():
            bad.extend(p for p in d.rglob('*') if p.is_file())
    bad.extend(p for p in BANNED_FILES if p.exists())
    bad.extend(p for p in ROOT.rglob('*.pyc') if p.is_file())
    bad.extend(p for p in (ROOT / 'tools').glob('*_v6.*.txt') if p.is_file())
    bad = sorted(set(bad))

    addon_v, hc_v, header_v = read_runtime_versions()
    diagnostic_errors = audit_runtime_diagnostics()
    versions = [addon_v, hc_v, header_v]
    version_error = None
    if None in versions:
        version_error = f'could not read all runtime version markers: {versions}'
    elif len(set(versions)) != 1:
        version_error = f'runtime version markers disagree: header={header_v}, addon={addon_v}, HC={hc_v}'
    elif args.expected_version and addon_v != args.expected_version:
        version_error = f'runtime version {addon_v} does not match expected release {args.expected_version}'

    if bad or version_error or diagnostic_errors:
        if bad:
            print(f'FAIL: {len(bad)} non-release artifact(s) found:')
            for p in bad:
                print(' -', p.relative_to(ROOT))
        if version_error:
            print('FAIL:', version_error)
        for error in diagnostic_errors:
            print('FAIL:', error)
        return 1

    print('PASS: release tree contains no captures/logs/state snapshots/generated reports/caches/history notes.')
    print(f'PASS: runtime version markers agree at {addon_v}.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
