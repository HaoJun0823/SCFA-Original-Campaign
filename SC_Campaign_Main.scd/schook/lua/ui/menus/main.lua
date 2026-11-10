--*****************************************************************************
--* File: schook/lua/ui/menus/main.lua
--* Summary: Hook ButtonCampaign to show SC/FA campaign selection dialog
--*****************************************************************************

-- Proof-of-life: runs while the main menu is built.
LOG('[SC Campaign] HOOK ALIVE: schook/lua/ui/menus/main.lua')

-- FA main.lua defines ButtonCampaign as a global function inside CreateUI().
-- schook appends this code at file scope after the base file.
-- We can access globals set by CreateUI() (like ButtonCampaign itself),
-- but NOT upvalues local to CreateUI() (like UIUtil, StopMusic, parent).
--
-- Strategy: wrap ButtonCampaign with a dialog. When user picks SC campaign,
-- we call origButtonCampaign() which runs FA's full menu-teardown sequence,
-- but we temporarily replace '/lua/ui/campaign/selectcampaign.lua'.CreateUI
-- with our SC version so the teardown leads into SC's selectcampaign instead.

local baseCreateUI = CreateUI

-- FA's ButtonCampaign chain is asynchronous (TutorialPrompt -> MenuAnimation
-- -> selectcampaign.CreateUI). If the player cancels it, or it errors, the
-- temporary CreateUI wrapper below would stay in the module table forever and
-- hijack every later campaign-menu entry. Keep the REAL FA function here and
-- restore it unconditionally whenever the button is pressed again.
local SC_faSelectOriginalCreateUI = nil

local function SC_GetFASelectModule()
    local ok, mod = pcall(function()
        return import('/lua/ui/campaign/selectcampaign.lua')
    end)
    if ok and type(mod) == 'table' then
        return mod
    end
    return nil
end

local function SC_RestoreFASelectCampaign()
    local mod = SC_GetFASelectModule()
    if mod and SC_faSelectOriginalCreateUI then
        mod.CreateUI = SC_faSelectOriginalCreateUI
    end
end

function CreateUI()
    baseCreateUI()

    local origButtonCampaign = ButtonCampaign

    ButtonCampaign = function()
        local faSelCamp = SC_GetFASelectModule()
        if faSelCamp then
            -- Capture the genuine FA function BEFORE any wrapper is installed,
            -- then clear a wrapper left over from an aborted transition.
            if SC_faSelectOriginalCreateUI == nil then
                SC_faSelectOriginalCreateUI = faSelCamp.CreateUI
            end
            SC_RestoreFASelectCampaign()
        end
        local ui = import('/lua/ui/uiutil.lua')
        ui.QuickDialog(GetFrame(0),
            "<LOC SC_CAMP_SELECT_0000>Which campaign would you like to play?",
            "<LOC SC_CAMP_ORIGINAL>Original Campaign",
            function()
                -- Temporarily swap FA's selectcampaign.CreateUI with SC's.
                -- origButtonCampaign() does: TutorialPrompt -> MenuAnimation(false) ->
                --   StopMusic -> parent:Destroy -> import('...selectcampaign.lua').CreateUI()
                -- The wrapper restores the REAL FA function once that async
                -- chain reaches it. If the chain is cancelled, the next
                -- ButtonCampaign press clears the leftover wrapper instead.
                local selCamp = SC_GetFASelectModule()
                if selCamp and SC_faSelectOriginalCreateUI then
                    selCamp.CreateUI = function()
                        selCamp.CreateUI = SC_faSelectOriginalCreateUI
                        import('/lua/sc_campaign/selectcampaign.lua').CreateUI()
                    end
                end
                local ok, err = pcall(origButtonCampaign)
                if not ok then
                    SC_RestoreFASelectCampaign()
                    LOG('[SC Campaign] campaign menu transition failed: ' .. tostring(err))
                end
            end,
            "<LOC SC_CAMP_FA>Forged Alliance",
            function()
                SC_RestoreFASelectCampaign()
                origButtonCampaign()
            end,
            "<LOC _Cancel>",
            nil,
            true, {worldCover = true, enterButton = 1, escapeButton = 3}
        )
    end
end
