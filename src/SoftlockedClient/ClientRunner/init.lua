-- Runs the game's client-sided code.
-- By udev2192

local Launchers = script:WaitForChild("Launchers")

local ClientRunner = {}

-- Runs the launcher module under the name specified.
-- Returns the launcher object created.
function ClientRunner.Run(Name)
	assert(typeof(Name) == "string", "Launcher module name must be provided as a string.")
	
	local Launcher = require(Launchers:WaitForChild(Name))
	
	local LauncherObj = Launcher.New()
	LauncherObj.Start()
	
	Launcher = nil
	
	return LauncherObj
end

--[[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RepModules = ReplicatedStorage:WaitForChild("SoftlockedReplicated")
local Adapters = RepModules:WaitForChild("Adapters")
local Replicators = RepModules:WaitForChild("Replicators")
local UtilRepModules = RepModules:WaitForChild("Utils")

local GuiModules = script:WaitForChild("Gui")
local Liquids = script:WaitForChild("Liquids")
local Movement = script:WaitForChild("Movement")
local Notifiers = script:WaitForChild("Notifiers")
local Sound = script:WaitForChild("Sound")
local ZiplineService = script:WaitForChild("ZiplineService")

local Object = require(UtilRepModules:WaitForChild("Object"))
local Runtime = require(UtilRepModules:WaitForChild("Runtime"))
local Util = require(UtilRepModules:WaitForChild("Utility"))

local AreaAdapter = require(Adapters:WaitForChild("AreaAdapter"))
local Hitbox = require(Adapters:WaitForChild("Hitbox"))

local BrowserLib = require(GuiModules:WaitForChild("BrowserLib"))

local MoverFinder = require(Movement:WaitForChild("MoverFinder"))

local NotifierToolkit = require(Notifiers:WaitForChild("NotifierToolkit"))
local Meter = require(Notifiers:WaitForChild("MeterNotification"))

local DeathFX = require(script:WaitForChild("DeathFX"))
local ZipRunner = require(script:WaitForChild("ZiplineRunner"))

local BGM = require(Sound:WaitForChild("BGM"))
local Swimmer = require(Liquids:WaitForChild("Swimmer"))

local Areas = workspace:WaitForChild("Areas")

local ClientRunner = {}
ClientRunner.StartArea = "Lobby"

function ClientRunner.New(Config)
	local Obj = Object.New("PlayerClientRunner")
	Obj.InitializedAt = 0
	Obj.ClientObjects = {}
	Obj.MoverNames = {"JumpPad", "LaunchRamp"}
	
	local Player = Players.LocalPlayer
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local Camera = workspace.CurrentCamera
	
	-- Runs the client stuff.
	function Obj.Start()
		Obj.InitializedAt = os.time()
		
		-- Initialize GUI.
		local ScreenGui = Util.CreateInstance("ScreenGui", {
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 3,
			Name = "MainGui",
			Parent = PlayerGui
		})
		
		-- Create a folder for the ui.
		local MainUi = Util.CreateInstance("Folder", {
			Name = "MainGui",
			Parent = ScreenGui
		})
		
		-- Create the loading ui
		local LoadingText = BrowserLib.New("TextLabel", {
			Size = UDim2.new(0.1, 0, 0.025, 0),
			Position = UDim2.new(0.1, 0, 0.95, 0),
			TextTransparency = 0.5,
			TextStrokeTransparency = 0.5,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "LOADING",
			Parent = MainUi
		})
		
		-- Initialize notifications
		local NotifKit = NotifierToolkit.New()
		NotifKit.SetParent(MainUi)
		
		-- Get the lobby's area adapter
		local LobbyAdapter = AreaAdapter.New(Areas:WaitForChild(ClientRunner.StartArea))
		
		local LobbyBGM = BGM.New()
		LobbyBGM.SoundURL = LobbyAdapter.GetInfo("BGM")
		
		-- Set the lobby lighting.
		LobbyAdapter.UseLighting(true)
		
		-- Initialize mechanics.
		local ObjSwimmer = Swimmer.New(Player)
		ObjSwimmer.SetWorkspaceUse(true)
		
		local ObjZipRunner = ZipRunner.New(Player)
		
		for i, v in pairs(Obj.MoverNames) do
			local Finder = MoverFinder.New(v)
			Obj.ClientObjects[v] = Finder
			Finder.Search()
			Finder = nil
		end
		
		-- Initialize death screen.
		local PlrDeathFx = DeathFX.New(Player)
		PlrDeathFx.SetParent(Camera)
		
		--local AirMeter = BrowserLib.New("TextLabel", {
		--	Size = UDim2.new(0.3, 0, 0.05, 0),
		--	Position = UDim2.new(0.5, 0, 0.75, 0),
		--	Font = Enum.Font.Gotham,
		--	Text = "Air: " .. ObjSwimmer.Air .. "/" .. ObjSwimmer.MaxAir,
		--	Name = "AirMeter",
		--	Parent = MainUi
		--})
		
		-- Initialize meter display
		local AirMeter = nil
		
		-- Display air meter when needed
		ObjSwimmer.AirChanged = function(Air)
			if Air < ObjSwimmer.MaxAir and Air > 0 then
				if AirMeter == nil then
					AirMeter = Meter.New(NotifKit, "Air")
					AirMeter.SetProgressColor(Color3.fromRGB(89, 197, 255))
					AirMeter.Value = Air
					AirMeter.MaxValue = ObjSwimmer.MaxAir
					AirMeter.Appear()
				end
				
				AirMeter.Value = Air
				AirMeter.MaxValue = ObjSwimmer.MaxAir
			else
				if AirMeter ~= nil then
					AirMeter.Dispose()
					AirMeter = nil
				end
			end
		end
		
		-- Get rid of loading text
		coroutine.wrap(function()
			local FadeTweenDur = 0.5
			
			Util.Tween(LoadingText, TweenInfo.new(FadeTweenDur), {TextTransparency = 1, TextStrokeTransparency = 1})
			Runtime.WaitForDur(FadeTweenDur)
			LoadingText:Destroy()
			LoadingText = nil
		end)()
		
		-- Say hello
		--local TestNotifColor = Color3.fromRGB(255, 38, 197)
		--local TestNotifRepeatDelay = 1
		
		--NotifKit.NotifyText("Hello, this is a test", TestNotifColor, 10)
		
		---- Do more notification testing
		--while true do
		--	local RandomWait = math.random(200, 1000) * 0.01
		--	NotifKit.NotifyText("Test, goes away after: " .. RandomWait .. "s", TestNotifColor, RandomWait)
		--	Runtime.WaitForDur(TestNotifRepeatDelay)
		--end
		
		-- Hitbox testing
		
		--local HitboxTesterGui = BrowserLib.New("TextLabel", {
		--	Size = UDim2.new(0.3, 0, 0.1, 0),
		--	Position = UDim2.new(0.5, 0, 0.25, 0),
		--	Font = Enum.Font.Gotham,
		--	Text = "Not touching",
		--	Name = "AirMeter",
		--	Parent = MainUi
		--})
		
		--local TestHitbox = Hitbox.New()
		
		--local HitboxTestPart = workspace:WaitForChild("HitboxTester")
		--TestHitbox.SetPartConnected(HitboxTestPart, true)
		
		--TestHitbox.OnHit.Connect(function(Index, HitPosition, HitSize)
		--	HitboxTesterGui.Text = "Index: " .. tostring(Index) .. "\n HitPosition: " .. tostring(HitPosition) .. "\n HitSize: " .. tostring(HitSize)
		--end)
		
		--TestHitbox.OnHitStop.Connect(function()
		--	HitboxTesterGui.Text = "Not touching"
		--end)
		
		--print("Connect test char added")
		--Player.CharacterAdded:Connect(function(Char)
		--	TestHitbox.UsePart(nil)
		--	TestHitbox.UsePart(Char:WaitForChild("HumanoidRootPart"))
		--	print("Root part binded to hitbox")
		--end)
	end
	
	-- Disposes of the module objects used to
	-- run the client stuff.
	function Obj.Shutdown()
		if Obj.ClientObjects ~= nil then
			for i, v in pairs(Obj.ClientObjects) do
				if v.Dispose ~= nil then
					v.Dispose()
				end
			end
		end
	end
	
	Obj.OnDisposal = function()
		Obj.Shutdown()
	end
	
	return Obj
end
]]--

return ClientRunner