-- This script runs the ServerPackage.
-- By udev2192

local Archive = game:GetService("ServerStorage"):WaitForChild("Archive", 5)
local ScriptPackage = script.Parent
local GameRunner = require(ScriptPackage:WaitForChild("GameRunner"))

-- Destroy the archive if found.
if typeof(Archive) == "Instance" then
	Archive:Destroy()
end
Archive = nil

local Maps = game:GetService("ServerStorage"):WaitForChild("GameStorage"):WaitForChild("Maps")
local MapWorkspace = workspace:WaitForChild("MapWorkspace")
for i, v in pairs(MapWorkspace:GetChildren()) do
	v.Parent = Maps
end
MapWorkspace:Destroy()
Maps, MapWorkspace = nil

-- Run the game
local Runner = GameRunner.Run()

-- Garbage collect, now that the game is initialized
ScriptPackage, GameRunner, Runner = nil