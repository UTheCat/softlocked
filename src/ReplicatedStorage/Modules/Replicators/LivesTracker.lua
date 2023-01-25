--[[
Tracks the amount of lives each player has. This is needed because
handling it almost completely on the client will result in inaccuracies
when players die.

This module assumes that characters tracked have humanoids. Do not use this
if humanoids will be removed before death.

By udev2192
]]--

local BaseReplicator = require(script.Parent:WaitForChild("BaseReplicator"))

local LivesTracker = {}
LivesTracker.__index = LivesTracker

LivesTracker.RequestCooldownTime = math.max(0, game:GetService("Players").RespawnTime - 0.1)

function LivesTracker.New()
	local Rep = BaseReplicator.New(script.Name)
	
	-- The minimum amount of lives.
	Rep.MinLives = 0
	
	-- The maximum amount of lives.
	Rep.MaxLives = 3
	
	return Rep
end

return LivesTracker