--*****************************************************************************
--* File: schook/lua/ui/campaign/campaignmanager.lua
--* Summary: Hook OperationVictory + LaunchBriefing to route SC campaign ops
--*****************************************************************************

-- Save original FA OperationVictory
local baseFAOperationVictory = OperationVictory
local baseFALaunchBriefing = LaunchBriefing

function OperationVictory(ovTable, skipDialog)
    LOG('=== schook campaignmanager.OperationVictory DEBUG ===')
    LOG('  ovTable.opKey=' .. tostring(ovTable and ovTable.opKey))
    LOG('  ovTable.success=' .. tostring(ovTable and ovTable.success))
    LOG('  ovTable.campaignID=' .. tostring(ovTable and ovTable.campaignID))
    LOG('  skipDialog=' .. tostring(skipDialog))
    -- Route to SC campaignmanager for original campaign (SCCA_ ops)
    if ovTable.opKey and string.sub(ovTable.opKey, 1, 5) == 'SCCA_' then
        LOG('  Routing to SC campaignmanager')
        import('/lua/sc_campaign/campaignmanager.lua').OperationVictory(ovTable, skipDialog)
    else
        LOG('  Routing to FA OperationVictory')
        baseFAOperationVictory(ovTable, skipDialog)
    end
end

-- Hook LaunchBriefing: intercept SC_HOLD placeholder (do nothing, let score
-- screen survive) and route SCCA_ ops to SC's own LaunchOperation.
function LaunchBriefing(nextOpData)
    LOG('=== schook campaignmanager.LaunchBriefing DEBUG ===')
    if nextOpData then
        LOG('  nextOpData.opID=' .. tostring(nextOpData.opID))
        LOG('  nextOpData.campaignID=' .. tostring(nextOpData.campaignID))
        LOG('  nextOpData.difficulty=' .. tostring(nextOpData.difficulty))
    else
        LOG('  nextOpData is nil')
    end
    if nextOpData and nextOpData.opID == 'SC_HOLD' then
        -- Placeholder set by SC campaignmanager.OperationVictory to prevent
        -- main_menu.sfd from covering the score screen. Return true so
        -- StartFrontEndUI does not fall through to main.lua.CreateUI().
        LOG('  SC_HOLD detected: returning true (no action, score screen survives)')
        return true
    end
    if nextOpData and string.sub(nextOpData.opID, 1, 5) == 'SCCA_' then
        -- Route SC campaign ops to SC briefing system
        LOG('  SCCA_ op detected: routing to SC LaunchOperation')
        local SCM = import('/lua/sc_campaign/campaignmanager.lua')
        SCM.LaunchOperation(nextOpData.opID, nextOpData.difficulty)
        return true
    end
    -- FA campaign ops: use original FA LaunchBriefing
    LOG('  FA op: calling baseFALaunchBriefing')
    return baseFALaunchBriefing(nextOpData)
end
