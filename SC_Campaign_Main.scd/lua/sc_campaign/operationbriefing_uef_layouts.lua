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

function CreateFactionLayout()

--[[ UEF LAYOUT ]]--

	# VARIABLES
		local textSize = 16
		local pBoxSep = -5			# number of pixels separating the phase counter checkboxes
		local facFont = 'Zeroes Three'
		local facFontColor = 'cyan'
		
		# TODO: connection movie

	# LOGICAL PARENT AND BACKGROUND
	    local parent = UIUtil.CreateScreenGroup(GetFrame(0), "Operation Briefing ScreenGroup")
	
		local background = Bitmap(parent, UIUtil.UIFile('/campaign/operations-02/background_bmp.dds'))
		LayoutHelpers.FillParent(background, parent)

	# BORDER - 12-piece background that tiles to accomodate various resolutions
		# top-level logical group
		local border = Group(background, "border")
		LayoutHelpers.FillParent(border, background)
	
		# bottom middle
		local btm_mid = Bitmap(border, UIUtil.UIFile('/campaign/operations-02/back_brd_horz_lm.dds'))
		LayoutHelpers.AtHorizontalCenterIn(btm_mid, border, 0)
		LayoutHelpers.AtBottomIn(btm_mid, border, 0)
		
		# top middle
		local top_mid = Bitmap(border, UIUtil.UIFile('/campaign/operations-02/back_brd_horz_um.dds'))
		LayoutHelpers.AtHorizontalCenterIn(top_mid, border, 0)
		LayoutHelpers.AtTopIn(top_mid, border, 0)
		
		# bottom left corner
		local btm_left = Bitmap(border, UIUtil.UIFile('/campaign/operations-02/back_brd_ll.dds'))
		LayoutHelpers.AtLeftIn(btm_left, border, 0)
		LayoutHelpers.AtBottomIn(btm_left, border, 0)
		
		# bottom right corner
		local btm_right = Bitmap(border, UIUtil.UIFile('/campaign/operations-02/back_brd_lr.dds'))
		LayoutHelpers.AtRightIn(btm_right, border, 0)
		LayoutHelpers.AtBottomIn(btm_right, border, 0)
		
		# top left corner
		local top_left = Bitmap(border, UIUtil.UIFile('/campaign/operations-02/back_brd_ul.dds'))
		LayoutHelpers.AtLeftIn(top_left, border, 0)
		LayoutHelpers.AtTopIn(top_left, border, 0)
		
		# top right corner
	    local top_right = Bitmap(border, UIUtil.UIFile('/campaign/operations-02/back_brd_ur.dds'))
		LayoutHelpers.AtRightIn(top_right, border, 0)
		LayoutHelpers.AtTopIn(top_right, border, 0)
		
		# lower left tile
		local tile_btm_left = Bitmap(border, UIUtil.UIFile('/campaign/operations-02/back_brd_horz_lml.dds'))
		LayoutHelpers.AtBottomIn(tile_btm_left, border, 0)
		tile_btm_left.Left:Set(btm_left.Right)
		tile_btm_left.Right:Set(btm_mid.Left)
		#tile_btm_left:SetTiled(true)
		
		# lower right tile
		local tile_btm_right = Bitmap(border, UIUtil.UIFile('/campaign/operations-02/back_brd_horz_lmr.dds'))
		LayoutHelpers.AtBottomIn(tile_btm_right, border, 0)
		tile_btm_right.Left:Set(btm_mid.Right)
		tile_btm_right.Right:Set(btm_right.Left)
		#tile_btm_right:SetTiled(true)
		
		# upper left tile
		local tile_top_left = Bitmap(border, UIUtil.UIFile('/campaign/operations-02/back_brd_horz_uml.dds'))
		LayoutHelpers.AtTopIn(tile_top_left, border, 0)
		tile_top_left.Left:Set(top_left.Right)
		tile_top_left.Right:Set(top_mid.Left)
		#tile_top_left:SetTiled(true)
		
		# upper right tile
		local tile_top_right = Bitmap(border, UIUtil.UIFile('/campaign/operations-02/back_brd_horz_umr.dds'))
		LayoutHelpers.AtTopIn(tile_top_right, border, 0)
		tile_top_right.Left:Set(top_mid.Right)
		tile_top_right.Right:Set(top_right.Left)
		#tile_top_right:SetTiled(true)
		
		# left mid tile
		local tile_mid_left = Bitmap(border, UIUtil.UIFile('/campaign/operations-02/back_brd_vert_l.dds'))
		LayoutHelpers.AtLeftIn(tile_mid_left, border, 0)
		tile_mid_left.Top:Set(top_left.Bottom)
		tile_mid_left.Bottom:Set(btm_left.Top)
		#tile_top_right:SetTiled(true)
		
		# right mid tile
		local tile_mid_right = Bitmap(border, UIUtil.UIFile('/campaign/operations-02/back_brd_vert_r.dds'))
		LayoutHelpers.AtRightIn(tile_mid_right, border, 0)
		tile_mid_right.Top:Set(top_right.Bottom)
		tile_mid_right.Bottom:Set(btm_right.Top)
		#tile_top_right:SetTiled(true)
		
	# MAIN PANEL - new group to parent all objects above the border
		local main_panel = Group(background, "main_panel")
		LayoutHelpers.FillParent(main_panel, background)
		main_panel.Depth:Set(border.Depth() + 2)

	# BACK BUTTON
	    local exitBack = Bitmap(main_panel, UIUtil.UIFile('/campaign/operations-02/back-back_bmp.dds'))
        LayoutHelpers.AtLeftIn(exitBack, parent, 38)
        LayoutHelpers.AtBottomIn(exitBack, parent)
        
		local exitButton = UIUtil.CreateButtonStd(exitBack, '/widgets/small', "<LOC _Back>", 16)
	    LayoutHelpers.AtCenterIn(exitButton, exitBack)

	# LAUNCH BUTTON
	    local launchButton_back = Bitmap(main_panel, UIUtil.UIFile('/campaign/operations-02/launch-back_bmp.dds'))
	    LayoutHelpers.AtRightIn(launchButton_back, main_panel, 15)
	    LayoutHelpers.AtBottomIn(launchButton_back, main_panel, 3)

    	local launchButton = UIUtil.CreateButtonStd(launchButton_back, '/medium-uef-btn/medium02', '<LOC _Launch>', 20, 2)
    	LayoutHelpers.AtCenterIn(launchButton, launchButton_back, -2)
    	launchButton:UseAlphaHitTest(false)
    	
    	launchButton.glow = Bitmap(launchButton, UIUtil.UIFile('/medium-uef-btn/medium02_btn_glow.dds'))
    	LayoutHelpers.AtCenterIn(launchButton.glow, launchButton)
    	launchButton.glow:SetAlpha(0)
    	launchButton.glow:DisableHitTest()
    	
        launchButton.pulse = Bitmap(launchButton, UIUtil.UIFile('/medium-uef-btn/medium02_btn_glow.dds'))
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
    	pageTitle:SetNewColor(facFontColor)
    	LayoutHelpers.AtHorizontalCenterIn(pageTitle, main_panel)
    	LayoutHelpers.AtTopIn(pageTitle, main_panel, 10)

	# TEXT AREA
		# logical group and nine-piece background
		local opTextBack = Group(main_panel, 'opTextBack')
		opTextBack.Height:Set(200)	# uef text background is always the same size
		LayoutHelpers.AtHorizontalCenterIn(opTextBack, main_panel, 0)
		
		LayoutHelpers.AtLeftIn(opTextBack, main_panel, 100)
		LayoutHelpers.AtRightIn(opTextBack, main_panel, 100)
		LayoutHelpers.AtBottomIn(opTextBack, main_panel, 160)
		
		local opTextBack_ul = Bitmap(opTextBack, UIUtil.UIFile('/campaign/text-panel/text-panel_brd_ul.dds'))
		LayoutHelpers.AtLeftTopIn(opTextBack_ul, opTextBack, 0, 0)
		
		local opTextBack_ur = Bitmap(opTextBack, UIUtil.UIFile('/campaign/text-panel/text-panel_brd_ur.dds'))
		LayoutHelpers.AtRightTopIn(opTextBack_ur, opTextBack, 0, 0)
		
		local opTextBack_um = Bitmap(opTextBack, UIUtil.UIFile('/campaign/text-panel/text-panel_brd_horz_um.dds'))
		LayoutHelpers.AtTopIn(opTextBack_um, opTextBack, 0)
		opTextBack_um.Left:Set(opTextBack_ul.Right)
		opTextBack_um.Right:Set(opTextBack_ur.Left)
		
		local opTextBack_ll = Bitmap(opTextBack, UIUtil.UIFile('/campaign/text-panel/text-panel_brd_ll.dds'))
		LayoutHelpers.AtBottomIn(opTextBack_ll, opTextBack, 0)
		LayoutHelpers.AtLeftIn(opTextBack_ll, opTextBack, 0)
		
		local opTextBack_lr = Bitmap(opTextBack, UIUtil.UIFile('/campaign/text-panel/text-panel_brd_lr.dds'))
		LayoutHelpers.AtBottomIn(opTextBack_lr, opTextBack, 0)
		LayoutHelpers.AtRightIn(opTextBack_lr, opTextBack, 0)
		
		local opTextBack_lm = Bitmap(opTextBack, UIUtil.UIFile('/campaign/text-panel/text-panel_brd_lm.dds'))
		LayoutHelpers.AtBottomIn(opTextBack_lm, opTextBack, 0)
		opTextBack_lm.Left:Set(opTextBack_ll.Right)
		opTextBack_lm.Right:Set(opTextBack_lr.Left)
		
		local opTextBack_l = Bitmap(opTextBack, UIUtil.UIFile('/campaign/text-panel/text-panel_brd_vert_l.dds'))
		LayoutHelpers.AtLeftIn(opTextBack_l, opTextBack, 0)
		opTextBack_l.Top:Set(opTextBack_ul.Bottom)
		opTextBack_l.Bottom:Set(opTextBack_ll.Top)
		
		local opTextBack_r = Bitmap(opTextBack, UIUtil.UIFile('/campaign/text-panel/text-panel_brd_vert_r.dds'))
		LayoutHelpers.AtRightIn(opTextBack_r, opTextBack, 0)
		opTextBack_r.Top:Set(opTextBack_ur.Bottom)
		opTextBack_r.Bottom:Set(opTextBack_lr.Top)
		
		local opTextBack_m = Bitmap(opTextBack, UIUtil.UIFile('/campaign/text-panel/text-panel_brd_m.dds'))
		opTextBack_m.Left:Set(opTextBack_l.Right)
		opTextBack_m.Right:Set(opTextBack_r.Left)
		opTextBack_m.Top:Set(opTextBack_um.Bottom)
		opTextBack_m.Bottom:Set(opTextBack_lm.Top)
		
		# text control
		local opTextArea = ItemList(opTextBack)
		LayoutHelpers.AtLeftIn(opTextArea, opTextBack, 20)
		LayoutHelpers.AtRightIn(opTextArea, opTextBack, 42)
		LayoutHelpers.AtBottomIn(opTextArea, opTextBack, 13)
		LayoutHelpers.AtTopIn(opTextArea, opTextBack, 13)
		
		opTextArea:SetFont(UIUtil.bodyFont, textSize)
	    opTextArea:SetColors(facFontColor, "00000000", UIUtil.fontColor,  UIUtil.highlightColor) #88EE00 green
	    UIUtil.CreateVertScrollbarFor(opTextArea)
	    opTextArea:Disable() # disable "select" functionality

    # MOVIE AREA
        local movRatio = 528 / 1168	 	# native movie size
        local movMinTop = 70			# movie top will never go below this distance from the top of the screen
            	
    	opMovieBack = Group(main_panel, "opMovieBack")
    	opMovieBack.Width:Set(1)
    	opMovieBack.Height:Set(1)
    	opMovieBack.Top:Set(0)
    	LayoutHelpers.AtHorizontalCenterIn(opMovieBack, main_panel, 0)
    	
    	opMovieBack.Top:Set(function()
    		return SetMovieSize()	
    	end)

		function SetMovieSize()
    		local movVSpace = (opTextBack.Top() - 20) - movMinTop
    		local sizeHeight = movVSpace
    		if sizeHeight > 528 then sizeHeight = 528 end						# never go above the native movie size
    		local sizeWidth = math.floor(sizeHeight / movRatio)
    		if sizeWidth + 300 > parent.Width() then								# give minimum 150px width between screen edge and movie
    			sizeWidth = parent.Width() - 300
    			sizeHeight = sizeWidth * movRatio
    		end
    		local movTop = math.floor((movVSpace - sizeHeight)/2 + movMinTop)
    		opMovieBack.Width:Set(sizeWidth)
    		opMovieBack.Height:Set(sizeHeight)
    		SetBrackets()
    		return movTop
		end
		
	# MOVIE BRACKETS
		local brackets = {}
		function SetBrackets()
			for k, v in brackets do
				v:Destroy()
			end
		
			# left bracket
			brackets.lBar_top = Bitmap(main_panel, UIUtil.UIFile('/campaign/display-bracket-l_bmp/display-bracket-l_bmp_r.dds'))
			brackets.lBar_top.Right:Set(function() return opMovieBack.Left() + 18 end)
			brackets.lBar_top.Top:Set(function() return opMovieBack.Top() - 15 end)
			brackets.lBar_top.Depth:Set(opMovieBack.Depth() + 2)

			brackets.lBar_btm = Bitmap(brackets.lBar_top, UIUtil.UIFile('/campaign/display-bracket-l_bmp/display-bracket-l_bmp_b.dds'))
			LayoutHelpers.AtRightIn(brackets.lBar_btm, brackets.lBar_top, 0)
			LayoutHelpers.AtBottomIn(brackets.lBar_btm, opMovieBack, -8)
	
			brackets.lBar_bm = Bitmap(brackets.lBar_top, UIUtil.UIFile('/campaign/display-bracket-l_bmp/display-bracket-l_bmp_bm.dds'))
			LayoutHelpers.AtRightIn(brackets.lBar_bm, brackets.lBar_top, 2)
			brackets.lBar_bm.Top:Set(brackets.lBar_top.Bottom)
			brackets.lBar_bm.Bottom:Set(brackets.lBar_btm.Top)
			
			brackets.lBar_l = Bitmap(brackets.lBar_top, UIUtil.UIFile('/campaign/display-bracket-l_bmp/display-bracket-l_bmp_l.dds'))
			brackets.lBar_l.Left:Set(0)
			brackets.lBar_l.Top:Set(function() return brackets.lBar_top.Top() + 91 end)
			
			brackets.lBar_lm = Bitmap(brackets.lBar_top, UIUtil.UIFile('/campaign/display-bracket-l_bmp/display-bracket-l_bmp_m.dds'))
			brackets.lBar_lm.Top:Set(function() return brackets.lBar_top.Top() + 103 end)
			brackets.lBar_lm.Left:Set(brackets.lBar_l.Right)
			brackets.lBar_lm.Right:Set(brackets.lBar_top.Left)
			
			# right bracket
			brackets.rBar_l = Bitmap(main_panel, UIUtil.UIFile('/campaign/display-bracket-r_bmp/display-bracket-l_bmp_r.dds'))
			brackets.rBar_l.Left:Set(function() return opMovieBack.Right() - 18 end)
			brackets.rBar_l.Top:Set(function() return opMovieBack.Top() - 15 end)
			brackets.rBar_l.Depth:Set(opMovieBack.Depth() + 2)
	
			brackets.rBar_btm = Bitmap(brackets.rBar_l, UIUtil.UIFile('/campaign/display-bracket-r_bmp/display-bracket-l_bmp_b.dds'))
			LayoutHelpers.AtLeftIn(brackets.rBar_btm, brackets.rBar_l, 1)
			LayoutHelpers.AtBottomIn(brackets.rBar_btm, opMovieBack, -8)
	
			brackets.rBar_bm = Bitmap(brackets.rBar_l, UIUtil.UIFile('/campaign/display-bracket-r_bmp/display-bracket-l_bmp_bm.dds'))
			LayoutHelpers.AtLeftIn(brackets.rBar_bm, brackets.rBar_l, 2)
			brackets.rBar_bm.Top:Set(brackets.rBar_l.Bottom)
			brackets.rBar_bm.Bottom:Set(brackets.rBar_btm.Top)
			
			brackets.rBar_r = Bitmap(brackets.rBar_l, UIUtil.UIFile('/campaign/display-bracket-r_bmp/display-bracket-l_bmp_l.dds'))
			brackets.rBar_r.Right:Set(parent.Width)
			brackets.rBar_r.Top:Set(function() return brackets.rBar_l.Top() + 91 end)
			
			brackets.rBar_rm = Bitmap(brackets.rBar_l, UIUtil.UIFile('/campaign/display-bracket-r_bmp/display-bracket-l_bmp_m.dds'))
			brackets.rBar_rm.Top:Set(function() return brackets.rBar_l.Top() + 103 end)
			brackets.rBar_rm.Left:Set(brackets.rBar_l.Right)
			brackets.rBar_rm.Right:Set(brackets.rBar_r.Left)
		end
    
	# VCR CONTROLS
		# logical parent
		local vcr_parent = Group(main_panel, "vcr_parent")
		
		# back button
		local vcr_back = Checkbox(vcr_parent, UIUtil.UIFile('/dialogs/movie-control/nav-back_btn_up.dds'), UIUtil.UIFile('/dialogs/movie-control/nav-back_btn_down.dds'), UIUtil.UIFile('/dialogs/movie-control/nav-back_btn_over.dds'), UIUtil.UIFile('/dialogs/movie-control/nav-back_btn_down.dds'), UIUtil.UIFile('/dialogs/movie-control/nav-back_btn_dis.dds'), UIUtil.UIFile('/dialogs/movie-control/nav-back_btn_dis.dds'), nil, 'UI_Tab_Rollover_01')
		LayoutHelpers.AtTopIn(vcr_back, vcr_parent, 0)
		LayoutHelpers.AtLeftIn(vcr_back, vcr_parent, 0)
		
		# rewind button
		local vcr_rw = Checkbox(vcr_parent, UIUtil.UIFile('/dialogs/movie-control/nav-rr_btn_up.dds'), UIUtil.UIFile('/dialogs/movie-control/nav-rr_btn_down.dds'), UIUtil.UIFile('/dialogs/movie-control/nav-rr_btn_over.dds'), UIUtil.UIFile('/dialogs/movie-control/nav-rr_btn_down.dds'), UIUtil.UIFile('/dialogs/movie-control/nav-rr_btn_dis.dds'), UIUtil.UIFile('/dialogs/movie-control/nav-rr_btn_dis.dds'), nil, 'UI_Tab_Rollover_01')
		LayoutHelpers.AtTopIn(vcr_rw, vcr_parent, 0)
		LayoutHelpers.RightOf(vcr_rw, vcr_back, 0)
		
		# ff button
		local vcr_ff = Checkbox(vcr_parent, UIUtil.UIFile('/dialogs/movie-control/nav-ff_btn_up.dds'), UIUtil.UIFile('/dialogs/movie-control/nav-ff_btn_down.dds'), UIUtil.UIFile('/dialogs/movie-control/nav-ff_btn_over.dds'), UIUtil.UIFile('/dialogs/movie-control/nav-ff_btn_down.dds'), UIUtil.UIFile('/dialogs/movie-control/nav-ff_btn_dis.dds'), UIUtil.UIFile('/dialogs/movie-control/nav-ff_btn_dis.dds'), nil, 'UI_Tab_Rollover_01')
		LayoutHelpers.AtTopIn(vcr_ff, vcr_parent, 0)
		LayoutHelpers.RightOf(vcr_ff, vcr_rw, 0)
		
		# end button
		local vcr_end = Checkbox(vcr_parent, UIUtil.UIFile('/dialogs/movie-control/nav-end_btn_up.dds'), UIUtil.UIFile('/dialogs/movie-control/nav-end_btn_down.dds'), UIUtil.UIFile('/dialogs/movie-control/nav-end_btn_over.dds'), UIUtil.UIFile('/dialogs/movie-control/nav-end_btn_down.dds'), UIUtil.UIFile('/dialogs/movie-control/nav-end_btn_dis.dds'), UIUtil.UIFile('/dialogs/movie-control/nav-end_btn_dis.dds'), nil, 'UI_Tab_Rollover_01')
		LayoutHelpers.AtTopIn(vcr_ff, vcr_parent, 0)
		LayoutHelpers.RightOf(vcr_end, vcr_ff, 0)
		
		vcr_parent.Width:Set(vcr_back.Width() + vcr_rw.Width() + vcr_ff.Width() + vcr_end.Width())
		vcr_parent.Height:Set(32)
		LayoutHelpers.AtHorizontalCenterIn(vcr_parent, main_panel, 0)
		LayoutHelpers.AtBottomIn(vcr_parent, main_panel, 91)
		
	# PHASE COUNTER																			
    	local phaseParent = Group(main_panel, "phaseParent")					# create phase counter parent
   		phaseParent.Height:Set(0)
   		LayoutHelpers.AtBottomIn(phaseParent, main_panel, 81)					# we'll set width and horiz. center after we know how many buttons there are
   		
   		local phaseCheckbox = { normalUnchecked = '/campaign/chapter-uef_btn/nav-chapter_btn_up.dds',
   								normalChecked = '/campaign/chapter-uef_btn/nav-chapter_btn_down.dds',
   								overUnchecked = '/campaign/chapter-uef_btn/nav-chapter_btn_sel.dds',
   								overChecked = '/campaign/chapter-uef_btn/nav-chapter_btn_over.dds',
   								disabledUnchecked = '/campaign/chapter-uef_btn/nav-chapter_btn_dis.dds',
   								disabledChecked = '/campaign/chapter-uef_btn/nav-chapter_btn_dis.dds'
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
			opTextBack = opTextBack,
			opTextArea = opTextArea,
			phaseParent = phaseParent,
			phaseCheckbox = phaseCheckbox,
			pBoxSep = pBoxSep,
			launchButton = launchButton,
			}
			
end