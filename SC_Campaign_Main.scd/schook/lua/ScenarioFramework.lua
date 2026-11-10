--*****************************************************************************
--* File: schook/lua/ScenarioFramework.lua
--* Style: Sorian AI Pack hook convention (self-contained do ... end block,
--*        executed after the original /lua/ScenarioFramework.lua chunk).
--*
--* Fourteen jobs:
--*   1) EndOperation() signature shim: SC scripts pass 7 args, FA passes 3.
--*   2) Re-add PatrolLocationFactoriesAI (removed in FA).
--*   3) Provide CDROverchargeBehavior (SC-only global, removed in FA).
--*   4) Drive the "Timer = n" objective countdown (FA's Protect forgot onTick).
--*   5) E05: complete the quantum-gate objective when the ACU reaches the gate.
--*   6) E05: complete the SMD objective when it is met after mission 1 ended.
--*   7) Translate SC's CreateTimerTrigger(cb, seconds, displayBool) to FA's
--*      5-argument form so the three on-screen countdowns still draw.
--*   8) Repair FA's broken CreateUnitNearTypeTrigger thread (references an
--*      undefined `catUnit`), which all five campaign near-type triggers use.
--*   9) R02 (Cybran op 2): complete the gate-evacuation objective when the ACU
--*      reaches M3Gate, independently of that trigger.
--*  10) Widen SC1's blueprint-id ACU categories in CreateAreaTrigger to
--*      categories.COMMAND (R05 Hex5 / R06 LeftGate).
--*  11) R05 (Cybran op 5): complete "Reach Hex5 with Your Commander" when the
--*      ACU stands in M2_Hex5Area, covering lost/never-armed area triggers.
--*  12) Campaign-wide fix for the same class of bug: alias every ACU
--*      blueprint id in `categories` to categories.COMMAND and add API-level
--*      fallbacks, so ALL decision entry points (including composite category
--*      expressions and old saves) accept a modded commander. Exact plot-unit
--*      ids - trucks, gates, components - are deliberately NOT widened.
--*  13) A02 (Aeon op 2): "Cleanse New Catalon" depends on a death-counter that
--*      FA's reworked unit callbacks can silently stop feeding. Recompute the
--*      city's real survivors, close M1P1, replay the mission-1 handover when a
--*      lost dialogue/result callback strands the operation, and guard that
--*      handover so it can only ever run ONCE. Both this watchdog and the map's
--*      own 900/600s M1AttackPlayer -> EndMission1 VO callback can reach
--*      BeginMission2; without the guard mission 2 is spawned twice.
--*  14) A05 (Aeon op 5): M2CheckObjectives() is the callback of TWO separate
--*      dialogues (3rd artillery destroyed, UEF commander Blake killed) and
--*      has no once-only guard. Once both are done, both VO callbacks fire
--*      ForkThread(EndMission2), so the M2 outro NIS, StartMission3() and the
--*      whole M3 opening play twice. Guard the M1->M2 and M2->M3 handovers.
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
    -- SC1 passes the opKey string first; FA's own form starts with a boolean
    -- `success` and has four arguments, the last of which (allBonus) may be
    -- `false`. Testing `d ~= nil` mistakes that legitimate FA call for the SC1
    -- 7-argument form. Discriminate by the TYPE of the first argument: all 61
    -- campaign call sites pass a 'SCCA_...' string, FA's own callers a boolean.
    if type(a) == 'string' then
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
        -- FA's EndOperation(success, allPrimary, allSecondary, allBonus) is
        -- 4-argument; forward all four so allBonus is not silently dropped.
        baseEndOperation(a, b, c, d)
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
        -- Defined in sections 9/11 below and exported to _G, so look them up
        -- safely at call time rather than through forward local references.
        local evacWatcher = SC_getGlobal('SC_R02EvacWatcher')
        if type(evacWatcher) == 'function' then
            ForkThread(evacWatcher)
        end
        local hex5Watcher = SC_getGlobal('SC_Hex5Watcher')
        if type(hex5Watcher) == 'function' then
            ForkThread(hex5Watcher)
        end
        local a02Watcher = SC_getGlobal('SC_A02CityWatcher')
        if type(a02Watcher) == 'function' then
            ForkThread(a02Watcher)
        end
        -- Section 14 was added later; without this the A05 handover guards are
        -- lost when a same-process save load lands on A05 after the startup
        -- watcher already exited on another operation's map name.
        local a05Watcher = SC_getGlobal('SC_A05HandoverWatcher')
        if type(a05Watcher) == 'function' then
            ForkThread(a05Watcher)
        end
        LOG('[SC Campaign] campaign watchers re-armed after save load')
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

--*****************************************************************************
--* 8) CreateUnitNearTypeTrigger: FA's thread body still reads `catUnit`
--*****************************************************************************
--* fa/lua/scenariotriggers.lua:415 rewrote SC1's
--*     for k, catUnit in brain:GetListOfUnits(category, false) do
--* into
--*     for _, triggerUnit in brain:GetListOfUnits(category, false) do
--* but left the distance test as
--*     VDist3(position, catUnit:GetPosition()) < distance
--* `catUnit` no longer exists. Under FA's strict _G guard that read throws
--* "access to nonexistent global variable catUnit" and kills the trigger
--* thread the moment the category list is non-empty; if the list is empty it
--* simply never fires. SC1's original loop is correct.
--*
--* Five campaign call sites use this API:
--*     SCCA_R02:2284  ACU near the evacuation gate
--*     SCCA_R06:886, 899, 930  gate near the ACU (QAI upload)
--*     SCCA_R06:1081  any unit near the Atlantis
--* Replace the thread with a faithful SC1 implementation and point BOTH
--* entry paths at it - ScenarioFramework.CreateUnitNearTypeTrigger (what the
--* map scripts call) and TriggerFile.CreateUnitNearTypeTriggerThread (what
--* TriggerManager.lua:677 restores from a save).
--*
--* Named global with no upvalues: FA resolves running sim threads by name
--* when a save is restored.
function SC_UnitNearTypeTriggerThread(callback, unit, brain, category, distance, name)
    local reportedEmpty = false
    while true do
        if unit == nil or brain == nil then
            return
        end
        local dead = false
        if unit.Dead then
            dead = true
        elseif type(unit.IsDead) == 'function' then
            local okDead, isDead = pcall(function() return unit:IsDead() end)
            if okDead and isDead then
                dead = true
            end
        end
        if dead then
            return
        end

        local okPos, position = pcall(function() return unit:GetPosition() end)
        local okList, units = pcall(function()
            return brain:GetListOfUnits(category, false)
        end)
        if okPos and position and okList and units then
            local count = 0
            for _, triggerUnit in units do
                count = count + 1
                local okHit, hit = pcall(function()
                    local other = triggerUnit:GetPosition()
                    return VDist3(position, other) < distance
                           and not triggerUnit:IsBeingBuilt()
                end)
                if okHit and hit then
                    LOG(string.format(
                        '[SC Campaign] near-type trigger fired (candidates=%d, distance=%s)',
                        count, tostring(distance)))
                    local okCb, cbErr = pcall(function()
                        -- Match SC1's documented named-callback signature
                        -- exactly: (TriggerManager, name, unit, triggerUnit).
                        if name then
                            callback(TriggerManager, name, unit, triggerUnit)
                        else
                            callback(unit, triggerUnit)
                        end
                    end)
                    if not okCb then
                        LOG('[SC Campaign] near-type trigger callback failed: ' ..
                            tostring(cbErr))
                    end
                    return
                end
            end
            if count == 0 and not reportedEmpty then
                reportedEmpty = true
                LOG(string.format(
                    '[SC Campaign] near-type trigger: category=%s matched 0 units ' ..
                    '(SC blueprint-id categories may not resolve in FA)',
                    tostring(category)))
            end
        end
        WaitSeconds(0.5)
    end
