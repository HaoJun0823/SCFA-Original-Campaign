--*****************************************************************************
--* File: lua/modules/ui/campaign/operationbriefing.lua
--* Author: Chris Blackwell, Evan Pongress
--* Summary: campaign operations view
--*
--* Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
--*****************************************************************************

local UIUtil = import('/lua/ui/uiutil.lua')
local MenuCommon = import('/lua/ui/menus/menucommon.lua')
local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local Movie = import('/lua/maui/movie.lua').Movie
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local Group = import('/lua/maui/group.lua').Group
local WrapText = import('/lua/maui/text.lua').WrapText
local Checkbox = import('/lua/maui/checkbox.lua').Checkbox
local Button = import('/lua/maui/button.lua').Button
local Prefs = import('/lua/user/prefs.lua')
local MapUtil = import('/lua/ui/maputil.lua')
local Mods = import('/lua/mods.lua')
local PlayCampaignMovie = import('campaignmovies.lua').PlayCampaignMovie

local mapErrorDialog = false
local opLayout = false

function CreateUI(operationID, briefingData, faction, opDiff, playOp1Movie)

--[[ ASSIGN BRIEFING DATA VARIABLES ]]--

	local opNum = briefingData.opNum
	local opTitle = briefingData.opTitle
	local opText = briefingData.opText
	local opMovPfx = briefingData.opMovPfx
	local opMap = briefingData.opMap

	local newOpText = {}

	# convert old "R" designation for Cybran to "C"
	if opMovPfx:sub(1,1) == 'R' then
		opMovPfx = 'C' .. opNum
	end

--[[ IMPORT FACTION LAYOUT ]]--

	opLayout = import('/lua/sc_campaign/operationbriefing_' .. faction .. '_layouts.lua').CreateFactionLayout()

	local parent = opLayout.parent
	local main_panel = opLayout.main_panel
	local exitButton = opLayout.exitButton
	local pageTitle = opLayout.pageTitle
	local vcr_ff = opLayout.vcr_ff
	local vcr_back = opLayout.vcr_back
	local vcr_rw = opLayout.vcr_rw
	local vcr_end = opLayout.vcr_end
	local opMovieBack = opLayout.opMovieBack
	local opTextBack = opLayout.opTextBack
	local opTextArea = opLayout.opTextArea
	local phaseParent = opLayout.phaseParent
	local phaseCheckbox = opLayout.phaseCheckbox
	local pBoxSep = opLayout.pBoxSep
	local launchButton = opLayout.launchButton

