--*****************************************************************************
--* File: lua/modules/ui/campaign/selectcampaign.lua
--* Author: Chris Blackwell, Evan Pongress
--* Summary: campaign menu options
--*
--* Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
--*****************************************************************************

local UIUtil = import('/lua/ui/uiutil.lua')
local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local EffectHelpers = import('/lua/maui/effecthelpers.lua')
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local Movie = import('/lua/maui/Movie.lua').Movie
local Slider = import('/lua/maui/slider.lua').IntegerSlider
local Button = import('/lua/maui/button.lua').Button
local ItemList = import('/lua/maui/itemlist.lua').ItemList
local PlayCampaignMovie = import('campaignmovies.lua').PlayCampaignMovie
local Group = import('/lua/maui/group.lua').Group
local Checkbox = import('/lua/maui/checkbox.lua').Checkbox
local Prefs = import('/lua/user/prefs.lua')
local CampaignManager = import('/lua/sc_campaign/campaignmanager.lua')
local Tooltip = import('/lua/ui/game/tooltip.lua')

local currentdiff = Prefs.GetFromCurrentProfile("campaign.difficulty") or 2
local currentfaction = nil
local TOOLTIP_DELAY = 1

local FactionData = import('/lua/factions.lua')

local factionIntroText = {
    uef = "<LOC campaign_select_0000>From the tattered remains of the Earth Empire emerges a new path for the future of the galaxy. The United Earth Federation seeks to reunite the scattered remnants of humanity under a single banner, so that all of Earth's children may once again live with order, justice and strength.",
    cybran = "<LOC campaign_select_0001>When the UEF \"enslaved\" the Symbionts, Dr. Gustaf Brackman and a small band of Symbionts fled to the furthest reaches of space and formed the Cybran Nation. A fusion of man and technology, their goal is simple: free their enslaved brothers and sisters and ensure lasting liberty for Cybrans everywhere.",
    aeon = "<LOC campaign_select_0002>The Aeon Illuminate are the human disciples of a now-extinct alien race, whose legacy is one of lasting peace and universal harmony: The Way. Seeing that all humanity will perish in the fires of endless warfare, the Aeon zealously seek to cleanse the galaxy so The Way may flourish."
}
local factionFMVNames = {
	uef = {'<LOC campaign_select_0008>No Matter the Cost', '<LOC campaign_select_0009>We Did It, General!'},
	cybran = {'<LOC _campaign_select_0000>Strategy, My Boy', '<LOC _campaign_select_0001>My Children Are Free'},
	aeon = {'<LOC _campaign_select_0002>What Price Must We Pay?', '<LOC _campaign_select_0003>So That Wars Can End'},
}
local factionFirstOpName = {
	uef = 'SCCA_E01',
	cybran = 'SCCA_R01',
	aeon = 'SCCA_A01'
}
local factionRolloverSound = {
    uef = "UI_UEF_Rollover",
    cybran = "UI_Cybran_Rollover",
    aeon = "UI_AEON_Rollover"
}
local factionFont = {
    uef = {
        font = "Zeroes Three",
        facNameSize = 22,
        opSelSize = 15,
        color = 'badbdb',
        color2 = '00FFFF', #'00e4ff',
        rollbackColorOver = 'FFbadbdb',
        rollbackColorDown = '00e4ff',
        rollFontColorOver = 'black',
        rollFontColorDown = 'black',
    },
    cybran = {
        font = "Wintermute",
        facNameSize = 24,
        opSelSize = 17,
        color = 'f3c7ae',
        color2 = 'FF9900',
		rollbackColorOver = 'FF9900',
        rollbackColorDown = 'FF1F1F',
        rollFontColorOver = 'black',
        rollFontColorDown = 'black',
    },
    aeon = {
        font = "Butterbelly",
        facNameSize = 26,
        opSelSize = 15,
        color = 'baF0ba',
        color2 = '00FF00',
        rollbackColorOver = '6ED660',
        rollbackColorDown = '00FF00',
        rollFontColorOver = 'black',
        rollFontColorDown = 'black',
    },
}

local ambientSoundHandle
local warpSound = {}

