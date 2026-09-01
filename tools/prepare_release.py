#!/usr/bin/env python3
"""Create a clean HorizonCheck release ZIP from the working tree."""
from pathlib import Path
import argparse
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument('--version', required=True, help='Release version, e.g. 6.60.0')
    p.add_argument('--output', type=Path, required=True)
    return p.parse_args()


def excluded(rel: Path) -> bool:
    s = rel.as_posix()
    name = rel.name
    if s.startswith('catalog/reports/') or s == 'catalog/reports':
        return True
    if '__pycache__' in rel.parts or name.endswith(('.pyc', '.pyo')):
        return True
    if rel.parent == Path('.') and (
        name.startswith('horizoncheck_capture_') or
        name.startswith('horizoncheck_mission_packets_') or
        name.startswith('horizoncheck_learning_') and name.endswith('.log') or
        name.startswith('horizoncheck_guided_') and name.endswith('.txt') or
        name.startswith('horizoncheck_release_health_') and name.endswith('.txt') or
        name.startswith('horizoncheck_audit_') and name.endswith('.log') or
        name == 'horizoncheck_packets.log' or
        name.startswith('horizoncheck_state') and (name.endswith('.lua') or '.bak' in name or '.migration' in name or '.write_test' in name) or
        name == 'tools_build_catalog.tmp'
    ):
        return True
    if rel.parent == Path('tools') and (re.fullmatch(r'.*_v6\..*\.txt', name) or name == 'quest_catalog_quality_audit.csv'):
        return True
    return False


def set_version(path: Path, version: str):
    text = path.read_text(encoding='utf-8')
    text = re.sub(r'^-- HorizonCheck v[^\s]+', f'-- HorizonCheck v{version}', text, count=1, flags=re.M)
    text = re.sub(r"addon\.version\s*=\s*'[^']+'", f"addon.version = '{version}'", text, count=1)
    text = re.sub(r"(local HC = \{\s*\n\s*version\s*=\s*)'[^']+'", rf"\1'{version}'", text, count=1)
    path.write_text(text, encoding='utf-8')


def write_release_manifest(stage: Path, version: str):
    required = [
        'horizoncheck.lua',
        'modules/state.lua',
        'modules/runtimeguard.lua',
        'modules/dependencies.lua',
        'modules/integrity.lua',
        'modules/performance_watchdog.lua',
        'modules/synchealth.lua',
        'modules/characterregistry.lua',
        'modules/releasehealth.lua',
        'modules/diagnostics.lua',
        'modules/zonesync.lua',
        'modules/assaultprogress.lua',
        'modules/historyimport.lua',
        'modules/uikit.lua',
        'data/horizon_canonical_content.lua',
        'INSTALL.md',
        'TROUBLESHOOTING.md',
        'KNOWN_LIMITATIONS.md',
        'CHANGELOG.md',
        'RELEASE_CHECKLIST.md',
    ]
    lines = ["return {", f"    version = '{version}',", "    state_schema = 24,", "    required = {"]
    lines.extend(f"        '{name}'," for name in required)
    lines.extend(["    },", "};", ""])
    target = stage / 'data' / 'release_manifest.lua'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text('\n'.join(lines), encoding='utf-8')


def main():
    args = parse_args()
    if not re.fullmatch(r'\d+\.\d+\.\d+', args.version):
        print('ERROR: version must be X.Y.Z', file=sys.stderr)
        return 2

    with tempfile.TemporaryDirectory(prefix='horizoncheck_release_') as td:
        stage = Path(td) / 'horizoncheck'
        stage.mkdir()
        for src in ROOT.rglob('*'):
            rel = src.relative_to(ROOT)
            if excluded(rel):
                continue
            dst = stage / rel
            if src.is_dir():
                dst.mkdir(parents=True, exist_ok=True)
            elif src.is_file():
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)

        set_version(stage / 'horizoncheck.lua', args.version)
        write_release_manifest(stage, args.version)

        checks = [
            [sys.executable, str(stage / 'tools' / 'validate_quest_lua.py')],
            [sys.executable, str(stage / 'tools' / 'audit_catalog_schema.py')],
            [sys.executable, str(stage / 'tools' / 'audit_quest_dependencies.py')],
            [sys.executable, str(stage / 'tools' / 'audit_runtime_metadata.py')],
            [sys.executable, str(stage / 'tools' / 'audit_canonical_content.py')],
            [sys.executable, str(stage / 'tools' / 'audit_release_hardening.py')],
            [sys.executable, str(stage / 'tools' / 'audit_performance_contracts.py')],
            [sys.executable, str(stage / 'tools' / 'audit_state_integrity.py')],
            [sys.executable, str(stage / 'tools' / 'audit_v720_contracts.py')],
            [sys.executable, str(stage / 'tools' / 'audit_lua_syntax.py')],
            [sys.executable, str(stage / 'tools' / 'run_regression_tests.py')],
            [sys.executable, str(stage / 'tools' / 'run_workflow_simulations.py')],
            [sys.executable, str(stage / 'tools' / 'dedupe_quest_metadata.py'), '--check'],
            [sys.executable, str(stage / 'tools' / 'compact_shadowed_metadata.py'), '--check'],
            [sys.executable, str(stage / 'tools' / 'audit_release_package.py'), '--expected-version', args.version],
        ]
        for cmd in checks:
            cp = subprocess.run(cmd, cwd=stage, text=True)
            if cp.returncode != 0:
                return cp.returncode

        args.output.parent.mkdir(parents=True, exist_ok=True)
        if args.output.exists():
            args.output.unlink()
        with zipfile.ZipFile(args.output, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
            for p in sorted(stage.rglob('*')):
                if p.is_file():
                    zf.write(p, Path('horizoncheck') / p.relative_to(stage))

        with zipfile.ZipFile(args.output, 'r') as zf:
            bad = zf.testzip()
            if bad:
                print('ERROR: ZIP integrity failed at', bad, file=sys.stderr)
                return 3
            count = len(zf.infolist())
        print(f'PASS: release ZIP created: {args.output} ({count} files)')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
