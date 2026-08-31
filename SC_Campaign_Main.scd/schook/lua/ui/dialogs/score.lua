--*****************************************************************************
--* File: schook/lua/ui/dialogs/score.lua
--* Summary: Hook CreateDialog to route SC campaign (SCCA_) ops to a custom
--*          SC-style campaign score screen (text debriefing + objective list
--*          + medals + faction-themed backgrounds) instead of FA's video-based
--*          debrief which crashes on SC ops.
--*
--*          This faithfully recreates SC's campaignscore.lua layout using
--*          extracted SC textures:
--*          - Faction background (/dialogs/score-{faction}/background_bmp.dds)
--*          - Faction border    (/dialogs/score-{faction}/back_brd_*.dds)
--*          - Faction panels    (/dialogs/score-{faction}/panels_bmp.dds)
--*          - Faction text box  (/dialogs/score-{faction}/text-box_bmp.dds)
--*          - Faction buttons   (/medium-{faction}-btn/medium02, /{faction}-btn-small/small)
--*          - Faction scrollbar (/small-vert_scroll-{faction}/)
--*          - Mission medals    (/missions/medal-*.dds)
--*****************************************************************************

-- Save original FA CreateDialog before we override it
local baseFACreateDialog = CreateDialog

local UIUtil = import('/lua/ui/uiutil.lua')
local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local EffectHelpers = import('/lua/maui/effecthelpers.lua')
local Group = import('/lua/maui/group.lua').Group
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local Button = import('/lua/maui/button.lua').Button
local Text = import('/lua/maui/text.lua').Text
local MultiLineText = import('/lua/maui/multilinetext.lua').MultiLineText
local Checkbox = import('/lua/maui/checkbox.lua').Checkbox
local Tooltip = import('/lua/ui/game/tooltip.lua')
local ItemList = import('/lua/maui/itemlist.lua').ItemList
local CampaignManager = import('/lua/ui/campaign/campaignmanager.lua')
local Prefs = import('/lua/user/prefs.lua')

local scGUI = false

-- Faction fonts like SC original
local facFont = {
    uef = {
        font = "Zeroes Three",
        titleSize = 20,
        titleOffset = 7,
        color = 'badbdb',
        color2 = '00FFFF',
        color3 = '01aec2',
    },
    cybran = {
        font = "Wintermute",
        titleSize = 22,
        titleOffset = 7,
        color = 'f3c7ae',
        color2 = 'FF9900',
        color3 = 'dd2221',
    },
    aeon = {
        font = "Butterbelly",
        titleSize = 24,
        titleOffset = 3,
        color = 'baF0ba',
        color2 = '00FF00',
        color3 = '02b217',
    },
}

local facAmbSound = {
    uef = Sound({ Cue = 'AMB_UEF_OP_Briefing', Bank = 'SC_AmbientTest' }),
    cybran = Sound({ Cue = 'AMB_CYBRAN_OP_Briefing', Bank = 'SC_AmbientTest' }),
    aeon = Sound({ Cue = 'AMB_AEON_OP_Briefing', Bank = 'SC_AmbientTest' }),
}

local factionColors = {
    cybran = 'orange',
    uef = 'cyan',
    aeon = 'FF55FF00',
}

local PositionData = {
    DataSections = { 24, 150, 357 },
}

-- Convert opKey to faction key: SCCA_E01 -> uef, SCCA_A01 -> aeon, SCCA_R01 -> cybran
local function OpKeyToFaction(opKey)
    local factionChar = string.upper(string.sub(opKey, 6, 6))
    local factionMap = { E = 'uef', A = 'aeon', R = 'cybran' }
    return factionMap[factionChar] or 'uef'
end

-- Get player nickname
local function GetPlayerName()
    local armies = GetArmiesTable()
    if armies and armies.focusArmy and armies.armiesTable then
        local army = armies.armiesTable[armies.focusArmy]
        if army and army.nickname then
            return army.nickname
        end
    end
    return 'Commander'
end

-- Format game time seconds as HH:MM:SS
-- NOTE: SC's original code calls GetGameTimeSeconds(), which does NOT exist
-- in FA. FA's GetGameTime() returns an already-formatted string like
-- "0h01m21s", so pass strings straight through and only format numbers.
local function FormatGameTime()
    local t = GetGameTime()
    if type(t) == 'string' then
        return t
    end
    local seconds = math.floor(tonumber(t) or 0)
    local hours = math.floor(seconds / 3600)
    local mins = math.floor(math.mod(seconds, 3600) / 60)
    local secs = math.mod(seconds, 60)
    return string.format("%02d:%02d:%02d", hours, mins, secs)
end