--[[ INIT BRIEFING ]]--

	local pTotal = 0
	if opText then																	# determine number of phases from SCUD sequence number
		local length = table.getn(opText)											#	get length of table so we can grab the last item
		pTotal = opText[length].phase	    										#	grab the phase number of the last item
	end

	pageTitle:SetText(LOC(opTitle))

	# init movie playback
	local btnFlag = 0														# flag to prevent double-click button behavior
	local opMovies = {}
	
	# faction-specific setup
	local opQAIBack = nil
	local opQAI = nil
	
	local ambSound = nil
	
	if faction == 'uef' then
		ambSound = Sound( {Cue = 'AMB_UEF_OP_Briefing', Bank = 'SC_AmbientTest'} )
	elseif faction == 'cybran' then
		ambSound = Sound( {Cue = 'AMB_CYBRAN_OP_Briefing', Bank = 'SC_AmbientTest'} )
		opQAIBack = opLayout.opQAIBack												# define QAI movie area
		opQAI = {}
		opQAI.loopMovie = '/movies/QAI_loop.sfd'
		for i = 1, pTotal do														# check if all phase movies for QAI exist
			local movName = '/movies/' .. opMovPfx .. '_B0' .. i .. '_QAI.sfd'
			if table.getn(DiskFindFiles(movName)) == 0 then
				opQAI.loop = true													# if not, use the generic QAI loop
				break
			end
		end
	elseif faction == 'aeon' then
		ambSound = Sound( {Cue = 'AMB_AEON_OP_Briefing', Bank = 'SC_AmbientTest'} )
	end

	local playAmbSound = PlaySound(ambSound)

	# button timer to prevent double-click behavior
	local btnTimer = Group(parent, "btnTimer")
	btnTimer.Width:Set(1)
	btnTimer.Height:Set(1)
	LayoutHelpers.AtLeftTopIn(btnTimer, parent, 0, 0)
	local btnElapsedTime = 0
	btnTimer.OnFrame = function(self, frameTime)
		btnElapsedTime = btnElapsedTime + frameTime
		if btnElapsedTime > .3 then
			btnTimer:SetNeedsFrameUpdate(false)
			btnFlag = 0
			btnElapsedTime = 0
		end
	end	

	function ButtonTimer()
		btnFlag = 1
		btnTimer:SetNeedsFrameUpdate(true)
	end

	# BUILD PHASE COUNTER
	local phaseCounter = {}
    for i = 1, pTotal do
	    phaseCounter[i] = Checkbox(phaseParent, UIUtil.UIFile(phaseCheckbox.normalUnchecked), UIUtil.UIFile(phaseCheckbox.normalChecked), UIUtil.UIFile(phaseCheckbox.overUnchecked), UIUtil.UIFile(phaseCheckbox.overChecked), UIUtil.UIFile(phaseCheckbox.disabledUnchecked), UIUtil.UIFile(phaseCheckbox.disabledChecked), nil, 'UI_Tab_Rollover_01')
	    local offset = (i - 1) * (phaseCounter[i].Width() + pBoxSep)
	    LayoutHelpers.AtLeftIn(phaseCounter[i], phaseParent, offset)
	    LayoutHelpers.AtTopIn(phaseCounter[i], phaseParent, 0)
    end

    local pCtrWidth = (phaseCounter[1].Width() * table.getn(phaseCounter)) + (pBoxSep * (table.getn(phaseCounter) - 1))
    phaseParent.Width:Set( pCtrWidth )																		# now set the width
   	LayoutHelpers.AtHorizontalCenterIn(phaseParent, main_panel, 0)											# and center

    for k, v in phaseCounter do													# 	set all phase counter buttons to stop this movie
		local index = k
		v.OnClick = function(self, modifiers)
		    if modifiers.Left and btnFlag == 0 then
		    	ButtonTimer()
			    KillMovies(false)
			    PlayPhase(index)													# 	when clicked, play the phase assigned to this button
            end
		end
	end

	# OTHER NAV BUTTONS
	vcr_back.OnClick = function(self, modifiers)
        if modifiers.Left and btnFlag == 0 then
        	ButtonTimer()
		    KillMovies(false)
		    PlayPhase(1)
        end
	end

	vcr_end.OnClick = function(self, modifiers)
        if modifiers.Left and btnFlag == 0 then
        	ButtonTimer()
		    KillMovies(false)
		    PlayPhase(pTotal + 1)
        end
	end

    import('/lua/ui/uimain.lua').SetEscapeHandler(function() exitButton.OnClick(exitButton) end)

    exitButton.OnClick = function(self, modifiers)
    	KillMovies(true)
        parent:Destroy()
        import('selectcampaign.lua').CreateUI(faction)
    end

    function LaunchMission()
        local scenario = MapUtil.LoadScenario(opMap)
        if scenario then
            local difficulty = opDiff or Prefs.GetFromCurrentProfile("campaign.difficulty") or 2
            import('/lua/sc_campaign/campaignmanager.lua').RecordOperationStart(operationID, difficulty)
            local campaignFlowInfo = {
                opKey = operationID,
                campaignID = faction,
                difficulty = difficulty,
            }
            local function TryLaunch()
                LaunchSinglePlayerSession(import('/lua/SinglePlayerLaunch.lua').SetupCampaignSession(scenario, difficulty, nil, campaignFlowInfo, false))
                parent:Destroy()
                MenuCommon.MenuCleanup()
            end
            local ok,msg = pcall(TryLaunch)
            if not ok then
                if mapErrorDialog then mapErrorDialog:Destroy() end
                mapErrorDialog = UIUtil.ShowInfoDialog(main_panel, LOC("<LOC opbrief_0000>Error loading map") .. ': ' .. msg, "<LOC _Ok>")
                mapErrorDialog.Depth:Set(GetFrame(0):GetTopmostDepth() + 1)
            end
        else
            if mapErrorDialog then mapErrorDialog:Destroy() end
            mapErrorDialog = UIUtil.ShowInfoDialog(main_panel, LOCF("<LOC opbrief_0001>Unknown map: %s", opMap), "<LOC _Ok>")
            mapErrorDialog.Depth:Set(GetFrame(0):GetTopmostDepth() + 1)
        end
    end

    launchButton.OnClick = function(self)
    	KillMovies(true)
    	if opNum == '01' and playOp1Movie then																			# if this is the first op
			parent:Destroy()
			PlayCampaignMovie('FMV_' .. faction .. "_Intro_2", GetFrame(0), false, function() LaunchMission() end)		# 	then play the second intro movie before launch
		else
			LaunchMission()																								# otherwise just launch
		end
    end

