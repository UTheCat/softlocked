--[[
Default launcher for win places
]]--

local MapLauncher = require(script.Parent:WaitForChild("MapLauncher"))
local BaseInteractive = MapLauncher.GetBaseInteractive()

local Launcher = {}

function Launcher.GetWinPlaceContainer()
	return game:GetService("ReplicatedStorage"):WaitForChild("WinPlaces")
end

function Launcher.New(Model: Model, Loader: {})
	local Map = MapLauncher.New(Model, Loader)
	
	local ExitConnection

	-- The map's name
	Map.Name = "Win Place"

	-- Number enclosed in brackets specifies the difficulty
	-- (1-14)
	Map.Difficulty = MapLauncher.DefaultInfo.FallbackDifficulty

	-- Whoever created the map
	Map.Creators = ""
	
	local function DisconnectExit()
		if ExitConnection then
			ExitConnection:Disconnect()
		end
	end
	
	Map.OnClientStart = function()
		Map.ApplyLighting()
		Map.StartInteractives()
		
		ExitConnection = Model:WaitForChild("Exit").Touched:Connect(function(OtherPart)
			if OtherPart == BaseInteractive.GetCharacterHandle().Parts.Hitbox then
				DisconnectExit()
				Loader.ExitWinPlace()
			end
		end)
		
		Model.Parent = MapLauncher.GetMapContainer()
		
		local Humanoid = BaseInteractive.GetCharacterHandle().Parts.Humanoid
		if Humanoid then
			Humanoid.Health = Humanoid.MaxHealth
		end
		
		Map.SpawnLocalPlayer()
		Loader.MusicPlayer.MainSound = Model:WaitForChild("WinMusic")
		
		return true
	end
	
	local DefaultEnd = Map.OnClientEnd
	Map.OnClientEnd = function()
		DisconnectExit()
		DefaultEnd()
		Model.Parent = Launcher.GetWinPlaceContainer()
	end

	return Map
end

return Launcher