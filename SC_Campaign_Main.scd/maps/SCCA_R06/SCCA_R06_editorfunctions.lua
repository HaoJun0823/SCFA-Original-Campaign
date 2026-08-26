#****************************************************************************
#**
#**  File     :  /maps/SCCA_R06/SCCA_R06_script.lua
#**  Author(s):  Jessica St. Croix
#**
#**  Summary  :  Custom PBM functions
#**
#**  Copyright © 2006 Gas Powered Games, Inc.  All rights reserved.
#****************************************************************************
local OpStrings = import('/maps/SCCA_R06/SCCA_R06_strings.lua')
local ScenarioFramework = import('/lua/scenarioframework.lua')

################################################################################
# function: CzarAttack = AddFunction	doc = ""
# 
# parameter 0: string	platoon         = "default_platoon"		
#
################################################################################
function CzarAttack(platoon)
    platoon:AttackTarget(ScenarioInfo.ControlCenter)
end