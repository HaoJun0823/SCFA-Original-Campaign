--*****************************************************************************
--* File: schook/lua/ScenarioFramework.lua
--* Style: Sorian AI Pack hook convention (self-contained do ... end block,
--*        executed after the original /lua/ScenarioFramework.lua chunk).
--*
--* Three jobs:
--*   1) EndOperation() signature shim: SC scripts pass 7 args, FA passes 3.
--*   2) Re-add PatrolLocationFactoriesAI (removed in FA).
--*   3) Provide CDROverchargeBehavior (SC-only global, removed in FA).
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

--*****************************************************************************
--* 1) EndOperation shim
--*****************************************************************************
local baseEndOperation = SC_getGlobal('EndOperation')

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

-- Public entry point used by the ported map scripts. Deliberately a plain
-- global: assignment never trips the _G guard, and it does not depend on how
-- Brain:MakePlatoon() builds its objects or on class-loading order.
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

--*****************************************************************************
--* 3) CDROverchargeBehavior shim
--*
--* SC's E04 does:  import('/lua/ai/AIBehaviors.lua').CDROverchargeBehavior(p)
--* AIBehaviors.lua has no return statement, so import() hands back _G and the
--* field read hits the strict _G.__index guard -> "access to nonexistent
--* global variable CDROverchargeBehavior" and StartMission2 dies half-way.
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

end