--[[ MAIN FUNCTION - ITERATE THROUGH PHASES ]]--

	function PlayPhase(phase)
		if phase <= 0 then
			PlayPhase(1)
		elseif phase >= pTotal + 1 then													# if the last phase has ended
			opMovies[opMovies.active].control:Hide()
	    	vcr_ff:Disable()															#	disable the FF button since there's no next phase
	    	vcr_end:Disable()
			for k, v in phaseCounter do													# 	set all phaseCounter boxes to false
				v:SetCheck(false)
			end
			PrintPhaseText(phase)														# 	print all text, no streaming
			if faction == 'cybran' and not opQAI.loop then
				local mov = opQAI[opQAI.active].control
				mov:Set(opQAI.loopMovie)												#   set QAI movie area and start loop
				mov:Play()
				mov:Loop(true)
			end
			btnFlag = 0
		else																			# otherwise, for all "normal" phases
			local tempIndex = 1
			for k, v in phaseCounter do													# 	set the correct phaseCounter box to true
				if tempIndex == phase then
					v:SetCheck(true)
				else
					v:SetCheck(false)
				end
				tempIndex = tempIndex + 1
			end

			vcr_ff:Enable()
			vcr_end:Enable()

			MovieManager(phase, opMovies)
						
			if faction == 'cybran' then
				if opQAI.loop and not opQAI.loopPlaying then							# if we're using the QAI loop movie and it's not currently looping
					opQAIBack:Set(opQAI.loopMovie)										#   set QAI movie area and start loop
					opQAIBack:Play()
					opQAIBack:Loop(true)
					opQAI.loopPlaying = true
				elseif not opQAI.loop then
					MovieManager(phase, opQAI)
				end
			end

			PrintPhaseText(phase)														# print text

			vcr_ff.OnClick = function(self, modifiers)
                if modifiers.Left and btnFlag == 0 then
                	ButtonTimer()
				    KillMovies(false)
				    PlayPhase(phase + 1)
                end
			end
			vcr_rw.OnClick = function(self, modifiers)
                if modifiers.Left and btnFlag == 0 then
                	ButtonTimer()
				    KillMovies(false)
				    PlayPhase(phase - 1)
                end
			end
		end
	end

--[[ STREAMING TEXT FUNCTIONS ]]--

	local cps = 100																# characters per second for text stream
	local secPerChar = 1 / cps													# convert to seconds per character
	local elapsedTime = 0
	local chunk = 0
	local stopStream = 0
	local gate = true

	local textTimer = Group(parent)
	textTimer.Width:Set(1)
	textTimer.Height:Set(1)
	LayoutHelpers.AtLeftTopIn(textTimer, parent, 0, 0)
	textTimer.OnFrame = function(self, frameTime)
		elapsedTime = elapsedTime + frameTime
		if elapsedTime > secPerChar then
			chunk = math.floor(elapsedTime / secPerChar)
			elapsedTime = 0
			gate = false														# tell UpdateLine to add a chunk
		end
	end

	function PrintPhaseText(phase)
		stopStream = 1
		textTimer:SetNeedsFrameUpdate(false)
		opTextArea:DeleteAllItems()
		FormatText()															# reflow text in case screen has been resized
