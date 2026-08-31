--*****************************************************************************
--* File: schook/lua/ui/dialogs/score.lua
--* Summary: Hook CreateDialog to route SC campaign (SCCA_) ops to a custom
--*          SC-style score screen (text debriefing + objective list + medals)
--*          instead of FA's video-based debrief which crashes on SC ops.
--*****************************************************************************

-- Save original FA CreateDialog before we override it
local baseFACreateDialog = CreateDialog

local UIUtil = import('/lua/ui/uiutil.lua')
local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local EffectHelpers = import('/lua/maui/effecthelpers.lua')
local Group = import('/lua/maui/group.lua').Group
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local Text = import('/lua/maui/text.lua').Text
local Movie = import('/lua/maui/movie.lua').Movie
local WrapText = import('/lua/maui/text.lua').WrapText
local MultiLineText = import('/lua/maui/multilinetext.lua').MultiLineText
local Checkbox = import('/lua/maui/checkbox.lua').Checkbox
local Tooltip = import('/lua/ui/game/tooltip.lua')
local ItemList = import('/lua/maui/itemlist.lua').ItemList
local CampaignManager = import('/lua/ui/campaign/campaignmanager.lua')
local Prefs = import('/lua/user/prefs.lua')

local scDialog = false

-- Faction key from opKey: SCCA_E01 -> uef, SCCA_A01 -> aeon, SCCA_R01 -> cybran
local function OpKeyToFaction(opKey)
    local factionChar = string.upper(string.sub(opKey, 6, 6))
    local factionMap = { E = 'uef', A = 'aeon', R = 'cybran' }
    return factionMap[factionChar] or 'uef'
end

-- Faction display name for title
local function FactionDisplayName(faction)
    local names = { uef = 'UEF', aeon = 'Aeon', cybran = 'Cybran' }
    return names[faction] or faction
end

-- Get player nickname from armies table
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

-- Check if a texture file exists on disk
local function TextureExists(path)
    return DiskGetFileInfo(path)
end

-- Format game time as HH:MM:SS
local function FormatGameTime()
    local seconds = math.floor(GetGameTime())
    local hours = math.floor(seconds / 3600)
    local mins = math.floor(math.mod(seconds, 3600) / 60)
    local secs = math.mod(seconds, 60)
    return string.format("%02d:%02d:%02d", hours, mins, secs)
end

-- Helper: create a border group like FA's CreateBorderGroup (reuse FA function)
local function CreateBorderGroupSafe(parent)
    -- FA's score.lua defines CreateBorderGroup as a global; call it if available
    if CreateBorderGroup then
        return CreateBorderGroup(parent)
    end
    -- Fallback: simple group
    return Group(parent)
end

