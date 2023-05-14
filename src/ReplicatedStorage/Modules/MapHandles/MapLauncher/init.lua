--[[
A base class for running maps and letting them use custom code easily
This also allows for maps to have custom anticheat

By udev2192
]]--

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BaseInteractive = require(script.Parent:WaitForChild("Interactives"):WaitForChild("BaseInteractive"))
local Object = BaseInteractive.GetObjectClass()
local Signal = BaseInteractive.GetSignalClass()
local Utils = BaseInteractive.GetGeneralUtils()
local TimeWaiter = require(BaseInteractive.GetUtilPackage():WaitForChild("TimeWaiter"))

local MapLauncher = {}
MapLauncher.__index = MapLauncher

MapLauncher.InteractiveValueId = "Interactive"
MapLauncher.MapsFolderName = "MapContainer"
MapLauncher.SpeedrunDecimalPrecision = 3

MapLauncher.Resources = {
	WinSound = script:WaitForChild("WinSound")
}

--[[
Returns:
<BaseInteractive> - The BaseInteractive class, which is used for implementing
					map mechanics and other things
]]--
function MapLauncher.GetBaseInteractive()
	return BaseInteractive
end

--[[
Creates a difficulty info table

Params:
Index <number> - The index of the difficulty to use as an identifier
Name <string?> - The name of the difficulty
Color <Color3?> - The difficulty's color

Returns:
<table> - The created difficulty info table
]]--
function MapLauncher.CreateDifficulty(Index: number, Name: string?, Color: Color3?)
	assert(typeof(Index) == "number", "Argument 1 must be a number")
	assert(Name == nil or typeof(Name) == "string", "Argument 2 must be a string or nil")
	assert(Color == nil or typeof(Color) == "Color3", "Argument 3 must be a Color3")

	return {
		Index = Index,
		Name = Name or "n/a",
		Color = Color or Color3.fromRGB(128, 128, 128)
	}
end


--[[
Creates a win request table

Params:
Time <number> - The time in milliseconds that the completion took

Returns:
<table> - The created win request table
]]--
function MapLauncher.CreateWinParams(Time: number)
	assert(typeof(Time) == "number", "Argument 1 must be a number")

	return {
		Time = Time
	}
end

--[[
Returns:
<Folder> - The workspace folder used to hold maps
]]--
function MapLauncher.GetMapContainer(): Folder
	local Name = MapLauncher.MapsFolderName
	local Folder = workspace:FindFirstChild(Name)

	if Folder == nil then
		Folder = Instance.new("Folder")
		Folder.Name = Name
		Folder.Parent = workspace
	end

	return Folder
end

function MapLauncher.SpawnLocalPlayerAt(MapSpawn: BasePart)
	BaseInteractive.AssertClient()

	local LocalPlayer = game:GetService("Players").LocalPlayer

	if LocalPlayer then
		local Char = LocalPlayer.Character

		if Char then
			local PrimaryPart = Char.PrimaryPart

			if PrimaryPart then
				if MapSpawn then
					local SpawnCFrame = MapSpawn.CFrame

					PrimaryPart.CFrame = SpawnCFrame + Vector3.new(
						0,
						(BaseInteractive.DefaultCharacterSize.Y / 2) + (MapSpawn.Size.Y / 2),
						0
					)
				end
			end
		end
	end
end

