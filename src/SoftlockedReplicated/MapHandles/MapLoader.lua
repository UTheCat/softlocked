--[[
Loads maps to the client.

potential tp sounds:
https://www.roblox.com/library/1253908460
https://www.roblox.com/library/289556450

By udev2192
]]--

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MapHandles = script.Parent
local RepModules = MapHandles.Parent

local MapHandleGui = MapHandles:WaitForChild("Gui")

local Controllers = MapHandles:WaitForChild("Interactives"):WaitForChild("Controllers")

local BaseReplicator = require(RepModules:WaitForChild("Replicators"):WaitForChild("BaseReplicator"))
local ButtonTimer = require(MapHandleGui:WaitForChild("ButtonTimer"))
local MapLauncher = require(MapHandles:WaitForChild("MapLauncher"))
local MusicPlayer = require(RepModules:WaitForChild("Sound"):WaitForChild("MusicPlayer"))
local Signal = BaseReplicator.GetSignalClass()
local TimerFrame = require(MapHandleGui:WaitForChild("TimerFrame"))
local TimeWaiter = require(RepModules:WaitForChild("Utils"):WaitForChild("TimeWaiter"))

local MapLoader = {}
MapLoader.__index = MapLoader
MapLoader.MapsFolderName = "Maps"
MapLoader.ReplicatorId = script.Name .. "Replicator"
MapLoader.MapLauncherName = "Launcher"

--[[
<number> - The number of seconds the client has to load the map in
]]--
MapLoader.MaxLoadTime = 23

MapLoader.RequestIds = {
	Load = 1,
	Start = 2,
	End = 3
}

MapLoader.Status = {
	WaitingForModel = "Waiting for map model",
	WaitingForObjects = "Waiting for objects",
	WaitingForInitialize = "Initializing map",
	WaitingForServer = "Waiting for server",
	Starting = "Starting",
	Cancelled = "Cancelled"
}

MapLoader.CooldownTime = math.max((Players.RespawnTime * 1000) - 100, 0)

local ServerStoredMaps
if RunService:IsServer() then
	ServerStoredMaps = game:GetService("ServerStorage")
	:WaitForChild("GameStorage")
	:WaitForChild("Maps")
end

local WinPlaces = game:GetService("ReplicatedStorage"):WaitForChild("WinPlaces")
local DefaultLobby = workspace:WaitForChild("Lobby")

function MapLoader.RemovePlayerFromLauncher(Launcher, Player: Player, HasWon: boolean)
	Launcher.OnPlayerLeave.Fire(Player, HasWon)
	Launcher.RemoveUserId(Player.UserId)
end

