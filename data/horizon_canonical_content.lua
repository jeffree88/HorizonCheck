-- HorizonXI canonical content authority profile.
-- Runtime catalog records are merged with these explicit server-specific rules.
return {
    schema = 1,

    -- A verified source is trusted for native quest-bit interpretation unless
    -- its label matches one of the generic/build-derived patterns below.
    generic_source_patterns = {
        'metadata pending',
        'native quest id map',
        'catalog completion pass',
        'generated catalog pipeline',
        'catalog reference fallback',
        'reference fallback',
    },

    -- Explicit quest authority overrides.  These always outrank retail/native
    -- bit assumptions and merged catalog fallbacks.
    quests = {
        ['3:92'] = {
            name = 'Chocobo on the Loose!',
            availability = 'UNAVAILABLE',
            native_policy = 'BLOCK',
            verified = true,
            source = 'HorizonXI availability correction',
            reason = 'This quest is not currently available on HorizonXI. Native quest bit 3:92 must not activate or complete this retail record.',
            collision = {
                kind = 'SERVER_ID_MISMATCH',
                detail = 'The native bit may be populated for a different HorizonXI server-side mapping; the retail quest record is quarantined.',
            },
        },
    },

    mission_caps = {
        toau = {
            current = 18,
            source = 'HorizonXI current progression profile',
            future_reason = 'Beyond the current HorizonXI mission cap; retained as future reference content.',
        },
    },
}
