--*****************************************************************************
--* File: lua/modules/ui/campaign/campaignmanager.lua
--* Author: Chris Blackwell
--* Summary: manages campiagn logic
--*
--* Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
--*****************************************************************************

local UIUtil = import('/lua/ui/uiutil.lua')
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local Prefs = import('/lua/user/prefs.lua')

campaignSequence = {
    aeon = {
        'SCCA_A01',
        'SCCA_A02',
        'SCCA_A03',
        'SCCA_A04',
        'SCCA_A05',
        'SCCA_A06',
    },
    uef = {
        'SCCA_E01',
        'SCCA_E02',
        'SCCA_E03',
        'SCCA_E04',
        'SCCA_E05',
        'SCCA_E06',
    },
    cybran = {
        'SCCA_R01',
        'SCCA_R02',
        'SCCA_R03',
        'SCCA_R04',
        'SCCA_R05',
        'SCCA_R06',
    },
}

diffIntToDiffKey = {
    'easy',
    'medium',
    'hard',
}

diffKeyToDiffInt = {
    easy = 1,
    medium = 2,
    hard = 3,
}

-- this is sync'd from the sim, so it should be authoritative
campaignMode = false

operationToCampaignMap = {}

-- mapping of operation keys to their campaigns
for campaign, opList in campaignSequence do
    for index, op in opList do
        operationToCampaignMap[op] = campaign
    end
end

-- Campaign table format:
-- campaignID - one for each campaign
--      completedOperationID - each operation completed will have an entry
--           difficulty - one entry for each difficulty completed
--              allPrimary  - bool true if all primary objectives completed for this difficulty
--              allSecondary - bool true if all secondary objectives completed for this difficulty
--              allBonus - bool true if all bonus objectives completed for this difficulty
local function GetCampaignTable()
    local cmpt = Prefs.GetFromCurrentProfile('sc_campaign')
    if not cmpt then cmpt = {} end
    return cmpt
end

local function SetCampaignTable(newTable)
    Prefs.SetToCurrentProfile('sc_campaign', newTable)
    SavePreferences()
end

function ResetCampaign(campaignID)
    local cmpt = GetCampaignTable()
    cmpt[campaignID] = nil
    SetCampaignTable(cmpt)
end

function RecordOperationStart(operationID, difficulty)
    local cmpt = GetCampaignTable()
    local camp = operationToCampaignMap[operationID]
    if camp then
        if not cmpt[camp] then cmpt[camp] = {} end
        SetCampaignTable(cmpt)
        local autoCont = {
            Op = operationID,
            Diff = difficulty,
            Success = nil,
        }
        SetFrontEndData("AutoContinue", autoCont)        
        Prefs.SetToCurrentProfile('sc_last_campaign', camp)
    else
        WARN("RecordOperationStart: Operation ID not found - " .. operationID)
    end
end

-- don't set this if we didn't record an op start
function SetAutoContinueOpStatus(success, opKey, diff)
    local autoCont = GetFrontEndData("AutoContinue")
    if autoCont.Op == opKey then
        autoCont.Success = success
    elseif opKey and diff then
        -- this can happen when a campaign is continued from a save game
        autoCont = {
            Op = opKey,
            Diff = diff,
            Success = success,
        }
    end
    SetFrontEndData("AutoContinue", autoCont)
end

-- return the current auto continue op info
function GetAutoContinueOp()
    local autoCont = GetFrontEndData("AutoContinue")
    return autoCont.Op, autoCont.Diff, autoCont.Success
end

function ClearAutoContinueOp()
    SetFrontEndData("AutoContinue", nil)
end

function GetCompletedOperations(campaignID, difficulty)
    local cmpt = GetCampaignTable()
    local result = nil
    if cmpt[campaignID] then
        result = {}
        for op, diffTable in cmpt[campaignID] do
            if difficulty then
                if diffTable[difficulty] then
                    table.insert(result, op)
                end
            else
                if diffTable then
                    table.insert(result, op)
                end
            end
        end
    end
    return result
end

-- returns the operation ID of the next uncompleted operation
-- if null is returned it means the campaign is complete 
function GetNextIncompleteOperation(campaignID, difficulty)
    local completed = GetCompletedOperations(campaignID, difficulty)
    local highestIndex = 0 -- default to 0 so we get next + 1 when none completed
    if completed then
        for index, opID in completed do
            for cIndex, cOpID in campaignSequence[campaignID] do
                if opID == cOpID then
                    if cIndex > highestIndex then highestIndex = cIndex end
                    break
                end
            end
        end
    end

    return campaignSequence[campaignID][highestIndex + 1]
end

-- returns the operation ID of the next operation after the specified, returns nil if no op (ie the end)
function GetNextOperation(operationID)
    local campaign = operationToCampaignMap[operationID]
    local retVal = nil
    if campaign then
        for index, op in campaignSequence[campaign] do
            if op == operationID then
                retVal = campaignSequence[campaign][index + 1]
                break
            end
        end
    else
        WARN("GetNextOperation - invalid operation specified: " .. operationID)
    end
    return retVal
