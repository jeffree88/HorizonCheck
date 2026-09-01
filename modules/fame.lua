local M = {};
local HC;

-- HorizonXI reputation-checker dialogue recognition.
-- Keep only short, distinctive anchor fragments here; player names and titles vary.
local CHECKERS = {
    {
        npc='flaco', kind='fame', key='1', label='Bastok',
        ranks={
            {1,{'some kind of snail','rookie adventurer'}},
            {2,{'sounds familiar','not many people know'}},
            {3,{"people of bastok will come to recognize","not doing bad for an adventurer"}},
            {4,{'quite a few people are talking','becoming quite famous'}},
            {5,{'a lot of people know','people are saying good things'}},
            {6,{'most everyone in this country knows','following your progress'}},
            {7,{'everyone knows your name','proud to have someone like you'}},
            {8,{'hero to the people of bastok','example every bastoker should follow'}},
            {9,{'household name in these parts','considered a hero by some'}},
        },
    },
    {
        npc='namonutice', kind='fame', key='0', label="San d'Oria",
        ranks={
            {1,{'never heard that name','every recruit'}},
            {2,{'might have heard that name','not famous yet'}},
            {3,{'name i often hear','deeds for the kingdom'}},
            {4,{'become well known in these parts','greatness lies in your future'}},
            {5,{'famous in our kingdom','no ill is spoken'}},
            {6,{'much the kingdom has heard','reputation sparkles'}},
            {7,{'practically all of the kingdom','reputation is stellar'}},
            {8,{'every infant in his cradle','highest regard'}},
            {9,{'doesn t consider you a hero','representative of the people of san d oria'}},
        },
    },
    {
        npc='zabirego hajigo', kind='fame', key='2', label='Windurst',
        ranks={
            {1,{'never heard that name before','missions for windurst'}},
            {2,{'some other guy','not making much of a name'}},
            {3,{'starting to talk about','pretty good things about you'}},
            {4,{'talking about you over their dinners','nothing but good things'}},
            {5,{'many windurstians who don t know','proud to have you on our side'}},
            {6,{'living in a hole somewhere','bards in the land'}},
            {7,{'soul in all of windurst','fledgling adventurer'}},
            {8,{'day doesn t go by','tale of your deeds'}},
            {9,{'hero of windurst','tales of your courage'}},
        },
    },
    {
        npc='ney hiparujah', kind='fame', key='2', label='Windurst / Kazham',
        ranks={
            {1,{'neverr heard of you','waltzes through our village gates'}},
            {2,{'might have heard that name somewherrre','villagers herrre'}},
            {3,{'hearing your name more often','everybody will know who you arrre'}},
            {4,{'telling everybody about my new friend','betterrr my friends look'}},
            {5,{'your name comes up a lot','nobody has anything bad'}},
            {6,{'person in this village who doesn t know','start calling you mister'}},
            {7,{'heading out on anotherrr dangerous mission','work is farrr from being done'}},
            {8,{'one smooth cat','did so much for islanders'}},
            {9,{'fame your name carries stretches','hero of kazham'}},
        },
    },
    {
        npc='mendi', kind='fame', key='3', label='Jeuno',
        ranks={
            {1,{'all roads lead to jeuno','fame and fortune should follow'}},
            {2,{'name is vaguely familiar','few in this town'}},
            {3,{'travelers in a tavern','fair reputation'}},
            {4,{'name mentioned quite often','done well my friend'}},
            {5,{'good deal of people here in jeuno','quite the do gooder'}},
            {6,{'growing reputation precedes you','substantial contributions'}},
            {7,{'literally everyone in jeuno','commendable generosity'}},
            {8,{'synonymous with courage and','saintlike service to jeuno'}},
            {9,{'emerged as a hero to the people of jeuno','good of the duchy'}},
        },
    },
    {
        npc='vaultimand', kind='reputation', key='tenshodo', label='Norg / Tenshodo',
        ranks={
            {1,{'who the hell are you','one puny ant'}},
            {2,{'mighta hearda somebody','little by little'}},
            {3,{'wait a minute i remember you','people start recognizin'}},
            {4,{'hear yer name lots','measly insect'}},
            {5,{'talkin to me mateys','heard about yer deeds fer norg'}},
            {6,{'hardly a soul in norg','know yer bloody name'}},
            {7,{'household name round norg','quite a reputation for yerself'}},
            {8,{'rumors of yer last adventure','some sorta legend'}},
            {9,{'next t our leader gilgamesh','most famous person in all a norg'}},
        },
    },
    {
        npc='waylea', kind='reputation', key='selbina_rabao', label='Selbina / Rabao',
        ranks={
            {1,{'ain t heard of your name','never heard of the name'}},
            {2,{'wonder if i have heard of your name'}},
            {3,{'building yourself a good reputation','long way to go'}},
            {4,{'heard your name mentioned once or twice','coming up in the world'}},
            {5,{'endeavors in neighboring countries','glory of your reputation'}},
            {6,{'it seems most people know you'}},
            {7,{'hardly a soul in all of rabao','truly great adventurers'}},
            {8,{'start making appointments','whole of rabao'}},
            {9,{'name is on everyone s lips','status of hero in my eyes'}},
        },
    },
};

