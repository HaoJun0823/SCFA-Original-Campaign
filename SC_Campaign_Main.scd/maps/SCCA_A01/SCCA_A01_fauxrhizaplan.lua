#****************************************************************************
#**
#**  File     :  /maps/SCCA_A01/SCCA_A01_fauxrhizaplan.lua
#**  Author(s):  Greg
#**
#**  Summary  :
#**
#**  Copyright © 2006 Gas Powered Games, Inc.  All rights reserved.
#****************************************************************************
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')

ScenarioInfo.FauxRhizaPlanRunOnce = false

function EvaluatePlan( brain )
    return 100
end

function BuildStructures( brain )
end

function BuildUnits( brain )
end

function ExecutePlan( brain )
	BuildStructures( brain )
	BuildUnits( brain )
end

function ExecutePlan(brain)
    if(not ScenarioInfo.FauxRhizaPlanRunOnce) then
        brain:PBMRemoveBuildLocation(nil, 'MAIN')
        ScenarioInfo.FauxRhizaPlanRunOnce = true
    end
end