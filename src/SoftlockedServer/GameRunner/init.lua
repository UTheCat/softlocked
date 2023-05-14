-- Provides an object that runs the game's server-sided code.
-- By udev2192

--local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
--local ServerStorage = game:GetService("ServerStorage")

local RepModules = ReplicatedStorage:WaitForChild("SoftlockedReplicated")
local Replicators = RepModules:WaitForChild("Replicators")

require(Replicators:WaitForChild("BaseReplicator"))

ReplicatedStorage, RepModules, Replicators = nil
--local UtilRepModules = RepModules:WaitForChild("Utils")

--local Object = require(UtilRepModules:WaitForChild("Object"))
--local Spawner = require(script:WaitForChild("Spawner"))

local Launchers = script:WaitForChild("Launchers")
--local ClientPackage = ServerStorage:WaitForChild("ObbyistClient")

--local Areas = workspace:WaitForChild("Areas")
--local Lobby = Areas:WaitForChild("Lobby")
--local MainSpawn = Lobby:WaitForChild("_Spawn")

-- Destroy archive objects
--if typeof(Archive) == "Instance" then
--	Archive:Destroy()
--end
--Archive = nil

local GameRunner = {}

-- The default launcher to use. This is the launcher that should be used for
-- the "start" place
GameRunner.DefaultLauncher = "Lobby"

-- If the ClientPackage scripts reset on player respawn
-- Only applied to the next distributed client packages.
--GameRunner.ClientPackResets = false

--local function IsPlayer(Player)
--	return typeof(Player) == "Instance" and Player:IsA("Player")
--end

--local function IsPlayerInGame(Player)
--	return IsPlayer(Player) and Player.Parent == Players
--end

--local function GiveClientPack(Player)
--	if typeof(ClientPackage) == "Instance" then
--		if IsPlayer(Player) == true then
--			coroutine.wrap(function()
--				local PlayerGui = Player:WaitForChild("PlayerGui")
--				if typeof(PlayerGui) == "Instance" then
--					local ClientPackClone = ClientPackage:Clone()
--					if ClientPackClone:IsA("ScreenGui") then
--						ClientPackClone.ResetOnSpawn = GameRunner.ClientPackResets
--						ClientPackClone.IgnoreGuiInset = true
--						ClientPackClone.Parent = PlayerGui
--					end
					
--					ClientPackClone = nil
--				end
				
--				PlayerGui = nil
--			end)()
--		end
--	end
--end

-- Gets a generic "object" for OOP handling.
--function GameRunner.GetGenericObject()
--	return Object
--end

-- The object that runs the server-sided code.
-- Use Obj.Dispose() for garbage collection.
--function GameRunner.New()
--	local Obj = Object.New("GameRunner")
--	Obj.StartedAt = 0
	
--	-- The start function
--	function Obj.Start()
--		-- Begin initialization.
--		Obj.StartedAt = os.time()
		
--		local PlayerObjects = {} -- A table of contents for each player
		
--		local function DisposePlrObjects(PlrObjects)
--			if PlrObjects ~= nil then
--				for i, v in pairs(PlrObjects) do
--					if v.Dispose ~= nil then
--						v.Dispose()
--					end
--				end
--			end
--		end
		
--		local function HandlePlayerRemoving(Player)
--			local PlrObjects = PlayerObjects[Player]
--			DisposePlrObjects(PlrObjects)
			
--			PlayerObjects[Player] = nil
--			PlrObjects = nil
--		end
		
--		local function HandlePlayer(Player)
--			local NextPlrObjects = {}
			
--			-- Initialize player
--			local SpawnerObj = Spawner.New(Player)
--			SpawnerObj.Spawn = MainSpawn
--			SpawnerObj.AutoRespawns = true
			
--			NextPlrObjects.Spawner = SpawnerObj
			
--			-- Only add if the player hasn't left while initializing.
--			if IsPlayerInGame(Player) == true then
--				PlayerObjects[Player] = NextPlrObjects
				
--				-- Give the player the ClientPackage
--				GiveClientPack(Player)
--			else
--				DisposePlrObjects(NextPlrObjects)
--			end
			
--			NextPlrObjects = nil
--		end
		
--		-- Initialize replicators.
--		--local TestRep = require(Replicators:WaitForChild("TestReplicator"))
--		--print("TestReplicator value:", TestRep)
--		--TestRep.Dispose()
		
--		-- Connect events.
--		for i, v in pairs(Players:GetPlayers()) do
--			coroutine.wrap(HandlePlayer)(v)
--		end
--		Players.PlayerAdded:Connect(HandlePlayer)
--		Players.PlayerRemoving:Connect(HandlePlayerRemoving)
--	end
	
--	return Obj
--end

-- Runs the launcher module under the given module name
-- If no name is specified or a blank string is provided,
-- the default will be used.
function GameRunner.Run(LauncherName)
	if typeof(LauncherName) ~= "string" or LauncherName == "" then
		LauncherName = GameRunner.DefaultLauncher
	end
	
	local Launcher = require(Launchers:WaitForChild(LauncherName))
	
	local LauncherObj = Launcher.New()
	LauncherObj.Start()
	
	--print("Initialized after " .. os.time() - LauncherObj.StartedAt .. " ms")
	
	Launcher = nil
	
	return LauncherObj
end

return GameRunner