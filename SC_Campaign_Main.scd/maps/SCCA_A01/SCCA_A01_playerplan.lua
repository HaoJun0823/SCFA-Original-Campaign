#****************************************************************************
#**
#**  File     :  /maps/SCCA_A01/SCCA_A01_playerplan.lua
#**  Author(s):  Drew Staltman
#**
#**  Summary  :
#**
#**  Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
#****************************************************************************

function EvaluatePlan( brain )
    return 100
end

function ExecutePlan( brain )
    BuildStructures( brain )
    BuildUnits( brain )
end

function BuildStructures( brain )
end

function BuildUnits( brain )
end
