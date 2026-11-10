--*****************************************************************************
--* File: schook/lua/ui/game/announcement.lua
--*
--* Keeps the "Objective Added" toast working while the game UI is starting up.
--*
--* Two separate faults showed up in E05:
--*
--*   1) objectives2.lua calls Announcement() from inside its update loop and
--*      runs LayoutObjectiveItems() only after that loop. So the control handed
--*      to CreateAnnouncement() still carries Control:ResetLayout()'s circular
--*      default (control.lua:33-40: Top = Bottom - Height, Bottom = Top +
--*      Height). announcement.lua reads goalControl.Top() from OnFrame, which
--*      raises "circular dependency in lazy evaluation" every frame and the
--*      banner never appears.
--*
--*   2) The first workaround for (1) swapped such goal controls for
--*      GetFrame(0). But the animation both starts AND ends at the goal rect
--*      (0 -> .2 s fly in, 3.5 -> 3.7 s fly out), so with the screen frame the
--*      banner covered the whole screen, shrank to the text size, then at
--*      3.5 s grew back to full screen and was destroyed at 3.7 s: the
--*      "maximises, then suddenly disappears" glitch.
--*
--* Fix
--* ---
--* Keep the real goal control and simply create the announcement a frame or
--* two later, after LayoutObjectiveItems() has given the row real edges. The
--* banner then flies in from / out to the objective icon exactly like vanilla
--* FA does.
--*
--* While a NIS runs, the game itself defers LayoutObjectiveItems(), so the
--* wait counter is paused for the duration of the NIS. If the row never
--* becomes usable (destroyed, panel gone), we fall back to a small invisible
--* 40x40 anchor at the objective panel's usual spot - never the full screen.
--*****************************************************************************
do

local SC_Group = import('/lua/maui/group.lua').Group
local SC_baseCreateAnnouncement = CreateAnnouncement

-- Frames (not seconds: the UI may run below 60 fps) to wait for the objective
-- row to be laid out. NIS time does not count towards this.
local SC_MAX_WAIT_FRAMES = 480
-- One UI frame. Small enough to not be noticeable, large enough to guarantee
-- the scheduler yields at least once.
local SC_FRAME = 0.01

-- Walks every edge/axis the animation touches. A circular lazy var throws on
-- evaluation, so pcall() is the cheapest reliable probe.
local function SC_layoutReady(control)
    if not control then
        return false
    end
    local ok, sum = pcall(function()
        return control.Top() + control.Left() + control.Right() + control.Bottom() +
               control.Width() + control.Height()
    end)
    return ok and sum ~= nil
end

local function SC_inNIS()
    local ok, gameMain = pcall(function() return import('/lua/ui/game/gamemain.lua') end)
    if not ok or type(gameMain) ~= 'table' then
        return false
    end
    local ok2, result = pcall(function() return gameMain.IsNISMode() end)
    return ok2 and result == true
end

-- Last-resort anchor: a small invisible square where the objective panel sits.
-- Deliberately NOT GetFrame(0) - see the header comment.
local SC_fallbackAnchor

local function SC_getFallbackAnchor()
    if SC_fallbackAnchor then
        return SC_fallbackAnchor
    end
    local screen = GetFrame(0)
    local anchor = SC_Group(screen)
    anchor.Left:Set(24)
    anchor.Right:Set(64)
    anchor.Top:Set(function() return screen.Height() * 0.33 end)
    anchor.Bottom:Set(function() return screen.Height() * 0.33 + 40 end)
    anchor:DisableHitTest(true)
    anchor:Hide()
    SC_fallbackAnchor = anchor
    return anchor
end

local SC_deferLogged = false

function CreateAnnouncement(text, goalControl, secondaryText, onFinished)
    if SC_layoutReady(goalControl) then
        return SC_baseCreateAnnouncement(text, goalControl, secondaryText, onFinished)
    end

    -- The row exists but has not been through LayoutObjectiveItems() yet.
    -- Wait for it instead of dropping the animation, so the banner keeps its
    -- anchor on the objective icon.
    if not SC_deferLogged then
        SC_deferLogged = true
        LOG('[SC Campaign] announcement deferred until the objective row is laid out')
    end
    ForkThread(function()
        local waited = 0
        local wasInNIS = false
        while not SC_layoutReady(goalControl) do
            if SC_inNIS() then
                wasInNIS = true
                waited = 0          -- layout is parked until the NIS ends
            else
                if wasInNIS then
                    wasInNIS = false
                    -- FA sets needsObjectiveLayoutPostNIS but never reads it, so
                    -- a row added during a NIS stays unlaid-out until something
                    -- else happens to call the layout function. Nudge it once,
                    -- both for the objective icon and for this banner's anchor.
                    pcall(function()
                        import('/lua/ui/game/objectives2.lua').LayoutObjectiveItems()
                    end)
                end
                waited = waited + 1
                if waited > SC_MAX_WAIT_FRAMES then
                    local okAnchor, anchor = pcall(SC_getFallbackAnchor)
                    if not okAnchor or not anchor then
                        return
                    end
                    LOG('[SC Campaign] announcement: objective row never laid out, ' ..
                        'using objective-panel anchor')
                    goalControl = anchor
                    break
                end
            end
            WaitSeconds(SC_FRAME)
        end
        SC_baseCreateAnnouncement(text, goalControl, secondaryText, onFinished)
    end)
end

end
