# HorizonCheck bulk quest catalog pipeline

This folder is the source-of-truth staging area for future bulk quest enrichment.
The runtime addon still uses the existing hand-curated `data/quest_metadata.lua`
and `data/quest_metadata_bulk.lua`; the builder produces an additional generated
overlay at `data/quest_metadata_generated.lua` that is loaded last.

## Source priority

Fields are merged independently, not quest-by-quest:

1. `manual_override` — explicit HorizonCheck corrections.
2. `horizonxi` — preferred source for Horizon-specific quest metadata.
3. `ffxiclopedia_2007` — historical fallback only. `source_date` is mandatory and
   must be **2007-09-30 or earlier**.
4. `dat` — bundled FFXI DAT maps, used for native quest identity/name only.

A lower-priority source only fills an empty field. A higher-priority source can
replace a lower-priority value. Every disagreement is written to
`catalog/reports/quest_catalog_conflicts.csv`.

## Add records in bulk

Put JSON or CSV files in `catalog/sources/`. JSON can be a list of records or
`{"records": [...]}`. Required fields are `log_id`, `quest_id`, and `source`.

Supported log IDs in this pipeline are:

- 0 San d'Oria
- 1 Bastok
- 2 Windurst
- 3 Jeuno
- 4 Other Areas
- 5 Outlands

Crystal War/Wings of the Goddess is intentionally excluded from generation.

Example JSON record:

```json
{
  "log_id": 0,
  "quest_id": 1,
  "source": "horizonxi",
  "source_label": "HorizonXI Wiki - Waters of the Cheval",
  "source_url": "https://horizonffxi.wiki/Waters_of_the_Cheval",
  "start_npc": "...",
  "start_zone": "...",
  "objective": "...",
  "reward": "...",
  "requirements": {"fame": 1}
}
```

FFXIclopedia fallback records also need a period-correct date:

```json
{
  "log_id": 0,
  "quest_id": 1,
  "source": "ffxiclopedia_2007",
  "source_date": "2007-09-20",
  "source_label": "FFXIclopedia historical revision",
  "objective": "..."
}
```

## Build

From the `horizoncheck` folder:

```text
python tools/build_quest_catalog.py
```

Validation-only mode:

```text
python tools/build_quest_catalog.py --check
```

Outputs:

- `data/quest_metadata_generated.lua` — runtime generated overlay.
- `catalog/reports/quest_field_provenance.json` — winning source per field.
- `catalog/reports/quest_catalog_conflicts.csv` — source disagreements.
- `catalog/reports/quest_catalog_gaps.csv` — every supported quest + missing fields.
- `catalog/reports/quest_catalog_stats.txt` — coverage summary by region.

The packet/native quest-state decoder is not modified by this pipeline.
