--*****************************************************************************
--* File: schook/lua/ScenarioFramework.lua
--* Style: Sorian AI Pack hook convention (self-contained do ... end block,
--*        executed after the original /lua/ScenarioFramework.lua chunk).
--*
--* Seven jobs:
--*   1) EndOperation() signature shim: SC scripts pass 7 args, FA passes 3.
--*   2) Re-add PatrolLocationFactoriesAI (removed in FA).
--*   3) Provide CDROverchargeBehavior (SC-only global, removed in FA).
--*   4) Drive the "Timer = n" objective countdown (FA's Protect forgot onTick).
--*   5) E05: complete the quantum-gate objective when the ACU reaches the gate.
--*   6) E05: complete the SMD objective when it is met after mission 1 ended.
--*   7) Translate SC's CreateTimerTrigger(cb, seconds, displayBool) to FA's
--*      5-argument form so the three on-screen countdowns still draw.
--*
--* Why globals and not just map-script edits: FA campaign saves embed the
--* COMPILED copy of the map script. A save taken before a map-script fix keeps
--* running the old bytecode no matter what the .scd contains, so anything the
--* old bytecode can trip over has to be repaired from a module that is
--* re-imported on every load - this file.
--*****************************************************************************
do

LOG('[SC Campaign] schook/lua/ScenarioFramework.lua loaded')

-- FA installs a strict __index on _G (lua/system/config.lua) that raises
-- "access to nonexistent global variable X" on a plain miss, while engine-side
-- globals such as `moho` are themselves served through a metatable - so
-- neither a bare read nor rawget() alone is safe here.
--
-- NOTE: a schook file is *appended* to the original and runs with the
-- ScenarioFramework MODULE table as its environment (import.lua sets
-- __module_metatable = {__index = _G}). Names defined by ScenarioFramework
-- itself - Objectives, EndOperation, ScenarioInfo helpers - therefore live in
-- that module table and are NOT in _G. Look them up directly; _G lookups only
-- work for engine globals (Sync, ForkThread, moho, ...).
local function SC_getGlobal(name)
    local ok, value = pcall(function() return _G[name] end)
    if ok and value ~= nil then
        return value
    end
    ok, value = pcall(function() return rawget(_G, name) end)
    if ok then
        return value
    end
    return nil
end

-- Expose a function defined in this module to bare-global readers. Map scripts
-- are loaded with import() too, so their unqualified reads fall through to _G;
-- a plain `function Name()` here would only land in the module table and stay
-- invisible to them (strict _G.__index then raises).
local function SC_exportGlobal(name, value)
    local ok, err = pcall(function() rawset(_G, name, value) end)
    if not ok then
        LOG('[SC Campaign] export ' .. name .. ' failed: ' .. tostring(err))
    end
end

--*****************************************************************************
--* 1) EndOperation shim
--*****************************************************************************
-- Defined earlier in this same file, so it sits in the module table.
local baseEndOperation = EndOperation

local function SCCaToFaction(opKey)
    if type(opKey) ~= 'string' then
        return nil
    end
    local prefix = string.sub(opKey, 6, 6)
    if prefix == 'E' then
        return 'uef'
    elseif prefix == 'R' then
        return 'cybran'
    elseif prefix == 'A' then
        return 'aeon'
    end
    return nil
end

function EndOperation(a, b, c, d, e, f, g)
    if d ~= nil then
        -- SC 7-arg form: opKey, success, difficulty, allPrimary, allSecondary, allBonus, factionNIS
        local faction = SCCaToFaction(a)
        LOG('[SC Campaign] EndOperation SC form: opKey=' .. tostring(a) ..
            ' success=' .. tostring(b) .. ' faction=' .. tostring(faction))
        Sync.OperationComplete = {
            opKey = a,
            success = b,
            difficulty = c,
            allPrimary = d,
            allSecondary = e,
            allBonus = f,
            factionVideo = g,
            campaignID = faction,
        }
    elseif baseEndOperation then
        baseEndOperation(a, b, c)
    else
        LOG('[SC Campaign] EndOperation: no base implementation available')
    end
end

