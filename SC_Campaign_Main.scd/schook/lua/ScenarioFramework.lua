--*****************************************************************************
--* File: schook/lua/ScenarioFramework.lua
--* Summary: Hook EndOperation to support both SC (7-param) and FA (3-param) signatures
--*****************************************************************************

-- SC scripts call: EndOperation(opKey, success, difficulty, allPrimary, allSecondary, allBonus, factionNIS)
-- FA scripts call: EndOperation(success, allPrimary, allSecondary)
-- Detect SC signature by checking if 4th param is not nil (FA never passes a 4th param)

local baseEndOperation = EndOperation

-- Map SC operation key prefix to faction campaign ID
local function SCCaToFaction(opKey)
    if not opKey then return nil end
    -- SCCA_E01 = UEF, SCCA_R01 = Cybran, SCCA_A01 = Aeon
    local prefix = string.sub(opKey, 6, 6)
    if prefix == 'E' then return 'uef'
    elseif prefix == 'R' then return 'cybran'
    elseif prefix == 'A' then return 'aeon'
    end
    return nil
end

function EndOperation(a, b, c, d, e, f, g)
    LOG('=== ScenarioFramework.EndOperation DEBUG ===')
    LOG('  a=' .. tostring(a) .. ' b=' .. tostring(b) .. ' c=' .. tostring(c) .. ' d=' .. tostring(d) .. ' e=' .. tostring(e) .. ' f=' .. tostring(f) .. ' g=' .. tostring(g))
    if d ~= nil then
        -- SC 7-param signature: a=opKey, b=success, c=difficulty, d=allPrimary, e=allSecondary, f=allBonus, g=factionNIS
        -- Add campaignID so FA's OperationVictory can process it
        local faction = SCCaToFaction(a)
        LOG('  SC signature detected: opKey=' .. tostring(a) .. ' faction=' .. tostring(faction))
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
        LOG('  Sync.OperationComplete set: ' .. repr(Sync.OperationComplete))
    else
        LOG('  FA signature detected: success=' .. tostring(a) .. ' allPrimary=' .. tostring(b) .. ' allSecondary=' .. tostring(c))
        -- FA 3-param signature: a=success, b=allPrimary, c=allSecondary
        baseEndOperation(a, b, c)
    end
end