end

SC_exportGlobal('SC_UnitNearTypeTriggerThread', SC_UnitNearTypeTriggerThread)
-- A save taken before this fix records the OLD thread name. On restore FA
-- resolves running sim threads by name, so make that name point at the fixed
-- implementation too (the module-table assignment below covers the other
-- lookup path).
SC_exportGlobal('CreateUnitNearTypeTriggerThread', SC_UnitNearTypeTriggerThread)

local SC_baseUnitNearTypeTrigger = CreateUnitNearTypeTrigger
if type(SC_baseUnitNearTypeTrigger) == 'function' then
    function CreateUnitNearTypeTrigger(callback, unit, brain, category, distance, name)
        return ForkThread(SC_UnitNearTypeTriggerThread, callback, unit, brain,
                          category, distance, name)
    end
    LOG('[SC Campaign] CreateUnitNearTypeTrigger thread repaired (FA catUnit typo)')
else
    LOG('[SC Campaign] CreateUnitNearTypeTrigger repair skipped (base missing)')
end

local okTriggers, SC_triggerFile = pcall(function()
    return import('/lua/scenariotriggers.lua')
end)
if okTriggers and type(SC_triggerFile) == 'table' then
    SC_triggerFile.CreateUnitNearTypeTriggerThread = SC_UnitNearTypeTriggerThread
    LOG('[SC Campaign] TriggerManager near-type thread repaired')
else
    LOG('[SC Campaign] TriggerManager near-type thread NOT repaired')
end