function CreateUI(faction)
  ambientSoundHandle = PlaySound(Sound({Cue = "AMB_Menu_Loop", Bank = "SC_AmbientTest",}))
	# parent, borders, title
	local parent = UIUtil.CreateScreenGroup(GetFrame(0), "Select Campaign ScreenGroup")

	local border = CreateBorder(parent)
	border.Depth:Set(100)

	border.title = UIUtil.CreateText(border.um, "<LOC campaign_select_0003>Choose Your Faction", 20)
	LayoutHelpers.AtHorizontalCenterIn(border.title, border.um)
	LayoutHelpers.AtTopIn(border.title, border.um, 10)
	
	# back button
    border.backBtn = UIUtil.CreateButtonStd(border.ll, '/widgets/small', "<LOC _Back>", 16, 0, 0, "UI_Back_MouseDown")
    LayoutHelpers.AtLeftIn(border.backBtn, border, 43)
    LayoutHelpers.AtBottomIn(border.backBtn, border, 4)
    
    import('/lua/ui/uimain.lua').SetEscapeHandler(function() border.backBtn.OnClick(border.backBtn) end)

    # continue/play button
	border.continueBtn = UIUtil.CreateButtonStd(border.lr, '/menus/main03/large', "<LOC _Continue>", 22, 0, 0, "UI_Menu_MouseDown", "UI_Opt_Affirm_Over")
	LayoutHelpers.AtRightIn(border.continueBtn, border, 16)
	LayoutHelpers.AtBottomIn(border.continueBtn, border, 10)
	EffectHelpers.ScaleTo(border.continueBtn, .88, 0)
	border.continueBtn.label.Top:Set(function() return border.continueBtn.Top() + 14 end)
	border.continueBtn:UseAlphaHitTest(false)
	
	border.continueBtn.glow = Bitmap(border.continueBtn, UIUtil.UIFile('/menus/main03/large_btn_glow.dds'))
	LayoutHelpers.AtCenterIn(border.continueBtn.glow, border.continueBtn)
	EffectHelpers.ScaleTo(border.continueBtn.glow, .88, 0)
	border.continueBtn.glow:SetAlpha(0)
	border.continueBtn.glow:DisableHitTest()
	
    border.continueBtn.pulse = Bitmap(border.continueBtn, UIUtil.UIFile('/menus/main03/large_btn_glow.dds'))
	LayoutHelpers.AtCenterIn(border.continueBtn.pulse, border.continueBtn)
    border.continueBtn.pulse.Width:Set(math.floor(border.continueBtn.pulse.BitmapWidth() * .88))
	border.continueBtn.pulse.Height:Set(math.floor(border.continueBtn.pulse.BitmapHeight() * .88))
	border.continueBtn.pulse:DisableHitTest()
	border.continueBtn.pulse:SetAlpha(.5)
	
    EffectHelpers.Pulse(border.continueBtn.pulse, 2, .5, 1)
    
	border.continueBtn.fmvUp = Bitmap(border.continueBtn, UIUtil.UIFile('/campaign/campaign-select-border/icon-video-white_bmp.dds'))
	LayoutHelpers.AtCenterIn(border.continueBtn.fmvUp, border.continueBtn)
	border.continueBtn.fmvUp:DisableHitTest()
	border.continueBtn.fmvUp:Hide()
	
	border.continueBtn.fmvOver = Bitmap(border.continueBtn, UIUtil.UIFile('/campaign/campaign-select-border/icon-video-black_bmp.dds'))
	LayoutHelpers.AtCenterIn(border.continueBtn.fmvOver, border.continueBtn)
	border.continueBtn.fmvOver:DisableHitTest()
	border.continueBtn.fmvOver:Hide()

	# difficulty slider
    border.diffTitle = UIUtil.CreateText(border.lr, "<LOC campaign_select_0004>Difficulty", 16)
    LayoutHelpers.AtBottomIn(border.diffTitle, border, 24)
    LayoutHelpers.AtRightIn(border.diffTitle, border, 553)
    
    border.diffEasy = UIUtil.CreateText(border.lr, "<LOC campaign_select_0005>Easy", 12, UIUtil.bodyFont)
    LayoutHelpers.AtBottomIn(border.diffEasy, border, 15)
    LayoutHelpers.AtRightIn(border.diffEasy, border, 498)
    
    border.diffNormal = UIUtil.CreateText(border.lr, "<LOC campaign_select_0006>Normal", 12, UIUtil.bodyFont)
    LayoutHelpers.RightOf(border.diffNormal, border.diffEasy, 55)
    
    border.diffHard = UIUtil.CreateText(border.lr, "<LOC campaign_select_0007>Hard", 12, UIUtil.bodyFont)
    LayoutHelpers.RightOf(border.diffHard, border.diffEasy, 150)
    
    border.diffSlider = Slider(border.lr, false, 1, 3, 1, 
    	UIUtil.UIFile('/slider02/slider_btn_up.dds'), 
    	UIUtil.UIFile('/slider02/slider_btn_over.dds'), 
    	UIUtil.UIFile('/slider02/slider_btn_down.dds'),
    	UIUtil.UIFile('/dialogs/options/slider-back_bmp.dds'))

    border.diffSlider.Top:Set(function() return border.diffEasy.Top() - 18 end)
    border.diffSlider.Left:Set(function() return border.diffEasy.Left() + 5 end)
    border.diffSlider.Right:Set(function() return border.diffHard.Right() - 5 end)
    border.diffSlider:SetValue( currentdiff )
    
    # load button
	border.loadBtn = UIUtil.CreateButtonStd(border.lr, '/widgets/small', "<LOC _Load>", 16, 0, 0, "UI_Back_MouseDown")
	LayoutHelpers.AtBottomIn(border.loadBtn, border.lr, 4)
    LayoutHelpers.AtLeftIn(border.loadBtn, border.lr, 13)

    Tooltip.AddButtonTooltip(border.loadBtn, 'esc_load', TOOLTIP_DELAY)
    
	# border functionality
	border.backBtn.OnClick = function()
    	parent:Destroy()
    	import('/lua/ui/menus/main.lua').CreateUI()
    end

    border.loadBtn.OnClick = function(self, modifiers)
        import('/lua/ui/dialogs/saveload.lua').CreateLoadDialog(parent, nil, "CampaignSave")
    end

    border.diffSlider.OnValueSet = function(self, newValue)
    	# 1 = easy, 2 = normal, 3 = hard
        currentdiff = math.floor(newValue)
    	  local sound = Sound({Bank = 'Interface', Cue = 'UI_Tab_Click_01'})
    	  PlaySound(sound)
        Prefs.SetToCurrentProfile("campaign.difficulty", currentdiff)
    end
    
    border.diffSlider.OnScrub = function(self)
    	  local sound = Sound({Bank = 'Interface', Cue = 'UI_Tab_Click_01'})
    	  PlaySound(sound)
    end
    
    border.diffSlider.OnBeginChange = function(self)
    	  local sound = Sound({Bank = 'Interface', Cue = 'UI_Tab_Click_01'})
    	  PlaySound(sound)
    end

	border.continueBtn.OnRolloverEvent = function(self, event) 
	   	if event == 'enter' then
			EffectHelpers.FadeIn(self.glow, .25, 0, 1)
			self.label:SetColor('black')
			if not self.fmvUp:IsHidden() then
			    self.fmvUp:Hide()
			    self.fmvOver:Show()
			end
		elseif event == 'down' then
			self.label:SetColor('black')
		else
			EffectHelpers.FadeOut(self.glow, .25, 1, 0)
			self.label:SetColor('FFbadbdb')
		    if not self.fmvOver:IsHidden() then
			    self.fmvOver:Hide()
			    self.fmvUp:Show()
			end
		end
	end

    # TODO: automatically go to the current campaign screen
    MakeFactionUI(faction or 'uef', parent, border)