-- Build SC-style campaign score screen
local function CreateSCCampaignScoreScreen(victory, operationVictoryTable)
    local opKey = operationVictoryTable.opKey
    local faction = OpKeyToFaction(opKey)
    local playerName = GetPlayerName()

    scoreScreenActive = true
    SessionEndGame()
    DisableWorldSounds()
    StopAllSounds()
    ConExecute("ren_Oblivion true")

    local frame = GetFrame(0)

    -- Destroy existing dialog if any
    if scDialog then
        scDialog:Destroy()
        scDialog = false
    end

    GetCursor():Show()

    -- Main dialog background (reuse FA's skin)
    scDialog = Bitmap(frame)
    scDialog:SetRenderPass(UIUtil.UIRP_PostGlow)
    scDialog.Depth:Set(frame:GetTopmostDepth() + 1)
    scDialog:SetNeedsFrameUpdate(true)
    scDialog:SetSolidColor('FF000000')
    scDialog.OnFrame = function(self, delta)
        self:SetNeedsFrameUpdate(false)
    end
    LayoutHelpers.FillParent(scDialog, frame)

    -- Ambient sound
    local ambientSounds = PlaySound(Sound({ Cue = "AMB_SER_OP_Briefing", Bank = "AmbientTest" }))
    scDialog.OnDestroy = function(self)
        StopSound(ambientSounds)
    end

    -- Background movie (FA menu background)
    local movieBG = Movie(scDialog, '/movies/menu_background.sfd')
    movieBG.Height:Set(frame.Height)
    movieBG.Width:Set(function()
        local ratio = frame.Height() / 1024
        return 1824 * ratio
    end)
    movieBG.OnLoaded = function(self)
        self:Loop(true)
        self:Play()
    end
    LayoutHelpers.AtCenterIn(movieBG, frame)
    movieBG:DisableHitTest()

    -- Main panel
    local bg = Bitmap(movieBG, UIUtil.UIFile('/scx_menu/score-victory-defeat/panel_bmp.dds'))
    LayoutHelpers.AtCenterIn(bg, frame)
    bg.brackets = UIUtil.CreateDialogBrackets(bg, 40, 30, 40, 30)

    -- Title
    local titleText
    if victory then
        titleText = "<LOC SCORE_0055>Operation Successful"
    else
        titleText = "<LOC SCORE_0056>Operation Failed"
    end
    bg.title = UIUtil.CreateText(bg, LOC(titleText), 20, UIUtil.titleFont)
    LayoutHelpers.AtHorizontalCenterIn(bg.title, bg)
    LayoutHelpers.AtTopIn(bg.title, bg, 28)

    -- Operation name subtitle
    local opNameText = ''
    local ok, opStrings = pcall(import, '/maps/' .. opKey .. '/' .. opKey .. '_strings.lua')
    if ok and opStrings and opStrings.OPERATION_NAME then
        opNameText = LOC(opStrings.OPERATION_NAME)
    else
        opNameText = opKey
    end
    bg.opName = UIUtil.CreateText(bg, opNameText, 14, UIUtil.bodyFont)
    LayoutHelpers.AtHorizontalCenterIn(bg.opName, bg)
    LayoutHelpers.AtTopIn(bg.opName, bg, 55)

    -- Game time
    local elapsedTimeLabel = UIUtil.CreateText(bg, "<LOC SCORE_0029>Game Time:", 16, UIUtil.bodyFont)
    LayoutHelpers.AtLeftTopIn(elapsedTimeLabel, bg, 760, 75)
    local elapsedTimeValue = UIUtil.CreateText(bg, FormatGameTime(), 16, UIUtil.bodyFont)
    LayoutHelpers.RightOf(elapsedTimeValue, elapsedTimeLabel, 5)

    -------------------------------------------------
    -- Left side: Debriefing text area
    -------------------------------------------------
    local debriefGroup = CreateBorderGroupSafe(bg)
    LayoutHelpers.AtLeftTopIn(debriefGroup, bg, 40, 90)
    debriefGroup.Height:Set(390)
    debriefGroup.Width:Set(445)

    -- Debrief title
    local debriefTitle = UIUtil.CreateText(debriefGroup, LOC("<LOC SCORE_0058>Debrief"), 16, UIUtil.titleFont)
    LayoutHelpers.AtLeftTopIn(debriefTitle, debriefGroup, 15, 8)

    -- Get debriefing text from SC campaign data
    local debriefingText = ''
    local ok2, debriefData = pcall(import, '/lua/sc_campaign/campaigndebriefingtext.lua')
    if ok2 and debriefData and debriefData.campaignDebriefingText and debriefData.campaignDebriefingText[opKey] then
        local opDebrief = debriefData.campaignDebriefingText[opKey]
        local textKey = 'failure'
        if victory then
            textKey = 'success'
        end
        if opDebrief[textKey] then
            debriefingText = LOC(opDebrief[textKey])
        end
    end

    -- Replace {g PlayerName} placeholder with actual player name
    if playerName and playerName ~= '' then
        debriefingText = string.gsub(debriefingText, '%{g PlayerName%}', playerName)
    end

    -- Determine header lines count
    local headerLines = 0
    if ok2 and debriefData and debriefData.campaignDebriefingText and debriefData.campaignDebriefingText[opKey] then
        local headerKey = 'successHeaderLines'
        if not victory then
            headerKey = 'failureHeaderLines'
        end
        headerLines = debriefData.campaignDebriefingText[opKey][headerKey] or 0
    end

    -- Debrief text container with scrollbar
    local debriefContainer = Group(debriefGroup)
    debriefContainer.Height:Set(function() return debriefGroup.Height() - 40 end)
    debriefContainer.Width:Set(function() return debriefGroup.Width() - 30 end)
    debriefContainer.top = 0
    LayoutHelpers.AtLeftTopIn(debriefContainer, debriefGroup, 12, 35)

    -- Wrap text for display
    local wrappedLines = {}
    if debriefingText and debriefingText ~= '' then
        -- Split by \n first
        local linesByNewline = {}
        local startIndex = 1
        while true do
            local nlStart, nlEnd = string.find(debriefingText, '\n', startIndex, true)
            if nlStart then
                table.insert(linesByNewline, string.sub(debriefingText, startIndex, nlStart - 1))
                startIndex = nlEnd + 1
            else
                table.insert(linesByNewline, string.sub(debriefingText, startIndex))
                break
            end
        end

        -- Wrap each line to fit container width
        for _, rawLine in linesByNewline do
            if rawLine == '' then
                table.insert(wrappedLines, { text = '', type = 'body' })
            else
                local WrappedTextLib = import('/lua/maui/text.lua')
                local tempText = UIUtil.CreateText(debriefContainer, '', 14, "Arial")
                local wrapped = WrappedTextLib.WrapText(rawLine, debriefContainer.Width(),
                    function(text)
                        return tempText:GetStringAdvance(text)
                    end)
                tempText:Destroy()
                for _, w in wrapped do
                    table.insert(wrappedLines, { text = w, type = 'body' })
                end
            end
        end
    end

    -- Mark header lines
    for i = 1, math.min(headerLines, table.getn(wrappedLines)) do
        if wrappedLines[i] then
            wrappedLines[i].type = 'header'
        end
    end

    -- Create text display elements
    local debriefDisplay = {}

    local function CreateDebriefElements()
        local function CreateElement(index)
            debriefDisplay[index] = UIUtil.CreateText(debriefContainer, '', 14, "Arial")
            debriefDisplay[index]:DisableHitTest()
        end

        CreateElement(1)
        LayoutHelpers.AtLeftTopIn(debriefDisplay[1], debriefContainer)

        local index = 2
        while debriefDisplay[table.getsize(debriefDisplay)].Bottom() + debriefDisplay[1].Height() < debriefContainer.Bottom() do
            CreateElement(index)
            LayoutHelpers.Below(debriefDisplay[index], debriefDisplay[index - 1])
            index = index + 1
        end
    end
    CreateDebriefElements()

    local numLines = function() return table.getsize(debriefDisplay) end
    local function DataSize()
        return table.getn(wrappedLines)
    end

    debriefContainer.GetScrollValues = function(self, axis)
        local size = DataSize()
        return 0, size, self.top, math.min(self.top + numLines(), size)
    end
    debriefContainer.ScrollLines = function(self, axis, delta)
        self:ScrollSetTop(axis, self.top + math.floor(delta))
    end
    debriefContainer.ScrollPages = function(self, axis, delta)
        self:ScrollSetTop(axis, self.top + math.floor(delta) * numLines())
    end
    debriefContainer.ScrollSetTop = function(self, axis, top)
        top = math.floor(top)
        if top == self.top then return end
        local size = DataSize()
        self.top = math.max(math.min(size - numLines(), top), 0)
        self:CalcVisible()
    end
    debriefContainer.IsScrollable = function(self, axis)
        return true
    end
    debriefContainer.CalcVisible = function(self)
        for i, v in debriefDisplay do
            local lineData = wrappedLines[i + self.top]
            if lineData then
                v:SetText(lineData.text)
                if lineData.type == 'header' then
                    v:SetFont("Arial Bold", 14)
                    v:SetColor('ffe59f00')
                else
                    v:SetFont("Arial", 14)
                    v:SetColor(UIUtil.fontColor)
                end
            else
                v:SetText('')
            end
        end
    end
    debriefContainer.HandleEvent = function(control, event)
        if event.Type == 'WheelRotation' then
            local lines = 1
            if event.WheelRotation > 0 then
                lines = -1
            end
            control:ScrollLines(nil, lines)
        end
    end

    UIUtil.CreateVertScrollbarFor(debriefContainer)
    debriefContainer:CalcVisible()

    -------------------------------------------------
    -- Right side: Objective list
    -------------------------------------------------
    local objGroup = CreateBorderGroupSafe(bg)
    LayoutHelpers.AtLeftTopIn(objGroup, bg, 500, 90)
    objGroup.Height:Set(250)
    objGroup.Width:Set(430)

    local objTitle = UIUtil.CreateText(objGroup, LOC("<LOC tooltipui0058>Objectives"), 16, UIUtil.titleFont)
    LayoutHelpers.AtLeftTopIn(objTitle, objGroup, 15, 8)

    -- Gather objectives from FA's objective system
    local sortedObjectives = {}
    local tempObjectives = {}
    local hasPrimaries = false
    local hasSecondaries = false

    local ok3, obTable = pcall(function()
        return import('/lua/ui/game/objectives2.lua').GetCurrentObjectiveTable()
    end)
    if ok3 and obTable then
        for key, objective in obTable do
            local compStr
            local compColor = 'ffff0000'
            if objective.complete == 'complete' then
                compStr = "<LOC SCORE_0038>Accomplished"
                compColor = 'ff00ff00'
            elseif objective.complete == 'failed' then
                compStr = "<LOC SCORE_0039>Failed"
                compColor = 'ffff0000'
            else
                compStr = "<LOC SCORE_0054>Incomplete"
                compColor = 'ff0000ff'
            end
            if objective.type == 'primary' then
                hasPrimaries = true
            elseif objective.type == 'secondary' then
                hasSecondaries = true
            end
            table.insert(tempObjectives, {
                title = LOC(objective.title) or key,
                complete = LOC(compStr) or compStr,
                completeColor = compColor,
                type = objective.type or 'primary'
            })
        end
    end

    if hasPrimaries then
        table.insert(sortedObjectives, { title = LOC("<LOC SCORE_0037>Primary Objectives"), type = 'header' })
        for _, v in tempObjectives do
            if v.type == 'primary' then
                table.insert(sortedObjectives, v)
            end
        end
    end

    if hasSecondaries then
        table.insert(sortedObjectives, { title = LOC("<LOC SCORE_0040>Secondary Objectives"), type = 'header' })
        for _, v in tempObjectives do
            if v.type == 'secondary' then
                table.insert(sortedObjectives, v)
            end
        end
    end

    -- If no objectives were found, show a placeholder
    if table.getn(sortedObjectives) == 0 then
        table.insert(sortedObjectives, { title = LOC("<LOC SCORE_0054>Incomplete"), type = 'header' })
    end

    -- Objective container with scrollbar
    local objContainer = Group(objGroup)
    objContainer.Height:Set(function() return objGroup.Height() - 40 end)
    objContainer.Width:Set(function() return objGroup.Width() - 30 end)
    objContainer.top = 0
    LayoutHelpers.AtLeftTopIn(objContainer, objGroup, 12, 35)

    local objEntries = {}

    local function CreateObjElements()
        local function CreateElement(index)
            objEntries[index] = {}
            objEntries[index].bg = Bitmap(objContainer)
            objEntries[index].bg.Left:Set(objContainer.Left)
            objEntries[index].bg.Right:Set(objContainer.Right)

            objEntries[index].title = UIUtil.CreateText(objEntries[1].bg, '', 16, UIUtil.bodyFont)
            objEntries[index].title:DisableHitTest()

            objEntries[index].result = UIUtil.CreateText(objEntries[1].bg, '', 16, UIUtil.bodyFont)
            objEntries[index].result:DisableHitTest()

            objEntries[index].bg.Height:Set(function() return objEntries[index].title.Height() + 4 end)

            LayoutHelpers.AtVerticalCenterIn(objEntries[index].title, objEntries[index].bg)
            LayoutHelpers.AtVerticalCenterIn(objEntries[index].result, objEntries[index].bg)
            LayoutHelpers.AtLeftIn(objEntries[index].title, objEntries[index].bg, 5)
            LayoutHelpers.AtRightIn(objEntries[index].result, objEntries[index].bg, 5)
        end

        CreateElement(1)
        LayoutHelpers.AtTopIn(objEntries[1].bg, objContainer)

        local index = 2
        while objEntries[table.getsize(objEntries)].bg.Top() + (2 * objEntries[1].bg.Height()) < objContainer.Bottom() do
            CreateElement(index)
            LayoutHelpers.Below(objEntries[index].bg, objEntries[index - 1].bg)
            index = index + 1
        end
    end
    CreateObjElements()

    local numObjLines = function() return table.getsize(objEntries) end
    local function ObjDataSize()
        return table.getn(sortedObjectives)
    end

    objContainer.GetScrollValues = function(self, axis)
        local size = ObjDataSize()
        return 0, size, self.top, math.min(self.top + numObjLines(), size)
    end
    objContainer.ScrollLines = function(self, axis, delta)
        self:ScrollSetTop(axis, self.top + math.floor(delta))
    end
    objContainer.ScrollPages = function(self, axis, delta)
        self:ScrollSetTop(axis, self.top + math.floor(delta) * numObjLines())
    end
    objContainer.ScrollSetTop = function(self, axis, top)
        top = math.floor(top)
        if top == self.top then return end
        local size = ObjDataSize()
        self.top = math.max(math.min(size - numObjLines(), top), 0)
        self:CalcVisible()
    end
    objContainer.IsScrollable = function(self, axis)
        return true
    end
    objContainer.CalcVisible = function(self)
        for i, v in objEntries do
            local data = sortedObjectives[i + self.top]
            if data then
                if data.type == 'header' then
                    LayoutHelpers.AtHorizontalCenterIn(v.title, objContainer)
                    v.bg:SetSolidColor('ff506268')
                    v.title:SetText(data.title)
                    v.title:SetFont(UIUtil.titleFont, 16)
                    v.title:SetColor(UIUtil.fontColor)
                    v.result:SetText('')
                else
                    LayoutHelpers.AtLeftIn(v.title, v.bg, 5)
                    v.bg:SetSolidColor('00000000')
                    v.title:SetText(data.title)
                    v.title:SetColor('ffffffff')
                    v.title:SetFont(UIUtil.bodyFont, 14)
                    v.result:SetText(data.complete or '')
                    v.result:SetColor(data.completeColor)
                end
            else
                v.bg:SetSolidColor('00000000')
                v.title:SetText('')
                v.result:SetText('')
            end
        end
    end
    objContainer.HandleEvent = function(control, event)
        if event.Type == 'WheelRotation' then
            local lines = 1
            if event.WheelRotation > 0 then
                lines = -1
            end
            control:ScrollLines(nil, lines)
        end
    end
    objContainer:CalcVisible()

    -------------------------------------------------
    -- Bottom right: Medals area (if textures exist)
    -------------------------------------------------
    local medalBitmaps = nil
    local ok4, medals = pcall(function()
        return import('/lua/sc_campaign/campaignmanager.lua').GetMedalBitmaps(
            opKey,
            operationVictoryTable.difficulty,
            operationVictoryTable.allPrimary,
            operationVictoryTable.allSecondary,
            operationVictoryTable.allBonus
        )
    end)

    if ok4 and medals then
        -- Check if all medal textures exist
        local allExist = true
        for k, v in medals do
            if not TextureExists(v) then
                allExist = false
                break
            end
        end

        if allExist then
            local medalGroup = CreateBorderGroupSafe(bg)
            LayoutHelpers.AtLeftTopIn(medalGroup, bg, 500, 355)
            medalGroup.Height:Set(125)
            medalGroup.Width:Set(430)

            local medalTitle = UIUtil.CreateText(medalGroup, LOC("<LOC SCORE_0042>Medals"), 14, UIUtil.bodyFont)
            LayoutHelpers.AtLeftTopIn(medalTitle, medalGroup, 15, 8)

            -- Display medals horizontally
            local medalIcons = {}
            local medalLabels = { difficulty = 'Difficulty', mission = 'Mission', award = 'Award' }
            local medalIndex = 1
            for key, texPath in medals do
                medalIcons[medalIndex] = Bitmap(medalGroup, texPath)
                medalIcons[medalIndex].Height:Set(48)
                medalIcons[medalIndex].Width:Set(48)
                if medalIndex == 1 then
                    LayoutHelpers.AtLeftTopIn(medalIcons[medalIndex], medalGroup, 30, 35)
                else
                    LayoutHelpers.RightOf(medalIcons[medalIndex], medalIcons[medalIndex - 1], 50)
                end

                local medalLabel = UIUtil.CreateText(medalGroup, LOC(medalLabels[key] or key), 12, UIUtil.bodyFont)
                LayoutHelpers.AtHorizontalCenterIn(medalLabel, medalIcons[medalIndex])
                LayoutHelpers.Below(medalLabel, medalIcons[medalIndex], 2)
                medalIndex = medalIndex + 1
            end
        end
    end

    -------------------------------------------------
    -- Buttons
    -------------------------------------------------
    -- Continue button
    bg.continueBtn = UIUtil.CreateButtonStd(bg, '/scx_menu/large-no-bracket-btn/large', "<LOC _Continue>", 22, 2, 0, "UI_Menu_MouseDown", "UI_Opt_Affirm_Over")
    LayoutHelpers.AtRightIn(bg.continueBtn, bg, -10)
    LayoutHelpers.AtBottomIn(bg.continueBtn, bg, 20)
    bg.continueBtn:UseAlphaHitTest(false)

    bg.continueBtn.glow = Bitmap(bg.continueBtn, UIUtil.UIFile('/scx_menu/large-no-bracket-btn/large_btn_glow.dds'))
    LayoutHelpers.AtCenterIn(bg.continueBtn.glow, bg.continueBtn)
    bg.continueBtn.glow:SetAlpha(0)
    bg.continueBtn.glow:DisableHitTest()

    bg.continueBtn.pulse = Bitmap(bg.continueBtn, UIUtil.UIFile('/scx_menu/large-no-bracket-btn/large_btn_glow.dds'))
    LayoutHelpers.AtCenterIn(bg.continueBtn.pulse, bg.continueBtn)
    bg.continueBtn.pulse:DisableHitTest()
    bg.continueBtn.pulse:SetAlpha(.5)
    EffectHelpers.Pulse(bg.continueBtn.pulse, 2, .5, 1)

    bg.continueBtn.OnRolloverEvent = function(self, event)
        if event == 'enter' then
            EffectHelpers.FadeIn(self.glow, .25, 0, 1)
            self.label:SetColor('black')
        elseif event == 'down' then
            self.label:SetColor('black')
        else
            EffectHelpers.FadeOut(self.glow, .25, 1, 0)
            self.label:SetColor('FFbadbdb')
        end
    end

    bg.continueBtn.OnClick = function(self, modifiers)
        ConExecute("ren_Oblivion false")
        if victory then
            -- Record the operation as complete and exit
            import('/lua/sc_campaign/campaignmanager.lua').SetAutoContinueOpStatus(true, opKey, operationVictoryTable.difficulty)
            ExitGame()
        else
            -- On failure, just exit
            ExitGame()
        end
    end
    Tooltip.AddButtonTooltip(bg.continueBtn, 'PostScore_Quit')

    -- Restart button (only on failure)
    if not victory then
        bg.continueBtn.label:SetText(LOC('<LOC _Skip>Skip'))
        bg.continueBtn.HandleEvent = bg.continueBtn.oldHandleEvent
        Tooltip.AddButtonTooltip(bg.continueBtn, 'CampaignScore_Skip')

        bg.restartBtn = UIUtil.CreateButtonStd(bg, '/scx_menu/large-no-bracket-btn/large', "<LOC _Restart>Restart", 22, 2, 0, "UI_Menu_MouseDown", "UI_Opt_Affirm_Over")
        LayoutHelpers.LeftOf(bg.restartBtn, bg.continueBtn, -40)
        bg.continueBtn:UseAlphaHitTest(false)

        bg.restartBtn.glow = Bitmap(bg.restartBtn, UIUtil.UIFile('/scx_menu/large-no-bracket-btn/large_btn_glow.dds'))
        LayoutHelpers.AtCenterIn(bg.restartBtn.glow, bg.restartBtn)
        bg.restartBtn.glow:SetAlpha(0)
        bg.restartBtn.glow:DisableHitTest()

        bg.restartBtn.pulse = Bitmap(bg.restartBtn, UIUtil.UIFile('/scx_menu/large-no-bracket-btn/large_btn_glow.dds'))
        LayoutHelpers.AtCenterIn(bg.restartBtn.pulse, bg.restartBtn)
        bg.restartBtn.pulse:DisableHitTest()
        bg.restartBtn.pulse:SetAlpha(.5)
        EffectHelpers.Pulse(bg.restartBtn.pulse, 2, .5, 1)

        bg.restartBtn.OnRolloverEvent = function(self, event)
            if event == 'enter' then
                EffectHelpers.FadeIn(self.glow, .25, 0, 1)
                self.label:SetColor('black')
            elseif event == 'down' then
                self.label:SetColor('black')
            else
                EffectHelpers.FadeOut(self.glow, .25, 1, 0)
                self.label:SetColor('FFbadbdb')
            end
        end

        bg.restartBtn.OnClick = function(self, modifiers)
            ConExecute("ren_Oblivion false")
            RestartSession()
        end
        Tooltip.AddButtonTooltip(bg.restartBtn, 'CampaignScore_Restart')
    end

    UIUtil.MakeInputModal(scDialog, function() bg.continueBtn:OnClick() end, function() bg.continueBtn:OnClick() end)
end

-- Override CreateDialog: route SC campaign ops to custom screen, FA ops to original
function CreateDialog(victory, showCampaign, operationVictoryTable, midGame)
    if midGame then
        ExitGame()
        return
    end

    -- Route to SC-style score screen for SCCA_ ops
    if showCampaign and operationVictoryTable and operationVictoryTable.opKey
       and string.sub(operationVictoryTable.opKey, 1, 5) == 'SCCA_' then
        CreateSCCampaignScoreScreen(victory, operationVictoryTable)
    else
        -- FA original behavior
        baseFACreateDialog(victory, showCampaign, operationVictoryTable, midGame)
    end
end