-- Create SC-style faction border
local function CreateBorder(frame, faction)
    local borderTable = {}

    borderTable.topMiddle = Bitmap(scGUI.bg, UIUtil.UIFile('/dialogs/score-' .. faction .. '/back_brd_horz_um.dds'))
    borderTable.topLeft = Bitmap(scGUI.bg, UIUtil.UIFile('/dialogs/score-' .. faction .. '/back_brd_ul.dds'))
    borderTable.topRight = Bitmap(scGUI.bg, UIUtil.UIFile('/dialogs/score-' .. faction .. '/back_brd_ur.dds'))
    borderTable.topRightStretch = Bitmap(scGUI.bg, UIUtil.UIFile('/dialogs/score-' .. faction .. '/back_brd_horz_umr.dds'))
    borderTable.topLeftStretch = Bitmap(scGUI.bg, UIUtil.UIFile('/dialogs/score-' .. faction .. '/back_brd_horz_uml.dds'))

    borderTable.bottomLeft = Bitmap(scGUI.bg, UIUtil.UIFile('/dialogs/score-' .. faction .. '/back_brd_ll.dds'))
    borderTable.bottomRight = Bitmap(scGUI.bg, UIUtil.UIFile('/dialogs/score-' .. faction .. '/back_brd_lr.dds'))
    borderTable.bottomLeftStretch = Bitmap(scGUI.bg, UIUtil.UIFile('/dialogs/score-' .. faction .. '/back_brd_horz_lml.dds'))
    borderTable.bottomRightStretch = Bitmap(scGUI.bg, UIUtil.UIFile('/dialogs/score-' .. faction .. '/back_brd_horz_lmr.dds'))

    LayoutHelpers.AtHorizontalCenterIn(borderTable.topMiddle, frame)
    LayoutHelpers.AtTopIn(borderTable.topMiddle, frame)

    borderTable.topLeft.Left:Set(frame.Left)
    borderTable.topRight.Right:Set(frame.Right)
    borderTable.topLeft.Top:Set(frame.Top)
    borderTable.topRight.Top:Set(frame.Top)

    borderTable.bottomLeft.Left:Set(frame.Left)
    borderTable.bottomRight.Right:Set(frame.Right)
    borderTable.bottomLeft.Bottom:Set(frame.Bottom)
    borderTable.bottomRight.Bottom:Set(frame.Bottom)

    borderTable.topLeftStretch.Top:Set(borderTable.topLeft.Top)
    borderTable.topRightStretch.Top:Set(borderTable.topLeft.Top)

    borderTable.bottomLeftStretch.Top:Set(borderTable.bottomLeft.Top)
    borderTable.bottomRightStretch.Top:Set(borderTable.bottomRight.Top)
    borderTable.bottomLeftStretch.Bottom:Set(borderTable.bottomLeft.Bottom)
    borderTable.bottomRightStretch.Bottom:Set(borderTable.bottomRight.Bottom)

    borderTable.topLeftStretch.Left:Set(borderTable.topLeft.Right)
    borderTable.topLeftStretch.Right:Set(borderTable.topMiddle.Left)
    borderTable.topRightStretch.Left:Set(borderTable.topMiddle.Right)
    borderTable.topRightStretch.Right:Set(borderTable.topRight.Left)

    borderTable.bottomLeftStretch.Left:Set(borderTable.bottomLeft.Right)
    borderTable.bottomLeftStretch.Right:Set(borderTable.bottomRightStretch.Left)
    borderTable.bottomRightStretch.Right:Set(borderTable.bottomRight.Left)

    return borderTable
end

-- Build objective log from FA's objective table (simplified vs SC's Widgets)
local function FormatObjectiveInfo()
    local retTable = {}
    local sortedCom = {}
    local sortedFail = {}

    local ok, obTable = pcall(function()
        return import('/lua/ui/game/objectives2.lua').GetCurrentObjectiveTable()
    end)
    if not ok or not obTable then return retTable end

    for key, obj in obTable do
        local entry = {
            title = obj.title or key,
            type = obj.type or 'primary',
            Status = obj.complete or 'incomplete',
            StartTime = nil,
            EndTime = nil,
            HideIcon = true,
        }
        if obj.complete == 'complete' then
            table.insert(sortedCom, entry)
        else
            table.insert(sortedFail, entry)
        end
    end

    local index = 1
    local function SortFunc(t1, t2)
        return false -- preserve original order
    end

    if table.getn(sortedCom) > 0 then
        retTable[index] = { type = 'title', title = '<LOC objui_0003>', color = 'ff5fbde9' }
        index = index + 1
        table.sort(sortedCom, SortFunc)
        for i, v in sortedCom do
            retTable[index] = v
            index = index + 1
        end
    end
    if table.getn(sortedFail) > 0 then
        retTable[index] = { type = 'title', title = '<LOC objui_0004>', color = 'ffe95f5f' }
        index = index + 1
        table.sort(sortedFail, SortFunc)
        for i, v in sortedFail do
            retTable[index] = v
            index = index + 1
        end
    end

    return retTable
end