#		for k, v in newOpText do
#			for k1, v1 in v do
#				LOG('newOpText[',k,'].',k1,' = ' , v1)
#			end
#		end
		if phase > 1 then														# dump any previous-phase text to screen immediately
			DumpText(phase - 1)
		end
		if phase > pTotal then													# if we're past the last phase, exit function
			return
		else																	# otherwise start streaming text
			ForkThread(StreamText,phase)
		end
	end

	function StreamText(phase)												# stream text for the phase
		textTimer:SetNeedsFrameUpdate(true)
		stopStream = 0
		local streamTable = {}
		for k, v in newOpText do											# add all current phase text to streamTable
			if v.phase == phase then
				table.insert(streamTable, v)
			end
		end
#		for k, v in streamTable do
#			for k1, v1 in v do
#				LOG('StreamText - streamTable[',k,'][',k1,']: ' , v1)
#			end
#		end
		for k, v in streamTable do											# iterate through streamTable
			if stopStream == 0 then											# if PrintPhaseText hasn't started again
				local currLine = streamTable[k].line						# grab variables for UpdateLine
				local length = currLine:len()
				local offset = 1
				if streamTable[k].offset then								# if there's an offset value
					offset = streamTable[k].offset							#   use that instead of 1. this is an addition to an already-existing line.
				else
					opTextArea:AddItem('')									# otherwise, add a new line to opTextArea
					opTextArea:ScrollToBottom()
				end
				local itemNum = opTextArea:GetItemCount() - 1				# get current length of the itemList (correct for 0-base list)
				UpdateLine(currLine, length, offset, itemNum)
			else
				break														# if PrintPhaseText has started again, abort further iterations
			end
		end
	end

	function UpdateLine(currLine, length, offset, itemNum)
		while gate and stopStream == 0 do									# as long as there are no break conditions, do nothing
			WaitFrames(1)
		end
		if stopStream == 0 then												# when gate = false, and if we aren't skipping to another phase,
			local txt = string.sub(currLine, 1, offset + chunk)				# new string is all previous plus next letter chunk
			local currLength = txt:len()
			opTextArea:ModifyItem(itemNum, txt)								# change last item to the new string
			gate = true														# set gate back to true to prevent further streaming
			if currLength >= length then									# if we're beyond the length of the line to stream, finish
				return
			else
				UpdateLine(currLine, length, currLength + 1, itemNum)		# otherwise start again at the updated offset
			end
		else
			return
		end
	end

	# FORMAT TEXT -- convert SCUD-generated strings to a table where each line is pre-wrapped for the current opTextArea size
	# TODO: add the new date info somewhere
	function FormatText()
		newOpText = {}																# clear newOpText
		local index = 1																# set index to define newOpText table entries
		local oldChar = ''
		for k, v in opText do														# for every entry in opText,
#			LOG('in opText index ' , k)
			local thisPhase = v.phase
			if thisPhase == 0 then													#   skip phase 0 (date)
				continue
			end
			local tmpWrap = {}
			local newChar = v.character
			local offset = nil
			if newChar == oldChar then												#   if this line is the same character as the last,
				local tblSize = table.getn(newOpText)								#     then grab the last line from newOpText
				local lastLine = newOpText[tblSize].line
				offset = lastLine:len()												#     save the length of the last line so the streamer can use it
				tmpWrap = WrapThisText(lastLine .. ' ' .. LOC(v.text) .. ' ')		#     and prepend it so word wrapping is maintained
			else																	#   otherwise, add the character name first then wrap
				if k == 2 then														#     if we're adding the first text in phase 1 (k=1 is the date)
					#  add the date w/ doublespace, then charname and string without LF
					tmpWrap = WrapThisText(LOC(opText[1].text) .. '\n\n' .. LOCF('%s: %s', newChar, v.text) .. ' ')	
				else
					# otherwise add the LF														
					tmpWrap = WrapThisText(LOCF('\n%s: %s', newChar, v.text) .. ' ')
				end
			end
