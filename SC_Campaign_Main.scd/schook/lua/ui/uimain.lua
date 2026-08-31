--*****************************************************************************
--* File: schook/lua/ui/uimain.lua
--* Summary: Hook StartFrontEndUI to check SC campaign AutoContinue before
--*          falling through to FA's native NextOpBriefing / main menu logic.
--*****************************************************************************

-- Save original FA StartFrontEndUI
local baseFAStartFrontEndUI = StartFrontEndUI

function StartFrontEndUI()
    -- Check SC campaign AutoContinue data first.
    -- SetAutoContinueOpStatus() is called from the SC score screen's
    -- endgame() before ExitGame(). FA's native StartFrontEndUI only
    -- checks 'NextOpBriefing' (for FA campaign), not 'AutoContinue'.
    local okSC, scCM = pcall(import, '/lua/sc_campaign/campaignmanager.lua')
    if okSC and scCM and scCM.GetAutoContinueOp then
        local autoOp = scCM.GetAutoContinueOp()
        if autoOp then
            scCM.AutoLaunchOperation()
            if GetNumRootFrames() > 1 then
                import('/lua/ui/game/multihead.lua').ShowLogoInHead1()
            end
            return
        end
    end

    -- No SC AutoContinue; fall through to FA native logic
    baseFAStartFrontEndUI()
end