--*****************************************************************************
--* 9) R02 (Cybran operation 2): "Move Your Commander to the Gate" never fires
--*****************************************************************************
--* M3P1Complete() (SCCA_R02_script.lua:2281) creates M3P2 as a plain Basic
--* objective and arms a single proximity trigger:
--*     CreateUnitNearTypeTrigger(M3PlayerReachedGate, ScenarioInfo.M3Gate,
--*         ArmyBrains[Player], categories.url0001, 2)
--* Two confirmed reasons why that trigger cannot complete the mission in FA:
--*   a) the FA thread bug repaired in section 8 references an undefined
--*      `catUnit`, so it dies as soon as the category list is non-empty; a
--*      save load drops the thread entirely;
--*   b) distance 2 is smaller than the 7x7 footprint of the uab0304 gate the
--*      ACU must walk up to, so even a matching ACU stays outside it.
--* If the SC1 blueprint-id category also fails to resolve, the thread simply
--* never sees a candidate - section 8 logs that case as "matched 0 units".
--*
--* Rather than patch the map script (a save keeps its compiled copy), watch
--* ScenarioInfo for the objective / gate / ACU and fire the map's own
--* M3PlayerReachedGate() handler once the ACU is genuinely at the gate. That
--* handler replays the teleport NIS, the dialogue and M3Complete() -> WinGame.
--* The map script is loaded with doscript(ScenarioInfo.script, ScenarioInfo.Env)
--* (fa/lua/simInit.lua:221), so its "globals" are FIELDS OF ScenarioInfo.Env,
--* not of _G. Reading M3PlayerReachedGate from _G hits FA's strict-global
--* guard and fails - exactly what the 19:35 log showed ("map handler
--* unreachable"). Never import() the map script here: it is not in the module
--* cache, so that would execute the whole chunk again and reset MissionNumber
--* plus every M1/M2 progress flag.
local function SC_MapFunction(name)
    local okEnv, env = pcall(function() return ScenarioInfo.Env end)
    if okEnv and type(env) == 'table' then
        local fn = rawget(env, name)
        if type(fn) == 'function' then
            return fn
        end
    end
    -- fa/lua/simInit.lua:128 sets ScenarioInfo.Env to exactly this module
    -- table:  ScenarioInfo.Env = import("/lua/scenarioenvironment.lua")
    -- (the file on disk is camel-cased scenarioEnvironment.lua; Windows is
    -- case-insensitive). Reaching it by import() covers the window before
    -- ScenarioInfo.Env has been assigned.
    local okMod, mod = pcall(function()
        return import('/lua/scenarioenvironment.lua')
    end)
    if okMod and type(mod) == 'table' then
        local fn = rawget(mod, name)
        if type(fn) == 'function' then
            return fn
        end
    end
    -- rawget avoids the strict-global __index guard on _G.
    local fn = rawget(_G, name)
    if type(fn) == 'function' then
        return fn
    end
    return nil
end

local SC_R02_MAP          = 'SCCA_R02'
local SC_R02_GATE_RADIUS  = 12

function SC_R02EvacWatcher()
    while true do
        -- ScenarioInfo is populated from _scenario.lua by BeginSession(), which
        -- runs AFTER this schook is imported. A nil table means "too early",
        -- not "wrong map" - keep polling instead of killing the thread.
        local ok, si = pcall(function() return ScenarioInfo end)
        if ok and si and si.name
           and string.lower(tostring(si.name)) ~= string.lower(SC_R02_MAP) then
            return
        end
        if ok and si then
            local objective = si.M3P2
            local gate      = si.M3Gate
            local acu       = si.PlayerCDR
            if objective and gate and acu and objective.Active ~= false
               and not objective.SC_evacHandled then
                local okState, apos, gpos = pcall(function()
                    return acu:GetPosition(), gate:GetPosition()
                end)
                if okState and apos and gpos then
                    local dx = apos[1] - gpos[1]
                    local dz = apos[3] - gpos[3]
                    local dist = math.sqrt(dx * dx + dz * dz)
                    local now = GetGameTimeSeconds()
                    if now - (objective.SC_evacLastLog or -100) >= 5 then
                        objective.SC_evacLastLog = now
                        LOG(string.format(
                            '[SC Campaign] R02 evac watchdog: bp=%s dist=%.1f tag=%s',
                            tostring(acu:GetBlueprint().BlueprintId), dist,
                            tostring(objective.Tag)))
                    end
                    if dist <= SC_R02_GATE_RADIUS then
                        objective.SC_evacHandled = true
                        LOG(string.format(
                            '[SC Campaign] R02 evac watchdog: ACU at the gate (%.1f units), ' ..
                            'completing M3P2', dist))
                        local called = false
                        local mapFn = SC_MapFunction('M3PlayerReachedGate')
                        if mapFn then
                            local okCall, err = pcall(mapFn)
                            if okCall then
                                called = true
                            else
                                LOG('[SC Campaign] R02 map handler failed: ' .. tostring(err))
                            end
                        end
                        if not called then
                            -- Replay M3PlayerReachedGate() from SCCA_R02_script.lua:2321.
                            -- Do NOT import() the map script: the engine loaded
                            -- it with doscript, so import() would execute the
                            -- chunk a second time and reset all progress flags.
                            LOG('[SC Campaign] R02 map handler unreachable - ' ..
                                'replaying the evacuation sequence')
                            objective.Active = false
                            if type(objective.ManualResult) == 'function' then
                                pcall(function() objective:ManualResult(true) end)
                            end
                            pcall(function() FakeTeleportUnit(acu, true) end)
                            pcall(function() CDRDeathNISCamera(acu) end)
                            pcall(function()
                                for _, tech in pairs(si.M3Techs or {}) do
                                    FakeTeleportUnit(tech, true)
                                end
                            end)
                            local complete = SC_MapFunction('M3Complete')
                            if complete then
                                ForkThread(complete)
                            else
                                LOG('[SC Campaign] R02 M3Complete unreachable - ' ..
                                    'ending the operation directly')
                                pcall(function()
                                    local difficulty = 2
                                    if si.Options and si.Options.Difficulty then
                                        difficulty = si.Options.Difficulty
                                    end
                                    local secondary = false
                                    if si.M3S1 then
                                        local okSec, sec = pcall(function()
                                            return import('/lua/SimObjectives.lua').IsComplete(si.M3S1)
                                        end)
                                        if okSec and sec then
                                            secondary = true
                                        end
                                    end
                                    EndOperation(SC_R02_MAP, true, difficulty, true, secondary)
                                end)
                            end
                        end
                        return
                    end
                end
            end
        end
        WaitSeconds(2)
    end
end

SC_exportGlobal('SC_R02EvacWatcher', SC_R02EvacWatcher)

ForkThread(SC_R02EvacWatcher)
LOG('[SC Campaign] R02 evac watchdog armed (map=' .. SC_R02_MAP ..
    ', radius=' .. tostring(SC_R02_GATE_RADIUS) .. ')')

--*****************************************************************************
--* 10) SC1 blueprint-id ACU categories in CreateAreaTrigger
--*****************************************************************************
--* Every SC1 campaign script identifies "the player's ACU" as
--* categories.url0001 / uel0001 / ual0001. FA unit blueprints never list their
--* own blueprint id in Categories (URL0001_unit.bp lists COMMAND and CYBRAN,
--* not url0001), and modded installs can swap the ACU for another blueprint
--* entirely - this install logs `bp=erl0001` for the player commander. Either
--* way the area trigger matches zero units and the objective never completes.
--*
--* Only five call sites in the whole campaign use these ids. E05:2115 and
--* R02:2284 are handled by sections 5 and 9; the two remaining ones both go
--* through CreateAreaTrigger:
--*     SCCA_R05:764  ACU enters M2_Hex5Area -> M2_DownloadToCommander
--*     SCCA_R06:911  ACU leaves the gate area -> LeftGate
--* Widen just that single-id mask to categories.COMMAND. Both call sites also
--* pass aiBrain, so enemy commanders are still filtered out. Composite
--* expressions (categories.AIR + categories.MOBILE, ...) never hit the table
--* lookup and are left untouched.
--*
--* NOTE: section 12 supersedes this as the campaign-wide fix. EntityCategory
--* values are rebuilt on every lookup, so the `category == mask` test below
--* never actually matched on this install (no "widened to COMMAND" log line).
--* Section 12 aliases the ids inside `categories` itself, which covers this
--* API plus GetListOfUnits / EntityCategoryContains / composite expressions /
--* Objective Requirements, and keeps this wrapper as a harmless fallback.
local SC_ACU_ID_CATEGORIES = {
    'url0001', 'uel0001', 'ual0001',
    -- replacement / enhanced ACUs shipped by common mods
    'erl0001', 'eel0001', 'eal0001',
}
local SC_acuMaskToCommand = {}
local SC_commandMask = nil
do
    local okCmd, cmd = pcall(function() return categories.COMMAND end)
    if okCmd and cmd then
        SC_commandMask = cmd
        for _, id in SC_ACU_ID_CATEGORIES do
            local okId, mask = pcall(function() return categories[id] end)
            if okId and mask then
                SC_acuMaskToCommand[mask] = id
            end
        end
    end
end

local SC_areaCategoryLogged = false
local SC_baseCreateAreaTrigger = CreateAreaTrigger
if type(SC_baseCreateAreaTrigger) == 'function' and SC_commandMask then
    function CreateAreaTrigger(callback, area, category, onceOnly, lessThan,
                               aiBrain, unitCount, requireBuilt, name)
        local alias = nil
        if category then
            -- Compare explicitly instead of using the mask as a table key:
            -- EntityCategory may be a value object with an __eq metamethod.
            for mask, id in pairs(SC_acuMaskToCommand) do
                if category == mask then
                    alias = id
                    break
                end
            end
        end
        if alias then
            if not SC_areaCategoryLogged then
                SC_areaCategoryLogged = true
                LOG('[SC Campaign] area trigger: ' .. alias ..
                    ' widened to COMMAND (SC blueprint-id category)')
            end
            category = SC_commandMask
        end
        return SC_baseCreateAreaTrigger(callback, area, category, onceOnly,
                                        lessThan, aiBrain, unitCount,
                                        requireBuilt, name)
    end
    LOG('[SC Campaign] CreateAreaTrigger ACU category shim installed')