local last = { sig=nil, at=0 };

local function normalize(s)
    s=string.lower(tostring(s or ''));
    s=s:gsub('[%z\1-\31\127]',' ');
    s=s:gsub('[^%w]+',' ');
    s=s:gsub('%s+',' ');
    return s;
end

local function contains(hay,needle)
    return needle and needle~='' and string.find(hay,needle,1,true)~=nil;
end

local function evidence_key(checker)
    local label=normalize(checker and checker.label or 'unknown'):gsub('%s+','_');
    return tostring(checker and checker.kind or 'fame')..':'..label;
end

local function publish_evidence(checker,level,source,confidence,rank,details)
    local ev=HC and HC.modules and HC.modules.evidence or nil;
    if not ev or not ev.submit then return; end
    pcall(ev.submit,evidence_key(checker),tonumber(level),{
        source=source or 'saved fame profile',
        source_id='fame:'..tostring(checker and checker.kind or 'fame')..':'..tostring(checker and checker.key or '?')..':'..tostring(source or 'saved'),
        confidence=confidence or 'CONFIRMED',
        rank=rank or 75,
        details=details,
        meta={npc=checker and checker.npc,key=checker and checker.key,label=checker and checker.label},
    });
end


local function match_rank(text,ranks)
    for _,r in ipairs(ranks or {}) do
        local level=tonumber(r[1]);
        for _,anchor in ipairs(r[2] or {}) do
            if contains(text,normalize(anchor)) then return level,anchor; end
        end
    end
    return nil,nil;
end

local function apply(checker,level,anchor)
    if not HC or not HC.modules or not HC.modules.state then return; end
    local c=HC.modules.state.get_char();
    if type(c)~='table' then return; end
    local old=nil;
    if checker.kind=='fame' then
        c.quest_fame_overrides=type(c.quest_fame_overrides)=='table' and c.quest_fame_overrides or {};
        old=tonumber(c.quest_fame_overrides[tostring(checker.key)]);
        c.quest_fame_overrides[tostring(checker.key)]=level;
    else
        c.quest_reputation_overrides=type(c.quest_reputation_overrides)=='table' and c.quest_reputation_overrides or {};
        old=tonumber(c.quest_reputation_overrides[tostring(checker.key)]);
        c.quest_reputation_overrides[tostring(checker.key)]=level;
    end
    c.quest_fame_dialogue_evidence=type(c.quest_fame_dialogue_evidence)=='table' and c.quest_fame_dialogue_evidence or {};
    local observed_at=os.time();
    c.quest_fame_dialogue_evidence[tostring(checker.kind)..':'..tostring(checker.key)]={
        level=level,
        npc=checker.npc,
        label=checker.label,
        anchor=tostring(anchor or ''),
        at=observed_at,
        source='HorizonXI fame-checker dialogue database',
    };
    -- Keep per-NPC synchronization proof separately. Some checker NPCs share
    -- the same underlying fame key (Windurst/Kazham), so the normal fame
    -- evidence table cannot prove that every checker was visited during setup.
    c.fame_checker_sync=type(c.fame_checker_sync)=='table' and c.fame_checker_sync or {};
    c.fame_checker_sync[tostring(checker.npc)]={
        at=observed_at, level=level, label=checker.label,
        kind=checker.kind, key=checker.key,
    };
    publish_evidence(checker,level,'HorizonXI fame-checker dialogue','VERIFIED',90,'Direct reputation-checker dialogue match: '..tostring(anchor or '?'));
    HC.modules.state.save();
    if HC.modules.dependencies and HC.modules.dependencies.invalidate then HC.modules.dependencies.invalidate('fame','fame checker dialogue synchronized');
    elseif HC.modules.releasehealth and HC.modules.releasehealth.invalidate then HC.modules.releasehealth.invalidate(); end
    if old~=level and HC.msg then
        HC.msg(string.format('FAME AUTO: %s rank %d confirmed from %s dialogue.',tostring(checker.label),tonumber(level),tostring(checker.npc)));
    end
end

local function on_text(s)
    local text=normalize(s);
    if text=='' then return; end
    for _,checker in ipairs(CHECKERS) do
        if contains(text,normalize(checker.npc)) then
            local level,anchor=match_rank(text,checker.ranks);
            if level then
                local sig=tostring(checker.kind)..':'..tostring(checker.key)..':'..tostring(level);
                local now=os.time();
                if last.sig~=sig or now-(tonumber(last.at) or 0)>2 then
                    last.sig=sig; last.at=now;
                    apply(checker,level,anchor);
                end
                return;
            end
        end
    end
end


