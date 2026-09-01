#!/usr/bin/env python3
from pathlib import Path
import re, csv, collections, sys

root=Path(__file__).resolve().parents[1]
data=root/"horizoncheck"/"data"
files=sorted(data.glob("quest_metadata*.lua"))
checks={
    "GENERIC_OBJECTIVE": re.compile(r"complete the quest'?s requested task|complete .* requested .* and return|follow the HorizonXI Wiki",re.I),
    "GENERIC_REWARD": re.compile(r"Quest reward documented by HorizonXI Wiki|Quest progression reward|reward='Varies'",re.I),
    "GENERIC_NPC": re.compile(r"quest NPC|quest contact|Goblin footprint / elemental trial NPC|Aht Urhgan quest contact",re.I),
    "GENERIC_ZONE": re.compile(r"quest region|Jeuno / Aht Urhgan progression",re.I),
    "REFERENCE_FALLBACK": re.compile(r"catalog reference fallback|Open the HorizonXI Wiki reference",re.I),
}
rows=[]
for p in files:
    for lineno,line in enumerate(p.read_text(errors="ignore").splitlines(),1):
        keym=re.search(r"\['([^']+)'\]",line)
        namem=re.search(r"\bname\s*=\s*('(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\")",line)
        key=keym.group(1) if keym else ""
        name=namem.group(1)[1:-1].replace("\\'","'") if namem else ""
        for issue,pat in checks.items():
            if pat.search(line):
                rows.append((issue,key,name,p.name,lineno))
out=root/"tools"/"quest_catalog_quality_audit.csv"
with out.open("w",newline="",encoding="utf-8") as f:
    w=csv.writer(f); w.writerow(["issue","quest_key","quest_name","source_file","line"]); w.writerows(rows)
c=collections.Counter(r[0] for r in rows)
print("Quest catalog quality audit")
for k in checks: print(f"{k}: {c[k]}")
print(f"TOTAL FLAGS: {len(rows)}")
print(out)
