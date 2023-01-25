--[[
Global BGM player
]]--

local GLOBAL_NAME = "GlobalMusicPlayer"

local MapHandles = script.Parent.Parent
local BaseInteractive = require(MapHandles:WaitForChild("Interactives"):WaitForChild("BaseInteractive"))

local GlobalMusicPlayer = BaseInteractive.GetGlobal(GLOBAL_NAME)

if GlobalMusicPlayer then
	return GlobalMusicPlayer
else
	GlobalMusicPlayer = require(MapHandles.Parent:WaitForChild("Sound"):WaitForChild("MusicPlayer")).New()
	BaseInteractive.SetGlobal(GLOBAL_NAME, GlobalMusicPlayer)
	return GlobalMusicPlayer
end