local function migrate_legacy_bastok_key()
    if not HC or not HC.modules or not HC.modules.state then return; end
    local c=HC.modules.state.get_char();
    if type(c)~='table' then return; end
    local ev=type(c.quest_fame_dialogue_evidence)=='table' and c.quest_fame_dialogue_evidence['fame:0'] or nil;
    if type(ev)~='table' or string.lower(tostring(ev.label or ''))~='bastok' then return; end

    local level=tonumber(ev.level);
    if level==nil and type(c.quest_fame_overrides)=='table' then
        level=tonumber(c.quest_fame_overrides['0']);
    end
    if level~=nil then
        level=math.max(1,math.min(9,math.floor(level)));
        c.quest_fame_overrides=type(c.quest_fame_overrides)=='table' and c.quest_fame_overrides or {};
        local cur=tonumber(c.quest_fame_overrides['1']);
        if cur==nil or level>cur then c.quest_fame_overrides['1']=level; end
        -- v6.84.18 and earlier accidentally stored Flaco/Bastok under city log 0
        -- (San d'Oria).  Remove only when the evidence proves that value came
        -- from Flaco so we do not leave a false San d'Oria confirmation behind.
        c.quest_fame_overrides['0']=nil;
    end

    c.quest_fame_dialogue_evidence=type(c.quest_fame_dialogue_evidence)=='table' and c.quest_fame_dialogue_evidence or {};
    c.quest_fame_dialogue_evidence['fame:1']=ev;
    c.quest_fame_dialogue_evidence['fame:0']=nil;
    HC.modules.state.save();
    if HC.msg then HC.msg('FAME MIGRATION: corrected legacy Flaco/Bastok fame profile key.'); end
end

function M.publish_evidence()
    if not HC or not HC.modules or not HC.modules.state then return false; end
    local c=HC.modules.state.get_char();
    if type(c)~='table' then return false; end
    for _,checker in ipairs(CHECKERS) do
        local level=nil;
        if checker.kind=='fame' and type(c.quest_fame_overrides)=='table' then
            level=tonumber(c.quest_fame_overrides[tostring(checker.key)]);
        elseif checker.kind=='reputation' and type(c.quest_reputation_overrides)=='table' then
            level=tonumber(c.quest_reputation_overrides[tostring(checker.key)]);
        end
        if level then
            local evid=type(c.quest_fame_dialogue_evidence)=='table' and c.quest_fame_dialogue_evidence[tostring(checker.kind)..':'..tostring(checker.key)] or nil;
            if type(evid)=='table' and tonumber(evid.level)==level then
                publish_evidence(checker,level,tostring(evid.source or 'HorizonXI fame-checker dialogue'),'VERIFIED',90,
                    'Saved direct dialogue proof from '..tostring(evid.npc or checker.npc)..'.');
            else
                publish_evidence(checker,level,'confirmed fame profile','CONFIRMED',75,'Saved HorizonCheck fame/reputation profile.');
            end
        end
    end
    return true;
end


function M.sync_status(c)
    c=c or (HC and HC.modules and HC.modules.state and HC.modules.state.get_char and HC.modules.state.get_char()) or {};
    c.fame_checker_sync=type(c.fame_checker_sync)=='table' and c.fame_checker_sync or {};
    local evidence=type(c.quest_fame_dialogue_evidence)=='table' and c.quest_fame_dialogue_evidence or {};
    local rows={}; local missing={}; local done=0;
    for _,checker in ipairs(CHECKERS) do
        local rec=c.fame_checker_sync[tostring(checker.npc)];
        -- Backfill per-NPC setup proof from older direct dialogue evidence when
        -- the saved evidence still names the exact checker NPC.
        if type(rec)~='table' then
            local ev=evidence[tostring(checker.kind)..':'..tostring(checker.key)];
            if type(ev)=='table' and normalize(ev.npc)==normalize(checker.npc) then rec=ev; end
        end
        local ok=type(rec)=='table' and tonumber(rec.level)~=nil;
        if ok then done=done+1; else missing[#missing+1]=tostring(checker.label); end
        rows[#rows+1]={npc=checker.npc,label=checker.label,kind=checker.kind,key=checker.key,synced=ok,level=ok and tonumber(rec.level) or nil,at=ok and tonumber(rec.at) or nil};
    end
    return {done=done,total=#CHECKERS,complete=done>=#CHECKERS,missing=missing,rows=rows};
end

function M.status()
    return { checkers=#CHECKERS, automatic=true, source='HorizonXI reputation dialogue chart' };
end

function M.init(ctx)
    HC=ctx;
    migrate_legacy_bastok_key();
    if HC.modules and HC.modules.packets and HC.modules.packets.register_text then
        HC.modules.packets.register_text('fame dialogue auto-detect',on_text);
    end
    if HC.modules and HC.modules.evidence and HC.modules.evidence.register_provider then
        HC.modules.evidence.register_provider('fame',M.publish_evidence);
    end
    M.publish_evidence();
end

return M;