function MapLoader.ServerCreate()
	BaseReplicator.AssertServer()

	local Loader = BaseReplicator.New(MapLoader.ReplicatorId)	

	-- Active map launchers
	local MapLaunchers = {}

	-- [map name] = descendant count
	local DescendantCount = {}

	-- [user id] = currently loading map
	local MapLoadingCache: {number: Model} = {}

	-- [user] = map they're currently in
	local PlayerMaps: {Player: string} = {}

	local PlayerLeaveConnection

	Loader.CooldownTime = MapLoader.CooldownTime

	--[[
	Refreshes stored map launcher instances.
	]]--
	function Loader.RefreshMapLaunchers()
		for i, v in pairs(ServerStoredMaps:GetChildren()) do
			if v.ClassName == "Model" then
				local Name = v.Name
				MapLaunchers[Name] = require(v:WaitForChild(MapLoader.MapLauncherName)).New(v, Loader)
				DescendantCount[Name] = #v:GetDescendants()
			end
		end
	end

	--[[
	Clears loading cache for a given user id.
	
	Params:
	UserId <number> - The user id of the client
	]]--
	function Loader.RemoveFromLoadCache(UserId: number)
		local Map = MapLoadingCache[UserId]

		if Map then
			MapLoadingCache[UserId] = nil
			Map:Destroy()
			Map = nil
		end
	end

	--[[
	Clears the loading cache.
	]]--
	function Loader.ClearLoadCache()
		for i, v in pairs(MapLoadingCache) do
			v:Destroy()
		end
		MapLoadingCache = {}
	end

	--[[
	Adds a map to the loading cache. Maps that are added to the load cache
	will be destroyed
	
	Params:
	UserId <number> - The user id of the player wanting to load the map
	Map <Model> - The map model to add to the cache
	]]--
	function Loader.AddToLoadCache(UserId: number, Map: Model)
		Loader.RemoveFromLoadCache()
		MapLoadingCache[UserId] = Map

		task.spawn(function()
			local DestroyTime = MapLoader.MaxLoadTime
			local Elapsed = 0

			while MapLoadingCache[UserId] do
				if Elapsed > DestroyTime then
					Loader.RemoveFromLoadCache(UserId)
					break
				end

				Elapsed += task.wait()
			end
		end)
	end

	Loader.OnError = function(Player, Error, RequestParams)
		print(Player.Name .. "'s message experienced an error:", Error.Message)
	end

	-- Handle requests
	Loader.ServerCallback = function(Player: Player, RequestParams: {RequestId: number}, MapName: string, HasWon: boolean, WinParams: {})
		print("Request id", RequestParams.RequestId, "from", Player.Name)

		--local MapClone = nil
		local LoadError = nil
		--local MapName = nil
		--local Info = {}
		local Response = {}

		-- Look for the map in the storage folder
		if typeof(MapName) == "string" and typeof(HasWon) == "boolean" then
			local Ids = MapLoader.RequestIds
			local RequestId = RequestParams.RequestId

			if RequestId == Ids.Load then
				local Map: Model = ServerStoredMaps:WaitForChild(MapName, 1)

				if Map and Map.ClassName == "Model" then
					local MapModelName = Map.Name
					local Launcher = MapLaunchers[MapModelName]

					if Launcher then
						-- Check if the map allows the player to enter
						if Launcher.OnMapRequest(Player) == true then
							local PlayerGui = Player:WaitForChild("PlayerGui", 3)

							if PlayerGui and PlayerGui.ClassName == "PlayerGui" then								
								Response.Info = {
									Name = Launcher.Name,
									Difficulty = Launcher.Difficulty,
									Creators = Launcher.Creators,
									NumDescendants = DescendantCount[MapModelName]
								}
								local MapClone = Map:Clone()

								-- The client will clone the map again
								-- Not ideal, but the server would otherwise crash
								-- with the player loading too many maps at once
								Loader.AddToLoadCache(Player.UserId, MapClone)
								Response.MapInstance = MapClone
								Response.ModelName = MapClone.Name

								MapClone.Parent = PlayerGui
								--task.wait() -- Wait a single frame for replication
							else
								LoadError = "Map loading destination not found"
							end
						end
					else
						LoadError = "Couldn't load map information"
					end
				else
					LoadError = "Map not found"
				end
			elseif RequestId == Ids.Start then
				-- If the player isn't in another map
				-- and if the map allows for their entry,
				-- let them get in
				local UserId = Player.UserId
				local CurrentMap: string = PlayerMaps[UserId]
				if CurrentMap == nil then
					local Launcher = MapLaunchers[MapName]

					if Launcher then
						-- Getting here should mean the player has loaded the map
						-- Destroy the clone from cache
						Loader.RemoveFromLoadCache(UserId)

						-- Let them play the map
						PlayerMaps[UserId] = MapName
						Launcher.AddUserId(UserId)
						Launcher.OnPlayerEnter.Fire(Player)

						Response.Info = {
							Name = Launcher.Name,
							Difficulty = Launcher.Difficulty,
							Creators = Launcher.Creators
						}
					else
						LoadError = "MapLauncher for starting the map session doesn't exist"
					end
				else
					LoadError = "Already in another map"
				end
			elseif RequestId == Ids.End then
				local UserId = Player.UserId
				local CurrentMap: string = PlayerMaps[UserId]
				if CurrentMap ~= nil then
					local Launcher = MapLaunchers[CurrentMap]

					if Launcher then
						local Kicked = false
						local IsWinValid = false

						if HasWon == true then
							if typeof(WinParams) == "table" and Launcher.OnWinRequest(Player, WinParams) then
								IsWinValid = true

								-- Display a win message
								-- or something
							else
								-- Either they didn't actually win,
								-- or the win request was denied from
								-- a bug in the callback
								Kicked = true
								Player:Kick("winner")
							end
						end

						MapLoader.RemovePlayerFromLauncher(Launcher, Player, IsWinValid)
						PlayerMaps[UserId] = nil

						if Kicked then
							return nil
						end

						Response.Info = {
							Name = Launcher.Name,
							Difficulty = Launcher.Difficulty,
							Creators = Launcher.Creators,
							HasWon = IsWinValid
						}
					else
						LoadError = "MapLauncher for ending the map session was somehow erased"
					end
				else
					-- kick because exploiters may try to fire
					-- this for free and instant wins
					Player:Kick("keep yourself safe")
					return nil
				end
			else
				LoadError = "Request id is invalid"
			end
		else
			LoadError = "Invalid arguments"
		end

		if LoadError then
			Response.LoadError = LoadError
		end

		-- Respond. The map should hopefully be replicated
		-- by the time the client receives this table.
		return Response
	end

	PlayerLeaveConnection = Players.PlayerRemoving:Connect(function(Player)
		local UserId = Player.UserId
		local Map = PlayerMaps[UserId]

		if Map then
			local Launcher = MapLaunchers[Map]

			if Launcher then
				MapLoader.RemovePlayerFromLauncher(Launcher, Player, false)
			else
				warn(
					"Map launcher is somehow missing for a player requesting to end a map session (errored for "
						.. Player.Name
						.. ")"
				)
			end

			PlayerMaps[UserId] = nil
		end
	end)

	Loader.AddDisposalListener(function()
		if PlayerLeaveConnection then
			PlayerLeaveConnection:Disconnect()
			PlayerLeaveConnection = nil
		end

		Loader.ClearLoadCache()

		for i, v in pairs(PlayerMaps) do
			local Launcher = MapLaunchers[v]

			if Launcher then
				MapLoader.RemovePlayerFromLauncher(Launcher, i, false)
			end
		end

		PlayerMaps = {}
	end)

	return Loader
