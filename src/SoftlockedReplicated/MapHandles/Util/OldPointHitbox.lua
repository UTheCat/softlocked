--[[
A simplified version of the Hitbox class that only handles logic that involves
whether or not a point is inside certain parts

Using this over the Hitbox class saves on memory usage although if you need to
account for a part's size, the Hitbox class should be used instead

By udev2192
]]--

local RunService = game:GetService("RunService")

local BaseInteractive = require(script.Parent.Parent
	:WaitForChild("Interactives")
	:WaitForChild("BaseInteractive")
)
local Object = BaseInteractive.GetObjectClass()
local Signal = BaseInteractive.GetSignalClass()

local PointHitbox = {}
PointHitbox.__index = PointHitbox
PointHitbox.ClassName = script.Name

function PointHitbox.New()
	local Hit = Object.New(PointHitbox.ClassName)
	
	local Runner: RBXScriptConnection
	
	--[[
	<boolean> - Whether or not the point is inside the hit region
	]]--
	Hit.IsEntered = false
	
	--[[
	<array> - The list of parts that the point/hitbox is touching
	]]--
	Hit.EnteredParts = {}
	
	--[[
	<array> - The list of parts to determine if the point/hitbox is touching them
	]]--
	Hit.ScannedParts = {}
	
	--[[
	<Vector3> - The point to use as a "hitbox"
	]]--
	Hit.Position = Vector3.zero
	
	--[[
	<Vector3> - The size of the hitbox
	]]--
	Hit.Size = Vector3.zero
	
	--[[
	<boolean> - Whether or not to account for the hitbox's size
	]]--
	Hit.ApplySize = true
	
	--[[
	<boolean> - Whether or not to apply the size negated.
				This is useful for determining if the hitbox
				is completely inside a part.
	]]--
	Hit.NegateSize = false
	
	--[[
	<BasePart> - If specified, this part's position (and size if wanted) will be
				 used
	]]--
	Hit.BindedPart = nil
	
	--[[
	Performs an entry scan to determine if the point is inside
	This will also fire the EntryChanged event, in case the entry
	status has changed during the operation
	
	Returns:
	<boolean> - Whether or not the point is within the hit region
	]]--
	function Hit.Scan()
		local BindedPart = Hit.BindedPart
		local Position: Vector3
		local Size: Vector3

		if BindedPart then
			local PartPos = BindedPart.Position
			if PartPos then
				Position = PartPos
			end
			
			if Hit.ApplySize == true then
				local PartSize = BindedPart.Size
				
				if PartSize then
					Size = PartSize
				else
					Size = Vector3.zero
				end
			else
				Size = Vector3.zero
			end
		else
			Position = Hit.Position
			
			if Hit.ApplySize == true then
				Size = Hit.Size
			else
				Size = Vector3.zero
			end
		end
		
		if Hit.NegateSize == true then
			Size *= -1
		end

		local Entered = {}

		for i, v in pairs(Hit.ScannedParts) do
			if BaseInteractive.IsPointInside(Position, v, Size) then
				table.insert(Entered, v)
			end
		end

		-- Detect whether or not entry status has changed
		local IsEntered = Hit.IsEntered
		local Changed
		if IsEntered == true and #Entered <= 0 then
			Hit.IsEntered = false
			IsEntered = false
			
			Changed = true
		elseif IsEntered == false and #Entered > 0 then
			Hit.IsEntered = true
			IsEntered = true
			
			Changed = true
		else
			Changed = false
		end

		-- This comes first for thread safety
		Hit.Parts = Entered

		if Changed then
			Hit.EntryChanged.Fire(IsEntered)
		end
		
		return IsEntered
	end
	
	--[[
	Stops entry detection
	]]--
	function Hit.Stop()
		if Runner then
			Runner:Disconnect()
			Runner = nil
		end
	end
	
	--[[
	Starts entry detection
	]]--
	function Hit.Start()
		if Runner == nil then
			Runner = RunService.Heartbeat:Connect(Hit.Scan)
		end
	end
	
	--[[
	Fired when the point entry status changes
	
	Params:
	IsEntered <boolean> - Whether or not the point is inside the hit region
	]]--
	Hit.EntryChanged = Signal.New()
	
	Hit.OnDisposal = function()
		Hit.Stop()
		Hit.EntryChanged.DisconnectAll()
	end
	
	return Hit
end

return PointHitbox