--*****************************************************************************
--* 2) PatrolLocationFactoriesAI  (SC lua/platoon.lua:546)
--*    Called from 12 places across 7 ported maps: A03(4) A05(2) A06(1)
--*    E01(1) E02(1) E03(1) R06(2), always from a forked platoon AI thread.
--*****************************************************************************
local function SC_patrolLocationFactoriesImpl(self)
    local aiBrain = self:GetBrain()
    if not aiBrain then
        return
    end
    local data = self.PlatoonData or {}
    local location = data.LocationType or 'MAIN'
    while aiBrain:PlatoonExists(self) do
        self:Stop()
        local factories = aiBrain:PBMGetLocationFactories(location)
        if factories then
            for _, fac in factories do
                if fac and not fac:IsDead() then
                    self:Patrol(fac:GetPosition())
                    local guards = fac:GetGuards()
                    if guards then
                        for _, guard in guards do
                            if guard and not guard:IsDead() then
                                self:Patrol(guard:GetPosition())
                            end
                        end
                    end
                end
            end
        else
            aiBrain:DisbandPlatoon(self)
        end
        WaitSeconds(71)
    end
end

-- Public entry point used by the ported map scripts. Must live in _G: map
-- scripts are imported as modules too, so their unqualified reads resolve
-- module -> _G, and the strict _G.__index would raise on a miss.
function SC_PatrolLocationFactoriesAI(platoon)
    if not platoon then
        return
    end
    -- Field probe must be guarded: the platoon metatable can raise on a miss.
    local ok, fn = pcall(function() return platoon.PatrolLocationFactoriesAI end)
    if ok and type(fn) == 'function' then
        return fn(platoon)
    end
    return SC_patrolLocationFactoriesImpl(platoon)
end

-- Map scripts are modules as well: their unqualified reads go module -> _G,
-- so this must exist in _G or the strict guard turns it into a Lua error.
SC_exportGlobal('SC_PatrolLocationFactoriesAI', SC_PatrolLocationFactoriesAI)

--*****************************************************************************
--* 3) CDROverchargeBehavior shim
--*
--* SC's E04 does:  import('/lua/ai/AIBehaviors.lua').CDROverchargeBehavior(p)
--* AIBehaviors.lua has no `return`, so import() hands back that file's module
--* table, whose __index falls through to _G. The miss therefore hits FA's
--* strict _G.__index -> "access to nonexistent global variable
--* CDROverchargeBehavior" and StartMission2 dies half-way.
--*
--* This matters even for code we already patched, because FA campaign saves
--* embed the compiled copy of the map script itself (verified: TEST4.*.SCFACampaignSave
--* contains /maps/scca_e04/scca_e04_script.lua plus its bytecode constants).
--* A save made before a map-script fix keeps executing the OLD bytecode
--* forever; only globals defined here at load time can reach it.
--*****************************************************************************
local SC_overchargeShim
-- Declared empty first, then assigned: a local initialised in its own
-- declaration is NOT in scope inside the function body (Lua 5.1 scoping).
SC_overchargeShim = function(platoon)
    local ok = pcall(function()
        import('/lua/AI/OpAI/OpBehaviors.lua')
    end)
    local real = rawget(_G, 'CDROverchargeBehavior')
    if ok and type(real) == 'function' and real ~= SC_overchargeShim then
        return real(platoon)
    end
    LOG('[SC Campaign] CDROverchargeBehavior shim: no real implementation, skipped')
end

if rawget(_G, 'CDROverchargeBehavior') == nil then
    rawset(_G, 'CDROverchargeBehavior', SC_overchargeShim)
    LOG('[SC Campaign] CDROverchargeBehavior shim installed')
else
    LOG('[SC Campaign] CDROverchargeBehavior already provided by engine/AI pack')
end

-- Attach the method under its original name so saved games can re-resolve it.
local SC_moho = SC_getGlobal('moho')
local SC_platoonMethods = SC_moho and SC_moho.platoon_methods
local SC_platoonClass = SC_getGlobal('Platoon')
local SC_aiPlatoonClass = SC_getGlobal('AIPlatoon')

LOG('[SC Campaign] attach probe: moho=' .. tostring(SC_moho ~= nil) ..
    ' platoon_methods=' .. tostring(SC_platoonMethods ~= nil) ..
    ' Platoon=' .. tostring(SC_platoonClass ~= nil) ..
    ' AIPlatoon=' .. tostring(SC_aiPlatoonClass ~= nil))

local SC_attachedTo = {}