-- ============================================================================
-- Main SC campaign score screen builder
-- ============================================================================
local function CreateSCCampaignScoreScreen(victory, operationVictoryTable)
    local opId = operationVictoryTable.opKey
    local faction = OpKeyToFaction(opId)
    local playerName = GetPlayerName()

    -- Clean up previous dialog
    if scGUI then
        if scGUI.bg then scGUI.bg:Destroy() end
        scGUI = false
    end

    if scGUI then scGUI:Destroy() scGUI = false end

    scGUI = {
        panel = false,
        bg = false,
        statSections = {},
        continueBtn = false,
        timeFieldTitle = false,
        elapsedTime = false,
        DebriefPanel = false,
        DebriefContainer = false,
        DebriefDisplay = {},
        ObjPanel = false,
        ObjContainer = false,
        ObjEntries = {},
        detailEntries = {},
    }

    -- scoreScreenActive/SessionEndGame/DisableWorldSounds/StopAllSounds
    -- are already called in the CreateDialog override (ForkThread parent)
    ConExecute("ren_Oblivion true")

    local ambSound = facAmbSound[faction]
    local playAmbSound = PlaySound(ambSound)

    local frame = GetFrame(0)

    -- Background
    scGUI.bg = Bitmap(frame, UIUtil.UIFile('/dialogs/score-' .. faction .. '/background_bmp.dds'))
    LayoutHelpers.FillParent(scGUI.bg, frame)
    scGUI.bg.Depth:Set(frame:GetTopmostDepth() + 1)

    -- Border
    scGUI.bg.border = CreateBorder(frame, faction)

    -- Main panels
    scGUI.panel = Bitmap(scGUI.bg, UIUtil.UIFile('/dialogs/score-' .. faction .. '/panels_bmp.dds'))
    scGUI.panel.Top:Set(function()
        return 48 + math.floor((frame.Height() - 48 - 79 - scGUI.panel.Height()) / 2)
    end)
    LayoutHelpers.AtHorizontalCenterIn(scGUI.panel, frame)
    scGUI.bg.OnDestroy = function(self)
        ConExecute("ren_Oblivion false")
    end

    -- Operation title
    local opNameText = opId
    local okOp, opStrings = pcall(import, '/maps/' .. opId .. '/' .. opId .. '_strings.lua')
    if okOp and opStrings and opStrings.OPERATION_NAME then
        opNameText = opStrings.OPERATION_NAME
    end
    scGUI.title = UIUtil.CreateText(scGUI.panel, opNameText, facFont[faction].titleSize, facFont[faction].font)
    scGUI.title:SetColor(facFont[faction].color2)
    LayoutHelpers.AtHorizontalCenterIn(scGUI.title, frame)
    LayoutHelpers.AtTopIn(scGUI.title, frame, facFont[faction].titleOffset)

    -- Game time
    scGUI.timeFieldTitle = UIUtil.CreateText(scGUI.panel, LOC('<LOC SCORE_0029>Game Time:'), 16, "Arial")
    LayoutHelpers.AtLeftTopIn(scGUI.timeFieldTitle, scGUI.panel, 75, 574)

    scGUI.elapsedTime = UIUtil.CreateText(scGUI.panel, FormatGameTime(), 16, "Arial Bold")
    LayoutHelpers.AtLeftTopIn(scGUI.elapsedTime, scGUI.panel, 220, 574)
    scGUI.elapsedTime:SetColor('fff79e00')

    ------------------------------------------------
    -- Continue button (medium faction button)
    ------------------------------------------------
    scGUI.continueBtn = UIUtil.CreateButtonStd(scGUI.panel, '/medium-' .. faction .. '-btn/medium02', '<LOC _Continue>', 20, 2)
    LayoutHelpers.AtRightIn(scGUI.continueBtn, scGUI.bg.border.bottomRight, 80)
    LayoutHelpers.AtBottomIn(scGUI.continueBtn, scGUI.bg.border.bottomRight, 6)
    Tooltip.AddButtonTooltip(scGUI.continueBtn, 'PostScore_Quit', 1)

    scGUI.continueBtn.glow = Bitmap(scGUI.continueBtn, UIUtil.UIFile('/medium-' .. faction .. '-btn/medium02_btn_glow.dds'))
    LayoutHelpers.AtCenterIn(scGUI.continueBtn.glow, scGUI.continueBtn)
    scGUI.continueBtn.glow:SetAlpha(0)
    scGUI.continueBtn.glow:DisableHitTest()

    scGUI.continueBtn.pulse = Bitmap(scGUI.continueBtn, UIUtil.UIFile('/medium-' .. faction .. '-btn/medium02_btn_glow.dds'))
    LayoutHelpers.AtCenterIn(scGUI.continueBtn.pulse, scGUI.continueBtn)
    scGUI.continueBtn.pulse:DisableHitTest()
    EffectHelpers.Pulse(scGUI.continueBtn.pulse, 2, 0, .3)

    scGUI.continueBtn.label:SetColor(factionColors[faction])
    scGUI.continueBtn.OnRolloverEvent = function(self, event)
        if event == 'enter' then
            EffectHelpers.FadeIn(self.glow, .25, 0, 1)
            self.label:SetColor('white')
        elseif event == 'down' then
            self.label:SetColor('black')
        else
            EffectHelpers.FadeOut(self.glow, .25, 1, 0)
            self.label:SetColor(factionColors[faction])
        end
    end

    -- Skip button (small faction button)
    scGUI.skipBtn = UIUtil.CreateButtonStd(scGUI.panel, '/' .. faction .. '-btn-small/small', '<LOC _Skip>', 16)
    LayoutHelpers.AtBottomIn(scGUI.skipBtn, scGUI.bg.border.bottomLeft, -8)
    LayoutHelpers.AtLeftIn(scGUI.skipBtn, scGUI.bg.border.bottomRight, -12)
    scGUI.skipBtn.label:SetColor(factionColors[faction])
    scGUI.skipBtn.OnRolloverEvent = function(self, event)
        if event == 'enter' then
            self.label:SetColor('white')
        elseif event == 'exit' then
            self.label:SetColor(factionColors[faction])
        elseif event == 'down' then
            self.label:SetColor('black')
        end
    end

    -- Restart button
    scGUI.restartBtn = UIUtil.CreateButtonStd(scGUI.panel, '/' .. faction .. '-btn-small/small', '<LOC SCORE_0031>Restart', 16)
    LayoutHelpers.RightOf(scGUI.restartBtn, scGUI.skipBtn, -25)
    scGUI.restartBtn.label:SetColor(factionColors[faction])
    scGUI.restartBtn.OnRolloverEvent = function(self, event)
        if event == 'enter' then
            self.label:SetColor('white')
        elseif event == 'exit' then
            self.label:SetColor(factionColors[faction])
        elseif event == 'down' then
            self.label:SetColor('black')
        end
    end

    scGUI.restartBtn.OnClick = function(self)
        if playAmbSound then StopSound(playAmbSound, true) end
        RestartSession()
    end

    -- Button click logic
    -- Set AutoContinue for both victory and defeat so that StartFrontEndUI
    -- (hooked in schook/lua/ui/uimain.lua) can route back to the correct
    -- faction campaign screen via AutoLaunchOperation().
    --   - Victory: AutoLaunchOperation launches next op briefing (or main
    --     menu if this was the last mission of the faction).
    --   - Defeat:  AutoLaunchOperation goes to selectcampaign(faction).
    local function endgame()
        LOG('=== score screen endgame() fired (Continue/Skip clicked) ===')
        local okCM, cm = pcall(import, '/lua/sc_campaign/campaignmanager.lua')
        if okCM and cm and cm.SetAutoContinueOpStatus then
            cm.SetAutoContinueOpStatus(victory, opId, operationVictoryTable.difficulty)
        end
        ExitGame()
    end

    if victory then
        -- Last mission of each faction: label "Finish"
        if string.sub(opId, 7) == '06' then
            scGUI.continueBtn.label:SetText(LOC('<LOC SCORE_0061>Finish'))
        end
        scGUI.continueBtn.OnClick = function(self)
            if playAmbSound then StopSound(playAmbSound, true) end
            endgame()
        end
        scGUI.skipBtn:Disable()
    else
        Tooltip.AddButtonTooltip(scGUI.skipBtn, 'CampaignScore_Skip', 1)
        Tooltip.AddButtonTooltip(scGUI.restartBtn, 'CampaignScore_Restart', 1)

        scGUI.continueBtn.OnClick = function(self, modifiers)
            if playAmbSound then StopSound(playAmbSound, true) end
            endgame()
        end
        scGUI.skipBtn.OnClick = function(self)
            if playAmbSound then StopSound(playAmbSound, true) end
            operationVictoryTable.allBonus = true
            operationVictoryTable.allPrimary = true
            operationVictoryTable.allSecondary = true
            operationVictoryTable.success = true
            local okCM, cm = pcall(import, '/lua/sc_campaign/campaignmanager.lua')
            if okCM and cm and cm.OperationVictory then
                cm.OperationVictory(operationVictoryTable, true)
            end
            endgame()
        end
    end

    -- MakeInputModal calls AddInputCapture internally, which stops the
    -- leftover MouseUp from the "Operation completed" InfoDialog from
    -- falling through and auto-clicking the freshly created Continue button.
    -- IMPORTANT: pass NO callbacks. FA's MakeInputModal(ctrl, onEnter, onEsc)
    -- binds VK_ENTER / VK_ESCAPE to those callbacks, and stale keyboard events
    -- then auto-trigger continue the same way. SC's original
    -- campaignscore.lua uses a bare AddInputCapture(GUI.panel) for exactly
    -- this reason -- capture input, bind nothing.
    UIUtil.MakeInputModal(scGUI.bg)

    ------------------------------------------------
    -- Stat Area (3 DataSections)
    ------------------------------------------------
    local ArmiesTable = GetArmiesTable()
    -- Original FA (lua.scd) syncs score data via Sync.Score ->
    -- scoreaccum.lua:UpdateScoreData() (see UserSync.lua).
    -- NOTE: hotstats.lua is FAF-only and does NOT exist in vanilla lua.scd.
    local ScoreData = import('/lua/ui/game/scoreaccum.lua').scoreData

    local DataSections = {
        {
            title = '<LOC SCORE_0059>',
            color = 'fffa0000',
            catKey = 'general',
            catCol = 'count',
            sections = {
                { title = '<LOC SCORE_0002>', scorekey = 'kills',    icon = UIUtil.UIFile('/dialogs/score-uef/icon-kills_bmp.dds') },
                { title = '<LOC SCORE_0004>', scorekey = 'lost',     icon = UIUtil.UIFile('/dialogs/score-uef/icon-loss_bmp.dds') },
                { title = '<LOC SCORE_0060>Kill/Loss Ratio', scoreratio = true, icon = UIUtil.UIFile('/dialogs/score-uef/icon-kill-death_bmp.dds') },
            }
        },
        {
            title = '<LOC SCORE_0018>Units Built',
            color = 'ff00d5db',
            catKey = 'units',
            catCol = 'built',
            sections = {
                { title = '<LOC SCORE_0012>', scorekey = 'land',         icon = UIUtil.UIFile('/dialogs/score-uef/icon-land_bmp.dds') },
                { title = '<LOC SCORE_0014>', scorekey = 'air',          icon = UIUtil.UIFile('/dialogs/score-uef/icon-air_bmp.dds') },
                { title = '<LOC SCORE_0013>', scorekey = 'naval',        icon = UIUtil.UIFile('/dialogs/score-uef/icon-naval_bmp.dds') },
                { title = '<LOC SCORE_0015>', scorekey = 'structures',   icon = UIUtil.UIFile('/dialogs/score-uef/icon-structure_bmp.dds') },
                { title = '<LOC SCORE_0016>', scorekey = 'experimental', icon = UIUtil.UIFile('/dialogs/score-uef/icon_experimental.dds') },
                { title = '<LOC tooltipui0253>', scoretotal = true,      icon = UIUtil.UIFile('/dialogs/score-uef/icon-cdr_bmp.dds') },
            }
        },
        {
            title = '<LOC SCORE_0020>',
            color = 'ff91d003',
            catKey = 'resources',
            catCol = 'total',
            sections = {
                { title = '<LOC SCORE_0021>', scorekey = 'massin',    icon = UIUtil.UIFile('/dialogs/score-uef/icon-mass_bmp.dds') },
                { title = '<LOC SCORE_0022>', scorekey = 'massout',   icon = UIUtil.UIFile('/dialogs/score-uef/icon-mass_bmp.dds') },
                { title = '<LOC SCORE_0023>Mass Wasted', catKey2 = 'resources', scorekey = 'massover', icon = UIUtil.UIFile('/dialogs/score-uef/icon-mass_bmp.dds') },
                { title = '<LOC SCORE_0024>', scorekey = 'energyin',  icon = UIUtil.UIFile('/dialogs/score-uef/icon-energy_bmp.dds') },
                { title = '<LOC SCORE_0025>', scorekey = 'energyout', icon = UIUtil.UIFile('/dialogs/score-uef/icon-energy_bmp.dds') },
                { title = '<LOC SCORE_0026>Energy Wasted', catKey2 = 'resources', scorekey = 'energyover', icon = UIUtil.UIFile('/dialogs/score-uef/icon-energy_bmp.dds') },
            }
        },
    }

    local function SafeGetScore(catKey, scorekey, catCol)
        if not ScoreData or not ScoreData.current then return 0 end
        if not ScoreData.current[ArmiesTable.focusArmy] then return 0 end
        local cat = ScoreData.current[ArmiesTable.focusArmy][catKey]
        if not cat then return 0 end
        local sk = cat[scorekey]
        if not sk then return 0 end
        if catCol and sk[catCol] then
            return math.floor(tonumber(sk[catCol]) or 0)
        end
        if type(sk) == 'number' then
            return math.floor(sk)
        end
        return math.floor(tonumber(sk) or 0)
    end

    for index, sectionInfo in DataSections do
        local section = Group(scGUI.panel)
        section.title = UIUtil.CreateText(section, LOC(sectionInfo.title), 20, "Arial")
        section.title:SetColor('ffc0c0c0')
        section.title:SetDropShadow(true)
        section.data = {}

        for i, sectionInfoInner in sectionInfo.sections do
            section.data[i] = {}
            section.data[i].icon = Bitmap(section, sectionInfoInner.icon)
            section.data[i].icon.Height:Set(22)
            section.data[i].icon.Width:Set(22)
            section.data[i].text = UIUtil.CreateText(section, LOC(sectionInfoInner.title), 16, "Arial")

            local value = 0
            if sectionInfoInner.scoreratio then
                local k = tonumber(section.data[1].value:GetText()) or 0
                local l = tonumber(section.data[2].value:GetText()) or 0
                value = string.format("%2.2f", k / math.max(l, 1))
            elseif sectionInfoInner.scoretotal then
                local curIndex = 1
                local total = 0
                while curIndex < table.getn(sectionInfo.sections) do
                    total = total + (tonumber(section.data[curIndex].value:GetText()) or 0)
                    curIndex = curIndex + 1
                end
                value = tostring(total)
            elseif sectionInfoInner.catKey2 then
                -- massover/energyover are plain numbers (Economy_AccumExcess_*)
                value = tostring(SafeGetScore(sectionInfoInner.catKey2, sectionInfoInner.scorekey, nil))
            else
                value = tostring(SafeGetScore(sectionInfo.catKey, sectionInfoInner.scorekey, sectionInfo.catCol))
            end
            section.data[i].value = UIUtil.CreateText(section, value, 16, "Arial")
            section.data[i].text:SetColor(sectionInfo.color)
            section.data[i].value:SetColor(sectionInfo.color)
        end

        section.Height:Set(1)
        section.Width:Set(315)
        LayoutHelpers.AtLeftTopIn(section, scGUI.panel, 0, PositionData.DataSections[index])

        -- Format section layout
        LayoutHelpers.AtHorizontalCenterIn(section.title, section)
        LayoutHelpers.AtTopIn(section.title, section)
        for i, sectionControls in section.data do
            LayoutHelpers.AtLeftTopIn(sectionControls.icon, section, 25, (i * 26) + 9)
            LayoutHelpers.AtVerticalCenterIn(sectionControls.text, sectionControls.icon)
            LayoutHelpers.AtVerticalCenterIn(sectionControls.value, sectionControls.icon)
            LayoutHelpers.AtLeftIn(sectionControls.text, section, 55)
            LayoutHelpers.AtRightIn(sectionControls.value, section, 25)
        end

        scGUI.statSections[index] = section
    end

    ------------------------------------------------
    -- Debriefing Area
    ------------------------------------------------
    scGUI.DebriefPanel = Bitmap(scGUI.panel, UIUtil.UIFile('/dialogs/score-' .. faction .. '/text-box_bmp.dds'))
    LayoutHelpers.AtLeftTopIn(scGUI.DebriefPanel, scGUI.panel, 322, 10)

    scGUI.DebriefPanel.title = UIUtil.CreateText(scGUI.DebriefPanel, LOC('<LOC SCORE_0058>Debrief'), 18, "Arial")
    LayoutHelpers.AtLeftTopIn(scGUI.DebriefPanel.title, scGUI.DebriefPanel, 20, 8)
    if faction == 'aeon' then
        LayoutHelpers.AtLeftTopIn(scGUI.DebriefPanel.title, scGUI.DebriefPanel, 22, 10)
    end
    scGUI.DebriefPanel.title:SetColor(facFont[faction].color2)

    scGUI.DebriefContainer = Group(scGUI.DebriefPanel)
    scGUI.DebriefContainer.Height:Set(function() return scGUI.DebriefPanel.Height() - 42 end)
    scGUI.DebriefContainer.Width:Set(function() return scGUI.DebriefPanel.Width() - 52 end)
    scGUI.DebriefContainer.top = 0
    LayoutHelpers.AtLeftTopIn(scGUI.DebriefContainer, scGUI.DebriefPanel, 15, 32)

    -- Get debriefing text from SC campaign data
    local debriefingString = ''
    local debriefingIsEmail = 0
    local okDebrief, DebriefingData = pcall(import, '/lua/sc_campaign/campaigndebriefingtext.lua')
    if okDebrief and DebriefingData and DebriefingData.campaignDebriefingText and DebriefingData.campaignDebriefingText[opId] then
        local outcomeKey = 'success'
        local emailKey = 'successHeaderLines'
        if not victory then
            outcomeKey = 'failure'
            emailKey = 'failureHeaderLines'
        end
        debriefingIsEmail = DebriefingData.campaignDebriefingText[opId][emailKey] or 0
        if DebriefingData.campaignDebriefingText[opId][outcomeKey] then
            debriefingString = LOC(DebriefingData.campaignDebriefingText[opId][outcomeKey])
        end
    end

    -- Replace {g PlayerName} placeholder
    if playerName and playerName ~= '' then
        debriefingString = string.gsub(debriefingString, '%%{g PlayerName%%}', playerName)
        debriefingString = string.gsub(debriefingString, '{g PlayerName}', playerName)
    end

    -- Create debrief display elements
    local function CreateDebriefElements()
        local function CreateElement(index)
            scGUI.DebriefDisplay[index] = UIUtil.CreateText(scGUI.DebriefContainer, '', 14, "Arial")
            scGUI.DebriefDisplay[index]:DisableHitTest()
        end

        CreateElement(1)
        LayoutHelpers.AtLeftTopIn(scGUI.DebriefDisplay[1], scGUI.DebriefContainer)

        local index = 2
        while scGUI.DebriefDisplay[table.getsize(scGUI.DebriefDisplay)].Top() + scGUI.DebriefDisplay[1].Height() < scGUI.DebriefContainer.Bottom() do
            CreateElement(index)
            LayoutHelpers.Below(scGUI.DebriefDisplay[index], scGUI.DebriefDisplay[index - 1])
            index = index + 1
        end
    end
    CreateDebriefElements()

    -- Wrap debrief text
    local textBoxWidth = scGUI.DebriefContainer.Right() - scGUI.DebriefContainer.Left()
    local tempWrappedDebriefText = import('/lua/maui/text.lua').WrapText(debriefingString, textBoxWidth,
        function(text)
            return scGUI.DebriefDisplay[1]:GetStringAdvance(text)
        end)

    local wrappedDebriefText = {}
    local successString = '<LOC SCORE_0055>Operation Successful'
    if not victory then
        successString = '<LOC SCORE_0056>Operation Failed'
    end
    wrappedDebriefText[1] = { text = LOC(successString), type = 'subject' }

    local debriefIndex = 2
    for i, v in tempWrappedDebriefText do
        wrappedDebriefText[debriefIndex] = {}
        wrappedDebriefText[debriefIndex].text = v
        if debriefingIsEmail and i <= debriefingIsEmail then
            wrappedDebriefText[debriefIndex].type = 'header'
        else
            wrappedDebriefText[debriefIndex].type = 'body'
        end
        debriefIndex = debriefIndex + 1
    end

    if table.getn(wrappedDebriefText) > table.getsize(scGUI.DebriefDisplay) then
        UIUtil.CreateVertScrollbarFor(scGUI.DebriefContainer, nil, '/small-vert_scroll-' .. faction .. '/')
    end

    local numDebriefLines = function() return table.getsize(scGUI.DebriefDisplay) end

    local function DebriefDataSize()
        return table.getn(wrappedDebriefText)
    end

    scGUI.DebriefContainer.GetScrollValues = function(self, axis)
        local size = DebriefDataSize()
        return 0, size, self.top, math.min(self.top + numDebriefLines(), size)
    end
    scGUI.DebriefContainer.ScrollLines = function(self, axis, delta)
        self:ScrollSetTop(axis, self.top + math.floor(delta))
    end
    scGUI.DebriefContainer.ScrollPages = function(self, axis, delta)
        self:ScrollSetTop(axis, self.top + math.floor(delta) * numDebriefLines())
    end
    scGUI.DebriefContainer.ScrollSetTop = function(self, axis, top)
        top = math.floor(top)
        if top == self.top then return end
        local size = DebriefDataSize()
        self.top = math.max(math.min(size - numDebriefLines(), top), 0)
        self:CalcVisible()
    end
    scGUI.DebriefContainer.IsScrollable = function(self, axis)
        return true
    end
    scGUI.DebriefContainer.CalcVisible = function(self)
        local function SetTextLine(line, data)
            if data.type == 'header' then
                line:SetText(data.text)
                line:SetFont("Arial Bold", 14)
                line:SetColor(facFont[faction].color3)
            elseif data.type == 'subject' then
                line:SetText(data.text)
                line:SetFont(UIUtil.titleFont, 16)
                line:SetColor(facFont[faction].color3)
            else
                line:SetText(data.text)
                line:SetFont("Arial", 14)
                line:SetColor(facFont[faction].color)
            end
        end
        for i, v in scGUI.DebriefDisplay do
            if wrappedDebriefText[i + self.top] then
                SetTextLine(v, wrappedDebriefText[i + self.top])
            else
                v:SetText('')
            end
        end
    end
    scGUI.DebriefContainer.HandleEvent = function(control, event)
        if event.Type == 'WheelRotation' then
            local lines = 1
            if event.WheelRotation > 0 then lines = -1 end
            control:ScrollLines(nil, lines)
        end
    end

    scGUI.DebriefContainer:CalcVisible()

    ------------------------------------------------
    -- Objective Area
    ------------------------------------------------
    local ObjectiveLogData = FormatObjectiveInfo()

    scGUI.ObjPanel = Bitmap(scGUI.panel, UIUtil.UIFile('/dialogs/score-' .. faction .. '/text-box_bmp.dds'))
    LayoutHelpers.Below(scGUI.ObjPanel, scGUI.DebriefPanel)

    scGUI.ObjPanel.title = UIUtil.CreateText(scGUI.ObjPanel, LOC('<LOC tooltipui0058>Objectives'), 18, "Arial")
    LayoutHelpers.AtLeftTopIn(scGUI.ObjPanel.title, scGUI.ObjPanel, 20, 8)
    if faction == 'aeon' then
        LayoutHelpers.AtLeftTopIn(scGUI.ObjPanel.title, scGUI.ObjPanel, 22, 10)
    end
    scGUI.ObjPanel.title:SetColor(facFont[faction].color2)

    scGUI.ObjContainer = Group(scGUI.ObjPanel)
    scGUI.ObjContainer.Height:Set(function() return scGUI.ObjPanel.Height() - 40 end)
    scGUI.ObjContainer.Width:Set(function() return scGUI.ObjPanel.Width() - 52 end)
    if faction == 'aeon' then
        scGUI.ObjContainer.Width:Set(function() return scGUI.ObjPanel.Width() - 54 end)
    end
    scGUI.ObjContainer.top = 0
    LayoutHelpers.AtLeftTopIn(scGUI.ObjContainer, scGUI.ObjPanel, 15, 30)
    UIUtil.CreateVertScrollbarFor(scGUI.ObjContainer, nil, '/small-vert_scroll-' .. faction .. '/')

    -- Objective log button bar textures
    local function GetBGTextures(bgtype)
        if bgtype == 'title' then
            return UIUtil.UIFile('/dialogs/objective-log-btn-bar/tab_bmp.dds'),
                   UIUtil.UIFile('/dialogs/objective-log-btn-bar/tab_bmp.dds'),
                   UIUtil.UIFile('/dialogs/objective-log-btn-bar/tab_bmp.dds'),
                   UIUtil.UIFile('/dialogs/objective-log-btn-bar/tab_bmp.dds'),
                   UIUtil.UIFile('/dialogs/objective-log-btn-bar/tab_bmp.dds'),
                   UIUtil.UIFile('/dialogs/objective-log-btn-bar/tab_bmp.dds')
        elseif bgtype == 'bottom' then
            return UIUtil.UIFile('/dialogs/objective-log-btn-bar/bar-bottom_btn_up.dds'),
                   UIUtil.UIFile('/dialogs/objective-log-btn-bar/bar-bottom_btn_select.dds'),
                   UIUtil.UIFile('/dialogs/objective-log-btn-bar/bar-bottom_btn_over.dds'),
                   UIUtil.UIFile('/dialogs/objective-log-btn-bar/bar-bottom_btn_select.dds'),
                   UIUtil.UIFile('/dialogs/objective-log-btn-bar/bar-bottom_btn_up.dds'),
                   UIUtil.UIFile('/dialogs/objective-log-btn-bar/bar-bottom_btn_up.dds')
        else
            return UIUtil.UIFile('/dialogs/objective-log-btn-bar/bar_btn_up.dds'),
                   UIUtil.UIFile('/dialogs/objective-log-btn-bar/bar_btn_select.dds'),
                   UIUtil.UIFile('/dialogs/objective-log-btn-bar/bar_btn_over.dds'),
                   UIUtil.UIFile('/dialogs/objective-log-btn-bar/bar_btn_select.dds'),
                   UIUtil.UIFile('/dialogs/objective-log-btn-bar/bar_btn_up.dds'),
                   UIUtil.UIFile('/dialogs/objective-log-btn-bar/bar_btn_up.dds')
        end
    end

    -- Create objective entries
    local function CreateObjectiveElements()
        local function CreateElement(index)
            scGUI.ObjEntries[index] = {}
            scGUI.ObjEntries[index].bg = Checkbox(scGUI.ObjContainer, GetBGTextures('title'))
            scGUI.ObjEntries[index].bg.Left:Set(scGUI.ObjContainer.Left)
            scGUI.ObjEntries[index].bg.Right:Set(scGUI.ObjContainer.Right)
            scGUI.ObjEntries[index].bg.Height:Set(64)

            scGUI.ObjEntries[index].icon = Button(scGUI.ObjEntries[index].bg)
            scGUI.ObjEntries[index].icon:SetSolidColor('00000000')
            scGUI.ObjEntries[index].icon:DisableHitTest()
            scGUI.ObjEntries[index].icon.Height:Set(48)
            scGUI.ObjEntries[index].icon.Width:Set(48)

            scGUI.ObjEntries[index].title = UIUtil.CreateText(scGUI.ObjEntries[index].bg, '', 14, "Arial")
            scGUI.ObjEntries[index].title:DisableHitTest()

            scGUI.ObjEntries[index].time = UIUtil.CreateText(scGUI.ObjEntries[index].bg, '', 12, "Arial")
            scGUI.ObjEntries[index].time:DisableHitTest()

            scGUI.ObjEntries[index].status = UIUtil.CreateText(scGUI.ObjEntries[index].bg, '', 12, "Arial")
            scGUI.ObjEntries[index].status:DisableHitTest()

            LayoutHelpers.AtLeftIn(scGUI.ObjEntries[index].icon, scGUI.ObjEntries[index].bg, 25)
            LayoutHelpers.AtVerticalCenterIn(scGUI.ObjEntries[index].icon, scGUI.ObjEntries[index].bg)
            scGUI.ObjEntries[index].title.Top:Set(function() return scGUI.ObjEntries[index].icon.Top() + 0 end)
            scGUI.ObjEntries[index].title.Left:Set(function() return scGUI.ObjEntries[index].icon.Right() + 5 end)
            LayoutHelpers.Below(scGUI.ObjEntries[index].time, scGUI.ObjEntries[index].title)
            LayoutHelpers.Below(scGUI.ObjEntries[index].status, scGUI.ObjEntries[index].time)
        end

        CreateElement(1)
        LayoutHelpers.AtTopIn(scGUI.ObjEntries[1].bg, scGUI.ObjContainer)

        local index = 2
        while scGUI.ObjEntries[table.getsize(scGUI.ObjEntries)].bg.Top() + (2 * scGUI.ObjEntries[1].bg.Height()) < scGUI.ObjContainer.Bottom() do
            CreateElement(index)
            LayoutHelpers.Below(scGUI.ObjEntries[index].bg, scGUI.ObjEntries[index - 1].bg, -4)
            index = index + 1
        end
    end
    CreateObjectiveElements()

    local numObjLines = function() return table.getsize(scGUI.ObjEntries) end

    local function ObjDataSize()
        return table.getn(ObjectiveLogData)
    end

    scGUI.ObjContainer.GetScrollValues = function(self, axis)
        local size = ObjDataSize()
        return 0, size, self.top, math.min(self.top + numObjLines(), size)
    end
    scGUI.ObjContainer.ScrollLines = function(self, axis, delta)
        self:ScrollSetTop(axis, self.top + math.floor(delta))
    end
    scGUI.ObjContainer.ScrollPages = function(self, axis, delta)
        self:ScrollSetTop(axis, self.top + math.floor(delta) * numObjLines())
    end
    scGUI.ObjContainer.ScrollSetTop = function(self, axis, top)
        top = math.floor(top)
        if top == self.top then return end
        local size = ObjDataSize()
        self.top = math.max(math.min(size - numObjLines(), top), 0)
        self:CalcVisible()
    end
    scGUI.ObjContainer.IsScrollable = function(self, axis)
        return true
    end
    scGUI.ObjContainer.CalcVisible = function(self)
        local function SetTextLine(line, data, lineID)
            line.bg:Show()
            line.bg:SetCheck(false, true)
            if data.type == 'title' then
                line.bg:Disable()
                line.bg:SetNewTextures(GetBGTextures(data.type))
                line.icon:Hide()
                line.title:SetText(LOC(data.title))
                line.title:SetColor(data.color)
                line.title:SetFont("Arial Bold", 18)
                line.time:SetText('')
                line.status:SetText('')
                LayoutHelpers.AtVerticalCenterIn(line.title, line.icon, 8)
                line.title.Left:Set(function() return line.bg.Left() + 12 end)
            else
                local bgtype = 'middle'
                if (ObjectiveLogData[lineID + 1] and ObjectiveLogData[lineID + 1].type == 'title') or not ObjectiveLogData[lineID + 1] then
                    bgtype = 'bottom'
                end
                line.bg:SetNewTextures(GetBGTextures(bgtype))
                line.bg:Enable()
                if data.HideIcon then
                    line.icon:Hide()
                    line.title.Left:Set(function() return line.bg.Left() + 25 end)
                else
                    line.title.Left:Set(function() return line.icon.Right() + 5 end)
                    line.icon:Show()
                end
                line.title:SetColor('ffffffff')
                line.title:SetText(LOC(data.title))
                line.title:SetFont("Arial", 14)
                line.title.Top:Set(function() return line.icon.Top() + 0 end)

                -- Status text
                local status = ''
                if data.Status == 'complete' then
                    status = "<LOC objui_0003>Complete"
                elseif data.Status == 'failed' then
                    status = "<LOC objui_0004>Failed"
                else
                    status = '<LOC objui_0005>Incomplete'
                end
                line.status:SetText(LOC(status))
                line.time:SetText('')
            end
        end
        for i, v in scGUI.ObjEntries do
            if ObjectiveLogData[i + self.top] then
                SetTextLine(v, ObjectiveLogData[i + self.top], i + self.top)
            else
                v.bg:Hide()
                v.title:SetText('')
                v.time:SetText('')
                v.status:SetText('')
                v.icon:Hide()
                v.bg:Disable()
            end
        end
    end
    scGUI.ObjContainer.HandleEvent = function(control, event)
        if event.Type == 'WheelRotation' then
            local lines = 1
            if event.WheelRotation > 0 then lines = -1 end
            control:ScrollLines(nil, lines)
        end
    end

    scGUI.ObjContainer:CalcVisible()

    ------------------------------------------------
    -- Medals Area
    ------------------------------------------------
    local okMedal, medals = pcall(function()
        return import('/lua/sc_campaign/campaignmanager.lua').GetMedalBitmaps(
            opId,
            operationVictoryTable.difficulty,
            operationVictoryTable.allPrimary,
            operationVictoryTable.allSecondary,
            operationVictoryTable.allBonus
        )
    end)

    if okMedal and medals then
        -- SC-original medal style: single localized title + stacked medals
        -- (mission = bottom layer, difficulty = middle layer, award = top layer).
        -- 'p' award type (primary-only) has no texture file; only pb/ps/psb exist.
        -- Medal textures are 116x40px; scale down to ~half for higher resolutions.
        local medalW = 58
        local medalH = 20

        local medalGroup = Group(scGUI.panel)
        medalGroup.Width:Set(medalW + 30)
        LayoutHelpers.Below(medalGroup, scGUI.ObjPanel, 10)

        local medalLabel = UIUtil.CreateText(medalGroup, LOC('<LOC SCORE_0057>Operation Medal'), 14, "Arial")
        medalLabel:SetColor(facFont[faction].color2)
        LayoutHelpers.AtLeftTopIn(medalLabel, medalGroup, 0, 0)

        -- mission (bottom), difficulty (middle), award (top), stacked via AtCenterIn.
        -- IMPORTANT: only build a layer whose texture actually resolved.
        -- GetMedalBitmaps() omits result.award whenever awardType == 'p'
        -- (primary objectives only), because SC ships no medal-*-p_bmp.dds.
        -- Calling SetTexture(nil) raises "attempting to set a LazyVar's
        -- evaluation function to nil" from lazyvar.lua, which aborts the rest
        -- of CreateSCCampaignScoreScreen. Guard every layer individually.
        local layers = {}
        if medals.mission then table.insert(layers, medals.mission) end
        if medals.difficulty then table.insert(layers, medals.difficulty) end
        if medals.award then table.insert(layers, medals.award) end

        local prevLayer = false
        for _, tex in ipairs(layers) do
            local bmp = Bitmap(medalGroup)
            bmp:SetTexture(tex)
            bmp.Width:Set(medalW)
            bmp.Height:Set(medalH)
            if prevLayer then
                LayoutHelpers.AtCenterIn(bmp, prevLayer)
            else
                LayoutHelpers.CenteredBelow(bmp, medalLabel)
            end
            prevLayer = bmp
        end

        medalGroup.Height:Set(medalLabel.Height() + medalH + 10)
    end
