-- Class that acts as a box that can cut through BaseParts.
-- For performance reasons, orientation isn't taken into account.
-- By udev2192

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RepModules = ReplicatedStorage:WaitForChild("SoftlockedReplicated")
local UtilRepModules = RepModules:WaitForChild("Utils")

local Object = require(UtilRepModules:WaitForChild("Object"))

local PartCut = {}

local ZERO_VECTOR3 = Vector3.new(0, 0, 0)

function PartCut.New()
	local Obj = Object.New("PartCut")
	local PartRunner = nil
	
	-- The size vector of the cut
	Obj.Size = ZERO_VECTOR3
	
	-- The position vector of the cut
	Obj.Position = ZERO_VECTOR3
	
	-- Binds a BasePart to the PartCutter.
	-- This means that the part provided will
	-- be doing the cut.
	-- Specify with nil to disable.
	function Obj.BindPart(Part)
		if typeof(Part) == "Instance" and Part:IsA("BasePart") then
			-- Disconnect previous connection
			Obj.BindPart(nil)
			
			-- Reconnect
			PartRunner = RunService.Heartbeat:Connect(function()
				Obj.Size = Part.Size
				Obj.Position = Part.Position
			end)
		else
			if PartRunner ~= nil then
				PartRunner:Disconnect()
				PartRunner = nil
			end
		end
	end
	
	Obj.OnDisposal = function()
		Obj.BindPart(nil)
	end
	
	return Obj
end

return PartCut