local function SC_tryAttach(target, label)
    if not target then
        return
    end
    -- rawset, not target[k] = v: moho.platoon_methods is a closed Class and its
    -- __newindex refuses any field added after the class was defined
    -- ("Attempted to add field ... after class was defined", class.lua:273).
    local ok, err = pcall(function()
        rawset(target, 'PatrolLocationFactoriesAI', SC_patrolLocationFactoriesImpl)
    end)
    local checkOk, got = pcall(function()
        return rawget(target, 'PatrolLocationFactoriesAI')
    end)
    if ok and checkOk and got == SC_patrolLocationFactoriesImpl then
        table.insert(SC_attachedTo, label)
    else
        LOG('[SC Campaign] attach to ' .. label .. ' failed: ok=' .. tostring(ok) ..
            ' err=' .. tostring(err))
    end
end

SC_tryAttach(SC_platoonMethods, 'moho.platoon_methods')
SC_tryAttach(SC_platoonClass, 'Platoon')
SC_tryAttach(SC_aiPlatoonClass, 'AIPlatoon')

if SC_attachedTo[1] ~= nil then
    LOG('[SC Campaign] PatrolLocationFactoriesAI attached via: ' .. table.concat(SC_attachedTo, ', '))
else
    LOG('[SC Campaign] PatrolLocationFactoriesAI not on any class table; ' ..
        'map scripts call the SC_PatrolLocationFactoriesAI global instead')
end

--*****************************************************************************
--* 4) Objective countdown ("Timer = n")
--*
--* Where the number comes from: SimObjectives.AddObjective sends
--*   targets = {Type = 'Timer', Time = Target.Timer}
--* and lua/ui/game/objectives2.lua builds the mm:ss label from targets.Time
--* (line 254/546), so the initial 01:30 appears fine on both games.
--*
--* What changed in FA:
--*   SC : TriggerFile.CreateTimerTrigger(cb, seconds, displayBool)
--*        -> sim thread rewrote Sync.ObjectiveTimer every second, SC UI drew it
--*   FA : TriggerFile.CreateTimerTrigger(cb, seconds, name, displayBool, onTickFunc)
--*        -> countdown moved to UpdateObjective(title, 'timer', {Time = n}, tag)
--*
--* FA's own Objectives.Timer() passes that onTick and works. Its Protect() still
--* passes only three arguments, so the `true` that used to be displayBool now
--* lands in `name`, displayBool is nil and no tick is ever created: the ported
--* E04 M3P2 ("protect the radars", 90 s) sits at 01:30 until it expires.
--* This is the only ported objective that sets Timer = <number> (E05 uses nil).
--*
--* The tick body is deliberately a GLOBAL function taking plain values: FA
--* serialises running sim threads into saves, and a named global entry point
--* with no upvalues is what the save format can resolve again on load.
--*****************************************************************************
-- Objectives resolves through this module's env to the SimObjectives module
-- table (set at the top of ScenarioFramework.lua). _G has no `Objectives`.
local okObjectives, objectivesModule = pcall(function() return Objectives end)
local SC_objectives = (okObjectives and objectivesModule) or SC_getGlobal('Objectives')
local SC_baseProtect = SC_objectives and SC_objectives.Protect
local SC_updateObjective = SC_objectives and SC_objectives.UpdateObjective

-- The thread body must not depend on upvalues, so hand it the update function
-- through _G instead of closing over SC_updateObjective. A NAMED function is
-- used on purpose: FA's save format resolves running sim threads by name
-- (compare TriggerFile.TimerTriggerThread), and only globals can be named.
function SC_ObjectiveCountdownThread(tag, title, deadline)
    local update = rawget(_G, 'SC_Objective_UpdateObjective')
    if type(update) ~= 'function' then
        return
    end
    while true do
        local remain = math.floor(deadline - GetGameTimeSeconds())
        if remain < 0 then remain = 0 end
        update(title, 'timer', {Time = remain}, tag)
        if remain <= 0 then
            break
        end
        WaitSeconds(1)
    end
end

SC_exportGlobal('SC_ObjectiveCountdownThread', SC_ObjectiveCountdownThread)

SC_exportGlobal('SC_Objective_UpdateObjective', SC_updateObjective)

