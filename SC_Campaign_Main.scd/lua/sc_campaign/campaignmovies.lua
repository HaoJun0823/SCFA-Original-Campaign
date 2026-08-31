--*****************************************************************************
--* File: lua/modules/ui/campaign/campaignmovies.lua
--* Author: Chris Blackwell
--* Summary: Play campaign movies on demand
--*
--* Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
--*****************************************************************************

local UIUtil = import('/lua/ui/uiutil.lua')
local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local ItemList = import('/lua/maui/itemlist.lua').ItemList
local WrapText = import('/lua/maui/text.lua').WrapText
local Movie = import('/lua/maui/movie.lua').Movie
local Prefs = import('/lua/user/prefs.lua')

local creditsMovies = {
    uef = 'FMV_UEF_Credits',
    aeon = 'FMV_Aeon_Credits',
    cybran = 'FMV_Cybran_Credits',
}

-- SC original SC_FMV.xsb only has 13 cues. These cues have NO voice audio
-- in the SC_FMV wave bank (background sound SC_FMV_BG has them, but voice
-- bank does not). PlayVoice will fail with a warning for these cues.
-- This is SC original behaviour - not a rebuild error.
local missingVoiceCues = {
    FMV_UEF_Intro_2 = true,
    FMV_Aeon_Intro_2 = true,
    FMV_UEF_Outro_2 = true,
}

local subtitleThread = false

function DisplaySubtitles(textControl,captions)
    subtitleThread = ForkThread(
        function()
            # Display subtitles
            local lastOff = 0
            for k,v in captions do
                WaitSeconds(v.offset - lastOff)
                textControl:DeleteAllItems()
                locText = LOC(v.text)
                #LOG("Wrap: ",locText)
                local lines = WrapText(locText, textControl.Width(), function(text) return textControl:GetStringAdvance(text) end)
                for i,line in lines do
                    textControl:AddItem(line)
                end
                textControl:ScrollToBottom()
                lastOff = v.offset
            end
        end
    )
end

-- Call this to play a full screen campaign movie
--  movieName = name of movie (no directory or extension required)
--  cueName = name of wavebank cue, if blank then use movieName
--  over = control to play above (to make sure depth is correct)
--  checkPlayed = if true, checks to see if the movie has been already been played before trying to play (optional)
--  exitBehavior = function that will get called when the movie is done playing (optional)