end

function MakeFactionUI(faction, parent, border)
	currentfaction = faction
    local textFontSize = 16
	local listFontSize = 14
	
	# faction data and init
    local opInfo = {}
    opInfo.ops = {}
	opInfo.nextop = {}

	function GetOpData(table, index, opName)
	    local opFile = import('/maps/'..opName..'/'..opName..'_operation.lua')
		table[index] = {}
    	table[index].ID = opName
       	table[index].name = index .. '. ' .. LOC(opFile.operationData.operationSelectData.long_name)
    	table[index].briefData = opFile.operationData.operationBriefingData
    end

    border.continueBtn.label:Show()
    border.continueBtn.fmvUp:Hide()
    
    local currentprogress = CampaignManager.GetCompletedOperations(faction)
    if currentprogress and table.getn(currentprogress) > 0 then
    	# campaign in progress
    	table.sort(currentprogress)
        local nextop = CampaignManager.GetNextIncompleteOperation(faction)
        if not nextop then
    	    # entire campaign has been finished
    	    opInfo.outroFMV = true
    	    border.continueBtn.label:SetText(LOC('<LOC _Replay>Replay'))
    	    Tooltip.AddButtonTooltip(border.continueBtn, 'campaignselect_replay', TOOLTIP_DELAY)
        else
            table.insert(currentprogress, nextop)
            border.continueBtn.label:SetText(LOC('<LOC _Continue>Continue'))
            Tooltip.AddButtonTooltip(border.continueBtn, 'campaignselect_continue', TOOLTIP_DELAY)
        end
	    for k, v in currentprogress do
	        #LOG('currentprogress[',k,']: ',v)
			GetOpData(opInfo.ops, k, v)
	    end
        opInfo.nextop = table.getn(currentprogress)
	else
		# no ops started; brand new campaign
		opInfo.new = true
		opInfo.nextop = 1
		GetOpData(opInfo.ops, 1, factionFirstOpName[faction])
       	border.continueBtn.label:SetText(LOC('<LOC _Select>Select'))
       	Tooltip.AddButtonTooltip(border.continueBtn, 'campaignselect_select', TOOLTIP_DELAY)
	end

	# background
	local facBack = Bitmap(parent, UIUtil.UIFile('/campaign/campaign-select-' .. faction .. '-16x12/background_bmp.dds'))
	LayoutHelpers.FillParent(facBack, parent)

    # planet and commander movies
    local facMovie = Movie(facBack)
    LayoutHelpers.AtCenterIn(facMovie, parent)
    facMovie.Width:Set(parent.Width)
    LayoutHelpers.FromBottomIn(facMovie, parent, .2)
    facMovie.Top:Set(function() return math.floor(parent.Height() * .2) end)
    facMovie:Hide()

    local facMovieBorder = Bitmap(parent, UIUtil.UIFile('/campaign/campaign-select-' .. faction .. '-16x12/movie-panel_bmp.dds'))
    facMovieBorder.Depth:Set(facMovie.Depth() - 1)
    LayoutHelpers.FillParentRelativeBorder(facMovieBorder, facMovie, -.04)
    
    local facCommander = Bitmap(facBack, UIUtil.UIFile('/campaign/campaign-select-' .. faction .. '-16x12/commander02.dds'))
    facCommander.Height:Set(parent.Height)
    facCommander.Width:Set(function() return math.floor((facCommander.Height() / facCommander.BitmapHeight()) * facCommander.BitmapWidth()) end)
    LayoutHelpers.AtTopIn(facCommander, parent)
    LayoutHelpers.AtRightIn(facCommander, parent)
    facCommander.Depth:Set(facBack.Depth() + 2) # make room for glow
    facCommander:Hide()

    local facCommanderGlow = Bitmap(facCommander, UIUtil.UIFile('/campaign/campaign-select-' .. faction .. '-16x12/commander02_glow.dds'))
    LayoutHelpers.FillParent(facCommanderGlow, facCommander)
    facCommanderGlow.Depth:Set(facCommander.Depth() - 1)
    	
	local facComMov = Movie(facCommander)
	facComMov:Hide()
    facComMov:Set('/movies/campaign-select-' .. faction .. '.sfd')

	facComMov.Height:Set(facCommander.Height)
	facComMov.Width:Set(function() return math.floor((facComMov.Height() / (facComMov.MovieHeight and facComMov:MovieHeight() or 256)) * (facComMov.MovieWidth and facComMov:MovieWidth() or 256)) end)
	LayoutHelpers.AtRightIn(facComMov, facCommander)
	LayoutHelpers.AtTopIn(facComMov, facCommander)

    local facComSoundHandle = nil

	
    facMovie.OnFinished = function()
        local movFinalFrame = Bitmap(facMovie, UIUtil.UIFile('/campaign/campaign-select-' .. faction .. '/campaign_select_planet.dds'))
        LayoutHelpers.FillParent(movFinalFrame, facMovie)
        movFinalFrame.Depth:Set(facMovie.Depth)
    end

    facComMov.OnFinished = function()
        facCommander:Show()
        EffectHelpers.Pulse(facCommanderGlow, 4, 1, .75)
    end

    facMovie:Set('/movies/FMV_campsel_planet_' .. faction .. '.sfd')
    if facMovie.PauseRetractsAmBX then
        facMovie:PauseRetractsAmBX(false)
    end
    
    ForkThread(
        function()

            while true do
                if not facMovie or not facComMov then
                    return
                end
                
                local facLoaded = (facMovie.IsLoaded and facMovie:IsLoaded()) or false
                local facComLoaded = (facComMov.IsLoaded and facComMov:IsLoaded()) or false
                if facLoaded and facComLoaded then
                    break
                end
                WaitSeconds(0.1)
            end
            
            if facMovie then
                facMovie:Show()
                facMovie:Play()
                warpSound[faction] = PlaySound(Sound({Cue = "UI_Warp_Click_" .. FactionData.Factions[FactionData.FactionIndexMap[faction]].SoundPrefix, Bank = "Interface",}))
            end

            WaitSeconds(1.2)

            if facComMov then
                facComSoundHandle = PlaySound(Sound({Cue = "UI_Warp_" .. FactionData.Factions[FactionData.FactionIndexMap[faction]].SoundPrefix .. "_Commander", Bank = "Interface",}))
                facComMov:Play()
                facComMov:Show()
            end
        end
    )

	# faction panel
	local facPanel = Bitmap(facBack, UIUtil.UIFile('/campaign/campaign-select-' .. faction .. '/panel_bmp.dds'))
	LayoutHelpers.AtLeftTopIn(facPanel, parent, 19, 40)
	facPanel.Depth:Set(facCommander.Depth() + 1)
	
	if faction == 'uef' then
		facPanel.Glow = Bitmap(facPanel, UIUtil.UIFile('/campaign/campaign-select-' .. faction .. '/bracket-effect_bmp.dds'))
		LayoutHelpers.AtCenterIn(facPanel.Glow, facPanel)
		facPanel.Glow:DisableHitTest()
	end
	
	local facName = UIUtil.CreateText(facPanel, FactionData.Factions[FactionData.FactionIndexMap[faction]].DisplayName, factionFont[faction].facNameSize)
	if faction == 'uef' then
        LayoutHelpers.AtLeftTopIn(facName, facPanel, 120, 203)
    elseif faction == 'cybran' then
        LayoutHelpers.AtLeftTopIn(facName, facPanel, 120, 201)
    elseif faction == 'aeon' then
		LayoutHelpers.AtLeftTopIn(facName, facPanel, 130, 200)
	end
	facName:SetColor(factionFont[faction].color2)
	facName:SetAlpha(.9)
	
	local facText = ItemList(facPanel)
	LayoutHelpers.AtLeftTopIn(facText, facPanel, 50, 285)
	facText.Width:Set(317)
	facText.Height:Set(300)
	facText:SetFont(UIUtil.bodyFont, textFontSize)
    facText:SetColors(factionFont[faction].color, '00000000')
    facText:Disable()
	
	UIUtil.SetTextBoxText(facText, factionIntroText[faction])

	local facBtnTitle = UIUtil.CreateText(facPanel, '<LOC _Factions>Factions', 20)
	facBtnTitle:SetFont(factionFont[faction].font, 20)
	facBtnTitle:SetColor(factionFont[faction].color2)
	facBtnTitle:SetAlpha(.8)
	LayoutHelpers.AtHorizontalCenterIn(facBtnTitle, facPanel)
	if faction == 'cybran' then
		LayoutHelpers.AtTopIn(facBtnTitle, facPanel, 40)
	else
	    LayoutHelpers.AtTopIn(facBtnTitle, facPanel, 37)
	end

    # prep for movie and sound cleanup
    function CleanupMedia()
        parent:SetNeedsFrameUpdate(false)
        facMovie.OnLoaded = nil
		facMovie.OnFinished = nil
		facMovie:Stop()
		facComMov.OnFinished = nil
		facComMov:Stop()
		facComMov = nil
		facMovie = nil
        if facComSoundHandle then
            StopSound(facComSoundHandle)
            facComSoundHandle = false
        end

        # stop any warp sounds in progress
        StopSound(warpSound[faction])
        warpSound = {}
    end

    parent.OnDestroy = function()
        CleanupMedia()
        if ambientSoundHandle then
            StopSound(ambientSoundHandle)
            ambientSoundHandle = false
        end
    end

	# faction buttons
	local facBtns = Group(facPanel, "facBtns")
	LayoutHelpers.AtLeftTopIn(facBtns, facPanel)
	
	facBtns.button = {}
	
	facBtns.button.uef = MakeFactionButton(facBtns, 'uef')
	LayoutHelpers.AtLeftTopIn(facBtns.button.uef, facBtns)
	
	facBtns.button.cybran  = MakeFactionButton(facBtns, 'cybran')
	LayoutHelpers.RightOf(facBtns.button.cybran, facBtns.button.uef, -10)
	
	facBtns.button.aeon = MakeFactionButton(facBtns, 'aeon')
	LayoutHelpers.RightOf(facBtns.button.aeon, facBtns.button.cybran, -10)
	
	facBtns.button[currentfaction]:SetCheck(true)
	
	facBtns.Width:Set(facBtns.button.aeon.Right() - facBtns.button.uef.Left())
	facBtns.Height:Set(facBtns.button.uef.Height())
	LayoutHelpers.AtHorizontalCenterIn(facBtns, facPanel)
	LayoutHelpers.AtTopIn(facBtns, facPanel, 70)

	for k, v in facBtns.button do
		local faction = k
		facBtns.button[faction].OnClick = function()
		    if currentfaction != faction then
		        CleanupMedia()
			    facBack:Destroy()
			    MakeFactionUI(faction, parent, border)
			end
		end
	end

	# op select button
	local opSelBtn = nil
	local opSelPanel = nil
	if not opInfo.new then
		local opSelText = {}

		opSelBtn = UIUtil.CreateButtonStd(facBack, '/campaign/op-select-btn/op-select-' .. faction, opInfo.ops[opInfo.nextop].name, 14, 0, 0, "UI_Tab_Click_01", "UI_Tab_Rollover_01")
		LayoutHelpers.CenteredAbove(opSelBtn, border.continueBtn, 1)
		opSelBtn.Depth:Set(border.lr.Depth() + 1)
        
		opSelBtn.label:SetFont(UIUtil.bodyFont, 12)
		opSelBtn.label:SetColor(factionFont[faction].color2)
		opSelBtn.OnRolloverEvent = function(self, event)
            if event == 'enter' then
                self.label:SetColor('white')
            elseif event == 'exit' then
                self.label:SetColor(factionFont[faction].color2)
            elseif event == 'down' then
                self.label:SetColor('black')
            end
		end
		
        opSelPanel = Group(facBack, "opSelPanel")

		opSelText.ops = ItemList(opSelPanel)
		opSelText.ops.Depth:Set(opSelPanel.Depth() + 5)
		opSelText.ops.OnMouseoverItem = function(self)
		    local sound = Sound({Bank = 'Interface', Cue = 'UI_Tab_Click_01'})
		    PlaySound(sound)
		end
		opSelText.ops:SetFont(UIUtil.bodyFont, listFontSize)
	    opSelText.ops:SetColors(factionFont[faction].color, "00000000", 
	    						factionFont[faction].rollFontColorDown, factionFont[faction].rollbackColorDown, 
	    						factionFont[faction].rollFontColorOver, factionFont[faction].rollbackColorOver)
	    opSelText.ops:ShowMouseoverItem(true)

	    # add op entries
		for k, v in opInfo.ops do
	    	opSelText.ops:AddItem(v.name)
	    end
 	    opSelText.ops.Height:Set(opSelText.ops:GetRowHeight() * opSelText.ops:GetItemCount())

		# add FMV entries
		local vOffset = 5
		function CreateEntryFMV(pos)
		    local fmvTitle = {}
