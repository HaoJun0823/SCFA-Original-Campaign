--*****************************************************************************
--* SC Campaign port: restore PlayEndGameMovie() for FA's /lua/ui/game/missiontext.lua
--*
--* FA removed the SC1 function PlayEndGameMovie(faction, callback)
--* (SC1 lua/ui/game/missiontext.lua:410) and replaced it with EndGameFMV(faction),
--* which takes NO callback. But both the ported
--*     /lua/sc_campaign/campaignmanager.lua:324
--* and FA's own /lua/ui/campaign/campaignmanager.lua still call the SC1 name.
--* Because a module table falls back to _G on a missing field, finishing the
--* last operation (SCCA_E06, factionVideo=1) trips FA's strict global guard:
--*     access to nonexistent global variable "PlayEndGameMovie"
--* The score dialog is registered as the callback, so it never opens either.
--*
--* The genuine SC1 outro files are present in /movies/
--* (gamedata/SC_Campaign_Data_Movie.scd/movies:
--*  FMV_UEF_Outro_1.sfd, FMV_Credits.sfd, FMV_UEF_Outro_2.sfd), and the port
--* already ships a working SC1 movie player in
--* /lua/sc_campaign/campaignmovies.lua. So rather than aliasing FA's
--* EndGameFMV (which would show the Forged Alliance outro and still has no
--* completion hook), we replay the original three-part SC1 outro and then
--* invoke the callback.
--*
--* This also repairs FA's UserSync.lua:354, which reacts to Sync.EndGameMovie
--* with the same (missing) function name.
--*****************************************************************************

LOG('[SC Campaign] HOOK ALIVE: schook/lua/ui/game/missiontext.lua ' ..
    '(PlayEndGameMovie restored)')

-- SC1 GetFaction(): 1 = UEF, 2 = Aeon, 3 = Cybran. Accept the numeric value
-- used by ovTable.factionVideo as well as the lowercase campaign ids.
local SC_ENDGAME_FACTION_BY_INDEX = { 'UEF', 'Aeon', 'Cybran' }
local SC_ENDGAME_FACTION_BY_NAME = {
    uef = 'UEF', aeon = 'Aeon', cybran = 'Cybran',
}

local function SC_EndGameFactionName(faction)
    if type(faction) == 'number' then
        return SC_ENDGAME_FACTION_BY_INDEX[faction] or 'UEF'
    end
    if type(faction) == 'string' then
        return SC_ENDGAME_FACTION_BY_NAME[string.lower(faction)] or 'UEF'
    end
    return 'UEF'
end

local SC_endgameRunning = false
local SC_endgameDone = false
local SC_endgameCallback = false

local function SC_EndGameDone(reason)
    SC_endgameRunning = false
    if SC_endgameDone then
        return
    end
    SC_endgameDone = true
    LOG('[SC Campaign] end-game movie chain finished (' .. tostring(reason) .. ')')
    local cb = SC_endgameCallback
    SC_endgameCallback = false
    if type(cb) == 'function' then
        local ok, err = pcall(cb)
        if not ok then
            LOG('[SC Campaign] score dialog callback failed: ' .. tostring(err))
        end
    end
end

-- PlayCampaignMovie(movieName, over, checkPlayed, exitBehavior, globalPrefs, cue)
-- The cue is always passed explicitly: FixCueName() expects a faction segment
-- in the movie name, which FMV_Credits does not have, and the case-sensitive
-- SC_FMV wavebank cues use the upper-case faction spelling.
local function SC_PlayEndGamePart(movies, movieName, cueName, onDone)
    -- PlayCampaignMovie's LeaveMovie() can be reached both from OnFinished and
    -- from a mouse/key press. Make sure the chain advances exactly once.
    local advanced = false
    local function AdvanceOnce()
        if advanced then
            return
        end
        advanced = true
        if onDone then
            onDone()
        end
    end
    local ok, played = pcall(function()
        return movies.PlayCampaignMovie(movieName, GetFrame(0), false,
                                        AdvanceOnce, false, cueName)
    end)
    if not ok then
        LOG('[SC Campaign] end-game movie ' .. tostring(movieName) ..
            ' failed: ' .. tostring(played))
        SC_EndGameDone('player error')
        return
    end
    if played == false then
        -- Never expected with checkPlayed=false, but never strand the player
        -- on a black screen without the score dialog.
        SC_EndGameDone('player declined')
    end
end

function PlayEndGameMovie(inFaction, callback)
    -- A second caller may arrive while the outro is running (FA's UserSync.lua
    -- reacts to Sync.EndGameMovie with no callback). Keep the newest callback
    -- but never start a second chain.
    if callback then
        SC_endgameCallback = callback
    end
    if SC_endgameRunning then
        LOG('[SC Campaign] end-game movie already running - request merged')
        return
    end

    SC_endgameRunning = true
    SC_endgameDone = false

    local faction = SC_EndGameFactionName(inFaction)
    local okMovies, movies = pcall(function()
        return import('/lua/sc_campaign/campaignmovies.lua')
    end)
    if not okMovies or type(movies) ~= 'table' or
       type(movies.PlayCampaignMovie) ~= 'function' then
        LOG('[SC Campaign] campaignmovies.lua unavailable (' ..
            tostring(movies) .. ') - skipping outro, opening score dialog')
        SC_EndGameDone('player unavailable')
        return
    end

    LOG('[SC Campaign] end-game movie: faction=' .. faction ..
        ', playing SC1 outro (3 parts)')

    local function PlayOutro2()
        SC_PlayEndGamePart(movies,
            'FMV_' .. faction .. '_Outro_2',
            'FMV_' .. faction .. '_Outro_2',
            function()
                SC_EndGameDone('outro complete')
            end)
    end

    local function PlayCredits()
        SC_PlayEndGamePart(movies,
            'FMV_Credits',
            'FMV_' .. faction .. '_Credits',
            PlayOutro2)
    end

    SC_PlayEndGamePart(movies,
        'FMV_' .. faction .. '_Outro_1',
        'FMV_' .. faction .. '_Outro_1',
        PlayCredits)
end
