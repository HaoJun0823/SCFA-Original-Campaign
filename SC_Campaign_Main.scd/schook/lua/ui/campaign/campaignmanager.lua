--*****************************************************************************
--* File: schook/lua/ui/campaign/campaignmanager.lua
--* Summary: Hook OperationVictory to route SC campaign ops to SC campaignmanager
--*****************************************************************************

-- Save original FA OperationVictory
local baseFAOperationVictory = OperationVictory

function OperationVictory(ovTable, skipDialog)
    -- Route to SC campaignmanager for original campaign (SCCA_ ops)
    if ovTable.opKey and string.sub(ovTable.opKey, 1, 5) == 'SCCA_' then
        import('/lua/sc_campaign/campaignmanager.lua').OperationVictory(ovTable, skipDialog)
    else
        baseFAOperationVictory(ovTable, skipDialog)
    end
end