else
    LOG('[SC Campaign] CreateAreaTrigger ACU category shim skipped')
end

--*****************************************************************************
--* 11) R05 (Cybran operation 5): "Reach Hex5 with Your Commander"
--*****************************************************************************
--* M2P1Complete() -> M2_Hex5Appears() creates M2P2 and forks
--* M2_Hex5UnloadCheckThread(). That thread waits for the transport unload
--* command, then arms ONE area trigger (SCCA_R05_script.lua:764) using
--* categories.url0001. Three things can stop it from ever firing:
--*   a) the player ACU is not url0001 on this install (log: bp=erl0001);
--*   b) the unload thread can stall, or be dropped on a save load, so the
--*      trigger is never armed at all;
--*   c) the trigger itself is a sim thread, also lost on save load.
--*
--* Section 10 fixes (a) for freshly armed triggers. This watcher covers (b)
--* and (c) and also works on saves made before the fix: it checks the ACU
--* position against the original M2_Hex5Area rectangle from
--* SCCA_R05_save.lua:60 = RECTANGLE(346.5, 307.5, 384.5, 341.5).
--* A 12-second grace period lets the map's own trigger win the race -
--* M2_DownloadToCommanderThread waits 3s + 5s before ManualResult(true) -
--* so we never replay the download NIS twice.
local SC_R05_MAP     = 'SCCA_R05'
local SC_HEX5_RECT   = { 346.5, 307.5, 384.5, 341.5 }
local SC_HEX5_GRACE  = 12

function SC_Hex5Watcher()
    local insideSince = nil
    while true do
        local ok, si = pcall(function() return ScenarioInfo end)
        if ok and si and si.name
           and string.lower(tostring(si.name)) ~= string.lower(SC_R05_MAP) then
            return
        end
        if ok and si then
            local objective = si.M2P2
            local acu       = si.PlayerCommander
            if objective and acu and not objective.SC_hex5Handled
               and objective.Active ~= false then
                local okPos, pos = pcall(function() return acu:GetPosition() end)
                if okPos and pos then
                    local inside = pos[1] >= SC_HEX5_RECT[1]
                               and pos[1] <= SC_HEX5_RECT[3]
                               and pos[3] >= SC_HEX5_RECT[2]
                               and pos[3] <= SC_HEX5_RECT[4]
                    local now = GetGameTimeSeconds()
                    if now - (objective.SC_hex5LastLog or -100) >= 5 then
                        objective.SC_hex5LastLog = now
                        LOG(string.format(
                            '[SC Campaign] R05 Hex5 watchdog: bp=%s pos=(%.1f,%.1f) inside=%s',
                            tostring(acu:GetBlueprint().BlueprintId),
                            pos[1], pos[3], tostring(inside)))
                    end
                    if inside then
                        if not insideSince then
                            insideSince = now
                        elseif now - insideSince >= SC_HEX5_GRACE then
                            objective.SC_hex5Handled = true
                            LOG(string.format(
                                '[SC Campaign] R05 Hex5 watchdog: ACU in M2_Hex5Area for %.0fs, ' ..
                                'completing M2P2', now - insideSince))
                            local mapFn = SC_MapFunction('M2_DownloadToCommander')
                            if mapFn then
                                local okCall, err = pcall(mapFn)
                                if not okCall then
                                    LOG('[SC Campaign] R05 map handler failed: ' ..
                                        tostring(err))
                                    pcall(function() objective:ManualResult(true) end)
                                end
                            else
                                LOG('[SC Campaign] R05 map handler unreachable - ' ..
                                    'completing M2P2 directly')
                                pcall(function() objective:ManualResult(true) end)
                            end
                            -- M2_DownloadToCommanderThread waits 8s before it
                            -- calls ManualResult(true). If it died on the way
                            -- (NIS error, dropped thread), close the objective
                            -- ourselves rather than leaving it stuck forever.
                            WaitSeconds(20)
                            if objective.Active ~= false then
                                LOG('[SC Campaign] R05 M2P2 still open after the ' ..
                                    'map handler - completing it directly')
                                objective.Active = false
                                pcall(function() objective:ManualResult(true) end)
                            end
                            return
                        end
                    else
                        insideSince = nil
                    end
                end
            end
        end
        WaitSeconds(2)
    end
end

SC_exportGlobal('SC_Hex5Watcher', SC_Hex5Watcher)

ForkThread(SC_Hex5Watcher)
LOG('[SC Campaign] R05 Hex5 watchdog armed (map=' .. SC_R05_MAP ..
    ', grace=' .. tostring(SC_HEX5_GRACE) .. 's)')

