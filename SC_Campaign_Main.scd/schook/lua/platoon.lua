--*****************************************************************************
--* File: schook/lua/platoon.lua
--* Summary: SC campaign compatibility hook - add PatrolLocationFactoriesAI
--*          method to FA's Platoon class (FA lacks this SC original method)
--*****************************************************************************

-- SC original platoon.lua has PatrolLocationFactoriesAI but FA's does not.
-- 7 SC campaign maps call platoon:PatrolLocationFactoriesAI():
--   SCCA_A03 (4 calls), SCCA_A05 (2), SCCA_A06 (1),
--   SCCA_E01 (1), SCCA_E02 (1), SCCA_E03 (1), SCCA_R06 (2)
--
-- Ported from SC original platoon.lua, adapted for Lua 5.1 (pairs instead
-- of unqualified for-in on tables).
--
-- IMPORTANT: FA's Class system freezes a class after its definition is complete
-- (Class:__newindex in class.lua rejects adding new fields post-freeze).
-- Sorian AI hook already replaces Platoon with Class(oldPlatoon){...} and
-- freezes it. We must use the same subclassing pattern to add our method,
-- otherwise "Attempted to add field after class was defined" error occurs.

do
local oldPlatoon = Platoon

Platoon = Class(oldPlatoon) {
    PatrolLocationFactoriesAI = function(self)
        local aiBrain = self:GetBrain()
        local location = self.PlatoonData.LocationType or 'MAIN'
        local position = aiBrain:PBMGetLocationCoords(location)
        local radius = aiBrain:PBMGetLocationRadius(location)
        while aiBrain:PlatoonExists(self) do
            self:Stop()
            local factories = aiBrain:PBMGetLocationFactories(location)
            if factories then
                for fType, fac in pairs(factories) do
                    if not fac:IsDead() then
                        self:Patrol(fac:GetPosition())
                        local guards = fac:GetGuards()
                        if guards then
                            for num, guard in pairs(guards) do
                                self:Patrol(guard:GetPosition())
                            end
                        end
                    end
                end
            else
                aiBrain:DisbandPlatoon(self)
            end
            WaitSeconds(71)
        end
    end,
}

end