--[[
<table> - Default set of information for maps to use
]]--
MapLauncher.DefaultInfo = {
	-- Credit to Juke's Towers of Hell for the assortment of difficulty rankings
	Difficulties = {
		-- tower game difficulties, as of February 2022
		MapLauncher.CreateDifficulty(1, "Easy", Color3.fromRGB(118, 244, 71)),
		MapLauncher.CreateDifficulty(2, "Medium", Color3.fromRGB(255, 255, 2)),
		MapLauncher.CreateDifficulty(3, "Hard", Color3.fromRGB(254, 124, 0)),
		MapLauncher.CreateDifficulty(4, "Difficult", Color3.fromRGB(255, 12, 4)),
		MapLauncher.CreateDifficulty(5, "Challenging", Color3.fromRGB(193, 0, 0)),
		MapLauncher.CreateDifficulty(6, "Intense", Color3.fromRGB(25, 40, 50)),
		MapLauncher.CreateDifficulty(7, "Remorseless", Color3.fromRGB(201, 1, 201)),
		MapLauncher.CreateDifficulty(8, "Insane", Color3.fromRGB(0, 58, 220)),
		MapLauncher.CreateDifficulty(9, "Extreme", Color3.fromRGB(3, 137, 255)),
		MapLauncher.CreateDifficulty(10, "Terrifying", Color3.fromRGB(1, 255, 255)),
		MapLauncher.CreateDifficulty(11, "Catastrophic", Color3.fromRGB(255, 255, 255)),

		-- rng difficulties (according to the obby community)
		MapLauncher.CreateDifficulty(12, "Horrific", Color3.fromRGB(236, 178, 250)),
		MapLauncher.CreateDifficulty(13, "Unreal", Color3.fromRGB(83, 24, 139)),
		MapLauncher.CreateDifficulty(14, "nil", Color3.fromRGB(101, 102, 109)),
	},

	FallbackDifficulty = MapLauncher.CreateDifficulty(0)
}

--[[
<number> - The time difference in milliseconds that win validation checks
		   can allow between the win time stored on the server
		   and the win time sent by a client
		   
		   This should be slightly above the ping that Roblox counts as
		   a disconnect
]]--
MapLauncher.WinPingAllowance = 11 * 1000

function MapLauncher.ApplyLightingUsing(LightingTable: {}, TweeningInfo: TweenInfo?)
	local Properties = LightingTable.Properties

	if Properties then
		Utils.Tween(
			game:GetService("Lighting"),
			TweeningInfo or TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			Properties
		)
	end
end

