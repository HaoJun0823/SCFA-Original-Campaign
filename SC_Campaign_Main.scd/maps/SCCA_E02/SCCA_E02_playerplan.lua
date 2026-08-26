#****************************************************************************
#**
#**  File     :  /maps/SCCA_E02/SCCA_E02_playerplan.lua
#**  Author(s):  David Tomandl
#**
#**  Summary  :
#**
#**  Copyright © 2006 Gas Powered Games, Inc.  All rights reserved.
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
