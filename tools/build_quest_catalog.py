#!/usr/bin/env python3
"""HorizonCheck bulk quest catalog builder.

Inputs: catalog/sources/*.json and *.csv
Output: data/quest_metadata_generated.lua + catalog/reports/*

Source priority (high wins per field):
  manual_override > horizonxi > ffxiclopedia_2007 > dat
FFXIclopedia records are rejected when source_date is later than 2007-09-30.

The builder deliberately does not touch packet/state logic. It only creates a
metadata overlay consumed by modules/quests.lua after the legacy catalog files.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
import subprocess
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any, Dict, Iterable, List, Tuple

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "catalog" / "sources"
REPORT_DIR = ROOT / "catalog" / "reports"
OUTPUT_LUA = ROOT / "data" / "quest_metadata_generated.lua"
PROVENANCE_JSON = REPORT_DIR / "quest_field_provenance.json"
GAPS_CSV = REPORT_DIR / "quest_catalog_gaps.csv"
CONFLICTS_CSV = REPORT_DIR / "quest_catalog_conflicts.csv"
STATS_TXT = REPORT_DIR / "quest_catalog_stats.txt"

SUPPORTED_LOGS = {
    0: ("San d'Oria", "sandoria"),
    1: ("Bastok", "bastok"),
    2: ("Windurst", "windurst"),
    3: ("Jeuno", "jeuno"),
    4: ("Other Areas", "other"),
    5: ("Outlands", "outlands"),
}

SOURCE_PRIORITY = {
    "dat": 10,
    "ffxiclopedia_2007": 30,
    "horizonxi": 50,
    "manual_override": 100,
}
FFXI_CUTOFF = date(2007, 9, 30)

# Fields that contribute to enrichment/gap reporting. "name" comes from DAT and
# does not make a record enriched by itself.
DETAIL_FIELDS = [
    "start_npc", "start_zone", "objective", "items_needed", "reward",
    "repeat_type", "next_step", "expansion", "keywords",
]
REQUIREMENT_FIELDS = ["fame", "job", "level", "rank", "mission", "quests"]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Build HorizonCheck quest metadata overlay")
    p.add_argument("--source-dir", type=Path, default=SOURCE_DIR)
    p.add_argument("--output", type=Path, default=OUTPUT_LUA)
    p.add_argument("--reports", type=Path, default=REPORT_DIR)
    p.add_argument("--check", action="store_true", help="validate and report without writing generated Lua")
    return p.parse_args()


def decode_lua_string(s: str) -> str:
    return s.replace("\\'", "'").replace('\\"', '"').replace('\\\\', '\\')


def load_dat_names() -> Dict[Tuple[int, int], Dict[str, Any]]:
    out: Dict[Tuple[int, int], Dict[str, Any]] = {}
    # The bundled DAT maps are authoritative only for quest identity/name.
    pat = re.compile(r"^\s*\[(\d+)\]\s*=\s*'((?:\\.|[^'])*)'\s*,?\s*$")
    for log_id, (region, stem) in SUPPORTED_LOGS.items():
        path = ROOT / "modules" / "questmaps" / f"{stem}.lua"
        if not path.exists():
            continue
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            m = pat.match(line)
            if not m:
                continue
            qid = int(m.group(1))
            name = decode_lua_string(m.group(2))
            out[(log_id, qid)] = {
                "log_id": log_id,
                "quest_id": qid,
                "region": region,
                "name": name,
                "source": "dat",
                "source_label": "Bundled FFXI DAT quest map",
            }
    return out


def normalize_scalar(v: Any) -> Any:
    if isinstance(v, str):
        v = v.strip()
        return v if v else None
    return v


def load_source_file(path: Path) -> List[Dict[str, Any]]:
    if path.suffix.lower() == ".json":
        data = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(data, dict):
            data = data.get("records", [])
        if not isinstance(data, list):
            raise ValueError(f"{path}: JSON must be a list or {{records:[...]}}")
        return [dict(x) for x in data if isinstance(x, dict)]
    if path.suffix.lower() == ".csv":
        with path.open("r", encoding="utf-8-sig", newline="") as f:
            return [dict(r) for r in csv.DictReader(f)]
    return []


def validate_source_record(rec: Dict[str, Any], path: Path, rowno: int) -> Dict[str, Any]:
    r = {k: normalize_scalar(v) for k, v in rec.items()}
    try:
        r["log_id"] = int(r["log_id"])
        r["quest_id"] = int(r["quest_id"])
    except Exception as e:
        raise ValueError(f"{path}:{rowno}: log_id and quest_id are required integers") from e
    if r["log_id"] not in SUPPORTED_LOGS:
        raise ValueError(f"{path}:{rowno}: unsupported log_id {r['log_id']} (pipeline scope is 0-5)")
    source = (r.get("source") or "").strip().lower()
    if source not in SOURCE_PRIORITY:
        raise ValueError(f"{path}:{rowno}: source must be one of {sorted(SOURCE_PRIORITY)}")
    r["source"] = source
    if source == "ffxiclopedia_2007":
        raw_date = r.get("source_date")
        if not raw_date:
            raise ValueError(f"{path}:{rowno}: FFXIclopedia records require source_date")
        try:
            d = date.fromisoformat(str(raw_date)[:10])
        except ValueError as e:
            raise ValueError(f"{path}:{rowno}: invalid source_date {raw_date!r}") from e
        if d > FFXI_CUTOFF:
            raise ValueError(f"{path}:{rowno}: FFXIclopedia source_date {d} is after 2007-09-30 cutoff")
    # requirements can be a JSON object or CSV JSON string.
    req = r.get("requirements")
    if isinstance(req, str):
        try:
            req = json.loads(req) if req else {}
        except json.JSONDecodeError as e:
            raise ValueError(f"{path}:{rowno}: requirements must be valid JSON") from e
    if req is None:
        req = {}
    if not isinstance(req, dict):
        raise ValueError(f"{path}:{rowno}: requirements must be an object")
    r["requirements"] = req
    return r


def load_external_sources(source_dir: Path) -> List[Dict[str, Any]]:
    records: List[Dict[str, Any]] = []
    if not source_dir.exists():
        return records
    for path in sorted(source_dir.iterdir()):
        if path.name.startswith("_"):
            continue
        if path.suffix.lower() not in {".json", ".csv"}:
            continue
        rows = load_source_file(path)
        for i, row in enumerate(rows, start=2 if path.suffix.lower() == ".csv" else 1):
            rec = validate_source_record(row, path, i)
            # Internal-only provenance used to resolve same-source ties.  Individual
            # quest gapfills must beat broad category tables, and broad tables must
            # beat the reference-fallback placeholders.
            rec["_source_file"] = path.name
            records.append(rec)
    return records


def record_priority(rec: Dict[str, Any]) -> int:
    """Return field merge priority including same-source specificity.

    The source class remains authoritative (manual > HorizonXI > historical
    FFXIclopedia > DAT).  A small sub-rank only breaks ties inside a source class.
    """
    base = SOURCE_PRIORITY[rec["source"]] * 100
    if rec["source"] != "horizonxi":
        return base
    name = str(rec.get("_source_file") or "").lower()
    label = str(rec.get("source_label") or "").lower()
    if "reference_fallback" in name or "reference fallback" in label:
        detail = -40
    elif "gapfill" in name:
        detail = 40
    elif "seed" in name:
        detail = 35
    elif any(x in name for x in ("jeuno_", "bastok_windurst_", "other_outlands_")):
        detail = 25
    elif "bulk" in name:
        detail = 20
    else:
        detail = 10
    return base + detail


def comparable(v: Any) -> str:
    return json.dumps(v, sort_keys=True, ensure_ascii=False) if isinstance(v, (dict, list)) else str(v)


def _norm_text(v: Any) -> str:
    s = str(v or "").strip().lower()
    s = re.sub(r"\s+", " ", s)
    return s


def _reward_equivalent(a: Any, b: Any) -> bool:
    # Ignore presentation-only reward differences from overlapping HorizonXI layers.
    na = re.sub(r"(?<=\d),(?=\d)", "", _norm_text(a))
    nb = re.sub(r"(?<=\d),(?=\d)", "", _norm_text(b))
    if na == nb:
        return True
    aliases = {
        "ifrit unlocked": "ifrit avatar pact",
    }
    return aliases.get(na, na) == aliases.get(nb, nb)


def _next_step_equivalent(a: Any, b: Any) -> bool:
    # A generic reference-fallback instruction and a source-specific instruction are
    # refinement, not a factual conflict. Likewise, two 'Speak with <NPC>' variants
    # naming the same NPC are compatible even when one adds coordinates/instructions.
    na, nb = _norm_text(a), _norm_text(b)
    generic = ("open the horizonxi wiki reference" in na, "open the horizonxi wiki reference" in nb)
    if generic[0] != generic[1]:
        return True
    if "to begin or continue this quest" in na or "to begin or continue this quest" in nb:
        return True
    def speaker(s: str):
        m = re.match(r"speak with ([^,.]+)", s)
        return m.group(1).strip() if m else None
    sa, sb = speaker(na), speaker(nb)
    return bool(sa and sb and sa == sb)


def _nonconflicting_variant(field: str, old: Any, new: Any) -> bool:
    if field == "reward":
        return _reward_equivalent(old, new)
    if field == "next_step":
        return _next_step_equivalent(old, new)
    return False


def merge_records(dat: Dict[Tuple[int, int], Dict[str, Any]], external: List[Dict[str, Any]]):
    merged: Dict[Tuple[int, int], Dict[str, Any]] = {k: dict(v) for k, v in dat.items()}
    provenance: Dict[str, Dict[str, Dict[str, Any]]] = defaultdict(dict)
    field_rank: Dict[Tuple[Tuple[int, int], str], int] = {}
    conflicts: List[Dict[str, Any]] = []

    for key, rec in merged.items():
        provenance[f"{key[0]}:{key[1]}"]["name"] = {
            "source": "dat", "source_label": rec.get("source_label", "DAT"), "priority": SOURCE_PRIORITY["dat"]
        }
        field_rank[(key, "name")] = SOURCE_PRIORITY["dat"]

    # Stable order lets higher priority naturally win later, while still logging conflicts.
    external = sorted(external, key=lambda r: (record_priority(r), r["log_id"], r["quest_id"]))
    meta_fields = {"log_id", "quest_id", "source", "source_label", "source_url", "source_date", "region", "_source_file"}
    for rec in external:
        key = (rec["log_id"], rec["quest_id"])
        base = merged.setdefault(key, {
            "log_id": key[0], "quest_id": key[1], "region": SUPPORTED_LOGS[key[0]][0]
        })
        rank = record_priority(rec)
        source_info = {
            "source": rec["source"],
            "source_label": rec.get("source_label") or rec["source"],
            "source_url": rec.get("source_url"),
            "source_date": rec.get("source_date"),
            "priority": rank,
        }
        for field, value in rec.items():
            if field in meta_fields or value is None or value == "" or value == {}:
                continue
            if field == "requirements":
                current_req = base.setdefault("requirements", {})
                for rk, rv in value.items():
                    if rv is None or rv == "":
                        continue
                    fkey = f"requirements.{rk}"
                    old = current_req.get(rk)
                    oldrank = field_rank.get((key, fkey), -1)
                    if old is not None and comparable(old) != comparable(rv):
                        conflicts.append({"key": f"{key[0]}:{key[1]}", "field": fkey, "old": comparable(old), "new": comparable(rv), "winner": source_info["source_label"] if rank >= oldrank else "existing higher-priority source"})
                    if rank >= oldrank:
                        current_req[rk] = rv
                        field_rank[(key, fkey)] = rank
                        provenance[f"{key[0]}:{key[1]}"][fkey] = source_info
                continue
            old = base.get(field)
            oldrank = field_rank.get((key, field), -1)

            # Search keywords are additive metadata, not mutually-exclusive facts.
            # Older builds treated complementary keyword strings from overlapping
            # HorizonXI source layers as conflicts, then discarded the lower-ranked
            # terms.  Preserve both sets so NPC/reward/category aliases remain
            # searchable while keeping the conflict report focused on real data
            # disagreements.
            if field == "keywords" and old is not None and comparable(old) != comparable(value):
                old_s = str(old).strip()
                new_s = str(value).strip()
                if old_s.lower() in new_s.lower():
                    merged_keywords = new_s
                elif new_s.lower() in old_s.lower():
                    merged_keywords = old_s
                else:
                    merged_keywords = old_s + " " + new_s
                base[field] = merged_keywords
                field_rank[(key, field)] = max(oldrank, rank)
                if rank >= oldrank:
                    provenance[f"{key[0]}:{key[1]}"][field] = source_info
                continue

            if old is not None and comparable(old) != comparable(value) and not _nonconflicting_variant(field, old, value):
                conflicts.append({"key": f"{key[0]}:{key[1]}", "field": field, "old": comparable(old), "new": comparable(value), "winner": source_info["source_label"] if rank >= oldrank else "existing higher-priority source"})
            if rank >= oldrank:
                base[field] = value
                field_rank[(key, field)] = rank
                provenance[f"{key[0]}:{key[1]}"][field] = source_info

    return merged, provenance, conflicts


def lua_quote(s: str) -> str:
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("\r", " ").replace("\n", "\\n") + "'"


def lua_value(v: Any) -> str:
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, str):
        return lua_quote(v)
    if isinstance(v, list):
        return "{" + ",".join(lua_value(x) for x in v) + "}"
    if isinstance(v, dict):
        bits = []
        for k, val in v.items():
            if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", str(k)):
                bits.append(f"{k}={lua_value(val)}")
            else:
                bits.append(f"[{lua_quote(str(k))}]={lua_value(val)}")
        return "{" + ",".join(bits) + "}"
    return lua_quote(str(v))


def record_is_enriched(rec: Dict[str, Any]) -> bool:
    if any(rec.get(f) not in (None, "", {}) for f in DETAIL_FIELDS):
        return True
    req = rec.get("requirements") or {}
    return any(req.get(f) not in (None, "", {}) for f in REQUIREMENT_FIELDS)


def load_authoritative_requirement_keys() -> set[Tuple[int, int]]:
    """Keys whose prerequisite truth is owned by the final CHECKREQS overlay.

    The generated catalog loads before quest_metadata_checkreqs.lua.  Suppressing a
    generated requirements_mapped=false placeholder for these keys avoids a
    transient contradiction and keeps prerequisite ownership centralized.
    """
    path = Path(__file__).resolve().parent.parent / "data" / "quest_metadata_checkreqs.lua"
    if not path.exists():
        return set()
    out: set[Tuple[int, int]] = set()
    rx = re.compile(r"^\s*\['(\d+):(\d+)'\]\s*=")
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        m = rx.match(line)
        if m:
            out.add((int(m.group(1)), int(m.group(2))))
    return out


def generate_lua(merged: Dict[Tuple[int, int], Dict[str, Any]], provenance: Dict[str, Dict[str, Any]], authoritative_requirement_keys: set[Tuple[int, int]] | None = None) -> str:
    lines = [
        "-- AUTO-GENERATED by tools/build_quest_catalog.py. DO NOT EDIT BY HAND.",
        "-- Field priority: manual_override > HorizonXI > FFXIclopedia <= 2007-09-30 > DAT.",
        "-- This file is metadata only; native 0x056 quest-state decoding is untouched.",
        "return {",
    ]
    # Only emit records that have external provenance beyond the DAT name. This avoids
    # overwriting rich legacy records with name-only DAT entries.
    for key in sorted(merged):
        p = provenance.get(f"{key[0]}:{key[1]}", {})
        if not any(info.get("source") != "dat" for info in p.values()):
            continue
        rec = merged[key]
        fields = []
        order = ["name", "expansion", "start_npc", "start_zone", "repeat_type", "objective", "items_needed", "reward", "next_step", "keywords"]
        for f in order:
            if rec.get(f) not in (None, "", {}):
                fields.append(f"{f}={lua_value(rec[f])}")
        # Prerequisite truth for CHECKREQS-owned quests is emitted only by the
        # final quest_metadata_checkreqs.lua overlay.  Suppress both positive
        # and negative generated requirement fields for those keys so earlier
        # catalog layers cannot contradict the authoritative runtime mapping.
        if key not in (authoritative_requirement_keys or set()):
            if rec.get("requirements"):
                fields.append("requirements_mapped=true")
                fields.append(f"requirements={lua_value(rec['requirements'])}")
            else:
                fields.append("requirements_mapped=false")
        # Preserve human-readable source provenance in the runtime record.
        used = []
        for info in p.values():
            label = info.get("source_label")
            if info.get("source") != "dat" and label and label not in used:
                used.append(label)
        fields.append("catalog_generated=true")
        fields.append(f"catalog_sources={lua_value(used)}")
        override_fields = []
        override_requirements = []
        for pf, info in p.items():
            if info.get("source") != "manual_override":
                continue
            if pf.startswith("requirements."):
                override_requirements.append(pf.split(".", 1)[1])
            elif pf != "name":
                override_fields.append(pf)
        if override_fields:
            fields.append(f"catalog_override_fields={lua_value(sorted(set(override_fields)))}")
        if override_requirements:
            fields.append(f"catalog_override_requirements={lua_value(sorted(set(override_requirements)))}")
        # Horizon compatibility marker is true when at least one HorizonXI field won.
        has_horizon = any(info.get("source") == "horizonxi" for info in p.values())
        if has_horizon:
            fields.append("horizon={enabled=true,verified=true,source='Generated catalog pipeline'}")
        else:
            fields.append("horizon={enabled=true,verified=false,source='Generated historical/reference catalog'}")
        lines.append(f"    ['{key[0]}:{key[1]}']={{ " + ", ".join(fields) + " },")
    lines.append("}")
    return "\n".join(lines) + "\n"


def write_reports(merged, provenance, conflicts, report_dir: Path):
    report_dir.mkdir(parents=True, exist_ok=True)
    PROV = report_dir / PROVENANCE_JSON.name
    GAPS = report_dir / GAPS_CSV.name
    CONFLICTS = report_dir / CONFLICTS_CSV.name
    STATS = report_dir / STATS_TXT.name
    PROV.write_text(json.dumps(provenance, indent=2, ensure_ascii=False, sort_keys=True), encoding="utf-8")

    gap_fields = ["start_npc", "start_zone", "objective", "items_needed", "reward", "repeat_type", "next_step"]
    with GAPS.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["log_id", "quest_id", "region", "name", "enriched", "missing_fields"])
        for key in sorted(merged):
            rec = merged[key]
            missing = [fld for fld in gap_fields if rec.get(fld) in (None, "", {})]
            w.writerow([key[0], key[1], SUPPORTED_LOGS[key[0]][0], rec.get("name", ""), "yes" if record_is_enriched(rec) else "no", ";".join(missing)])

    with CONFLICTS.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["key", "field", "old", "new", "winner"])
        w.writeheader()
        w.writerows(conflicts)

    by_region = defaultdict(lambda: [0, 0])
    sources = Counter()
    for key, rec in merged.items():
        by_region[key[0]][0] += 1
        if record_is_enriched(rec):
            by_region[key[0]][1] += 1
    for fields in provenance.values():
        for info in fields.values():
            sources[info.get("source", "unknown")] += 1
    total = len(merged)
    enriched = sum(1 for r in merged.values() if record_is_enriched(r))
    lines = [
        "HorizonCheck Quest Catalog Pipeline Stats",
        "========================================",
        f"Mapped DAT/native records in supported logs: {total}",
        f"Pipeline-enriched records: {enriched}",
        f"Enrichment coverage: {(enriched/total*100 if total else 0):.1f}%",
        f"Merge conflicts logged: {len(conflicts)}",
        "",
        "By region:",
    ]
    for log_id in sorted(SUPPORTED_LOGS):
        mapped, rich = by_region[log_id]
        pct = rich / mapped * 100 if mapped else 0
        lines.append(f"  {SUPPORTED_LOGS[log_id][0]}: {rich}/{mapped} enriched ({pct:.1f}%)")
    lines += ["", "Winning field provenance counts:"]
    for src, count in sorted(sources.items()):
        lines.append(f"  {src}: {count}")
    STATS.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    try:
        dat = load_dat_names()
        external = load_external_sources(args.source_dir)
        merged, provenance, conflicts = merge_records(dat, external)
        write_reports(merged, provenance, conflicts, args.reports)
        if not args.check:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            authoritative_requirement_keys = load_authoritative_requirement_keys()
            args.output.write_text(generate_lua(merged, provenance, authoritative_requirement_keys), encoding="utf-8")
            # Keep shipped overlays compact after regeneration. This removes only
            # exact descriptive reassignments; requirement/provenance authority is excluded.
            from dedupe_quest_metadata import process as dedupe_metadata
            if dedupe_metadata(check=False) != 0:
                raise RuntimeError("quest metadata dedupe failed")
            # Keep only the earliest fallback and final authoritative assignment
            # when a descriptive field is shadowed three or more times.
            from compact_shadowed_metadata import process as compact_shadowed_metadata
            if compact_shadowed_metadata(check=False) != 0:
                raise RuntimeError("shadowed quest metadata compaction failed")
            schema_audit = subprocess.run([sys.executable, str(ROOT / "tools" / "audit_catalog_schema.py")], cwd=ROOT)
            if schema_audit.returncode != 0:
                raise RuntimeError("quest catalog schema/source audit failed")
        print(f"DAT/native records: {len(dat)}")
        print(f"External source records: {len(external)}")
        print(f"Merged records: {len(merged)}")
        print(f"Conflicts: {len(conflicts)}")
        print(f"Generated: {args.output if not args.check else '(check only)'}")
        print(f"Reports: {args.reports}")
        return 0
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
