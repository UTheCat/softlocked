-- The launcher that handles the "lobby" game state.
-- This is usually the starting place.

-- By udev2192

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RepModules = ReplicatedStorage:WaitForChild("SoftlockedReplicated")
local MapHandles = RepModules:WaitForChild("MapHandles")
local Replicators = RepModules:WaitForChild("Replicators")
local UtilRepModules = RepModules:WaitForChild("Utils")

local ObjectGroup = require(UtilRepModules:WaitForChild("ObjectGroup"))
local BaseLauncher = require(UtilRepModules:WaitForChild("BaseLauncher"))

local BaseInteractive = require(
	MapHandles
	:WaitForChild("Interactives")
	:WaitForChild("BaseInteractive")
)
local MapLoader = require(
	MapHandles
	:WaitForChild("MapLoader")
)

local Launchers = script.Parent
local ServerPackage = Launchers.Parent
local PlayerHandlers = ServerPackage:WaitForChild("PlayerHandlers")

local PingTester = require(Replicators:WaitForChild("SpeedTest"))

local LauncherUtil = require(Launchers:WaitForChild("LauncherUtil"))

local Spawner = require(PlayerHandlers:WaitForChild("Spawner"))

--local Areas = workspace:WaitForChild("Areas")
local Lobby = workspace:WaitForChild("Lobby")
local MainSpawn = Lobby:WaitForChild("_Spawn")

local LobbyLauncher = {}
--local SpawnDelay = game:GetService("Players").RespawnTime

local function HasDisposalFunc(Val)
	return typeof(Val) == "table" and typeof(Val.Dispose) == "function"
end

--local WhitelistedJoinIds = {game.CreatorId, 1564385423}

local function CanJoin(Player)
	return true--table.find(WhitelistedJoinIds, Player.UserId) ~= nil
end

function LobbyLauncher.New()
	local LobbyLaunch = BaseLauncher.New()
	
	local PlayerObjects = {}
	
	-- Connection object group
	local Connections = ObjectGroup.New()
	Connections.CleansOnDisposal = true
	
	BaseInteractive.CreateCollisionGroups()
	BaseInteractive.RefreshCollisionGroups()
	
	LobbyLaunch.SetStarter(function()
		-- Initialize client package
		LauncherUtil.SetLaunchMode(script.Name)
		
		-- Initialize ping tester
		local CurrentPingTester = PingTester.New()
		Connections.Add(CurrentPingTester)
		CurrentPingTester.Open()
		
		-- Initialize map loader
		local CurrentMapLoader = MapLoader.ServerCreate()
		CurrentMapLoader.RefreshMapLaunchers()
		CurrentMapLoader.Open()
		
		-- Initialize player connection
		local function OnPlayerJoin(Player)
			if CanJoin(Player) then
				if LauncherUtil.IsPlayer(Player) then
					local PlrObjGroup = ObjectGroup.New()
					PlrObjGroup.CleansOnDisposal = true

					PlayerObjects[Player.UserId] = PlrObjGroup

					-- Create a spawner for the player
					local Spawner = Spawner.New(Player)
					Spawner.Spawn = MainSpawn
					Spawner.AutoRespawns = true

					-- Add player objects
					PlrObjGroup.Add(Spawner)

					-- Give the player the client package
					LauncherUtil.GiveClientPack(Player)

					-- Add player to replicator whitelists
					local UserId = Player.UserId
					CurrentPingTester.AddToWhitelist(UserId)
					CurrentMapLoader.AddToWhitelist(UserId)
				end
			end
		end
		
		-- Connect player events
		for i, v in pairs(Players:GetPlayers()) do
			coroutine.wrap(OnPlayerJoin)(v)
		end
		
		Connections.Add(Players.PlayerAdded:Connect(OnPlayerJoin))
		Connections.Add(Players.PlayerRemoving:Connect(function(v)
			local UserId = v.UserId
			local PlrGroup = PlayerObjects[UserId]

			if HasDisposalFunc(PlrGroup) then
				PlrGroup.Dispose()
			end
			
			PlayerObjects[UserId] = nil
			UserId, PlrGroup = nil, nil
		end))
	end)
	
	LobbyLaunch.BindToShutdown(function()
		-- Disconnect events
		Connections.Dispose()
		Connections = nil
		
		-- Clear player objects
		for i, v in pairs(PlayerObjects) do
			if HasDisposalFunc(v) then
				v.Dispose()
			end
		end
		
		PlayerObjects = {}
	end)
	
	return LobbyLaunch
end

return LobbyLauncher