end

--*****************************************************************************
-- Override CreateDialog: route SC campaign ops to custom SC-style screen,
-- FA ops to original.
--*****************************************************************************
function CreateDialog(victory, showCampaign, operationVictoryTable, midGame)
    if midGame then
        ExitGame()
        return
    end

    -- Route to SC-style score screen for SCCA_ ops
    if showCampaign and operationVictoryTable and operationVictoryTable.opKey
       and string.sub(operationVictoryTable.opKey, 1, 5) == 'SCCA_' then
        LOG('=== score.lua CreateDialog: SCCA_ op -> SC campaign score screen ===')
        LOG('  opKey=' .. tostring(operationVictoryTable.opKey) .. ' victory=' .. tostring(victory))
        -- Immediate setup (mirrors FA's CreateDialog)
        scoreScreenActive = true
        SessionEndGame()
        DisableWorldSounds()
        StopAllSounds()
        -- Wait for score data to sync via Sync.Score -> scoreaccum.scoreData.
        -- ForkThread also matters for input: building the screen on a later
        -- frame keeps the InfoDialog's MouseUp from reaching the new buttons.
        ForkThread(function()
            local tries = 0
            local ScoreData = import('/lua/ui/game/scoreaccum.lua').scoreData
            while not (ScoreData and ScoreData.current and ScoreData.current[GetArmiesTable().focusArmy]) do
                if tries > 20 then break end -- 10s cap, render anyway
                tries = tries + 1
                WaitSeconds(0.5)
            end
            LOG('  score data ready after ' .. tries .. ' tries, building SC score screen')
            CreateSCCampaignScoreScreen(victory, operationVictoryTable)
            LOG('=== SC score screen built (waiting for player input) ===')
        end)
    else
        LOG('=== score.lua CreateDialog: NOT an SCCA_ op -> FA base CreateDialog ===')
        -- FA original behavior
        baseFACreateDialog(victory, showCampaign, operationVictoryTable, midGame)
    end
end