end

function MapLoader.ClientCreate(ScreenGui: ScreenGui)
	local Loader = BaseReplicator.New(MapLoader.ReplicatorId)
	local LocalPlayer = Players.LocalPlayer
	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
	
	local Timer = TimerFrame.New()
	local TimerLabel: TextLabel = Timer.Label

	local ClientMapStorage: {string: {Map: Model, Launcher: {}, Initialized: boolean}} = {}
	local CurrentControllers: {[string]: {}} = {}
	local IsInMap = false
	local IsAttemptingLoad = false
	local IsAttemptingStart = false
	--local CurrentMap: Model
	--local LaunchInst
	
	--local CurrentWinPlace
	local CurrentWinLauncher

	-- Pointer to the currently playing map's table in ClientMapStorage
	local CurrentMap
	
	local HeartbeatConnection

	-- Timestamp that the last response was received
	--local LastLoadTime = 0
	--local RequestCooldown = 0
	
	-- Cooldown expiry timestamp
	local CooldownExpireTime = 0
	local MapBeginTime = 0 -- in seconds
	local EndRetries = 0
	
	Loader.MaxEndRetries = 2

	--Loader.MainRequestId = 0
	Loader.MaxDescendantLoadTime = 5
	
	Loader.LastMapStartTime = 0
	Loader.LastMapEndTime = 0
	
	Loader.Lobby = DefaultLobby
	Loader.LobbyMainMusic = DefaultLobby:WaitForChild("Config"):WaitForChild("MainBGM")
	Loader.TimerGui = Timer.Gui
	Loader.MapTimer = Timer
	
	local MusicPlayerInit = MusicPlayer.New()
	MusicPlayerInit.FindMusicZones = true
	MusicPlayerInit.MainSound = Loader.LobbyMainMusic
	Loader.MusicPlayer = MusicPlayerInit
	
	MusicPlayerInit = nil

	--[[
	<boolean> - Whether or not the loader will save maps that are received
				from the server
	
	Currently unused
	]]--
	--Loader.ShouldSaveMaps = true

	--[[
	<table> - The map info of the currently loading map
	]]--
	Loader.LoadingMapInfo = {}

	Loader.Timeout = 2000
	--Loader.CurrentMapName = nil

	local function FireError(Message: string)
		--LastLoadTime = BaseReplicator.GetCurrentTime()
		Loader.OnLoadError.Fire(Message)
	end

	local function WaitForCooldown()
		--local CurrentTime = BaseReplicator.GetCurrentTime()
		--local CurrentCooldown = CurrentTime - LastLoadTime
		----Loader.CanSendRequest().CooldownRemaining + (LocalPlayer:GetNetworkPing() * 1000)
		--print("Waiting", (CurrentCooldown) / 1000, "seconds")

		--if CurrentCooldown > RequestCooldown then
		--	task.wait((RequestCooldown - CurrentCooldown) / 1000)
		--end
		--local CooldownPassed = math.min(BaseReplicator.GetCurrentTime() - LastLoadTime, RequestCooldown)
		--print("cooldown is", math.min(BaseReplicator.GetCurrentTime() - LastLoadTime, RequestCooldown))
		--if CooldownPassed <= RequestCooldown then
		--	task.wait(CooldownPassed / 1000)
		--end

		--LastLoadTime = BaseReplicator.GetCurrentTime()
		
		--local CooldownLeft = CooldownExpireTime - BaseReplicator.GetCurrentTime()
		--print("wait", CooldownLeft / 1000, "seconds")
		--if CooldownLeft > 0 then
		--	task.wait(CooldownLeft / 1000)
		--end
		
		task.wait(MapLoader.CooldownTime / 1000)
	end
	
	--[[
	Pauses timer updating
	]]--
	--function Loader.PauseTimer()
	--	if HeartbeatConnection then
	--		HeartbeatConnection:Disconnect()
	--		HeartbeatConnection = nil
	--	end
	--end
	
	--[[
	Starts timer updating
	]]--
	--function Loader.StartTimer()
	--	if HeartbeatConnection == nil then
	--		HeartbeatConnection = RunService.Heartbeat:Connect(function()
	--			Timer.SetText(
	--				TimeWaiter.FormatSpeedrunTimeIndividual(
	--					(BaseReplicator.GetCurrentTime() / 1000) - MapBeginTime,
	--					3
	--				)
	--			)
	--		end)
	--	end
	--end
	
	--[[
	Returns the specify controller if currently added
	
	Params:
	Name <string> - The name of the controller to retrieve
	]]--
	function Loader.GetController(Name: string)
		return CurrentControllers[Name]
	end
	
	--[[
	Disposes of all current controllers
	]]--
	function Loader.DisposeAllControllers()
		for i, v in pairs(CurrentControllers) do
			v.Dispose()
		end
		
		CurrentControllers = {}
	end
	
	--[[
	Adds a controller to the loader
	
	Params:
	Name <string> - The name to associate the controller with
	Controller <{}> - The loader object
	]]--
	function Loader.AddController(Name: string, Controller: {})
		CurrentControllers[Name] = Controller
	end
	
	--[[
	Adds all default controllers using "default" configurations
	]]--
	function Loader.AddDefaultControllers()
		local Dash = require(Controllers:WaitForChild("Dash")).New(LocalPlayer)
		Dash.Enable()
		
		CurrentControllers["Dash"] = Dash
		CurrentControllers["Swimmer"] = require(Controllers:WaitForChild("Swimmer")).New(Loader, LocalPlayer)
		CurrentControllers["ButtonTimer"] = ButtonTimer.New(ScreenGui)
	end

	Loader.ResponseReceived.Connect(function(Response)
		--LastLoadTime = BaseReplicator.GetCurrentTime()
		--RequestCooldown = Loader.CanSendRequest().CooldownTime
		CooldownExpireTime = BaseReplicator.GetCurrentTime() + Loader.CanSendRequest().CooldownTime
		--print("loader response received")

		local MapLoad = nil
		local NumDescendants = 0
		local LoadError = nil
		local ResponseTable = Response.Data[1]
		local InitialLoadError = Response.Error
		
		local RequestId = Response.RequestId
		local Ids = MapLoader.RequestIds

		if InitialLoadError then
			LoadError = InitialLoadError.Message
		else
			InitialLoadError = nil

			--print(typeof(ResponseTable))
			if typeof(ResponseTable) == "table" then
				LoadError = ResponseTable.LoadError

				if LoadError == nil then
					local MapInfo = ResponseTable.Info

					if typeof(MapInfo) == "table" then
						if RequestId == Ids.Load then
							Loader.StatusChanged.Fire(MapLoader.Status.WaitingForModel, MapInfo)
							Loader.MapReceived.Fire(MapInfo)
							local Model = PlayerGui:WaitForChild(ResponseTable.ModelName, 5)--Response.MapInstance

							if Model and Model:IsA("Model") then
								--local Map = Instance.new("Model")
								--Map.Name = Model.Name

								-- Attempt to load the first batch of descendants
								NumDescendants = MapInfo.NumDescendants or 1
								Loader.StatusChanged.Fire(MapLoader.Status.WaitingForObjects, MapInfo)
								local NumLoadedDescendants = #Model:GetDescendants()
								local Loaded = false
								local LoadDelay = 0

								--local function Load(d, FireSignal)
								--	LoadDelay = 0

								--	if d.Archivable == true then
								--		d:Clone().Parent = Map
								--		NumLoadedDescendants += 1

								--		if FireSignal then
								--			Loader.DescendantLoaded.Fire(NumLoadedDescendants, NumDescendants)
								--		end
								--	end
								--end

								--for i, v in pairs(FirstDescendants) do
								--	Load(v, false)
								--end
								Loader.LoadingMapInfo = MapInfo
								Loader.DescendantLoaded.Fire(NumLoadedDescendants, NumDescendants)

								-- Wait for other descendants to load
								if NumLoadedDescendants >= NumDescendants then
									Loaded = true
								else
									local DescendantMaxDelay = Loader.MaxDescendantLoadTime
									local AddConnection
									AddConnection = Model.DescendantAdded:Connect(function(d)
										NumLoadedDescendants = math.min(NumLoadedDescendants + 1, NumDescendants)
										Loader.DescendantLoaded.Fire(NumLoadedDescendants, NumDescendants)
									end)

									while true do
										if NumLoadedDescendants >= NumDescendants then
											Loaded = true
											break
										elseif LoadDelay > DescendantMaxDelay then
											LoadError = "Exceeded max loading time for each descendant"
											break
										elseif Model.Parent == nil then
											-- Getting here means the server destroyed the clone
											-- before the client could load the map
											LoadError = "Map took too long to load"
											break
										elseif IsAttemptingLoad == false then
											LoadError = "Client cancelled load request"
											break
										end

										LoadDelay += task.wait()
									end

									AddConnection:Disconnect()
								end

								-- Save if loaded
								if Loaded then
									MapLoad = Model:Clone()
									--task.wait() -- just in case
									Model:Destroy()

									local LoadedMapName = MapLoad.Name
									ClientMapStorage[LoadedMapName] = {
										Map = MapLoad,
										Launcher = require(MapLoad:WaitForChild(MapLoader.MapLauncherName)).New(MapLoad, Loader),
										Initialized = false
									}
									
									IsAttemptingLoad = false
									Loader.MapLoadFinished.Fire(LoadedMapName)
								end

								-- Wait for one frame, just in case
								--task.wait()
							else
								LoadError = "Map instance failed to load"
							end
						elseif RequestId == Ids.Start then
							IsAttemptingStart = false
							
							if CurrentMap then
								local LaunchInst = CurrentMap.Launcher

								if LaunchInst then
									if LaunchInst.Name == MapInfo.Name then
										local Now = BaseReplicator.GetCurrentTime()
										Loader.LastMapStartTime = Now
										Loader.StatusChanged.Fire(MapLoader.Status.Starting, MapInfo)
										if LaunchInst.OnClientStart() == true then
											--Loader.CurrentMapName = ResponseTable.Info.Name
											IsInMap = true
											
											--MapBeginTime = Now / 1000
											Timer.ElapsedTime = 0
											Timer.Start()
											Timer.SetVisible(true)
											
											Loader.OnMapBegin.Fire()
										else
											LoadError = "Map failed to start successfully"
										end
									else
										LoadError = "Attempted to start a map that doesn't match the current one"
									end
								else
									LoadError = "No launcher instance is in session"
								end
							else
								LoadError = "No current map is in session"
							end
						elseif RequestId == Ids.End then
							IsInMap = false

							if CurrentMap then
								local LaunchInst = CurrentMap.Launcher

								if LaunchInst then
									if LaunchInst.Name == MapInfo.Name then
										local PlayerWon = MapInfo.HasWon
										
										if typeof(PlayerWon) == "boolean" then
											if LaunchInst.OnClientEnd(PlayerWon) == true then
												CurrentMap = nil
												Loader.OnMapEnd.Fire()
											else
												--LaunchInst.Dispose()
												--LaunchInst = nil
												LoadError = "Failed to end map session. Please try resetting your character."
											end
										else
											LoadError = "HasWon variable isn't a boolean, couldn't check if player won"
										end
										--Loader.CurrentMapName = nil
									else
										LoadError = "Attempted to end a map that doesn't match the current one"
									end
								else
									LoadError = "No launcher instance is in session"
								end
							else
								LoadError = "No current map is in session"
							end
						end
					else
						LoadError = "No map information was provided"
					end
				end
			else
				LoadError = "Server response didn't include any data"
			end
		end

		if LoadError then
			FireError(LoadError)
			--print("error", LoadError)
		end

		-- Just in case
		if MapLoad then
			MapLoad = nil
		end
	end)

	--[[
	Returns:
	<boolean> - If a map is in session
	]]--
	function Loader.IsPlayingMap()
		return CurrentMap ~= nil and IsInMap == true
	end
	
	--[[
	Returns:
	<boolean> - If a win place is currently active
	]]--
	function Loader.IsInWinPlace()
		return CurrentWinLauncher ~= nil
	end

	--[[
	Checks if a map is already loaded from the server
	
	Params:
	Name <string> - The name of the map's model
	
	Returns:
	<boolean> - If the map is loaded
	]]--
	function Loader.IsMapLoaded(Name: string)
		return ClientMapStorage[Name] ~= nil
	end
	
	--[[
	Attempts to retrieve a launcher instance for a loaded map
	
	Params:
	Name <string> - The name of the map
	
	Returns:
	<MapLauncher> - The map's launcher instance, or nil if it couldn't be found
	]]--
	function Loader.GetMapLauncher(Name: string)
		if Loader.IsMapLoaded(Name) then
			return ClientMapStorage[Name].Launcher
		end
	end

	--[[
	Clears the current map storage. Any maps currently
	loaded would have to reload them from the server.
	]]--
	function Loader.ClearMapStorage()
		--CurrentMap = nil
		for i, v in pairs(ClientMapStorage) do
			v.Launcher.Dispose()
			v.Map:Destroy()
		end
		ClientMapStorage = {}
	end
	
	--[[
	Cancels a map trying to load from the server
	]]--
	function Loader.CancelLoad()
		Loader.Cancel(MapLoader.RequestIds.Load)
		IsAttemptingLoad = false
	end
	
	--[[
	Cancels a map trying to start from the client
	]]--
	function Loader.CancelStart()
		Loader.Cancel(MapLoader.RequestIds.Start)
		IsAttemptingStart = false
	end

	--[[
	Attempts to load a map from the server, if it hasn't been
	loaded already.
	
	Params:
	Name <string> - The name of the map's model.
	]]--
	function Loader.LoadMap(Name: string)
		assert(typeof(Name) == "string", "Argument 1 must be a string.")

		local InitialLoadError

		if Loader.CanSendRequest().CooldownRemaining <= 0 then
			local RequestId = MapLoader.RequestIds.Load

			if Loader.IsRequestActive(RequestId) == false then
				IsAttemptingLoad = true
				Loader.Request(BaseReplicator.CreateRequestParams(RequestId, true, nil, Name, false))
			else
				InitialLoadError = "Already awaiting a server response for map loading"
			end
		else
			InitialLoadError = "Can't make a map loading request because cooldown is still active"
		end

		if InitialLoadError then
			FireError(InitialLoadError)
		end
	end

	--[[
	Ends the map for the local player
	
	Params:
	Beaten <boolean> - Whether or not the map was beaten
	]]--
	function Loader.EndMap(Beaten: boolean, WinParams: {})
		assert(typeof(Beaten) == "boolean", "Argument 1 must be a boolean")

		if Loader.IsPlayingMap() then
			Loader.LastMapEndTime = BaseReplicator.GetCurrentTime()
			Timer.Pause()
			Timer.SetVisible(false)
			
			local End = MapLoader.RequestIds.End

			if Loader.IsRequestActive(End) == false then
				--if Beaten then
				--	Loader.LastMapEndTime = WinParams.Time--BaseReplicator.GetCurrentTime()
				--else
				--	Loader.LastMapEndTime = BaseReplicator.GetCurrentTime()
				--end
				
				Loader.Request(BaseReplicator.CreateRequestParams(End, true, nil, "", Beaten, Beaten and WinParams))
			else
				FireError("Already awaiting a server response for map ending")
			end
		else
			error("Cannot end map because no map is in session.")
		end
	end

	--[[
	Attempts to start the currently loaded map
	]]--
	function Loader.StartMap(MapName: string)
		local StartError

		local MapTable = ClientMapStorage[MapName]

		if MapTable then
			local Launcher = MapTable.Launcher--CurrentMap:WaitForChild(MapLoader.MapLauncherName)
			local MapInfo = {
				Name = Launcher.Name,
				Difficulty = Launcher.Difficulty,
				Creators = Launcher.Creators
			}

			if Launcher then
				-- Initialize if needed
				if MapTable.Initialized == false then
					Loader.StatusChanged.Fire(MapLoader.Status.WaitingForInitialize, MapInfo)

					if Launcher.OnClientInitialize() == true then
						MapTable.Initialized = true
					else
						StartError = "Map failed to initialize on the client"
					end
				end

				-- Start only if initialized successfully
				if MapTable.Initialized == true then
					CurrentMap = MapTable
					IsAttemptingStart = true
					Loader.StatusChanged.Fire(MapLoader.Status.WaitingForServer, MapInfo)
					
					--local TimeToWait = MapLoader.CooldownTime / 1000
					--local Elapsed = 0
					--while true do
					--	if Elapsed > TimeToWait then
					--		break
					--	elseif IsAttemptingStart == false then
					--		StartError = "Client cancelled request to start map"
					--	end
						
					--	Elapsed += task.wait()
					--end

					if StartError == nil then
						local Start = MapLoader.RequestIds.Start
						if Loader.IsRequestActive(Start) == false then
							Loader.Request(BaseReplicator.CreateRequestParams(Start, true, nil, MapName, false))
						else
							StartError = "Already awaiting a server response for round starting"
						end
					end
				end
			else
				StartError = "Launcher not found"
			end
		else
			StartError = "Map named '" .. MapName .. "' wasn't loaded to the client"
		end

		if StartError then
			FireError(StartError)
		end
	end
	
	--[[
	Makes the player leave the win place and return to the lobby spawn
	]]--
	function Loader.ExitWinPlace()
		if CurrentWinLauncher then
			CurrentWinLauncher.OnClientEnd()
			CurrentWinLauncher.Dispose()
			CurrentWinLauncher = nil
		end
		
		local Lobby = Loader.Lobby
		MapLauncher.SpawnLocalPlayerAt(Lobby:WaitForChild("_Spawn"))
		MapLauncher.ApplyLightingUsing(require(Lobby:WaitForChild("DefaultLighting")))
		
		local LoaderMusicPlayer = Loader.MusicPlayer
		local LobbyMusic = Loader.LobbyMainMusic
		
		if LoaderMusicPlayer and LoaderMusicPlayer.MainSound ~= LobbyMusic then
			LoaderMusicPlayer.MainSound = LobbyMusic
		end
		
		Loader.OnMapEnd.Fire()
	end
	
	--[[
	Loads and plays a win place/room to the client
	
	Params:
	<Name> - The winroom's name
	]]--
	function Loader.UseWinPlace(Name: string)
		if CurrentWinLauncher == nil then
			local WinPlace = game:GetService("ReplicatedStorage")
			:WaitForChild("WinPlaces")
			:WaitForChild(Name)
			
			if WinPlace then
				CurrentWinLauncher = require(
					WinPlace
					:WaitForChild("Launcher")
				).New(WinPlace, Loader)

				if CurrentWinLauncher.OnClientInitialize() then
					if CurrentWinLauncher.OnClientStart() then
						return
					end
				end
			end
			
			Loader.ExitWinPlace()
			warn("Returned to lobby because the selected win place launcher failed to start")
		end
	end

	--[[
	Fires when an error occurs
	
	Params:
	Message <string> - The error message
	]]--
	Loader.OnLoadError = Signal.New()

	--[[
	Fires when the loading status changes
	
	Params:
	Status <string> - The loading status
	Info <{[string]: any}> - Information on the currently loading/starting map
	]]--
	Loader.StatusChanged = Signal.New()

	--[[
	Fires when progress changes on loading the map's descendants
	
	Params:
	Loaded <number> - The current number of descendants loaded
	MaxLoad <number> - The total number of descendants being loaded from the server
	]]--
	Loader.DescendantLoaded = Signal.New()

	--[[
	Fires when map loading from server to client is finished
	
	Params:
	MapName <string> - The name of the map model that finished loading
	]]--
	Loader.MapLoadFinished = Signal.New()

	--[[
	Fires when a server response for map loading is received
	
	Params:
	Info <table> - Map info table (name, difficulty, creators)
	]]--
	Loader.MapReceived = Signal.New()

	--[[
	Fires when the loading of a map is finished and the map
	has begun.
	]]--
	Loader.OnMapBegin = Signal.New()
	
	--[[
	Fires when the map has successfully ended
	]]--
	Loader.OnMapEnd = Signal.New()

	Loader.AddDisposalListener(function()
		Loader.ClearMapStorage()
		Loader.EndMap()
		Loader.OnLoadError.DisconnectAll()
		Loader.StatusChanged.DisconnectAll()
		Loader.DescendantLoaded.DisconnectAll()
		Loader.MapLoadFinished.DisconnectAll()
		Loader.MapReceived.DisconnectAll()
		Loader.OnMapBegin.DisconnectAll()
		Loader.OnMapEnd.DisconnectAll()
		
		Timer.Dispose()
	end)
	
	Loader.AddDefaultControllers()
	
	return Loader
end

return MapLoader