#			for k, v in tmpWrap do
#				LOG('tmpWrap[',k,']: ' , v)
#			end
			for wrapKey, wrapTxt in tmpWrap do										#   add new entries to newOpText and increment index
				newOpText[index] = {}
				newOpText[index].phase = v.phase
				newOpText[index].character = LOC(v.character)
				newOpText[index].line = wrapTxt
				if offset then
					newOpText[index].offset = offset
					offset = nil
				end
				index = index + 1
			end
			oldChar = newChar
		end
	end

	function WrapThisText(txt)
		return WrapText(txt, opTextArea.Width(), function(text) return opTextArea:GetStringAdvance(text) end)
	end

    function DumpText(phase)														# immediately dump text from phase 1 to this phase onto the screen
    	for k, v in newOpText do
    		if v.phase <= phase then												# look through newOpText for eligible phases
    			if v.offset then													# if an entry has an offset value, then it's a continuation of the previous line instead of a new one
    				local count = opTextArea:GetItemCount()	- 1						#   get the length of opTextArea (subtract 1 to compensate for 0-based item list)
    				opTextArea:ModifyItem(count, v.line)							#   and replace the last line in opTextArea with this line
    			else
    				opTextArea:AddItem(v.line)										# otherwise add the new line
    			end
    		end
    	end
    	opTextArea:ScrollToBottom()
	end

