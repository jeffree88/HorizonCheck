-- HorizonCheck v6.46.0 prerequisite enrichment overlay.
-- These custom prerequisites improve catalog completeness but remain requirements_mapped=false
-- unless already mapped elsewhere, so Available/Locked will not guess on manual conditions.
return {
    ['4:32']={ requirements={custom='Avatar quest progression; requires access to the relevant prime avatar battles and prerequisite avatar progression.'}, requirements_mapped=false },
    ['6:90']={ requirements={custom='Salaheem\'s Sentinels promotion to Private First Class; requires the preceding mercenary rank and sufficient promotion points/assault progress.'}, requirements_mapped=false },
}