end

function GetLastOperation(campaignID)
    return campaignSequence[campaignID][table.getn(campaignSequence[campaignID])]
end

function GetOperationSequence(operationID)
    if operationID then
        local camp = operationToCampaignMap[operationID]
        if camp then
            for index, opID in campaignSequence[camp] do
                if opID == operationID then
                    return index
                end
            end
        end
    end
end

function CanSelect(contCamp)
    local nextOp = GetNextIncompleteOperation(contCamp)
    if nextOp then
        local index = GetOperationSequence(nextOp)
        if index and index == 1 then
            return false
        end
    end
    return true
end

function CanContinue(contCamp)
    local nextOp = GetNextIncompleteOperation(contCamp)
    if nextOp then
        local index = GetOperationSequence(nextOp)
        if index and index > 1 then
            return true
        end
    end
    return false
end

function CanQuickContinue()
    return CanContinue(Prefs.GetFromCurrentProfile('sc_last_campaign'))
end

function QuickContinue()
    local nextOp = GetNextIncompleteOperation(Prefs.GetFromCurrentProfile('sc_last_campaign'))
    if nextOp then
        LaunchOperation(nextOp, Prefs.GetFromCurrentProfile("campaign.difficulty") or 2)
    end
end

-- Operation victory table contains the following fields
--  string opKey - unique identifier for the current operation (ie SCCA_E01 would be a good key)
--  bool success - instructs UI which dialog to show
--  int difficulty - 1,2,3 currently supported
--  bool allPrimary - true if all primary objectives completed, otherwise, false
--  bool allSecondary - true if all secondary objectives completed, otherwise, false
--  bool allBonus - true if all bonus objectives completed, otherwise, false
--  int factionVideo - Opt.  If present, display this factions end game video
function OperationVictory(ovTable, skipDialog)
    LOG('=== SC campaignmanager.OperationVictory DEBUG ===')
    LOG('  ovTable.opKey=' .. tostring(ovTable.opKey))
    LOG('  ovTable.success=' .. tostring(ovTable.success))
    LOG('  ovTable.difficulty=' .. tostring(ovTable.difficulty))
    LOG('  ovTable.allPrimary=' .. tostring(ovTable.allPrimary))
    LOG('  ovTable.allSecondary=' .. tostring(ovTable.allSecondary))
    LOG('  ovTable.allBonus=' .. tostring(ovTable.allBonus))
    LOG('  ovTable.factionVideo=' .. tostring(ovTable.factionVideo))
    LOG('  ovTable.campaignID=' .. tostring(ovTable.campaignID))
    LOG('  skipDialog=' .. tostring(skipDialog))
    StopAllSounds()
    DisableWorldSounds()
    
    local resultText
    if ovTable.success == true then
        resultText = "<LOC CAMPMGR_0000>Operation completed"
    else
        resultText = "<LOC CAMPMGR_0001>Operation failed"
    end
    
    if ovTable.success == true then
        local cmpt = GetCampaignTable()
        
        local camp = operationToCampaignMap[ovTable.opKey]
        LOG('  operationToCampaignMap[' .. ovTable.opKey .. '] = ' .. tostring(camp))
        if camp then
            if not cmpt[camp] then
                cmpt[camp] = {}
            end
            if not cmpt[camp][ovTable.opKey] then
                cmpt[camp][ovTable.opKey] = {{}, {}, {}}
            end
            
            if not cmpt[camp][ovTable.opKey][ovTable.difficulty] then
                cmpt[camp][ovTable.opKey][ovTable.difficulty] = {}
            end
            
            cmpt[camp][ovTable.opKey][ovTable.difficulty].allPrimary = ovTable.allPrimary
            cmpt[camp][ovTable.opKey][ovTable.difficulty].allSecondary = ovTable.allSecondary
            cmpt[camp][ovTable.opKey][ovTable.difficulty].allBonus = ovTable.allBonus

            SetCampaignTable(cmpt)
            LOG('  Campaign progress saved')
        else
            WARN("OperationVictory: Operation ID not found - " .. ovTable.opKey)
        end
    end
    
    -- Set NextOpBriefing to a placeholder so that when the engine calls
    -- StartFrontEndUI() after SessionEndGame(), uimain.lua routes to
    -- LaunchBriefing (which we hook to do nothing for SC_HOLD) instead of
    -- main.lua.CreateUI() which would cover our score screen with main_menu.sfd
    local camp = operationToCampaignMap[ovTable.opKey]
    if camp then
        SetFrontEndData('NextOpBriefing', {opID = 'SC_HOLD', campaignID = camp, difficulty = ovTable.difficulty})
        LOG('  SetFrontEndData NextOpBriefing = SC_HOLD (camp=' .. camp .. ')')
    end

    if not skipDialog then
        LOG('  skipDialog=false: showing InfoDialog')
        import('/lua/ui/game/worldview.lua').UnlockInput()
        pcall(function()
            import('/lua/ui/game/score.lua').SignalGameOver()
        end)
        if not ovTable.factionVideo then
            LOG('  No factionVideo: calling ShowInfoDialog')
            UIUtil.ShowInfoDialog(
                GetFrame(0),
                resultText,
                "<LOC _Ok>",
                function() 
                    LOG('=== InfoDialog OK callback: calling score.lua.CreateDialog ===')
                    import('/lua/ui/dialogs/score.lua').CreateDialog(ovTable.success, true, ovTable) 
                end,
                true)
        else
            LOG('  factionVideo=' .. tostring(ovTable.factionVideo) .. ': calling PlayEndGameMovie')
            import('/lua/ui/game/missiontext.lua').PlayEndGameMovie(ovTable.factionVideo, function()
                LOG('=== PlayEndGameMovie callback: calling score.lua.CreateDialog ===')
                import('/lua/ui/dialogs/score.lua').CreateDialog(ovTable.success, true, ovTable) 
            end)
        end
    else
        LOG('  skipDialog=true: no dialog shown')
    end