#"<LOC _UEF_Credits>"
#"<LOC _UEF_Teaser>"
#"<LOC _Aeon_Credits>"
#"<LOC _Aeon_Teaser>"
#"<LOC _Cybran_Credits>"
#"<LOC _Cybran_Teaser>"
    		local fmvText = ItemList(opSelText.ops)
    		fmvText.Width:Set(opSelText.ops.Width)
    		fmvText:SetFont(UIUtil.bodyFont, listFontSize)
    		fmvText.OnMouseoverItem = function(self)
    		    local sound = Sound({Bank = 'Interface', Cue = 'UI_Tab_Click_01'})
    		    PlaySound(sound)
    		end
    	    fmvText:SetColors(factionFont[faction].color2, "00000000", 
	    						factionFont[faction].rollFontColorDown, factionFont[faction].rollbackColorDown, 
	    						factionFont[faction].rollFontColorOver, factionFont[faction].rollbackColorOver)
	    	local fmvfactionname = ''
	    	if currentfaction == 'uef' then
	    	    fmvfactionname = 'UEF'
	    	elseif currentfaction == 'aeon' then
	    	    fmvfactionname = 'Aeon'
	    	elseif currentfaction == 'cybran' then
	    	    fmvfactionname = 'Cybran'
	    	end
    		if pos == 'intro' then
    		    LayoutHelpers.Above(fmvText, opSelText.ops, vOffset)
    		    fmvTitle = {LOC('<LOC _Intro_Movie>'), LOC(factionFMVNames[faction][1])}
    		    fmvText.key = {{vid = 'FMV_Campaign_Intro', cue = 'FMV_Campaign_Intro'},
    		                    {vid = 'FMV_' .. fmvfactionname .. '_Intro_1', cue = 'FMV_' .. fmvfactionname .. '_Intro_1'}}
    		else
    		    LayoutHelpers.Below(fmvText, opSelText.ops, vOffset)
    		    fmvTitle = {LOC(factionFMVNames[faction][2]), LOC('<LOC _'..fmvfactionname..'_Credits>'), LOC('<LOC _'..fmvfactionname..'_Teaser>')}
    		    fmvText.key = {{vid = 'FMV_' .. fmvfactionname .. '_Outro_1', cue = 'FMV_' .. fmvfactionname .. '_Outro_1'},
    		                    {vid = 'FMV_Credits', cue = "FMV_"..fmvfactionname.."_Credits"},
    		                    {vid = 'FMV_' .. fmvfactionname .. '_Outro_2', cue = 'FMV_' .. fmvfactionname .. '_Outro_2'}}
    		end
    		for i, v in fmvTitle do
    		local index = i
			fmvText:AddItem(v)
    		local fmvPic = Bitmap(opSelText.ops, UIUtil.UIFile('/campaign/campaign-select-' .. faction .. '/icon-video_bmp.dds'))
    		fmvPic.Height:Set(fmvText:GetRowHeight())
    		fmvPic.Width:Set(math.floor((fmvText:GetRowHeight()/fmvPic.BitmapHeight()) * fmvPic.BitmapWidth()))
    		LayoutHelpers.LeftOf(fmvPic, fmvText, 5)
    		fmvPic.Top:Set(function() return fmvText.Top() + (index - 1) * fmvText:GetRowHeight() end)
			end
			fmvText.Height:Set(function() return fmvText:GetRowHeight()*table.getn(fmvTitle) end)		
    		opSelText[pos] = fmvText
    		opSelText[pos]:ShowMouseoverItem(true)

    	end

        CreateEntryFMV('intro')
        if opInfo.outroFMV then
        	CreateEntryFMV('outro')
        end
 	    
 	    # add 'restart' option
 	    local restartOffset = 55
 	    local opSelRestart = ItemList(opSelText.ops)
 	    opSelRestart:SetFont(UIUtil.bodyFont, listFontSize)
		opSelRestart.OnMouseoverItem = function(self)
		    local sound = Sound({Bank = 'Interface', Cue = 'UI_Tab_Click_01'})
		    PlaySound(sound)
		end
	    opSelRestart:SetColors(factionFont[faction].color, "00000000", 
	    						factionFont[faction].rollFontColorDown, factionFont[faction].rollbackColorDown, 
	    						factionFont[faction].rollFontColorOver, factionFont[faction].rollbackColorOver)
        opSelRestart:ShowMouseoverItem(true)	    						
 	    opSelRestart:AddItem(LOC('<LOC campaign_select_0010>Restart Campaign') .. '...')
 	    opSelRestart.Width:Set(opSelText.ops.Width)
 	    opSelRestart.Height:Set(opSelRestart:GetRowHeight())
		LayoutHelpers.Below(opSelRestart, opSelText.ops, restartOffset) 	    
 	    
 	    # op select panel
 	    local midheight = (opSelText.ops:GetRowHeight() * opSelText.ops:GetItemCount()) + ((opSelText.intro:GetRowHeight() + vOffset) * 2) + (opSelRestart:GetRowHeight() + restartOffset) + 30
 	    
        opSelPanel.mid = Bitmap(opSelPanel, UIUtil.UIFile('/campaign/campaign-select-' .. faction .. '/op-select-panel_bmp_m.dds'))
        opSelPanel.mid.Height:Set(midheight)
        
        opSelPanel.top = Bitmap(opSelPanel.mid, UIUtil.UIFile('/campaign/campaign-select-' .. faction .. '/op-select-panel_bmp_t.dds'))
        LayoutHelpers.Above(opSelPanel.top, opSelPanel.mid, -1)
        
        opSelPanel.btm = Bitmap(opSelPanel.mid, UIUtil.UIFile('/campaign/campaign-select-' .. faction .. '/op-select-panel_bmp_b.dds'))
        LayoutHelpers.Below(opSelPanel.btm, opSelPanel.mid)
        
        opSelPanel.Height:Set(midheight + opSelPanel.top.Height() + opSelPanel.btm.Height())
 	    opSelPanel.Width:Set(opSelPanel.btm.Width)
 	    LayoutHelpers.CenteredAbove(opSelPanel, opSelBtn)
		opSelPanel:Hide()
 	    
	    LayoutHelpers.AtVerticalCenterIn(opSelText.ops, opSelPanel)
		LayoutHelpers.AtLeftIn(opSelText.ops, opSelPanel, 40)
		LayoutHelpers.AtRightIn(opSelText.ops, opSelPanel, 10)
		
		LayoutHelpers.AtCenterIn(opSelPanel.mid, opSelPanel)
		
		# click handlers for op/fmv/restart lists
        function OpSelBtnBehavior(control, row)
            opSelBtn.label:SetText(control:GetItem(row))
            opSelPanel:Hide()
            opInfo.fmv = nil
            opInfo.restart = nil
            if control == opSelText.intro or control == opSelText.outro then
                LOG(repr(control.key[row+1]))
                opInfo.fmv = control.key[row+1].vid
                if control.key[row+1].cue then
                    opInfo.cue = control.key[row+1].cue
                end
                border.continueBtn.label:Hide()
                border.continueBtn.fmvUp:Show()
                Tooltip.AddButtonTooltip(border.continueBtn, 'campaignselect_fmv', TOOLTIP_DELAY)
            else
                border.continueBtn.label:Show()
                border.continueBtn.fmvUp:Hide()
                if control == opSelRestart then
                    border.continueBtn.label:SetText(LOC('<LOC _Restart>Restart'))
                    Tooltip.AddButtonTooltip(border.continueBtn, 'campaignselect_restart', TOOLTIP_DELAY)
                    opInfo.restart = true
                else
                    if row + 1 == table.getn(opInfo.ops) and not opInfo.outroFMV then
        		        border.continueBtn.label:SetText(LOC('<LOC _Continue>Continue'))
        		        Tooltip.AddButtonTooltip(border.continueBtn, 'campaignselect_continue', TOOLTIP_DELAY)
        		    else
        		        border.continueBtn.label:SetText(LOC('<LOC _Replay>Replay'))
        		        Tooltip.AddButtonTooltip(border.continueBtn, 'campaignselect_replay', TOOLTIP_DELAY)
        		    end
                    opInfo.nextop = row + 1 # offset for 0-based itemlist
                end
            end
        end

		opSelText.intro.OnClick = function(self, row, event)
		    OpSelBtnBehavior(self, row)
		end
		
		opSelText.ops.OnClick = function(self, row, event)
		    OpSelBtnBehavior(self, row)
		end
		
		if opInfo.outroFMV then
    		opSelText.outro.OnClick = function(self, row, event)
                OpSelBtnBehavior(self, row)
    		end
    	end

        opSelRestart.OnClick = function(self, row, event)
            OpSelBtnBehavior(self, row)
        end
        
		# toggle op select button
		opSelBtn.OnClick = function()
			if opSelPanel:IsHidden() then
				opSelPanel:Show()
			else
				opSelPanel:Hide()
			end
		end
	else
		opSelBtn = UIUtil.CreateButtonStd(facBack, '/campaign/op-select-btn/op-select-' .. faction, '<LOC camp_sel0000>Play Initial Video', 14, 0, 0, "UI_Tab_Click_01", "UI_Tab_Rollover_01")
		LayoutHelpers.CenteredAbove(opSelBtn, border.continueBtn, 1)
		opSelBtn.Depth:Set(border.lr.Depth() + 1)
		opSelBtn.OnClick = function()
	        parent:Destroy()
        PlayCampaignMovie(
            'FMV_Campaign_Intro',
            GetFrame(0),
            false,
            function()
            	import('/lua/sc_campaign/selectcampaign.lua').CreateUI(currentfaction) 
            end)
		end
	end
	
	# CONTINUE button
	border.continueBtn.OnClick = function(self, modifiers)
	    if opInfo.fmv then
	        parent:Destroy()
	        # FMV is selected
            PlayCampaignMovie(
                opInfo.fmv,
                GetFrame(0),
                false,
                function()
                	import('/lua/sc_campaign/selectcampaign.lua').CreateUI(currentfaction) 
                end, nil, opInfo.cue)
        else
    		local op = opInfo.ops[opInfo.nextop]
    		if opInfo.restart then
    		    #parent, dialogText, button1Text, button1Callback, button2Text, button2Callback, button3Text, button3Callback, destroyOnCallback, modalInfo
    		    UIUtil.QuickDialog(facMovie, "<LOC campaignselect_0000>You are about to erase all progress in this campaign. Continue?", 
                    "<LOC _Yes>", function()
                        parent:Destroy()
                        import('/lua/sc_campaign/campaignmanager.lua').ResetCampaign(currentfaction)
                        import('/lua/sc_campaign/selectcampaign.lua').CreateUI(currentfaction) end, 
                    "<LOC _No>", function() 
                        parent:Destroy()
                        import('/lua/sc_campaign/selectcampaign.lua').CreateUI(currentfaction) end,
                    nil, nil, 
                    false,
                    {escapeButton = 2, enterButton = 1, worldCover = true})
    		elseif opInfo.new then
    		    parent:Destroy()
    			# new campaign
    			PlayCampaignMovie(
                'FMV_' .. currentfaction .. "_Intro_1",
                GetFrame(0),
                false,
                function()
                	import('/lua/sc_campaign/operationbriefing.lua').CreateUI(op.ID, op.briefData, currentfaction, nil, true) 
                end)
    		else
    		    parent:Destroy()
    			import('/lua/sc_campaign/operationbriefing.lua').CreateUI(op.ID, op.briefData, currentfaction, nil, false) 
    		end
    	end
    end