if type(SC_baseProtect) == 'function' then
    -- Writes a field into the SimObjectives module table, shadowing the base
    -- function for every `Objectives.Protect` reader (map scripts included).
    SC_objectives.Protect = function(Type, Complete, Title, Description, Target)
        local objective = SC_baseProtect(Type, Complete, Title, Description, Target)
        if Target and Target.Timer and not Target.TimerHidden and Type ~= 'bonus'
            and objective and objective.Tag and objective.Tag ~= 'Invalid' then
            local seconds = tonumber(Target.Timer)
            local thread = rawget(_G, 'SC_ObjectiveCountdownThread')
            if seconds and seconds > 0 and thread then
                LOG('[SC Campaign] objective countdown armed: tag=' .. tostring(objective.Tag) ..
                    ' seconds=' .. tostring(seconds))
                ForkThread(thread, objective.Tag, Title, GetGameTimeSeconds() + seconds)
            end
        end
        return objective
    end
    LOG('[SC Campaign] Objectives.Protect countdown tick installed')
else
    LOG('[SC Campaign] Objectives.Protect not found; countdown tick NOT installed')
end

--*****************************************************************************
--* 5) E05 final objective: "get the ACU back through the quantum gate"
--*
--* E05 builds M3P3 with
--*   Objectives.CategoriesInArea(..., Requirements = {
--*       { Area = 'CDR_Gate_Area', Category = categories.uel0001, ... } })
--* and CDR_Gate_Area is only a 5x5 box (494.5,467.5)-(499.5,472.5) centred on
--* the gateway, whose own footprint is 7x7 (units/UEB0304). Parking the ACU
--* right in front of the gate can therefore still leave its centre outside the
--* box - the much smaller trucks of M3P2 use the same area and do fit. Result:
--* the objective sits at (0/1) forever even though the ACU is at the gate.
--*
--* Two safety nets, both keyed to E05 only:
--*   1) CategoriesInArea objectives watching CDR_Gate_Area get their unit
--*      filter widened from blueprint id uel0001 to categories.COMMAND, so a
--*      modded or replaced ACU can never be the reason the check fails.
--*   2) A mission-long watcher completes ScenarioInfo.M3P3 once the player's
--*      ACU is within SC_GATE_RADIUS of the gate. Watching ScenarioInfo rather
--*      than the creation call means this also works for saves made after M3P3
--*      already existed - the objective is restored there, not created again.
--* The watcher logs blueprint id and distance every 5 s while M3P3 is active,
--* so a future report can tell "wrong unit" from "just outside the box".
--*****************************************************************************
local SC_GATE_AREA   = 'CDR_Gate_Area'
local SC_E05_MAP     = 'SCCA_E05'
local SC_GATE_RADIUS = 15

-- Plain globals only (no upvalues) so FA can resolve the running thread again
-- after a save/load; everything it needs is passed in or read from _G.
function SC_GateGoalWatcher(mapName, radius)
    while true do
        local ok, scenarioInfo = pcall(function() return ScenarioInfo end)
        if ok and scenarioInfo and scenarioInfo.name then
            if scenarioInfo.name ~= mapName then
                return
            end
            local objective = scenarioInfo.M3P3
            if objective and not objective.Active then
                return                      -- already completed or failed
            end
            local acu = scenarioInfo.PlayerCDR
            local gate = scenarioInfo.Gate
            if objective and acu and not acu:IsDead() and gate and not gate:IsDead() then
                local apos = acu:GetPosition()
                local gpos = gate:GetPosition()
                local dx = apos[1] - gpos[1]
                local dz = apos[3] - gpos[3]
                local dist = math.sqrt(dx * dx + dz * dz)
                local now = GetGameTimeSeconds()
                if now - (objective.SC_gateLastLog or -100) >= 5 then
                    objective.SC_gateLastLog = now
                    LOG(string.format(
                        '[SC Campaign] gate watchdog: tag=%s bp=%s dist=%.1f isCommander=%s',
                        tostring(objective.Tag), tostring(acu:GetBlueprint().BlueprintId),
                        dist, tostring(EntityCategoryContains(categories.COMMAND, acu))))
                end
                if dist <= radius and not objective.SC_gateHandled then
                    objective.SC_gateHandled = true
                    LOG(string.format(
                        '[SC Campaign] gate watchdog: ACU at the gate (%.1f units), completing %s',
                        dist, tostring(objective.Tag)))
                    objective.Active = false
                    if type(objective.ManualResult) == 'function' then
                        objective:ManualResult(true)
                    else
                        -- Restored save without the closure: replay what
                        -- ManualResult/OnResult would have done.
                        if type(objective.OnResult) == 'function' then
                            objective:OnResult(true)
                        end
                        if objective.Title then
                            import('/lua/SimObjectives.lua').UpdateObjective(
                                objective.Title, 'complete', 'complete', objective.Tag)
                        end
                    end
                    return
                end
            end
        end
        WaitSeconds(2)
    end
