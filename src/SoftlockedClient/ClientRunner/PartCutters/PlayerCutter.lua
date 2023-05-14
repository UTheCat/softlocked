-- An object provided so that players can cut through parts.
-- By udev2192

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RepModules = ReplicatedStorage:WaitForChild("Modules")
local UtilRepModules = RepModules:WaitForChild("Utils")

local Object = require(UtilRepModules:WaitForChild("Object"))

local PlayerCutter = {}

function PlayerCutter.New(CharAdapter)
	assert(typeof(CharAdapter) == "table", "Argument 1 must be a CharacterAdapter.")
	
	
end

return PlayerCutter