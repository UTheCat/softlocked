-- Provides a hit object list using the Hitbox class. The most
-- recently touched object will have the priority.

-- By udev2192

local RunService = game:GetService("RunService")

local ModulePack = script.Parent

local Utils = ModulePack.Parent:WaitForChild("Utils")

local Hitbox = require(ModulePack:WaitForChild("Hitbox"))

local Object = require(Utils:WaitForChild("Object"))
local Signal = require(Utils:WaitForChild("Signal"))

local HitArray = {}
HitArray.__index = HitArray

local HitStatus = HitArray.GetStatusList()

-- Utility function for getting the list of possible Hitbox
-- HitStatus values.
function HitArray.GetStatusList()
	return HitStatus
end

function HitArray.New()
	local Obj = Object.New("HitArrayList")
	local Array = {}
	local CurrentHitboxes = {}
	
	-- The hit status number that is considered "not touching"
	Obj.TouchStopStatus = HitStatus.NotTouching
	
	-- The hit status number that is considered "touching"
	Obj.TouchStatus = HitStatus.CompletelyInside
	
	-- Status change handler.
	local function OnStatusChange(Part, Result)
		local Status = Result.Status
		local Changed = false
		
		if Status == Obj.TouchStatus then
			Changed = true
			
			-- Add the most recently touched part to the end of the array.
			table.insert(Array, Part)
			
		elseif Status == Obj.TouchStopStatus then
			Changed = true
			
			-- Remove the most recent part that stopped touching
			local Index = table.find(Array, Part)
			if Index ~= nil then
				table.remove(Array, Index)
			end
		end
		
		-- If there was a change, signal it.
		-- The most recent part would be at the end of the list.
		if Changed == true then
			Hitbox.PartChanged.Fire(Array[#Array])
		end
		
		Hitbox.HitboxTouchChanged.Fire(Part, Result)
	end
	
	-- Removes the specified hitbox from modifying the array.
	function Obj.Remove(Hitbox)
		CurrentHitboxes[Hitbox] = nil
		Hitbox.HitStatusChanged.Disconnect(OnStatusChange)
	end
	
	-- Lets the specified hitbox add to the array.
	function Obj.Add(Hitbox)
		if CurrentHitboxes ~= nil then
			CurrentHitboxes[Hitbox] = true
			Hitbox.HitStatusChanged.Connect(OnStatusChange)
		end
	end
	
	-- Fires when a Hitbox's HitStatus changes.
	-- Params:
	-- Part - The box that had its touch status changed
	-- Result - The box's new HitResults
	Obj.HitboxTouchChanged = Signal.New()
	
	-- Fires when the most recently touched part changes.
	-- if the first parameter is nil, no parts are being touched.
	-- Params:
	-- Part - The most recently touched part.
	Obj.PartChanged = Signal.New()
	
	Obj.OnDisposal = function()
		Obj.HitboxTouchChanged.DisconnectAll()
		Obj.PartChanged.DisconnectAll()
		
		for i, v in pairs(CurrentHitboxes) do
			Obj.Remove(Hitbox)
		end
		
		Array, CurrentHitboxes = nil, nil
	end
	
	return Obj
end

return HitArray