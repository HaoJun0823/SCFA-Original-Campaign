--*****************************************************************************
--* File: schook/lua/ui/menus/main.lua
--* Summary: Hook ButtonCampaign to show SC/FA campaign selection dialog
--*****************************************************************************

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

function CreateUI()
    baseCreateUI()

    local origButtonCampaign = ButtonCampaign

    ButtonCampaign = function()
        local ui = import('/lua/ui/uiutil.lua')
        ui.QuickDialog(GetFrame(0),
            "<LOC SC_CAMP_SELECT_0000>Which campaign would you like to play?",
            "<LOC SC_CAMP_ORIGINAL>Original Campaign",
            function()
                -- Temporarily swap FA's selectcampaign.CreateUI with SC's.
                -- origButtonCampaign() does: TutorialPrompt -> MenuAnimation(false) ->
                --   StopMusic -> parent:Destroy -> import('...selectcampaign.lua').CreateUI()
                -- By swapping the function, the same teardown leads to SC campaign.
                local faSelCamp = import('/lua/ui/campaign/selectcampaign.lua')
                local origCreateUI = faSelCamp.CreateUI
                faSelCamp.CreateUI = function()
                    -- Restore original first, then launch SC campaign
                    faSelCamp.CreateUI = origCreateUI
                    import('/lua/sc_campaign/selectcampaign.lua').CreateUI()
                end
                origButtonCampaign()
            end,
            "<LOC SC_CAMP_FA>Forged Alliance",
            function()
                origButtonCampaign()
            end,
            nil, nil,
            true, {worldCover = true, enterButton = 1, escapeButton = 2}
        )
    end
end
