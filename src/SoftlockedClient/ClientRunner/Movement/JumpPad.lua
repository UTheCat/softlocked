-- Provides a class that launches a player upward when they touch it.
-- By udev2192

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RepModules = ReplicatedStorage:WaitForChild("SoftlockedReplicated")
local UtilRepModules = RepModules:WaitForChild("Utils")

local Movement = script.Parent
local BaseMover = require(Movement:WaitForChild("BaseMover"))

local JumpPad = {}

function JumpPad.New(Part, CharAdapter)
	BaseMover.AssertPart(Part, 1)
	
	Part.CanCollide = false
	
	local Mover = BaseMover.New(CharAdapter)
	Mover.Part = Part
	Mover.NextForce = Vector3.new(0, Part:GetAttribute("Power"), 0)
	Mover.ForceDuration = Part:GetAttribute("ForceDuration") or 0
	Mover.SoundId = Part:GetAttribute("SoundId") or Mover.SoundId
	Mover.UseJumpBoost = true
	
	return Mover
end

return JumpPad