end

function CreateBorder(parent)
	 local border = Group(parent, "border")
	 LayoutHelpers.FillParent(border, parent)
	 border:DisableHitTest()
	 
	 border.um = Bitmap(border, UIUtil.UIFile('/campaign/campaign-select-border/back_brd_horz_um.dds'))
	 LayoutHelpers.AtHorizontalCenterIn(border.um, border)
	 LayoutHelpers.AtTopIn(border.um, border)
	 
	 border.ur = Bitmap(border, UIUtil.UIFile('/campaign/campaign-select-border/back_brd_ur.dds'))
	 LayoutHelpers.AtRightTopIn(border.ur, border)
	 
	 border.ul = Bitmap(border, UIUtil.UIFile('/campaign/campaign-select-border/back_brd_ul.dds'))
	 LayoutHelpers.AtLeftTopIn(border.ul, border)
	 
	 border.umr = Bitmap(border, UIUtil.UIFile('/campaign/campaign-select-border/back_brd_horz_umr.dds'))
	 LayoutHelpers.AtTopIn(border.umr, border)
	 border.umr.Left:Set(border.um.Right)
	 border.umr.Right:Set(border.ur.Left)
	 
	 border.uml = Bitmap(border, UIUtil.UIFile('/campaign/campaign-select-border/back_brd_horz_uml.dds'))
	 LayoutHelpers.AtTopIn(border.uml, border)
	 border.uml.Left:Set(border.ul.Right)
	 border.uml.Right:Set(border.um.Left)
	 
	 border.lr = Bitmap(border, UIUtil.UIFile('/campaign/campaign-select-border/back_brd_lr.dds'))
	 LayoutHelpers.AtRightIn(border.lr, border)
	 LayoutHelpers.AtBottomIn(border.lr, border)
	 
	 border.ll = Bitmap(border, UIUtil.UIFile('/campaign/campaign-select-border/back_brd_ll.dds'))
	 LayoutHelpers.AtLeftIn(border.ll, border)
	 LayoutHelpers.AtBottomIn(border.ll, border)
	 
	 border.lml = Bitmap(border, UIUtil.UIFile('/campaign/campaign-select-border/back_brd_horz_lml.dds'))
	 LayoutHelpers.AtBottomIn(border.lml, border)
	 border.lml.Left:Set(border.ll.Right)
	 border.lml.Right:Set(border.lr.Left)

	 return border
end

function MakeFactionButton(parent, faction)
    # parent, normalUnchecked, normalChecked, overUnchecked, overChecked, disabledUnchecked, disabledChecked, clickCue, rolloverCue, debugname) 
	local facButton = Checkbox(parent,
		UIUtil.UIFile('/campaign/logo-btn/logo-' .. faction .. '_btn_up.dds'),
		UIUtil.UIFile('/campaign/logo-btn/logo-' .. faction .. '_btn_sel.dds'),
		UIUtil.UIFile('/campaign/logo-btn/logo-' .. faction .. '_btn_over.dds'),
		UIUtil.UIFile('/campaign/logo-btn/logo-' .. faction .. '_btn_over_sel.dds'),
		UIUtil.UIFile('/campaign/logo-btn/logo-' .. faction .. '_btn_dis.dds'), 
		UIUtil.UIFile('/campaign/logo-btn/logo-' .. faction .. '_btn_dis.dds'), 
		nil, 
		factionRolloverSound[faction])
	return facButton
end