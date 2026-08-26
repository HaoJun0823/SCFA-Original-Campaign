#****************************************************************************
#**
#**  File     :  /maps/SCCA_Tutorial/SCCA_Tutorial_script.lua
#**  Author(s):  Marc Scattergood
#**
#**  Summary  :  Supreme Commander Tutorial
#**
#**  Copyright © 2006 Gas Powered Games, Inc.  All rights reserved.
#****************************************************************************

local Objectives = import('/lua/ScenarioFramework.lua').Objectives
local ScenarioFramework = import('/lua/scenarioframework.lua')
local ScenarioStrings = import('/lua/ScenarioStrings.lua')
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local Cinematics = import( '/lua/cinematics.lua')
local Utilities = import('/lua/Utilities.lua')
local Weather = import('/lua/weather.lua')

ScenarioInfo.Player = 1
ScenarioInfo.Cybran = 2
ScenarioInfo.Instructor = 3

local player = ScenarioInfo.Player
local cybran = ScenarioInfo.Cybran
local instructor = ScenarioInfo.Instructor

local Training_Computer = '<LOC SCCA_Tutorial_0000>Cybernetic Instructor Mark 9.32'

local P2Obj_PowerRequired = 3

function OnPopulate()

	ScenarioUtils.InitializeScenarioArmies()
    #Weather.CreateWeather() 
    	
end

function OnStart(self)
    
    Cinematics.CameraMoveToMarker( ScenarioUtils.GetMarker( 'Intro_Cam'), 0.0)
    
    ScenarioInfo.Player_CDR = ScenarioUtils.CreateArmyUnit( 'Player', 'Player_CDR' )
    ScenarioInfo.Player_CDR:PlayCommanderWarpInEffect()
    ScenarioInfo.Player__Aeon_CDR = ScenarioUtils.CreateArmyUnit( 'Player', 'Player_Aeon_CDR' )
    ScenarioInfo.Player__Cybran_CDR = ScenarioUtils.CreateArmyUnit( 'Player', 'Player_Cybran_CDR' )
    #ScenarioInfo.Player_Instructor = ScenarioUtils.CreateArmyUnit( 'Instructor', 'Instructor_Unit' )
    #ScenarioInfo.Cybran_Start = ScenarioUtils.CreateArmyGroup( 'Cybran', 'CybranBase' )
    
    ScenarioInfo.Player_CDR:SetCustomName(LOC '{i CDR_Player}')
    #ScenarioInfo.Player_Instructor:SetCustomName(Training_Computer)
    
    ForkThread(function() ScenarioFramework.HelpPrompt(true) end)
    
    #ForkThread(Start_Tutorial)
    
end

#function Start_Tutorial()
#
#    WaitSeconds(5.0)
#    
#    Part2_TUB100()
#
#end
#
#
#function Part1_Intro_TUB050()
#
#
#end
#
#function Part2_TUB100()
#    
#    ScenarioInfo.MissionNumber = 1
#    
#    ScenarioFramework.HelpPrompt(true)
#
#    local P02_Obj = Objectives.CreateGroup('tutorial1', Part3Obj)
#    ScenarioInfo.P02Obj = Objectives.ArmyStatCompare(
#        'primary',                      # type
#        'incomplete',                   # complete
#        '<LOC Tutorial_Obj_Title_0000>Build an Energy Infrastructure',     # title
#        '<LOC Tutorial_Obj_Desc_0000>Build three power generators to get your energy economy started.',      # description
#        'build',                        # action
#        {                               # target
#            Army = player,
#            StatName = 'Units_Active',
#            CompareOp = '>=',
#            Value = P2Obj_PowerRequired,
#            Category = categories.ueb1101,
#        }
#    )
#    ScenarioInfo.P02Obj:AddResultCallback(
#        function()
#            #ScenarioFramework.Dialogue(ScenarioStrings.PObjComp)
#            #if(ScenarioInfo.P02Obj.Active) then
#             #   ScenarioFramework.CreateTimerTrigger(M1P2Reminder1, M1P2Time)
#            #end
#        end
#    )
#    P02_Obj:AddObjective(ScenarioInfo.P02Obj)
#    #ScenarioFramework.CreateTimerTrigger(M1P1Reminder1, M1P1Time)
#
#    ScenarioInfo.P02_2Obj = Objectives.CategoriesInArea(
#        'primary',                      # type
#        'incomplete',                   # complete
#        '<LOC Tutorial_Obj_Title_0001>Build a Mass Infrastructure',     # title
#        '<LOC Tutorial_Obj_Desc_0001>Build three mass extractors on the locations that are highlighted on the ground.',      # description
#        'build',                        # action
#        {                               # target
#            MarkArea = true,
#            Requirements = {
#                {Area = 'Mass1', Category = categories.ueb1103, CompareOp='>=', Value = 1,},
#                {Area = 'Mass2', Category = categories.ueb1103, CompareOp='>=', Value = 1,},
#                {Area = 'Mass3', Category = categories.ueb1103, CompareOp='>=', Value = 1,},
#            },
#        }
#    )
#    ScenarioInfo.P02_2Obj:AddResultCallback(
#        function()
#            #ScenarioFramework.Dialogue(ScenarioStrings.PObjComp)
#            #if(ScenarioInfo.P02Obj.Active) then
#             #   ScenarioFramework.CreateTimerTrigger(M1P2Reminder1, M1P2Time)
#            #end
#        end
#    )
#    P02_Obj:AddObjective(ScenarioInfo.P02_2Obj)
#    #ScenarioFramework.CreateTimerTrigger(M1P1Reminder1, M1P1Time)
#
#
#end
#
#function Part3Obj()
#    ScenarioInfo.MissionNumber = 2
#    #ScenarioFramework.Dialogue(OpStrings.E01_M02_010, StartMission2)
#end