end

-- Given the appropriate parameters, returns the table of bitmaps to display for a medal
function GetMedalBitmaps(operationID, difficulty, allPrimary, allSecondary, allBonus)
    if not allPrimary then return nil end    -- return nil if no primary since that doesn't merit a medal
    local awardType
    if allSecondary and not allBonus then
        awardType = 'ps'
    elseif not allSecondary and allBonus then
        awardType = 'pb'
    elseif allSecondary and allBonus then
        awardType = 'psb'
    else
        awardType = 'p'
    end

    local difficultyName = diffIntToDiffKey[difficulty]
    
    local prefix = '/missions/medal-'
    local postfix = '_bmp.dds'
    
    local facName = ''
    for k, v in campaignSequence do
    	for k1, v1 in v do
    		if operationID == v1 then
    			facName = k .. '-'
				break    		
    		end
    	end
    end
    
    local result = {}
    local difficultyPath = UIUtil.UIFile(prefix .. facName .. difficultyName .. postfix)
    local missionPath = UIUtil.UIFile(prefix .. operationID .. postfix)
    if DiskGetFileInfo(difficultyPath) then
        result.difficulty = difficultyPath
    end
    if DiskGetFileInfo(missionPath) then
        result.mission = missionPath
    end
    -- Only include award medal if its texture exists (medal-*-p_bmp.dds may not exist)
    if awardType ~= 'p' then
        local awardPath = UIUtil.UIFile(prefix .. facName .. awardType .. postfix)
        if DiskGetFileInfo(awardPath) then
            result.award = awardPath
        end
    end
    return result
end

-- Given the appropriate parameters, returns the table of bitmaps to display for a medal
function QuickGetMedalBitmaps(faction, operationID, difficulty)
    local tempopdata = GetCampaignTable()
    local opmedaldata = {}
    
    local cmpt = GetCampaignTable()
    local result = nil
    if tempopdata[faction] then
        result = {}
        for op, diffTable in tempopdata[faction] do
            if diffTable[difficulty] then
                result = diffTable[difficulty]
            end
        end
    end
    return GetMedalBitmaps(operationID, difficulty, result.allPrimary, result.allSecondary, result.allBonus)
end

-- an easy way to launch an operation
function LaunchOperation(operationID, difficulty)
    local briefingData = import('/maps/' .. operationID .. '/' .. operationID .. '_operation.lua').operationData
    import('/lua/sc_campaign/operationbriefing.lua').CreateUI(operationID, briefingData.operationBriefingData, operationToCampaignMap[operationID], difficulty)
end

-- call if you want to launch the next appropriate op, or take another action
function AutoLaunchOperation()
    local autoOp, autoDiff, autoSuccess = GetAutoContinueOp()
    if autoSuccess then
        autoOp = GetNextOperation(autoOp, autoDiff)
        ClearAutoContinueOp()
        if autoOp then
            LaunchOperation(autoOp, autoDiff)
        else
            import('/lua/ui/menus/main.lua').CreateUI()
        end
    else
        local faction = nil
        for k, v in campaignSequence do
            for k1, v1 in v do
                if v1 == autoOp then
                    faction = k
                end
            end
        end
        import('/lua/sc_campaign/selectcampaign.lua').CreateUI(faction)
    end
    return true
end

-- insta win all the campaigns
function InstaWin()
    for camp, ops in campaignSequence do
        for index, op in ops do
            for diff = 1,3 do
                local ov = {
                    opKey = op,
                    success = true,
                    difficulty = diff,
                    allPrimary = true,
                    allSecondary = true,
                    allBonus = true,
                }
                OperationVictory(ov, true)
            end
        end
    end
end