end

SC_exportGlobal('SC_GateGoalWatcher', SC_GateGoalWatcher)

-- Widens the unit filter of the M3P3 style objective when it is created. The
-- completion itself is handled by SC_GateGoalWatcher, which also covers
-- objectives that already exist inside a save.
local SC_baseCategoriesInArea = SC_objectives and SC_objectives.CategoriesInArea

if type(SC_baseCategoriesInArea) == 'function' and not SC_baseCategoriesInArea.SC_gatePatched then
    local function SC_CategoriesInArea(Type, Complete, Title, Description, Action, Target)
        if Target and Target.Requirements then
            for _, requirement in Target.Requirements do
                if requirement.Area == SC_GATE_AREA then
                    requirement.Category = categories.COMMAND
                    LOG('[SC Campaign] gate objective armed: ' .. tostring(Title) ..
                        ' (unit filter widened to COMMAND)')
                end
            end
        end
        return SC_baseCategoriesInArea(Type, Complete, Title, Description, Action, Target)
    end
    SC_CategoriesInArea.SC_gatePatched = true
    SC_objectives.CategoriesInArea = SC_CategoriesInArea
    LOG('[SC Campaign] gate objective wrapper installed')
else
    LOG('[SC Campaign] gate objective wrapper NOT installed ' ..
        '(CategoriesInArea missing or already patched)')
end

-- The watcher is armed twice on purpose: once when the sim state is created
-- (a mission started from the campaign menu) and once in OnPostLoad, which
-- schook's simInit.lua calls after a save has been restored. Should both
-- survive, they share objective.SC_gateLastLog / .SC_gateHandled and only one
-- of them can complete the objective.
local function SC_startGateWatcher()
    ForkThread(SC_GateGoalWatcher, SC_E05_MAP, SC_GATE_RADIUS)
end

SC_startGateWatcher()
LOG('[SC Campaign] gate goal watcher armed (map=' .. SC_E05_MAP ..
    ', radius=' .. tostring(SC_GATE_RADIUS) .. ')')

--*****************************************************************************
--* 6) E05 M1P2 "Deploy Two Strategic Missile Defenses" can never complete once
--*    mission 1 is over
--*****************************************************************************
--* MissileDefenseCreated() (SCCA_E05_script.lua:754) gates completion on
--*     ScenarioInfo.AntiNukeNumber >= 2
--*     and not ScenarioInfo.MissionFailed
--*     and ScenarioInfo.MissionNumber == 1
--*     and not ScenarioInfo.AntiNukesBuilt
--* but EndMission1() (:1063) only waits for AeonNukesDestroyed and M1P3 and
--* never closes M1P2. A player who finishes mission 1 without having parked two
--* SMDs in the marked areas is therefore left with a live objective whose
--* completion test is permanently false: the counter keeps climbing (2/2, then
--* 3/2 - it is capped at 3) and the objective never flips. M1P2Reminder keeps
--* nagging on top of that, because it only watches AntiNukesBuilt.
--*
--* The map script is not touched (a save would keep running its compiled copy
--* anyway), so - same shape as the gate watcher above - a small sim-side watcher
--* completes the objective once the requirement is genuinely met. It can only
--* act where the map script's own check refused: during a normal mission 1 the
--* SiloAmmoThread (0.5 s poll) gets there first and this watcher just sees
--* Active = false and exits.
--*
--* Deliberately NOT replayed here: CallAeonTripleNukeAttack() and
--* VarTable['BuildAeonLandAssault']. Both belong to mission 1, which has already
--* handed over to mission 2 by the time this can fire; AntiNukesBuilt is set so
--* the reminder thread stops.
function SC_MissileDefenseWatcher()
    while true do
        local ok, scenarioInfo = pcall(function() return ScenarioInfo end)
        if ok and scenarioInfo and scenarioInfo.name then
            if scenarioInfo.name ~= SC_E05_MAP then
                return
            end
            local objective = scenarioInfo.M1P2
            local built = scenarioInfo.AntiNukeNumber
            if objective and type(built) == 'number' and built >= 2 then
                if not objective.Active then
                    return                  -- the map script got there first
                end
                LOG(string.format(
                    '[SC Campaign] SMD objective: %d built but still open ' ..
                    '(mission=%s, failed=%s) - completing it',
                    built, tostring(scenarioInfo.MissionNumber),
                    tostring(scenarioInfo.MissionFailed)))
                scenarioInfo.AntiNukesBuilt = true
                if type(objective.ManualResult) == 'function' then
                    objective:ManualResult(true)
                else
                    if type(objective.OnResult) == 'function' then
                        objective:OnResult(true)
                    end
                    if objective.Title then
                        import('/lua/SimObjectives.lua').UpdateObjective(
                            objective.Title, 'complete', 'complete', objective.Tag)
                    end
                end
                return
            end
        end
        WaitSeconds(2)
    end
