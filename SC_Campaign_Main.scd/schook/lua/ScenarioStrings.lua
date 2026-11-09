--*****************************************************************************
-- File     :  schook/lua/ScenarioStrings.lua
-- Style    :  Sorian AI Pack hook convention (self-contained do ... end block,
--             executed after the original /lua/ScenarioStrings.lua chunk).
--
-- Summary  :  Restores the three "generic reminder" dialogue tables that exist
--             in the original Supreme Commander ScenarioStrings.lua but were
--             dropped from Forged Alliance.
--
-- Why this is needed
-- ------------------
-- The ported campaign scripts reference these tables in 37 live call sites
-- across 8 maps:
--
--     Aeon    : A02 (4), A03 (2), A06 (3)
--     Cybran  : R02 (7), R03 (7), R04 (5), R05 (4)
--     UEF     : E02 (2), E03 (3)
--
-- Typical call:
--     ScenarioFramework.Dialogue( ScenarioStrings.UEFGenericReminder )
--
-- In FA the symbol resolves to nil and ScenarioFramework.Dialogue does
--     local dTable = table.deepcopy(dialogueTable)   --> nil
--     dTable.Callback = callback                     --> hard Lua error
-- so the first reminder the player triggers kills the mission script.
--
-- NOTE: the existence tests must use rawget(_G, ...). FA installs a strict
-- __index guard on _G (lua/system/config.lua) that raises
-- "access to nonexistent global variable X" on a plain read - writing
-- `if not X then` would abort this very hook before it could define X.
--*****************************************************************************
do

LOG('[SC Campaign] schook/lua/ScenarioStrings.lua loaded')

local SC_rawget = rawget

-- The <LOC ...> keys below already exist in this campaign's localisation
-- (SC_Campaign_Main_Localization.scd/lua/sc_campaign/loc/*/strings_db.lua),
-- including the Chinese translation, so only the table binding is missing.

if not SC_rawget(_G, 'UEFGenericReminder') then
    UEFGenericReminder = {
        {
            text = '<LOC E01_M01_060_010>[{i EarthCom}]: Sir, maybe you should check your objectives.',
            vid = 'E01_EarthCom_M01_01131.sfd',
            bank = 'E01_VO',
            cue = 'E01_EarthCom_M01_01131',
            faction = 'UEF',
        },
    }
end

if not SC_rawget(_G, 'CybranGenericReminder') then
    CybranGenericReminder = {
        {
            text = '<LOC C01_M01_060_010>[{i Ops}]: I would suggest you check your objectives, Commander. Ops out.',
            vid = 'C01_Ops_M01_01536.sfd',
            bank = 'C01_VO',
            cue = 'C01_Ops_M01_01536',
            faction = 'Cybran',
        },
    }
end

if not SC_rawget(_G, 'AeonGenericReminder') then
    AeonGenericReminder = {
        {
            text = '<LOC A01_M01_060_010>[{i Choir}]: Check your objectives if necessary, Commander. Choir out.',
            vid = 'A01_Choir_M01_01557.sfd',
            bank = 'A01_VO',
            cue = 'A01_Choir_M01_01557',
            faction = 'Aeon',
        },
    }
end

LOG('[SC Campaign] ScenarioStrings: restored UEF/Cybran/Aeon GenericReminder dialogue tables')

end
