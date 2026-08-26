--*****************************************************************************
--* File: schook/lua/system/Localization.lua (in SC_Campaign_Main_Localization.scd)
--* Summary: SC (Supreme Commander 2007) campaign localization merge hook
--*
--* Mechanism:
--*   Stock FA engine (mohodata.scd lua/system/Localization.lua) loads
--*   /loc/<lang>/strings_db.lua into its internal loc_table, then defines
--*   global LOC()/LOCF()/LocExpand().
--*
--*   The engine appends schook files (bin/SupComDataPath.lua sets
--*   hook = { '/schook' }) AFTER the base script runs, in the same
--*   environment. We therefore run AFTER FA's loc_table is populated.
--
--*   Strategy (per user's design):
--*     1. Load the ORIGINAL Supreme Commander strings_db.lua for the current
--*        language into merged (full table, all keys).
--*     2. Load FA's /loc/<lang>/strings_db.lua over it into the same table:
--*        same-key values are overwritten by FA, FA-only keys are appended.
--*        (This is exactly "load SC first, then FA overwrites/supplements".)
--*     3. Wrap global LOC() so that <LOC key> lookups hit the merged table
--*        first; fall back to the original LOC (which reads FA's loc_table).
--*        Strings without a <LOC > tag go straight to original LOC.
--
--*   Why not just patch loc_table?  loc_table is an upvalue-local of the
--*   base Localization.lua, unreachable from here. Wrapping LOC() is the
--*   supported hook point (LOCF/LOC_ALL call LOC internally, so they follow).
--
--*   Dictionary files (shipped in this .scd):
--*     /lua/sc_campaign/loc/<LANG>/strings_db.lua   (LANG = CN CZ DE ES FR IT PL RU US)
--*   These are verbatim copies of Supreme Commander's gamedata/loc_XX.scd.
--*****************************************************************************

-- FA's engine has already loaded its own loc; __language is lowercase ('cn').
local engineLang = tostring(__language or '')
if engineLang == '' then
    engineLang = 'us'
end
engineLang = string.lower(engineLang)

-- SC dictionary dirs are UPPERCASE (CN CZ DE ES FR IT PL RU US); FA loc dirs are
-- also uppercase on disk (CN TW US). Engine FS is case-insensitive, but we
-- normalize to uppercase explicitly for the SC dict path.
local scLang = string.upper(engineLang)

local SC_DICT_ROOT = '/lua/sc_campaign/loc/'

-- Build the merged table: SC first, then FA over it.
local merged = {}
local ok, err

-- 1) SC original dictionary (full)
ok, err = pcall(doscript, SC_DICT_ROOT .. scLang .. '/strings_db.lua', merged)
if not ok then
    LOG('SC campaign loc: no SC dict for lang=' .. scLang .. ' (' .. tostring(err) .. ')')
else
    LOG('SC campaign loc: loaded SC dict for ' .. scLang)
end

-- 2) FA dictionary over it (same-key overwrite, FA-only append)
ok, err = pcall(doscript, '/loc/' .. scLang .. '/strings_db.lua', merged)
if not ok then
    LOG('SC campaign loc: FA overlay load failed for ' .. scLang .. ' (' .. tostring(err) .. ')')
else
    LOG('SC campaign loc: FA overlay applied for ' .. scLang)
end

local oldLOC = LOC

-- count keys for logging
local n = 0
for _ in pairs(merged) do n = n + 1 end
LOG('SC campaign loc: merged dict keys = ' .. n)

function LOC(s)
    if type(s) ~= 'string' then
        return oldLOC(s)
    end
    if string.sub(s, 1, 5) == '<LOC ' then
        local i = string.find(s, '>')
        if i then
            local key = string.sub(s, 6, i - 1)
            local v = merged[key]
            if v ~= nil then
                return LocExpand(v)
            end
        end
    end
    return oldLOC(s)
end

LOG('SC campaign localization merge installed (lang=' .. engineLang .. ')')