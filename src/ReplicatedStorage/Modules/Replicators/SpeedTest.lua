-- A test for BaseReplicator.
-- By udev2192

local Replicators = script.Parent

local Base = require(Replicators:WaitForChild("BaseReplicator"))

local SpeedTest = {}

-- Testing flags
local USE_WHITELIST = true
local KICK_ENABLED = false
local COOLDOWN_TIME = 1000
local NOT_SO_SECRET_NUMBER = 21
local OUTPUT_ENABLED = true

function SpeedTest.GetBaseReplicator()
	return Base
end

function SpeedTest.New()
	local TestReplicator = Base.New("SpeedTestReplicator")
	
	-- Do test replicator setup
	if Base.IsServer() then
		-- Toggle flags
		TestReplicator.UsePlayerWhitelist = USE_WHITELIST
		TestReplicator.KickingEnabled = KICK_ENABLED
		TestReplicator.CooldownTime = COOLDOWN_TIME
		
		if KICK_ENABLED == true then
			TestReplicator.OnError = function(Player, Error, RequestParams)
				Player:Kick(Error or "lol")
			end
		end

		-- Setup the listeners.
		TestReplicator.RequestReceived.Connect(function(Player)
			if OUTPUT_ENABLED then
				print("Request received by server from", Player.Name)
			end
		end)

		TestReplicator.ServerCallback = function(Player, RequestParams, RandomNumber)
			if OUTPUT_ENABLED then
				print("Request id:", RequestParams.RequestId)
				print("Server callback arguments:", Player.Name, RandomNumber)
			end

			return "please work thanks"
		end
	end
	
	return TestReplicator
end

return SpeedTest