end

SC_exportGlobal('SC_MissileDefenseWatcher', SC_MissileDefenseWatcher)

local function SC_startMissileWatcher()
    ForkThread(SC_MissileDefenseWatcher)
end

SC_startMissileWatcher()
LOG('[SC Campaign] SMD objective watcher armed (map=' .. SC_E05_MAP .. ')')

if type(OnPostLoad) == 'function' and not OnPostLoad.SC_gatePatched then
    local SC_baseOnPostLoad = OnPostLoad
    function OnPostLoad()
        SC_baseOnPostLoad()
        SC_startGateWatcher()
        SC_startMissileWatcher()
        LOG('[SC Campaign] gate goal watcher re-armed after save load')
    end
    OnPostLoad.SC_gatePatched = true
end

--*****************************************************************************
--* 7) CreateTimerTrigger: SC's 3rd argument is displayBool, FA's is `name`
--*****************************************************************************
--* SC1: ScenarioFramework.CreateTimerTrigger(cb, seconds, displayBool)
--*      -> scenariotriggers.TimerTriggerThread rewrites Sync.ObjectiveTimer
--*         every second; UserSync.lua:321 -> timer.lua.SetTimer draws it.
--* FA : ScenarioFramework.CreateTimerTrigger(cb, seconds, name, displayBool,
--*                                          onTickFunc)
--*
--* Of 672 ported call sites, 669 pass only 2 args and are already fine.
--* Three pass `true` expecting an on-screen countdown:
--*     SCCA_A04_script.lua:786, SCCA_E02_script.lua:828, SCCA_R06_script.lua:912
--* In FA that `true` lands in `name`: no tick thread is created, no timer UI
--* appears, and the callback fires as cb(TriggerManager, true) rather than
--* cb(). Both games still ship the display path (timer.lua.SetTimer takes the
--* remaining seconds and hides the panel at 0), so translating the call into
--* FA's 5-argument form is enough.
--*
--* The call deliberately goes through the ORIGINAL CreateTimerTrigger: that
--* function owns the file-local `timerThread` which ResetUITimer() kills
--* (called at E02:1111 and R06:902/926). Spawning our own tick thread would
--* leave the countdown running after those maps reset it.
--*
--* The tick is a named global with no upvalues so FA's save format can resolve
--* the running thread again after a load.
function SC_TimerTickToUI(seconds)
    Sync.ObjectiveTimer = math.max(0, math.floor(seconds or 0))
end
SC_exportGlobal('SC_TimerTickToUI', SC_TimerTickToUI)

local SC_baseCreateTimerTrigger = CreateTimerTrigger
if type(SC_baseCreateTimerTrigger) == 'function' then
    function CreateTimerTrigger(callback, seconds, nameOrDisplay, doOnTickSecond, onTickSecond)
        if type(nameOrDisplay) == 'boolean' then
            if nameOrDisplay then
                return SC_baseCreateTimerTrigger(callback, seconds, nil, true,
                                                 SC_TimerTickToUI)
            end
            return SC_baseCreateTimerTrigger(callback, seconds, nil)
        end
        return SC_baseCreateTimerTrigger(callback, seconds, nameOrDisplay,
                                        doOnTickSecond, onTickSecond)
    end
    LOG('[SC Campaign] CreateTimerTrigger displayBool shim installed')
else
    LOG('[SC Campaign] CreateTimerTrigger shim skipped (base function missing)')
end

end