--[[
Constructor function for map launchers

Params:
Model <Instance> - The model of the map
Loader <MapLoader> - The loader being used to run the launcher
]]--
function MapLauncher.New(Model: Instance, Loader: {})
	local Map = Object.New()
	--local Info = require(Model:WaitForChild("Info"))

	-- UserIds in the map
	local UsersInMap = {}

	-- Custom interactive definitions
	local CustomInteractives = {}

	-- Currently loaded interactives
	local LoadedInteractives: {BaseInteractive.InteractiveObject} = {}
	
	local CurrentWinpad: BasePart
	local WinpadTouchConnection: RBXScriptConnection
	local WinpadOriginalColor: Color3
	local WinpadOriginalMaterial: Enum.Material

	Map.Name = ""
	Map.Difficulty = MapLauncher.DefaultInfo.FallbackDifficulty
	Map.Creators = ""
	Map.Description = ""
	Map.ThumbnailId = "https://www.roblox.com/asset/?id=9618869998"

	--[[
	<number> - The minimum win time in seconds
	]]--
	Map.MinTime = 0
	
	--[[
	<MapLoader> - A reference to the map loader being used to launch the map
	]]--
	--Map.Loader = nil
	
	--[[
	Returns:
	<Loader> - Corresponding map loader for the script context (client or server)
	]]--
	function Map.GetLoader()
		return Loader
	end

	--[[
	Returns:
	<string> - The text intended to be displayed when the player is dropped into the map
	]]--
	function Map.GetIntroText()
		local Name = Map.Name
		local Diff = Map.Difficulty
		local Creators = Map.Creators

		local Text = ""

		if Name then
			Text = Name
		end

		if Diff then
			Text ..= " [" .. Diff.Name .. "]"
		end

		if Creators then
			Text ..= " by " .. Creators
		end

		return Text
	end
	
	--[[
	Displays default intro text at the top of the screen
	]]--
	function Map.DisplayIntroText()
		BaseInteractive.DisplayIntroText(Map.GetIntroText(), Map.Difficulty.Color)
	end
	
	--[[
	Applies the map's default lighting
	]]--
	function Map.ApplyLighting(TweeningInfo: TweenInfo?)
		local Default = Model:WaitForChild("DefaultLighting")
		
		if Default then
			--local DefaultTable = require(Default)
			--local Properties = DefaultTable.Properties
			
			--if Properties then
			--	Utils.Tween(
			--		game:GetService("Lighting"),
			--		TweeningInfo or TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			--		Properties
			--	)
			--end
			
			MapLauncher.ApplyLightingUsing(require(Default), TweeningInfo)
		end
	end
	
	--[[
	Unlinks the winpad from the map
	]]--
	function Map.UnlinkWinpad()
		if WinpadTouchConnection then
			WinpadTouchConnection:Disconnect()
			WinpadTouchConnection = nil
		end
		
		if CurrentWinpad then
			if WinpadOriginalColor then
				CurrentWinpad.Color = WinpadOriginalColor
				WinpadOriginalColor = nil
			end
			
			if WinpadOriginalMaterial then
				CurrentWinpad.Material = WinpadOriginalMaterial
				WinpadOriginalMaterial = nil
			end
			
			CurrentWinpad = nil
		end
	end
	
	--[[
	Links a winpad to the map (winpad refers to the platform you touch to beat a tower)
	]]--
	function Map.LinkWinpad()
		local Winpad: BasePart = Model:FindFirstChild("WinPad")
		
		if Winpad then
			if WinpadTouchConnection == nil then
				CurrentWinpad = Winpad
				
				WinpadTouchConnection = Winpad.Touched:Connect(function(OtherPart)
					if OtherPart == BaseInteractive.GetCharacterHandle().Parts.Hitbox then
						if WinpadTouchConnection then
							WinpadTouchConnection:Disconnect()
							WinpadTouchConnection = nil
						end
						
						Map.UnlinkWinpad()

						local MapTimer = Loader.MapTimer
						MapTimer.Pause()
						Loader.EndMap(true, MapLauncher.CreateWinParams(MapTimer.ElapsedTime * 1000))
						
						--local MusicPlayer = Loader.MusicPlayer
						--MusicPlayer.MainSound = MapLauncher.Resources.WinSound
						--MusicPlayer.PlayMusicZones = false
						
						--local WinpadMask = Winpad:Clone()
						--WinpadMask.Size += Vector3.new(0.1, 0.1, 0.1)
						--WinpadMask.Color = Color3.fromRGB(255, 255, 255)
						--WinpadMask.Material = Enum.Material.Neon
						--WinpadMask.Transparency = 0.5
						--WinpadMask.Parent = Winpad
						
						--local WinTween = TweenService:Create(
						--	WinpadMask,
						--	TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
						--	{Transparency = 1}
						--)
						--WinTween.Completed:Connect(function()
						--	WinTween:Destroy()
						--	WinpadMask:Destroy()
							
						--	Map.UnlinkWinpad()
							
						--	task.wait(1)

						--	local MapTimer = Loader.MapTimer
						--	MapTimer.Pause()
						--	Loader.EndMap(true, MapLauncher.CreateWinParams(MapTimer.ElapsedTime * 1000))
						--end)
						--WinTween:Play()
					end
				end)
			end
			
			if Winpad:GetAttribute("FlashMaterials") == true then
				task.spawn(function()
					if WinpadTouchConnection then
						WinpadOriginalColor = Winpad.Color
						WinpadOriginalMaterial = Winpad.Material
						
						local Elapsed = 0
						local FlashInterval = "FlashInterval"
						local Materials = Enum.Material
						
						local MaterialList = Materials:GetEnumItems()
						local NumMaterials = #MaterialList
						local Air = Materials.Air

						while WinpadTouchConnection do
							if Elapsed > Winpad:GetAttribute(FlashInterval) then
								Elapsed = 0
								
								Winpad.BrickColor = BrickColor.Random()
								
								local NewMaterial = MaterialList[math.random(1, NumMaterials)]
								if NewMaterial ~= Air then
									Winpad.Material = NewMaterial
								end
							end
							
							Elapsed += task.wait()
						end
					end
				end)
			end
		end
	end

	--[[
	Returns if the player's win time is valid
	The actual win time is calculated by the client
	for the sake of speedrunners
	
	Params:
	UserId <number> - The player's UserId
	ClientRunTime <number> - The completion time to validate
	
	Returns:
	<boolean> - If the win time is valid
	]]--
	function Map.IsValidTime(UserId, ClientRunTime)
		print("Checking win time")
		if typeof(ClientRunTime) == "number" and ClientRunTime > 0 then
			print("Time looks good at first glance")
			local EnterLog = UsersInMap[UserId]

			if EnterLog then
				print("Entry log found, check actual time")
				local CurrentServerTime = DateTime.now().UnixTimestampMillis
				
				-- How long the run is supposed to last
				local ServerRunTime = CurrentServerTime - EnterLog.TimeEntered
				print("(unit: milliseconds)\n server time:", ServerRunTime, "\n client time:", ClientRunTime, "\n difference:", math.abs(ServerRunTime - ClientRunTime))
				
				-- Verify that the difference between the server and client provided time
				-- are within the win ping allowance
				
				--local ServerRunTime = math.abs(CurrentServerTime - ServerTime)
				if math.abs(ServerRunTime - ClientRunTime) <= MapLauncher.WinPingAllowance then
					print("win ping check passed")
					if ServerRunTime >= Map.MinTime then
						print("player", UserId, "wins")
						return true
					end
				end
			end
		end

		return false
	end

	--[[
	Returns if the player's win is valid, excluding
	any custom win checks
	
	Params:
	UserId <number> - The player's UserId
	WinParams <table> - The win parameters table sent by the client
	
	Returns:
	<boolean> - If the win is valid
	]]--
	function Map.CanWinDefault(UserId, WinParams)
		print("Now checking if player", UserId, "'s win is valid")
		return typeof(WinParams) == "table" and Map.IsValidTime(UserId, WinParams.Time)
	end

	--[[
	Returns:
	<boolean> - If the user id is playing the map
	]]--
	function Map.IsUserIdPlaying(UserId: number)
		return UsersInMap[UserId] ~= nil
	end

	--[[
	Removes a player from the map's playing list
	
	Params:
	UserId <number> - The player's UserId
	]]--
	function Map.RemoveUserId(UserId: number)
		if UsersInMap[UserId] then
			UsersInMap[UserId] = nil
		end
	end

	--[[
	Adds a player into the map's playing list.
	This will assist in win validation
	
	Params:
	UserId <number> - The player's UserId
	]]--
	function Map.AddUserId(UserId: number)
		UsersInMap[UserId] = {
			TimeEntered = DateTime.now().UnixTimestampMillis
		}
	end

	--[[
	Gets a custom-defined definition added
	by DefineInteractive().
	
	Params:
	Name <string> - The name of the class definition
	
	Returns:
	<table?> - The definition (or nil if it's not defined)
	]]--
	function Map.GetInteractiveDefinition(Type: string)
		assert(typeof(Type) == "string", "Argument 1 must be a string")

		return CustomInteractives[Type]
	end

	--[[
	Removes a custom interactive definition
	
	Params:
	Name <string> - The name of the class definition
	]]--
	function Map.UndefineInteractive(Type: string)
		assert(typeof(Type) == "string", "Argument 1 must be a string")

		if CustomInteractives[Type] then
			CustomInteractives[Type] = nil
		end
	end

	--[[
	Adds a custom interactive class definition so that
	it can be loaded using the default loop
	
	You may know "custom interactive class" as
	"Custom Client Object"
	
	Params:
	Name <string> - The name of the class definition
	Class <table> - The class definition
	]]--
	function Map.DefineInteractive(Type: string, Class: {})
		assert(typeof(Type) == "string", "Argument 1 must be a string")
		assert(typeof(Class) == "table", "Argument 2 must be a class table")

		CustomInteractives[Type] = Class
	end

	--[[
	Shuts down all currently loaded interactives but doesn't dispose
	them so they can be used for later
	
	Useful for quick-restarting a map and certain other things
	]]--
	function Map.ShutdownInteractives()
		for i, v in pairs(LoadedInteractives) do
			local OnShutdown = v.OnShutdown
			
			if OnShutdown then
				OnShutdown()
			end
		end
	end

	--[[
	Starts all currently loaded interactives
	]]--
	function Map.StartInteractives()
		for i, v in pairs(LoadedInteractives) do
			local OnStart = v.OnStart
			
			if OnStart then
				OnStart()
			end
		end
	end
	
	--[[
	Initializes all currently loaded interactives
	]]--
	function Map.InitializeInteractives()
		for i, v in pairs(LoadedInteractives) do
			local OnInitialize = v.OnInitialize
			
			if OnInitialize then
				OnInitialize()
			end
		end
	end

	--[[
	Disposes all currently loaded interactives
	]]--
	function Map.DisposeInteractives()
		for i, v in pairs(LoadedInteractives) do
			v.Dispose()
		end

		LoadedInteractives = {}
	end
	
	--[[
	Spawns the local player's character in the map
	]]--
	function Map.SpawnLocalPlayer()
		--BaseInteractive.AssertClient()
		
		--local LocalPlayer = game:GetService("Players").LocalPlayer
		
		--if LocalPlayer then
		--	local Char = LocalPlayer.Character
			
		--	if Char then
		--		local PrimaryPart = Char.PrimaryPart
				
		--		if PrimaryPart then
		--			local MapSpawn: BasePart = Model:WaitForChild("Spawn")
					
		--			if MapSpawn then
		--				local SpawnCFrame = MapSpawn.CFrame
						
		--				PrimaryPart.CFrame = SpawnCFrame + Vector3.new(
		--					0,
		--					(BaseInteractive.DefaultCharacterSize.Y / 2) + (MapSpawn.Size.Y / 2),
		--					0
		--				)
		--			end
		--		end
		--	end
		--end
		
		MapLauncher.SpawnLocalPlayerAt(Model:WaitForChild("Spawn"))
	end

	--[[
	Load an interactive using the information provided
	in the current launcher instance or
	from a global definition and initializes them
	
	Params:
	Type <string> - The type of interactive to use
	... <any> - Constructor arguments to be handled by the interactive
	]]--
	function Map.LoadInteractive(Type: string, ...: any)
		assert(typeof(Type) == "string", "Argument 1 must be a string")

		local Interact = Map.GetInteractiveDefinition(Type)
		if Interact == nil then
			Interact = BaseInteractive.GetByName(Type)
		end

		if Interact then
			table.insert(LoadedInteractives, Interact.New(...))
		end
	end

	--[[
	Makes the client load and start interactives
	using the default loop
	]]--
	function Map.DefaultLoadInteractives()
		local ClassName = BaseInteractive.ValueClassName
		local InteractId = MapLauncher.InteractiveValueId

		for i, v in pairs(Model:WaitForChild("Interactives"):GetDescendants()) do
			if v.ClassName == ClassName and v.Name == InteractId then
				Map.LoadInteractive(v.Value, v, Map)
			end
		end
	end
	
	--[[
	Displays victory text
	]]--
	function Map.DisplayWinText()
		--local Decimals = MapLauncher.SpeedrunDecimalPrecision
		--local Minutes, Seconds, Milliseconds = TimeWaiter.GetSpeedrunTime(
		--	(Loader.LastMapEndTime - Loader.LastMapStartTime) / 1000
		--	, Decimals
		--)
		
		--BaseInteractive.DisplayIntroText(
		--	"Winner! ("
		--		.. tostring(Minutes) .. ":" .. tostring(Seconds) .. string.format("%." .. tostring(Decimals) .. "d", Milliseconds)
		--	.. ")",
		--	Color3.fromRGB(0, 255, 127)
		--)
		
		BaseInteractive.DisplayIntroText(
			"Winner! ("
				.. TimeWaiter.FormatSpeedrunTime((Loader.LastMapEndTime - Loader.LastMapStartTime) / 1000, 3)
				.. ")",
			Color3.fromRGB(0, 255, 127)
		)
	end

	--[[
	Uses default client win code
	]]--
	function Map.UseDefaultWin()
		Model.Parent = nil
		Map.ShutdownInteractives()
		
		Loader.UseWinPlace("Default")
		Map.DisplayWinText()
	end

	-- Loading signals here

	--[[
	Callback that's fired when a player requests to enter
	the map.
	
	Params:
	Player <Player> - The player that made the request
	
	Expected return:
	<boolean> - Whether or not they can get in
	]]--
	Map.OnMapRequest = function(Player)
		return Map.IsUserIdPlaying(Player.UserId) == false
	end

	--[[
	Callback that's fired when a player claims
	to have won a map
	
	Params:
	Player <Player> - The player that made the request
	WinParams <table> - Win parameters (such as run time)
	
	Expected return:
	<boolean> - Whether or not they actually won
	]]--
	Map.OnWinRequest = function(Player, WinParams)
		print("Win request from", Player.Name)
		return Map.CanWinDefault(Player.UserId, WinParams)
	end

	--[[
	Fired when a player is authorized to enter the map
	
	Params:
	Player <Player> - The player that made the request
	]]--
	Map.OnPlayerEnter = BaseInteractive.CreateSyncedSignal()

	--[[
	Fired when a player leaves the map
	
	Params:
	Player <Player> - The player that made the request
	Beaten <boolean> - If the player beat the map
	]]--
	Map.OnPlayerLeave = BaseInteractive.CreateSyncedSignal()

	--[[
	Callback that's fired when the client requests to initialize the map
	
	Expected return:
	<boolean> - If map initialization was successful.
	]]--
	Map.OnClientInitialize = function()
		Map.DefaultLoadInteractives()
		Map.InitializeInteractives()
		return true
	end

	--[[
	Callback that's fired when the client requests to enter the map
	
	Expected return:
	<boolean> - If map starting was successful.
	]]--
	Map.OnClientStart = function()
		Map.StartInteractives()
		Map.LinkWinpad()
		Model.Parent = MapLauncher.GetMapContainer()
		Map.SpawnLocalPlayer()
		Map.DisplayIntroText()
		
		return true
	end

	--[[
	Callback that's fired when the client requests to leave the map
	
	Params:
	Beaten <boolean> - If the local player beat the map
	]]--
	Map.OnClientEnd = function(Beaten)
		Map.UnlinkWinpad()
		
		if Beaten then
			Map.UseDefaultWin()
		else
			Model.Parent = nil
			Map.ShutdownInteractives()
		end
		
		return true
	end
	
	--[[
	Callback that's fired when the client requests to remove the map
	from the computer's memory
	
	Whatever binded to this callback should make it so interactives
	would have to be loaded again
	]]--
	Map.OnClientRemove = Map.DisposeInteractives
	
	--Map.AddDisposalListener(function()
	--	if RunService:IsClient() then
	--		Map.OnClientEnd()
	--		Map.OnClientRemove()
	--	end
	--end)
	if RunService:IsClient() then
		Map.OnDisposal = Map.OnClientRemove
	end

	return Map
end

return MapLauncher