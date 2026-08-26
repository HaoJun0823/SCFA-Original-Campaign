#****************************************************************************
#**
#**  File     :  /lua/ui/campaign/operationvars.lua
#**  Author(s):  Evan Pongress
#**
#**  Summary  :  function to generate the vars for operationselect.lua and operationbriefing.lua. uses the ID set in /maps/*_operation.lua, e.g. SCCA_E01.
#**
#**  Copyright © 2006 Gas Powered Games, Inc.  All rights reserved.
#****************************************************************************

function MakeOpVars(thisID, factionKey, sequenceID)
	local opStrings = import('/maps/' .. thisID .. '/' .. thisID .. '_strings.lua')

    local factionData = import('/lua/factions.lua')
	
	thisFacLtr = factionData.Factions[factionData.FactionIndexMap[factionKey]].CampaignFileDesignator
	
	op_short_name = factionKey .. ' ' .. sequenceID										# short name = faction/opnumber, e.g. UEF 1
	op_long_name = opStrings.OPERATION_NAME												# long name = the actual operation name, e.g. Operation Black Earth
	op_num = string.sub(thisID, 7)														# last two digits of thisID. operationbriefing.lua needs this two-digit number.
	op_map = '/maps/' .. thisID .. '/' .. thisID .. '_scenario.lua'							# build map path for op brief
	op_BtnPfx = '/campaign/select/button_op_' .. sequenceID								# build button prefix for op select
	op_MovPfx = thisFacLtr .. op_num													# movie prefix for op brief, e.g. E01

	if rawget(opStrings, 'BriefingData') then											# if briefing data exists (use 'rawget' to bypass missing global error if it doesn't exist)
		op_text = opStrings.BriefingData
	else
		op_text = {{phase = 1, character = 'NO_DATA', text = 'ERROR - NO BRIEFING DATA'}}
	end

	return {op_short_name = op_short_name,
			op_long_name = op_long_name,
			op_num = op_num,
			op_map = op_map,
			op_BtnPfx = op_BtnPfx,
			op_MovPfx = op_MovPfx,
			op_text = op_text,
			}
end