-- returns true if movie played, else false
function PlayCampaignMovie(movieName, over, checkPlayed, exitBehavior, globalPrefs, cue)
    if checkPlayed then
        local played = false
        if globalPrefs then
            played = GetPreference("movie.played." .. movieName)
        else
            played = Prefs.GetFromCurrentProfile("movie_played_" .. movieName)
        end
        if played then
            return false
        end
        if globalPrefs then
            SetPreference("movie.played." .. movieName, true)
        else
            Prefs.SetToCurrentProfile("movie_played_" .. movieName, true)
        end
    end
    
    GetCursor():Hide()

	# fix the faction portion of the wavebank cue name, since the wavebank cue is case sensitive
	# e.g. the movieName is "FMV_uef_Intro" but the cue in the wavebank is named "FMV_UEF_Intro"
	# FMV_Campaign_Intro doesn't follow this rule, so is omitted
    local cueName = movieName
    local subtitleKey = movieName
    if cueName != 'FMV_Campaign_Intro' then
        if cue then
            cueName = cue
            subtitleKey = cue
        else
            cueName = FixCueName(cueName)
            subtitleKey = cueName
          end
    end
    LOG('  cueName (final) = ', cueName)
    LOG('  subtitleKey = ', subtitleKey)

    local parent = UIUtil.CreateScreenGroup(GetFrame(over:GetRootFrame():GetTargetHead()), "Campaign Movie ScreenGroup")
    parent.Depth:Set(function() return over.Depth() + 1 end)
    AddInputCapture(parent)

	local background = Bitmap(parent)
    LayoutHelpers.FillParent(background, parent)
	background:SetSolidColor('black')

    local movie = Movie(background)
    LayoutHelpers.FillParentPreserveAspectRatio(movie, parent)

    movie:DisableHitTest()    -- get clicks to parent group
    
    # black background for subtitles (only impacts 16:9 ratio slightly)
    local subtitleBG = Bitmap(movie)

    local textArea = ItemList(subtitleBG)
    textArea:SetFont(UIUtil.bodyFont, 15)
    local height = 4 * textArea:GetRowHeight()
    textArea.Height:Set( height )
    textArea.Top:Set( function() return background.Bottom() - height - 4 end )
    textArea.Width:Set( function() return movie.Width() / 2 end )
    LayoutHelpers.AtHorizontalCenterIn(textArea,parent)
    textArea:SetColors(UIUtil.fontColor, "00000000", UIUtil.fontColor,  UIUtil.highlightColor)

    subtitleBG:SetSolidColor('black')
    subtitleBG.Left:Set( function() return parent.Left() end )
    subtitleBG.Top:Set( function() return textArea.Top() end )
    subtitleBG.Height:Set( function() return textArea.Height() end )
    subtitleBG.Width:Set( function() return parent.Width() end )

    local useSubtitles = Prefs.GetOption('subtitles') or not HasLocalizedVO(__language)
    local captions = false
    if useSubtitles then
        local strings = import('/lua/sc_campaign/fmv_strings.lua')
        for k,v in strings do
            if k == subtitleKey then
                captions = v.captions
                break
            end
        end
    end

    movie.OnLoaded = function(self)
        if not missingVoiceCues[cueName] then
            movie.voice = PlayVoice(Sound( {Cue = cueName, Bank = 'SC_FMV'} ))
        end
        movie.sound = PlaySound(Sound( {Cue = cueName, Bank = 'SC_FMV_BG'} ))
        movie:Play()
        if captions then
            DisplaySubtitles(textArea,captions)
        end
    end

    movie:Set("/movies/" .. movieName .. ".sfd")

    local function LeaveMovie()
        GetCursor():Show()
        RemoveInputCapture(parent)
        if subtitleThread then
            KillThread(subtitleThread)
            subtitleThread = false
        end
        movie:Stop()
        movie.OnLoaded = nil
        if movie.voice then
            StopSound(movie.voice, true)
        end
        StopSound(movie.sound, true)
        parent:Destroy()
        if exitBehavior != nil then
            exitBehavior()
        end
    end

    parent.HandleEvent = function(self, event)
        -- cancel movie playback on mouse click or key hit
        if event.Type == "ButtonPress" or event.Type == "KeyDown" then
            if event.KeyCode then
                if event.KeyCode == UIUtil.VK_ESCAPE or event.KeyCode == UIUtil.VK_ENTER or event.KeyCode == UIUtil.VK_SPACE or event.KeyCode == 1  or event.KeyCode == 3 then
                else
                    return true
                end
            end 
            LeaveMovie()
            return true
        end
    end

    movie.OnFinished = function(self)
        LeaveMovie()
    end

    return true
end

function PlayEndGameFMV(faction)
	local outroName_1 = 'FMV_' .. faction .. '_Outro_1'
	PlayCampaignMovie(outroName_1, GetFrame(0), false, function(self) PlayCredits(faction, GetFrame(0)) end)
end

function PlayCredits(faction, over)

	local cueName = creditsMovies[faction]
    if not curName then
		LOG('ERROR - PlayCredits() was passed bad faction: ' , faction)
	end

   	local parent = UIUtil.CreateScreenGroup(GetFrame(over:GetRootFrame():GetTargetHead()), "Campaign Movie ScreenGroup")
    parent.Depth:Set(function() return over.Depth() + 1 end)
    AddInputCapture(parent)

    local movie = Movie(parent)
    LayoutHelpers.FillParentPreserveAspectRatio(movie, parent)
    movie:DisableHitTest()    -- get clicks to parent group

    movie:Set("/movies/FMV_Credits.sfd",
          Sound( {Cue = cueName, Bank = 'SC_FMV_BG'} ))
    movie.OnLoaded = function(self)
		movie:Play()
	end

    local function LeaveMovie()
            RemoveInputCapture(parent)
            movie:Stop()
            parent:Destroy()
    end

    parent.HandleEvent = function(self, event)
        -- cancel movie playback on mouse click or key hit
        if event.Type == "ButtonPress" or event.Type == "KeyDown" then
            LeaveMovie()
            return true
        end
    end

    movie.OnFinished = function(self)
    	PlayCampaignMovie('FMV_' .. faction .. '_Outro_2', GetFrame(0), false)
    end

end

function FixCueName(cueName)
    local suffix = nil
    suffix = cueName:sub(5)
    local facName = suffix:sub(1, suffix:find('_') - 1)
    suffix = suffix:sub(string.sub(suffix:find('_'), 1, 1))
    local factionData = import('/lua/factions.lua')
    facName = factionData.Factions[factionData.FactionIndexMap[facName]].SoundPrefix
    if not facName then
        LOG('ERROR -- unknown faction: ' , facName)
    end
    cueName = 'FMV_' .. facName .. suffix
    return cueName
end