--*****************************************************************************
--* 12) Campaign-wide: widen every "fixed blueprint id" ACU decision to a type
--*     check, leaving exact plot units alone
--*****************************************************************************
--* Full-campaign audit (tools + reports live in the game root _work/ folder):
--*   246 map lua files scanned, 772 `categories.<blueprint-id>` uses,
--*   219 distinct ids, and EVERY ONE of those ids has a matching unit
--*   blueprint in this install (fa/units + mods/*/units). So the trucks
--*   (uec0001), the E06 Black Sun component (ope6003), R06's quantum gates
--*   (urb0304), the Czar (uaa0310), artillery, factories ... all still
--*   resolve. Those are EXACT plot units: widening them to a type would let
--*   any unit satisfy a story-specific condition. They stay untouched.
--*
--* The only id-based decisions that actually break are the 5 ACU ones:
--*     SCCA_E05:2115  Objectives.CategoriesInArea  Requirements[1].Category
--*     SCCA_R02:2284  CreateUnitNearTypeTrigger
--*     SCCA_R02:2341  exclusion list (categories.ENGINEER + ... + ual0001)
--*     SCCA_R05:764   CreateAreaTrigger
--*     SCCA_R06:911   CreateAreaTrigger
--* This install swaps the player commander for a BlackOps ACU (game log:
--* E05 bp=eel0001, R05 bp=erl0001) while the scripts were compiled against
--* uel0001 / ual0001 / url0001. `categories.COMMAND` matches exactly the 8
--* COMMAND blueprints present here (3 SC1 ACUs, 4 BlackOps ACUs, 1 Seraphim
--* ACU) and NOTHING else - no SCU, no engineer - so it is a precise type-level
--* replacement, not a blanket "any unit" widening.
--*
--* Section 10 wrapped only CreateAreaTrigger and compared masks with `==`.
--* EntityCategory values are re-created on each lookup, so that comparison
--* never matched (no "widened to COMMAND" line ever appeared in any log).
--*
--* Fix: alias the ACU ids INSIDE `categories` with rawset(). `categories.<id>`
--* is a runtime table lookup - compiled map bytecode stores only the string
--* key - so this repairs saves made long before the fix too, and it reaches
--* entry points no wrapper can see: ArmyBrains[x]:GetListOfUnits(),
--* EntityCategoryContains(), composite +/-/* expressions (R02:2341), and
--* Requirements tables nested inside SimObjectives.
--*
--* Side effect, checked explicitly: no file under fa/lua uses these ids
--* (0 hits). The only external reader is M28AI's SteamCompatibility.lua:171-172,
--* which adds the four stock ACU ids to its "amphibious" reference category;
--* through the alias it now also picks up the four mod/Seraphim ACUs. All of
--* them are amphibious commanders anyway.
--*****************************************************************************
local SC_ACU_TYPE_IDS = {
    'uel0001', 'ual0001', 'url0001',                 -- SC1 stock ACUs (used by the scripts)
    'eel0001', 'eal0001', 'erl0001', 'esl0001',     -- BlackOpsACUs replacements
    'xsl0001',                                      -- FA Seraphim ACU
}

-- Reuse the COMMAND mask resolved in section 10 when available.
local SC_cmdMask = SC_commandMask
if not SC_cmdMask then
    local okCmd2, cmd2 = pcall(function() return categories.COMMAND end)
    if okCmd2 then
        SC_cmdMask = cmd2
    end
end

-- Save the ORIGINAL single-id masks before aliasing, so the API-level
-- fallback below can still recognise them on installs where rawset() on
-- `categories` is impossible (e.g. it is engine userdata).
local SC_originalACUMasks = {}
if SC_cmdMask then
    for _, id in SC_ACU_TYPE_IDS do
        local okMask, mask = pcall(function() return categories[id] end)
        if okMask and mask ~= nil then
            SC_originalACUMasks[id] = mask
        end
    end
end

local SC_aliasCount = 0
local SC_aliasFailures = {}
if SC_cmdMask then
    for _, id in SC_ACU_TYPE_IDS do
        local okWrite, writeErr = pcall(function()
            rawset(categories, id, SC_cmdMask)
        end)
        if okWrite then
            -- Verify by reading back: a protected / cached categories table
            -- could silently ignore rawset, and we must not claim success.
            local okRead, got = pcall(function() return categories[id] end)
            if okRead and got ~= nil
               and (got == SC_cmdMask or tostring(got) == tostring(SC_cmdMask)) then
                SC_aliasCount = SC_aliasCount + 1
            else
                table.insert(SC_aliasFailures, id .. ' (verify failed)')
            end
        else
            table.insert(SC_aliasFailures, id .. ' (' .. tostring(writeErr) .. ')')
        end
    end
end

-- NOTE: '#' starts a line comment in the moho Lua dialect, so use
-- table.getn() instead of the Lua 5.1 '#' length operator here.
LOG(string.format(
    '[SC Campaign] ACU blueprint-id aliases: %d/%d -> categories.COMMAND ' ..
    '(216 exact plot-unit ids untouched)',
    SC_aliasCount, table.getn(SC_ACU_TYPE_IDS)))
if table.getn(SC_aliasFailures) > 0 then
    LOG('[SC Campaign] ACU alias failures: ' ..
        table.concat(SC_aliasFailures, ', ') .. ' - using API wrappers instead')
end

-- Defence in depth / fallback, ACTIVE ONLY IF the categories aliasing above
-- did not fully succeed. When all 8 aliases verified, every `categories.<id>`
-- lookup already resolves to COMMAND and these wrappers must be a no-op:
-- comparing engine userdata with tostring() is unreliable (it either embeds an
-- address and never matches, or returns only a class name and would match EVERY
-- category). Keeping the fallback live on a healthy install risks rewriting
-- unrelated triggers to COMMAND. This is the release-safety guard (audit
-- 2026-11-11).
local SC_aliasesComplete = (SC_aliasCount == table.getn(SC_ACU_TYPE_IDS))
local SC_widenLogged = {}
local function SC_WidenCategory(category, where)
    if category == nil or SC_cmdMask == nil then
        return category
    end
    if SC_aliasesComplete then
        return category
    end
    for id, oldMask in pairs(SC_originalACUMasks) do
        if category == oldMask or tostring(category) == tostring(oldMask) then
            if not SC_widenLogged[where] then
                SC_widenLogged[where] = true
                LOG('[SC Campaign] ' .. where .. ': ' .. id ..
                    ' widened to COMMAND (SC blueprint-id category)')
            end
            return SC_cmdMask
        end
    end
    return category
end

-- Chain on top of the section 8 / 10 wrappers (they hold the older functions).
-- Only exact ACU id masks are replaced; composite expressions and every
-- non-ACU id pass straight through unchanged.
local SC_areaTrigger12 = CreateAreaTrigger
if type(SC_areaTrigger12) == 'function' then
    function CreateAreaTrigger(callback, area, category, onceOnly, lessThan,
                               aiBrain, unitCount, requireBuilt, name)
        return SC_areaTrigger12(callback, area,
            SC_WidenCategory(category, 'CreateAreaTrigger'), onceOnly, lessThan,
            aiBrain, unitCount, requireBuilt, name)
    end
end

local SC_nearTypeTrigger12 = CreateUnitNearTypeTrigger
if type(SC_nearTypeTrigger12) == 'function' then
    function CreateUnitNearTypeTrigger(callback, unit, brain, category, distance, name)
        return SC_nearTypeTrigger12(callback, unit, brain,
            SC_WidenCategory(category, 'CreateUnitNearTypeTrigger'),
            distance, name)
    end
end

-- Objectives.CategoriesInArea: Requirements[].Category (E05:2115). Widening
-- by category value, not by area name, covers any future ACU requirement too.
if type(SC_objectives) == 'table' then
    local SC_cia12 = SC_objectives.CategoriesInArea
    if type(SC_cia12) == 'function' then
        SC_objectives.CategoriesInArea = function(Type, Complete, Title,
                                                 Description, Action, Target)
            if Target and type(Target.Requirements) == 'table' then
                for _, req in pairs(Target.Requirements) do
                    if type(req) == 'table' and req.Category ~= nil then
                        req.Category = SC_WidenCategory(req.Category,
                                                        'CategoriesInArea')
                    end
                end
            end
            return SC_cia12(Type, Complete, Title, Description, Action, Target)
        end
        LOG('[SC Campaign] CategoriesInArea ACU requirement shim installed')
    end
end

LOG('[SC Campaign] ACU type widening active (categories aliases + API fallback)')

--*****************************************************************************
--* 13) A02 (Aeon operation 2): "Cleanse New Catalon" stalls once the city is gone
--*****************************************************************************
--* OnPopulate() spawns M1_City (33 civilian buildings) and counts deaths ONLY
--* through
--*     ScenarioFramework.CreateUnitDestroyedTrigger(M1CityBuildingDestroyed, unit)
--* M1CityBuildingDestroyed() decrements ScenarioInfo.M1CityBuildingsAlive and,
--* once alive < total * 0.2 (80% cleansed), sets M1P1Complete and calls
--* M1P1Objective:ManualResult(true). Nothing else ever re-checks the counter.
--*
--* SC1 -> FA drift on that chain:
--*   SC: AddOnReclaimedCallback / AddOnCapturedCallback / AddOnKilledCallback
--*   FA: unit:AddUnitCallback(cb, 'OnReclaimed' | 'OnCaptured' | 'OnKilled')
--* M28AI also wraps all three registrations. If any death is missed (reclaim,
--* a dropped thread on save load, a rebuilt callback table, ...), the counter
--* never reaches the threshold and the objective stays open even with every
--* building gone.
--*
--* Two more single-point failures sit behind it:
--*   EndMission1() is ONLY Dialogue(A02_M01_060, BeginMission2), so a lost VO
--*   callback strands the handover;
--*   M1P2Complete is ONLY set by M1AttackersDestroyed(), reached through
--*   AddResultCallback / OnResult(true) in M1AttackerTimeout(). If that result
--*   callback does not fire, mission 1 can never end.
--*
--* Fix: a mission-1 watcher that recomputes the city's REAL survivors from the
--* unit handles, closes M1P1 when the threshold is genuinely met, and - after
--* a grace period in which the map script can still advance on its own -
--* replays BeginMission2(). Saves are covered because the watcher is re-armed
--* from OnPostLoad(); handles that throw on access count as survivors
--* (conservative), with the map's own counter as a second, independent gate.
--*
--* Observed in game.log (2026-11-10): SetPlayableArea('M2_Playable_Area')
--* ran TWICE, ~170 log lines apart. The first came from this watchdog's
--* replay; the second was preceded by A02_Choir_M01_00805.sfd, i.e. the map's
--* own EndMission1 VO callback. M1AttackPlayer() (:369, 900/900/600s) has no
--* MissionNumber guard, so it can still fire after we have advanced, create
--* M1P2Objective, resolve it, and call EndMission1() -> BeginMission2() again.
--* That duplicates the M2 bases, M2 city, objectives and expansion NIS.
--*
--* Fix: wrap BeginMission2 / EndMission1 in ScenarioInfo.Env with a one-shot
--* guard. Both paths resolve those names against Env at CALL time, so this is
--* the single choke point that covers the watchdog, the VO callback and the
--* late timer. The guard is installed on the watcher's FIRST poll (not at
--* replay time) so a dialogue already in flight cannot capture the unguarded
--* function value. A save already in mission 2 (MissionNumber >= 2) starts
--* with the guard closed, which also protects existing saves on reload.
--*****************************************************************************
local SC_A02_MAP   = 'SCCA_A02'
local SC_A02_GOAL  = 0.2      -- survivors must be < 20%, i.e. 80% cleansed
local SC_A02_GRACE = 60       -- seconds for the map's own handover to run

-- Resolve ScenarioInfo freshly: a same-process save load can replace the table,
-- and a guard closure holding the old one would silently go stale.
local function SC_currentScenarioInfo(fallback)
    local ok, cur = pcall(function() return ScenarioInfo end)
    if ok and type(cur) == 'table' then
        return cur
    end
    return fallback
end

local function SC_a02M2AlreadyStarted(cur)
    return cur.SC_a02M2Started == true
        or (tonumber(cur.MissionNumber) or 1) >= 2
end

-- returns true when the guard is in place (already installed or just done)
local function SC_InstallA02M2Guard(si)
    if type(si) ~= 'table' then
        return false
    end
    if rawget(si, 'SC_a02M2GuardInstalled') then
        return true
    end

    -- fa/lua/simInit.lua assigns ScenarioInfo.Env = import(...) and runs the
    -- map chunk against it, so map functions normally live there, not in _G.
    -- Probe in the SAME order as SC_MapFunction() and wrap whichever table
    -- actually owns BeginMission2, otherwise the guard would sit on an empty
    -- table and silently do nothing.
    local env, source = nil, nil

    local siEnv = rawget(si, 'Env')
    if type(siEnv) == 'table'
       and type(rawget(siEnv, 'BeginMission2')) == 'function' then
        env, source = siEnv, 'ScenarioInfo.Env'
    end

    if not env then
        local okMod, mod = pcall(function()
            return import('/lua/scenarioenvironment.lua')
        end)
        if okMod and type(mod) == 'table'
           and type(rawget(mod, 'BeginMission2')) == 'function' then
            env, source = mod, 'scenarioenvironment module'
        end
    end

    if not env and type(rawget(_G, 'BeginMission2')) == 'function' then
        env, source = _G, '_G'
    end

    if not env then
        return false
    end

    local beginFn = rawget(env, 'BeginMission2')
    local endFn   = rawget(env, 'EndMission1')
    if type(beginFn) ~= 'function' then
        return false
    end

    -- Keep the ORIGINAL named function for our own ForkThread. Save restore
    -- resolves thread entry points by global name; replaying an anonymous
    -- upvalue-bearing wrapper would be unrecoverable after a load.
    si.SC_a02RawBeginMission2 = beginFn

    -- A save written by an older build can already be in mission 2 without
    -- ever having seen our flag. MissionNumber (set at A02 script :755) wins.
    if (tonumber(si.MissionNumber) or 1) >= 2 then
        si.SC_a02M2Started = true
    end

    -- Both map functions are declared with no parameters. moho's Lua dialect
    -- does not accept `...` vararg in this position, so forward explicitly.
    rawset(env, 'BeginMission2', function()
        local cur = SC_currentScenarioInfo(si)
        if SC_a02M2AlreadyStarted(cur) then
            LOG('[SC Campaign] A02: duplicate BeginMission2 suppressed')
            return
        end
        cur.SC_a02M2Started = true
        LOG('[SC Campaign] A02: BeginMission2 guard - first handover allowed')
        return beginFn()
    end)

    -- Also silence a late EndMission1(): it would replay the mission-1 VO in
    -- the middle of mission 2 and enqueue yet another BeginMission2 callback.
    if type(endFn) == 'function' then
        si.SC_a02RawEndMission1 = endFn
        rawset(env, 'EndMission1', function()
            local cur = SC_currentScenarioInfo(si)
            if SC_a02M2AlreadyStarted(cur) then
                LOG('[SC Campaign] A02: late EndMission1 suppressed')
                return
            end
            return endFn()
        end)
    end

    si.SC_a02M2GuardInstalled = true
    LOG('[SC Campaign] A02: mission-2 handover guard installed via ' .. source ..
        ' (MissionNumber=' .. tostring(si.MissionNumber) ..
        ', started=' .. tostring(si.SC_a02M2Started) .. ')')
    return true
end

function SC_A02CityWatcher()
    local goalSince = nil
    while true do
        local ok, si = pcall(function() return ScenarioInfo end)
        local scName = ''
        if ok and si and si.name then
            scName = string.lower(tostring(si.name))
        end
        -- ScenarioInfo.M1City exists ONLY in SCCA_A02 (verified across all 19
        -- map scripts). Five operations define a BeginMission2, so the guard
        -- must never be installed on the other four - use the field as a
        -- name-independent second discriminator for saves with no si.name.
        local scIsA02 = (scName == string.lower(SC_A02_MAP))
            or (ok and si and type(si.M1City) == 'table')
        if ok and si and si.name and not scIsA02 then
            return
        end
        -- Install BEFORE any handover can happen, and before the
        -- MissionNumber ~= 1 early return so saves already in mission 2 are
        -- protected on reload too. Retried each poll until Env is available.
        if scIsA02 then
            SC_InstallA02M2Guard(si)
        end
        if ok and si and si.MissionNumber == 1
           and type(si.M1City) == 'table' and not si.SC_a02M1Handled then
            local total, alive, unknown = 0, 0, 0
            for _, unit in si.M1City do
                total = total + 1
                local okDead, dead = pcall(function()
                    if unit.Dead then return true end
                    if type(unit.IsDead) == 'function' then
                        return unit:IsDead()
                    end
                    return false
                end)
                if not okDead then
                    -- Destroyed engine object (or a stale save handle): do not
                    -- assume it is dead, that could "complete" a live city.
                    unknown = unknown + 1
                elseif not dead then
                    alive = alive + 1
                end
            end
            if total > 0 then
                local now = GetGameTimeSeconds()
                -- Count unknown handles as survivors for the handle-based test.
                local byHandles = (alive + unknown) < total * SC_A02_GOAL
                local byCounter = type(si.M1CityBuildingsAlive) == 'number'
                    and type(si.M1CityBuildingsTotal) == 'number'
                    and si.M1CityBuildingsTotal > 0
                    and si.M1CityBuildingsAlive < si.M1CityBuildingsTotal * SC_A02_GOAL
                if now - (si.SC_a02LastLog or -100) >= 10 then
                    si.SC_a02LastLog = now
                    LOG(string.format(
                        '[SC Campaign] A02 M1 watchdog: city alive=%d unknown=%d/%d ' ..
                        '(script=%s/%s, byHandles=%s, byCounter=%s) ' ..
                        'M1P1 active=%s complete=%s M1P2 obj=%s active=%s complete=%s',
                        alive, unknown, total, tostring(si.M1CityBuildingsAlive),
                        tostring(si.M1CityBuildingsTotal), tostring(byHandles),
                        tostring(byCounter),
                        tostring(si.M1P1Objective and si.M1P1Objective.Active),
                        tostring(si.M1P1Complete),
                        tostring(si.M1P2Objective ~= nil),
                        tostring(si.M1P2Objective and si.M1P2Objective.Active),
                        tostring(si.M1P2Complete)))
                end
                if byHandles or byCounter then
                    if not goalSince then
                        goalSince = now
                        -- Give the map's own handover a chance first: when M1P2
                        -- is already resolved, only its VO callback is missing.
                        local m2done = (si.M1P2Complete == true)
                            or (si.M1P2Objective and si.M1P2Objective.Active == false)
                        if m2done and not si.SC_a02EndMission1Called then
                            local endFn = si.SC_a02RawEndMission1
                                or SC_MapFunction('EndMission1')
                            if endFn then
                                si.SC_a02EndMission1Called = true
                                LOG('[SC Campaign] A02: both M1 objectives resolved - ' ..
                                    'replaying EndMission1')
                                pcall(function() ForkThread(endFn) end)
                            end
                        end
                    end
                    -- Deliberately leave M1CityBuildingsAlive alone: overwriting
                    -- it could invalidate byCounter on the next poll and reset
                    -- goalSince forever. M1P1Reminder only looks at
                    -- M1P1Objective.Active, which we close below.
                    local objective = si.M1P1Objective
                    if objective and objective.Active ~= false then
                        local okRes = pcall(function() objective:ManualResult(true) end)
                        if not okRes then
                            pcall(function() objective:OnResult(true) end)
                        end
                        objective.Active = false
                        LOG('[SC Campaign] A02 M1P1 closed by watchdog ' ..
                            '(city genuinely cleansed)')
                    end
                    si.M1P1Complete = true
                    -- M1AttackersDestroyed() checks this very flag; setting it
                    -- lets the map's own M1P2 completion end mission 1 normally.
                    if now - goalSince >= SC_A02_GRACE then
                        si.SC_a02M1Handled = true
                        if SC_a02M2AlreadyStarted(SC_currentScenarioInfo(si)) then
                            LOG('[SC Campaign] A02: handover already ran - ' ..
                                'skipping watchdog replay')
                            return
                        end
                        -- Claim the guard BEFORE forking: if the map's own VO
                        -- callback lands in the meantime, the Env wrapper sees
                        -- the flag and refuses to run a second handover.
                        si.SC_a02M2Started = true
                        local handover = si.SC_a02RawBeginMission2
                            or SC_MapFunction('BeginMission2')
                        if handover then
                            LOG('[SC Campaign] A02: mission 1 still open after ' ..
                                tostring(SC_A02_GRACE) .. 's - replaying BeginMission2')
                            pcall(function() ForkThread(handover) end)
                        else
                            LOG('[SC Campaign] A02: BeginMission2 unreachable - ' ..
                                'mission 1 cannot advance')
                        end
                        return
                    end
                else
                    goalSince = nil
                end
            end
        elseif ok and si and si.MissionNumber ~= nil and si.MissionNumber ~= 1 then
            return
        end
        WaitSeconds(2)
    end
end

SC_exportGlobal('SC_A02CityWatcher', SC_A02CityWatcher)

ForkThread(SC_A02CityWatcher)
LOG('[SC Campaign] A02 M1 city watchdog armed (map=' .. SC_A02_MAP ..
    ', goal=80% cleansed, grace=' .. tostring(SC_A02_GRACE) .. 's)')

--*****************************************************************************
--* 14) A05 (Aeon operation 5): duplicated M2 outro / M3 intro
--*****************************************************************************
--* SCCA_A05_script.lua points TWO independent dialogue callbacks at the same
--* unguarded function:
--*     M2OneArtilleryDefeated(): Dialogue(A05_M02_080, M2CheckObjectives) :916
--*     M2BlakeDestroyed():       Dialogue(A05_M02_110, M2CheckObjectives) :963
--* M2CheckObjectives() merely does ForkThread(EndMission2) when BOTH
--* M2BlakeDestroyedBool and M2ArtilleryDestroyedBool are true (:979-983).
--* Whichever objective finishes SECOND makes both callbacks satisfied, so
--* EndMission2() runs twice -> A05_M02_150 (A05_Choir_M02_01003.sfd) twice,
--* StartMission3() twice -> M3_Playable_Area expansion twice, all M3 units
--* spawned twice, A05_M03_010 (A05_Princess_M03_01004.sfd etc.) twice.
--*
--* game.log 2026-11-11: one sim load (:40360), one save load (:40563), yet
--* OpenMovie count = 2 for exactly those 10 M2-outro/M3-intro movies, and
--* SetPlayableArea 0,0 1024,1024 (M3_Playable_Area) appears at :42536 AND
--* :42559. M2_Playable_Area appears only once (:42229), so StartMission2 was
--* not duplicated in that run - but it has the same unguarded shape and a
--* replayed A05_M01_160 VO callback after a save load could duplicate it too.
--*
--* Fix: wrap the map functions in ScenarioInfo.Env. M2CheckObjectives() is
--* A05-only (checked across all 19 map scripts) and is the discriminator;
--* StartMission2/StartMission3 exist in ~10 other operations, so they are
--* wrapped ONLY when that A05-only function sits in the same env table.
--* The claim flag is set ONLY when both M2 conditions are true: burning it on
--* an early, incomplete check would strand mission 2 forever.
--* EndMission2 is deliberately NOT wrapped - M2CheckObjectives() passes it to
--* ForkThread(), and save restore resolves thread entries by global name.
--*****************************************************************************
local SC_A05_MAP = 'SCCA_A05'

local function SC_InstallA05HandoverGuards(si)
    if type(si) ~= 'table' then
        return false
    end
    if rawget(si, 'SC_a05GuardInstalled') then
        return true
    end

    local env, source = nil, nil
    local function SC_tryA05Env(t, src)
        if env == nil and type(t) == 'table'
           and type(rawget(t, 'M2CheckObjectives')) == 'function'
           and type(rawget(t, 'StartMission3')) == 'function' then
            env = t
            source = src
        end
    end

    SC_tryA05Env(rawget(si, 'Env'), 'ScenarioInfo.Env')
    if env == nil then
        local okMod, mod = pcall(function()
            return import('/lua/scenarioenvironment.lua')
        end)
        if okMod then
            SC_tryA05Env(mod, 'scenarioenvironment module')
        end
    end
    if env == nil then
        SC_tryA05Env(_G, '_G')
    end
    if env == nil then
        return false
    end

    local checkFn    = rawget(env, 'M2CheckObjectives')
    local startM2Fn  = rawget(env, 'StartMission2')
    local startM3Fn  = rawget(env, 'StartMission3')

    rawset(env, 'M2CheckObjectives', function()
        local cur = SC_currentScenarioInfo(si)
        if rawget(cur, 'SC_a05M2EndClaimed') then
            LOG('[SC Campaign] A05: duplicate M2CheckObjectives suppressed')
            return
        end
        if cur.M2BlakeDestroyedBool and cur.M2ArtilleryDestroyedBool then
            rawset(cur, 'SC_a05M2EndClaimed', true)
        end
        return checkFn()
    end)

    if type(startM2Fn) == 'function' then
        si.SC_a05RawStartMission2 = startM2Fn
        rawset(env, 'StartMission2', function()
            local cur = SC_currentScenarioInfo(si)
            if rawget(cur, 'SC_a05M2Started')
               or (tonumber(cur.MissionNumber) or 1) >= 2 then
                LOG('[SC Campaign] A05: duplicate StartMission2 suppressed')
                return
            end
            rawset(cur, 'SC_a05M2Started', true)
            return startM2Fn()
        end)
    end

    if type(startM3Fn) == 'function' then
        si.SC_a05RawStartMission3 = startM3Fn
        rawset(env, 'StartMission3', function()
            local cur = SC_currentScenarioInfo(si)
            if rawget(cur, 'SC_a05M3Started')
               or (tonumber(cur.MissionNumber) or 1) >= 3 then
                LOG('[SC Campaign] A05: duplicate StartMission3 suppressed')
                return
            end
            rawset(cur, 'SC_a05M3Started', true)
            return startM3Fn()
        end)
    end

    -- Saves written before this fix have no flags. MissionNumber is set by
    -- StartMission2 (:715) / StartMission3 (:1050) and is authoritative.
    local mn = tonumber(si.MissionNumber) or 1
    if mn >= 2 then
        rawset(si, 'SC_a05M2Started', true)
    end
    if mn >= 3 then
        rawset(si, 'SC_a05M3Started', true)
        rawset(si, 'SC_a05M2EndClaimed', true)
    end

    rawset(si, 'SC_a05GuardInstalled', true)
    LOG('[SC Campaign] A05: handover guards installed via ' .. source ..
        ' (MissionNumber=' .. tostring(si.MissionNumber) .. ')')
    return true
end

function SC_A05HandoverWatcher()
    while true do
        local ok, si = pcall(function() return ScenarioInfo end)
        if ok and si then
            local nm = ''
            if si.name then
                nm = string.lower(tostring(si.name))
            end
            if nm ~= '' and nm ~= string.lower(SC_A05_MAP) then
                return
            end
            SC_InstallA05HandoverGuards(si)
        end
        WaitSeconds(2)
    end
end

SC_exportGlobal('SC_A05HandoverWatcher', SC_A05HandoverWatcher)
ForkThread(SC_A05HandoverWatcher)
LOG('[SC Campaign] A05 handover guard watcher armed (map=' .. SC_A05_MAP .. ')')

end