--[[ OTHER FUNCTIONS ]]--

	function MovieManager(phase, movTable)
		if movTable.active then
			local active = movTable.active
			local nextActive = 3 - active
			local movA = movTable[active]
			local movNA = movTable[nextActive]
			
			if phase == movA.phase then
				QueueMovies(phase, active, movTable)					# replay same movie
			else
				local nextPhase = GetNextPhase(phase)
				if phase == movNA.phase then
					movTable.active = nextActive
					local oldActive = active
					QueueMovies(nextPhase, oldActive, movTable)			# flip active control, play new movie and load next movie into old control
				else
					movTable.active = 1
					QueueMovies(phase, 1, movTable, nextPhase, true)	# reload everything and restart on new phase
				end
			end
		else
			InitMovies(movTable)
			movTable.active = 1
			QueueMovies(1, 1, movTable, 2, true)
		end
		PlayActiveMovie(movTable)
	end	


	function InitMovies(movTable)
		if movTable == opQAI then
			opQAI[1] = {}
			opQAI[1].control = Movie(opQAIBack)
			LayoutHelpers.FillParent(opQAI[1].control, opQAIBack)
			if not opQAI.loop then
				opQAI[2] = {}
				opQAI[2].control = Movie(opQAIBack)
				LayoutHelpers.FillParent(opQAI[2].control, opQAIBack)	
				opQAI[2].control:Hide()
			end
		else
			for i = 1, 2 do
				opMovies[i] = {}
				opMovies[i].control = Movie(opMovieBack)
				LayoutHelpers.FillParent(opMovies[i].control, opMovieBack)	
				opMovies[i].control:Hide()
			end
			opMovies[1].control.OnFinished = function(self)
				KillMovies(nil, true)
			    PlayPhase(opMovies[1].phase + 1) 
			end
			opMovies[2].control.OnFinished = function(self)
				KillMovies(nil, true)
			    PlayPhase(opMovies[2].phase + 1) 
			end
		end
	end

	function GetNextPhase(phase)
		if phase == pTotal then
			return 1
		else
			return phase + 1
		end
	end

	function QueueMovies(phase, slotNum, movTable, nextPhase, allFlag)
		LoadMovie(movTable, slotNum, phase)
		if allFlag then
			local otherSlot = 3 - slotNum
			LoadMovie(movTable, otherSlot, nextPhase)
		end
	end
	
	function BuildMediaNames(phase, QAI)
		local num = tostring(phase)													# start building movie/sound filenames
		if num:len() == 1 then num = '0' .. phase end								# if phase is a single digit, add a preceding 0
		local opCue = opMovPfx .. '_B' .. num										# create filename that gets used for movie AND sound, e.g. E01_B01
		local opBank = nil															
		local movName = nil
		if QAI then
			movName = '/movies/'..opCue..'_QAI.sfd'									# set to QAI phase movie (e.g. C01_B01_QAI.sfd)
			opCue = nil
		else
			movName = '/movies/' .. opCue .. '.sfd'
			opBank = opMovPfx .. '_VO'												# create wavebank name for sound, e.g. E01_VO
		end
		return movName, opCue, opBank
	end
	
	function LoadMovie(movTable, num, phase)
		if movTable == opQAI then
			local mov = opQAI[num]
			mov.movName = BuildMediaNames(phase, true)
			mov.control:Set(mov.movName)
			mov.control:Loop(false)													# make sure we don't inherit loop(true) from the end-of-brief script
		else
			local opCue = nil
			local opBank = nil
			local mov = opMovies[num]
			mov.phase = phase
			mov.movName, opCue, opBank = BuildMediaNames(phase)
			mov.control:Set(mov.movName)
			mov.voSound = Sound( {Cue = opCue, Bank = opBank} )
			mov.bgSound = Sound( {Cue = opCue, Bank = 'SC_Op_Briefing'} )
		end
	end
	
	function PlayActiveMovie(movTable)
		local mov = movTable[movTable.active]
		if movTable == opQAI then
			mov.control:Show()
			mov.control:Play()
		else
			if mov.control.IsLoaded and mov.control:IsLoaded() then
				mov.control:Show()
				mov.control:Play()
				mov.voSoundHandle = PlayVoice(mov.voSound)
				mov.bgSoundHandle = PlaySound(mov.bgSound)
			else
				mov.control.OnLoaded = function()
					mov.control:Show()
					mov.control:Play()
					mov.voSoundHandle = PlayVoice(mov.voSound)
					mov.bgSoundHandle = PlaySound(mov.bgSound)
				end
			end
		end
		local oldControl = movTable[3 - movTable.active].control
		oldControl:Hide()
	end

	function KillMovies(exitscreen, onFinish)
		stopStream = 1
		gate = false
		opMovies[opMovies.active].control:Stop()
		if not onFinish then 												# if player pressed a button, kill the sound. otherwise, let the sound trail past the movie since some WAVs are longer.
			StopSound(opMovies[opMovies.active].voSoundHandle, true)
			StopSound(opMovies[opMovies.active].bgSoundHandle, true)
		end
		opMovies[1].control.OnLoaded = nil
		opMovies[2].control.OnLoaded = nil
		if exitscreen then											# if we're leaving this screen,
			StopSound(playAmbSound, true)
			playAmbSound = false
			if faction == 'cybran' then
				if opQAI.loop then
					opQAIBack:Stop()
				else
					opQAI[1].control:Stop()								# 	if Cybran, kill QAI movie (looping or phase movie)
					opQAI[1].control.OnLoaded = nil
					if opQAI[2] then
						opQAI[2].control:Stop()
						opQAI[2].control.OnLoaded = nil							
					end
				end
			end
		elseif faction == 'cybran' then
			if not opQAI.loop then								# 	if we're not leaving, just kill the QAI phase movie. if we're using the QAI loop, leave it.
				opQAI[opQAI.active].control:Stop()
			end
		end
	end

	# Prefetch the map if it exists.  Don't worry about it if it doesn't because we show an error when they click launch.
	function PreloadOpMap()
    	LOG('OP LOAD ',opMap)
    	local scenario = MapUtil.LoadScenario(opMap)
    	if scenario then
	        LOG("scenario = ", repr(scenario))
        	PrefetchSession(scenario.map, Mods.GetCampaignMods(scenario), true)
    	end
	end


--[[ AND... GO! ]]--

	#PreloadOpMap()
	PlayPhase(1)

end
