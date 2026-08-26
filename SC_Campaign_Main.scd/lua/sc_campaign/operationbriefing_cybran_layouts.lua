#****************************************************************************
#**
#**  File     :  /lua/ui/campaign/operationbriefing_layouts.lua
#**  Author(s):  Evan Pongress
#**
#**  Summary  :  faction-specific layout information for the operation briefing screen
#**
#**  Copyright © 2006 Gas Powered Games, Inc.  All rights reserved.
#****************************************************************************

local UIUtil = import('/lua/ui/uiutil.lua')
local MenuCommon = import('/lua/ui/menus/menucommon.lua')
local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local EffectHelpers = import('/lua/maui/effecthelpers.lua')
local Movie = import('/lua/maui/movie.lua').Movie
local ItemList = import('/lua/maui/itemlist.lua').ItemList
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local Group = import('/lua/maui/group.lua').Group
local Checkbox = import('/lua/maui/checkbox.lua').Checkbox
local Button = import('/lua/maui/button.lua').Button
local Text = import('/lua/maui/text.lua').Text
local Scrollbar = import('/lua/maui/scrollbar.lua').Scrollbar

function CreateFactionLayout()

--[[ CYBRAN LAYOUT ]]--

	# VARIABLES
		local textSize = 16
		local pBoxSep = 0			# number of pixels separating the phase counter checkboxes
		local facFont = 'Wintermute'
		local facFontColor = 'orange'
		
	# LOGICAL PARENT AND BACKGROUND
	    local parent = UIUtil.CreateScreenGroup(GetFrame(0), "Operation Briefing ScreenGroup")

		local background = Bitmap(parent, UIUtil.UIFile('/campaign/operations-briefing-cybran/background_bmp.dds'))
		LayoutHelpers.FillParent(background, parent)

	# BORDER - 12-piece background that tiles to accomodate various resolutions
		# top-level logical group
		local border = Group(background, "border")
		LayoutHelpers.FillParent(border, background)
	
		# bottom middle
		local btm_mid = Bitmap(border, UIUtil.UIFile('/campaign/operations-briefing-cybran/back_brd_horz_lm.dds'))
		LayoutHelpers.AtHorizontalCenterIn(btm_mid, border, 0)
		LayoutHelpers.AtBottomIn(btm_mid, border, 0)
		
		# top middle
		local top_mid = Bitmap(border, UIUtil.UIFile('/campaign/operations-briefing-cybran/back_brd_horz_um.dds'))
		LayoutHelpers.AtHorizontalCenterIn(top_mid, border, 0)
		LayoutHelpers.AtTopIn(top_mid, border, 0)
		
		# bottom left corner
		local btm_left = Bitmap(border, UIUtil.UIFile('/campaign/operations-briefing-cybran/back_brd_ll.dds'))
		LayoutHelpers.AtLeftIn(btm_left, border, 0)
		LayoutHelpers.AtBottomIn(btm_left, border, 0)
		
		# bottom right corner
		local btm_right = Bitmap(border, UIUtil.UIFile('/campaign/operations-briefing-cybran/back_brd_lr.dds'))
		LayoutHelpers.AtRightIn(btm_right, border, 0)
		LayoutHelpers.AtBottomIn(btm_right, border, 0)
		
		# top left corner
		local top_left = Bitmap(border, UIUtil.UIFile('/campaign/operations-briefing-cybran/back_brd_ul.dds'))
		LayoutHelpers.AtLeftIn(top_left, border, 0)
		LayoutHelpers.AtTopIn(top_left, border, 0)
		
		# top right corner
	    local top_right = Bitmap(border, UIUtil.UIFile('/campaign/operations-briefing-cybran/back_brd_ur.dds'))
		LayoutHelpers.AtRightIn(top_right, border, 0)
		LayoutHelpers.AtTopIn(top_right, border, 0)
		
		# lower left tile
		local tile_btm_left = Bitmap(border, UIUtil.UIFile('/campaign/operations-briefing-cybran/back_brd_horz_lml.dds'))
		LayoutHelpers.AtBottomIn(tile_btm_left, border, 0)
		tile_btm_left.Left:Set(btm_left.Right)
		tile_btm_left.Right:Set(btm_mid.Left)
		#tile_btm_left:SetTiled(true)
		
		# lower right tile
		local tile_btm_right = Bitmap(border, UIUtil.UIFile('/campaign/operations-briefing-cybran/back_brd_horz_lmr.dds'))
		LayoutHelpers.AtBottomIn(tile_btm_right, border, 0)
		tile_btm_right.Left:Set(btm_mid.Right)
		tile_btm_right.Right:Set(btm_right.Left)
		#tile_btm_right:SetTiled(true)
		
		# upper left tile
		local tile_top_left = Bitmap(border, UIUtil.UIFile('/campaign/operations-briefing-cybran/back_brd_horz_uml.dds'))
		LayoutHelpers.AtTopIn(tile_top_left, border, 0)
		tile_top_left.Left:Set(top_left.Right)
		tile_top_left.Right:Set(top_mid.Left)
		#tile_top_left:SetTiled(true)
		
		# upper right tile
		local tile_top_right = Bitmap(border, UIUtil.UIFile('/campaign/operations-briefing-cybran/back_brd_horz_umr.dds'))
		LayoutHelpers.AtTopIn(tile_top_right, border, 0)
		tile_top_right.Left:Set(top_mid.Right)
		tile_top_right.Right:Set(top_right.Left)
		#tile_top_right:SetTiled(true)
		
		# left mid tile
		local tile_mid_left = Bitmap(border, UIUtil.UIFile('/campaign/operations-briefing-cybran/back_brd_vert_l.dds'))
		LayoutHelpers.AtLeftIn(tile_mid_left, border, 0)
		tile_mid_left.Top:Set(top_left.Bottom)
		tile_mid_left.Bottom:Set(btm_left.Top)
		#tile_top_right:SetTiled(true)
		
		# right mid tile
		local tile_mid_right = Bitmap(border, UIUtil.UIFile('/campaign/operations-briefing-cybran/back_brd_vert_r.dds'))
		LayoutHelpers.AtRightIn(tile_mid_right, border, 0)
		tile_mid_right.Top:Set(top_right.Bottom)
		tile_mid_right.Bottom:Set(btm_right.Top)
		#tile_top_right:SetTiled(true)

	# MAIN PANEL - new group to parent all objects above the border
		local main_panel = Group(background, "main_panel")
		LayoutHelpers.FillParent(main_panel, background)
		main_panel.Depth:Set(border.Depth() + 2)

	# BUTTON FUNCTION
		function CreateFactionButton(parent, label, btnType, fontsize)
			local button = UIUtil.CreateButtonStd(parent, btnType, label, fontsize or 16)
			button.label:SetFont(facFont, fontsize or 16)
			button.label:SetColor(facFontColor)
			button.OnRolloverEvent = function(self, event)
	            if event == 'enter' then
	                button.label:SetColor('white')
	            elseif event == 'exit' then
	                button.label:SetColor(facFontColor)
	            elseif event == 'down' then
	                button.label:SetColor('black')
	            end
			end
			return button
        end

	# BACK BUTTON
	    local exitButton_back = Bitmap(main_panel, UIUtil.UIFile('/campaign/operations-briefing-cybran/back-back_bmp.dds'))
	    LayoutHelpers.AtLeftIn(exitButton_back, main_panel, 40)
	    LayoutHelpers.AtBottomIn(exitButton_back, main_panel, 5)
	    
		local exitButton = CreateFactionButton(exitButton_back, "<LOC _Back>", '/cybran-btn-small/small')
	    LayoutHelpers.AtCenterIn(exitButton, exitButton_back)

	# LAUNCH BUTTON
	    local launchButton_back = Bitmap(main_panel, UIUtil.UIFile('/campaign/operations-briefing-cybran/btn-panel-launch_bmp.dds'))
	    LayoutHelpers.AtRightIn(launchButton_back, main_panel, 15)
	    LayoutHelpers.AtBottomIn(launchButton_back, main_panel, -5)

    	local launchButton = UIUtil.CreateButtonStd(launchButton_back, '/medium-cybran-btn/medium02', '<LOC _Launch>', 20, 2)
    	LayoutHelpers.AtCenterIn(launchButton, launchButton_back)
    	launchButton:UseAlphaHitTest(false)
    	
    	launchButton.glow = Bitmap(launchButton, UIUtil.UIFile('/medium-cybran-btn/medium02_btn_glow.dds'))
    	LayoutHelpers.AtCenterIn(launchButton.glow, launchButton)
    	launchButton.glow:SetAlpha(0)
    	launchButton.glow:DisableHitTest()
    	
        launchButton.pulse = Bitmap(launchButton, UIUtil.UIFile('/medium-cybran-btn/medium02_btn_glow.dds'))
    	LayoutHelpers.AtCenterIn(launchButton.pulse, launchButton)
    	launchButton.pulse:DisableHitTest()
    	launchButton.pulse:SetAlpha(.5)

    	launchButton.OnRolloverEvent = function(self, event) 
    	   	if event == 'enter' then
    			EffectHelpers.FadeIn(self.glow, .25, 0, 1)
    			self.label:SetColor('black')
    		elseif event == 'down' then
    			self.label:SetColor('black')
    		else
    			EffectHelpers.FadeOut(self.glow, .25, 1, 0)
    			self.label:SetColor('white')
    		end
    	end
    	
        EffectHelpers.Pulse(launchButton.pulse, 2, .5, 1)

	# PAGE TITLE
    	local pageTitle = Text(main_panel)
    	pageTitle:SetFont(facFont, 20)
    	pageTitle:SetColor(facFontColor)
    	LayoutHelpers.AtHorizontalCenterIn(pageTitle, main_panel)
    	LayoutHelpers.AtTopIn(pageTitle, main_panel, 10)

	# TEXT AREA
		# logical group and nine-piece background
		local opTextBack = Group(main_panel, 'opTextBack')
		opTextBack.Height:Set(function() return parent.Height() * .26 end)
		LayoutHelpers.AtHorizontalCenterIn(opTextBack, main_panel, 0)
		
		LayoutHelpers.AtLeftIn(opTextBack, main_panel, 40)
		LayoutHelpers.AtRightIn(opTextBack, main_panel, 40)
		LayoutHelpers.AtBottomIn(opTextBack, main_panel, 98)
		
		local opTextBack_ul = Bitmap(opTextBack, UIUtil.UIFile('/campaign/text-panel-cybran/text-panel_brd_ul.dds'))
		LayoutHelpers.AtLeftTopIn(opTextBack_ul, opTextBack, 0, 0)
		
		local opTextBack_ur = Bitmap(opTextBack, UIUtil.UIFile('/campaign/text-panel-cybran/text-panel_brd_ur.dds'))
		LayoutHelpers.AtRightTopIn(opTextBack_ur, opTextBack, 0, 0)
		
		local opTextBack_um = Bitmap(opTextBack, UIUtil.UIFile('/campaign/text-panel-cybran/text-panel_brd_horz_um.dds'))
		LayoutHelpers.AtTopIn(opTextBack_um, opTextBack, 0)
		opTextBack_um.Left:Set(opTextBack_ul.Right)
		opTextBack_um.Right:Set(opTextBack_ur.Left)
		
		local opTextBack_ll = Bitmap(opTextBack, UIUtil.UIFile('/campaign/text-panel-cybran/text-panel_brd_ll.dds'))
		LayoutHelpers.AtBottomIn(opTextBack_ll, opTextBack, 0)
		LayoutHelpers.AtLeftIn(opTextBack_ll, opTextBack, 0)
		
		local opTextBack_lr = Bitmap(opTextBack, UIUtil.UIFile('/campaign/text-panel-cybran/text-panel_brd_lr.dds'))
		LayoutHelpers.AtBottomIn(opTextBack_lr, opTextBack, 0)
		LayoutHelpers.AtRightIn(opTextBack_lr, opTextBack, 0)
		
		local opTextBack_lm = Bitmap(opTextBack, UIUtil.UIFile('/campaign/text-panel-cybran/text-panel_brd_lm.dds'))
		LayoutHelpers.AtBottomIn(opTextBack_lm, opTextBack, 0)
		opTextBack_lm.Left:Set(opTextBack_ll.Right)
		opTextBack_lm.Right:Set(opTextBack_lr.Left)
		
		local opTextBack_l = Bitmap(opTextBack, UIUtil.UIFile('/campaign/text-panel-cybran/text-panel_brd_vert_l.dds'))
		LayoutHelpers.AtLeftIn(opTextBack_l, opTextBack, 0)
		opTextBack_l.Top:Set(opTextBack_ul.Bottom)
		opTextBack_l.Bottom:Set(opTextBack_ll.Top)
		
		local opTextBack_r = Bitmap(opTextBack, UIUtil.UIFile('/campaign/text-panel-cybran/text-panel_brd_vert_r.dds'))
		LayoutHelpers.AtRightIn(opTextBack_r, opTextBack, 0)
		opTextBack_r.Top:Set(opTextBack_ur.Bottom)
		opTextBack_r.Bottom:Set(opTextBack_lr.Top)
		
		local opTextBack_m = Bitmap(opTextBack, UIUtil.UIFile('/campaign/text-panel-cybran/text-panel_brd_m.dds'))
		opTextBack_m.Left:Set(opTextBack_l.Right)
		opTextBack_m.Right:Set(opTextBack_r.Left)
		opTextBack_m.Top:Set(opTextBack_um.Bottom)
		opTextBack_m.Bottom:Set(opTextBack_lm.Top)
		
		# text control
		local opTextArea = ItemList(opTextBack)
		LayoutHelpers.AtTopIn(opTextArea, opTextBack, 40)
		LayoutHelpers.AtLeftIn(opTextArea, opTextBack, 65)
		LayoutHelpers.AtRightIn(opTextArea, opTextBack, 90)
		LayoutHelpers.AtBottomIn(opTextArea, opTextBack, 43)

		opTextArea:SetFont(UIUtil.bodyFont, textSize)
	    opTextArea:SetColors(facFontColor, "00000000", UIUtil.fontColor,  UIUtil.highlightColor)
	    opTextArea:Disable() # disable "select" functionality
	    
	    local scrollbar = Scrollbar(opTextArea, import('/lua/maui/scrollbar.lua').ScrollAxis.Vert)
	    scrollbar:SetTextures(  UIUtil.UIFile('/small-vert_scroll-cybran/back_scr_mid.dds')
	                            ,UIUtil.UIFile('/small-vert_scroll-cybran/bar-mid_scr_up.dds')
	                            ,UIUtil.UIFile('/small-vert_scroll-cybran/bar-top_scr_up.dds')
	                            ,UIUtil.UIFile('/small-vert_scroll-cybran/bar-bot_scr_up.dds'))
	                            
	    local scrollUpButton = Button(  scrollbar
	                                    , UIUtil.UIFile('/small-vert_scroll-cybran/arrow-up_scr_up.dds')
	                                    , UIUtil.UIFile('/small-vert_scroll-cybran/arrow-up_scr_over.dds')
	                                    , UIUtil.UIFile('/small-vert_scroll-cybran/arrow-up_scr_down.dds')
	                                    , UIUtil.UIFile('/small-vert_scroll-cybran/arrow-up_scr_dis.dds')
	                                    , "UI_Arrow_Click")
	
	    local scrollDownButton = Button(  scrollbar
	                                    , UIUtil.UIFile('/small-vert_scroll-cybran/arrow-down_scr_up.dds')
	                                    , UIUtil.UIFile('/small-vert_scroll-cybran/arrow-down_scr_over.dds')
	                                    , UIUtil.UIFile('/small-vert_scroll-cybran/arrow-down_scr_down.dds')
	                                    , UIUtil.UIFile('/small-vert_scroll-cybran/arrow-down_scr_dis.dds')
	                                    , "UI_Arrow_Click")
	
	    scrollbar.Left:Set(function() return opTextArea.Right() + 30 end)
	    scrollbar.Top:Set(scrollUpButton.Bottom)
	    scrollbar.Bottom:Set(scrollDownButton.Top)
	
	    scrollUpButton.Left:Set(scrollbar.Left)
	    scrollUpButton.Top:Set(function() return opTextArea.Top() + 3 end)
	    scrollDownButton.Left:Set(scrollbar.Left)
	    scrollDownButton.Bottom:Set(function() return opTextArea.Bottom() + 3 end)
	    
	    scrollbar.Right:Set(scrollUpButton.Right)
	    
	    scrollbar:AddButtons(scrollUpButton, scrollDownButton)
	    scrollbar:SetScrollable(opTextArea)

    # MOVIE AREA
        local movRatio = 528 / 1040	 	# native movie size
        local movMinTop = 70			# movie top will never go below this distance from the top of the screen
            	
    	opMovieBack = Movie(main_panel)
    	opMovieBack.Width:Set(1)
    	opMovieBack.Height:Set(1)
    	LayoutHelpers.AtHorizontalCenterIn(opMovieBack, main_panel, 0)
		
		parent.Height.OnDirty = function() return SetMovieSize() end
		parent.Width.OnDirty = function() return SetMovieSize() end
		
		opMovieBack.Top:Set(function() return (((opTextArea.Top() - 20) - movMinTop) - opMovieBack.Height())/2 + movMinTop end)
		
		opMovieArea = Movie(opMovieBack)
		LayoutHelpers.FillParent(opMovieArea, opMovieBack)

	# QAI & MOVIE BRACKETS
		local bracketRight = Bitmap(border, UIUtil.UIFile('/campaign/operations-briefing-cybran/display-bracket-cybran-r_bmp.dds'))
		LayoutHelpers.AtRightTopIn(bracketRight, border, 0, 50)

		local bracketLeft = Bitmap(border, UIUtil.UIFile('/campaign/operations-briefing-cybran/display-bracket-cybran-l_bmp.dds'))
		LayoutHelpers.AtLeftIn(bracketLeft, border, 0)
		bracketLeft.Bottom:Set(function() return opTextArea.Top() -10 end)

		local opQAIBack = Movie(bracketRight)
		LayoutHelpers.FromRightIn(opQAIBack, bracketRight, .021)
		LayoutHelpers.FromTopIn(opQAIBack, bracketRight, .052)
		opQAIBack.Width:Set(function() return math.floor(bracketRight.Width() * .918) end)
		opQAIBack.Height:Set(opQAIBack.Width)
	
	# RESIZE MOVIES

		function SetMovieSize()
    		local sizeHeight = (opTextArea.Top() - 20) - movMinTop
    		#if sizeHeight > 528 then sizeHeight = 528 end						# never go above the native movie size
    		local sizeWidth = math.floor(sizeHeight / movRatio)
    		if sizeWidth + 0 > parent.Width() then								# give minimum 0px width between screen edge and movie
    			sizeWidth = parent.Width() - 0
    			sizeHeight = sizeWidth * movRatio
    		end
    		#LOG('in SetMovieSize(): sizeHeight = ' , sizeHeight , ', sizeWidth = ' , sizeWidth)
    		opMovieBack.Width:Set(sizeWidth)
    		opMovieBack.Height:Set(sizeHeight)

			# resize brackets
			local ratio = parent.Width() / 1600
			local minRWidth = 280
			local oldRWidth = bracketRight.BitmapWidth()
			local newRWidth = math.floor(oldRWidth * ratio)
			if newRWidth < minRWidth then
				ratio = minRWidth / oldRWidth
			end
			bracketLeft.Width:Set(function() return math.floor(bracketLeft.BitmapWidth() * ratio) end)
			bracketLeft.Height:Set(function() return math.floor(bracketLeft.BitmapHeight() * ratio) end)
			bracketRight.Width:Set(function() return math.floor(bracketRight.BitmapWidth() * ratio) end)
			bracketRight.Height:Set(function() return math.floor(bracketRight.BitmapHeight() * ratio) end)
		end
		
		SetMovieSize()
		
	# VCR CONTROLS
		# logical parent
		local vcr_parent = Group(main_panel, "vcr_parent")
		
		# back button
		local vcr_back = Checkbox(vcr_parent, UIUtil.UIFile('/campaign/movie-control-cybran/nav-back_btn_up.dds'), UIUtil.UIFile('/campaign/movie-control-cybran/nav-back_btn_down.dds'), UIUtil.UIFile('/campaign/movie-control-cybran/nav-back_btn_over.dds'), UIUtil.UIFile('/campaign/movie-control-cybran/nav-back_btn_down.dds'), UIUtil.UIFile('/campaign/movie-control-cybran/nav-back_btn_dis.dds'), UIUtil.UIFile('/campaign/movie-control-cybran/nav-back_btn_dis.dds'), nil, 'UI_Tab_Rollover_01')
		LayoutHelpers.AtTopIn(vcr_back, vcr_parent, 0)
		LayoutHelpers.AtLeftIn(vcr_back, vcr_parent, 0)
		
		# rewind button
		local vcr_rw = Checkbox(vcr_parent, UIUtil.UIFile('/campaign/movie-control-cybran/nav-rr_btn_up.dds'), UIUtil.UIFile('/campaign/movie-control-cybran/nav-rr_btn_down.dds'), UIUtil.UIFile('/campaign/movie-control-cybran/nav-rr_btn_over.dds'), UIUtil.UIFile('/campaign/movie-control-cybran/nav-rr_btn_down.dds'), UIUtil.UIFile('/campaign/movie-control-cybran/nav-rr_btn_dis.dds'), UIUtil.UIFile('/campaign/movie-control-cybran/nav-rr_btn_dis.dds'), nil, 'UI_Tab_Rollover_01')
		LayoutHelpers.AtTopIn(vcr_rw, vcr_parent, 0)
		LayoutHelpers.RightOf(vcr_rw, vcr_back, 0)
		
		# ff button
		local vcr_ff = Checkbox(vcr_parent, UIUtil.UIFile('/campaign/movie-control-cybran/nav-ff_btn_up.dds'), UIUtil.UIFile('/campaign/movie-control-cybran/nav-ff_btn_down.dds'), UIUtil.UIFile('/campaign/movie-control-cybran/nav-ff_btn_over.dds'), UIUtil.UIFile('/campaign/movie-control-cybran/nav-ff_btn_down.dds'), UIUtil.UIFile('/campaign/movie-control-cybran/nav-ff_btn_dis.dds'), UIUtil.UIFile('/campaign/movie-control-cybran/nav-ff_btn_dis.dds'), nil, 'UI_Tab_Rollover_01')
		LayoutHelpers.AtTopIn(vcr_ff, vcr_parent, 0)
		LayoutHelpers.RightOf(vcr_ff, vcr_rw, 0)
		
		# end button
		local vcr_end = Checkbox(vcr_parent, UIUtil.UIFile('/campaign/movie-control-cybran/nav-end_btn_up.dds'), UIUtil.UIFile('/campaign/movie-control-cybran/nav-end_btn_down.dds'), UIUtil.UIFile('/campaign/movie-control-cybran/nav-end_btn_over.dds'), UIUtil.UIFile('/campaign/movie-control-cybran/nav-end_btn_down.dds'), UIUtil.UIFile('/campaign/movie-control-cybran/nav-end_btn_dis.dds'), UIUtil.UIFile('/campaign/movie-control-cybran/nav-end_btn_dis.dds'), nil, 'UI_Tab_Rollover_01')
		LayoutHelpers.AtTopIn(vcr_ff, vcr_parent, 0)
		LayoutHelpers.RightOf(vcr_end, vcr_ff, 0)
		
		vcr_parent.Width:Set(vcr_back.Width() + vcr_rw.Width() + vcr_ff.Width() + vcr_end.Width())
		vcr_parent.Height:Set(32)
		LayoutHelpers.AtHorizontalCenterIn(vcr_parent, main_panel, 0)
		LayoutHelpers.AtBottomIn(vcr_parent, main_panel, 66)
		
	# PHASE COUNTER																			
    	local phaseParent = Group(main_panel, "phaseParent")					# create phase counter parent
   		phaseParent.Height:Set(0)
   		LayoutHelpers.AtBottomIn(phaseParent, main_panel, 39)					# we'll set width and horiz. center after we know how many buttons there are
   		
   		local phaseCheckbox = { normalUnchecked = '/campaign/chapter-cybran_btn/nav-chapter_btn_up.dds',
   								normalChecked = '/campaign/chapter-cybran_btn/nav-chapter_btn_down.dds',
   								overUnchecked = '/campaign/chapter-cybran_btn/nav-chapter_btn_sel.dds',
   								overChecked = '/campaign/chapter-cybran_btn/nav-chapter_btn_over.dds',
   								disabledUnchecked = '/campaign/chapter-cybran_btn/nav-chapter_btn_dis.dds',
   								disabledChecked = '/campaign/chapter-cybran_btn/nav-chapter_btn_dis.dds'
   								}

--[[ RETURN LAYOUT ELEMENTS ]]--
	# first variable name is actually the key name, only the second contains the variable data, so: parent = (parent table)
	return {parent = parent,
			main_panel = main_panel,
			exitButton = exitButton,
			pageTitle = pageTitle,
			vcr_ff = vcr_ff,
			vcr_rw = vcr_rw,
			vcr_back = vcr_back,
			vcr_end = vcr_end,
			opMovieBack = opMovieBack,
			opQAIBack = opQAIBack,
			opTextBack = opTextBack,
			opTextArea = opTextArea,
			phaseParent = phaseParent,
			phaseCheckbox = phaseCheckbox,
			pBoxSep = pBoxSep,
			launchButton = launchButton,
			}
end