-- Client launcher for the lobby.
-- By udev2192

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RepModules = ReplicatedStorage:WaitForChild("SoftlockedReplicated")
local Adapters = RepModules:WaitForChild("Adapters")
local GuiModules = RepModules:WaitForChild("Gui")
local Replicators = RepModules:WaitForChild("Replicators")
local Sound = RepModules:WaitForChild("Sound")
local UtilRepModules = RepModules:WaitForChild("Utils")

local Package = script.Parent.Parent

local CameraFX = Package:WaitForChild("CameraFX")
local Liquids = Package:WaitForChild("Liquids")
local Movement = Package:WaitForChild("Movement")
local Notifiers = Package:WaitForChild("Notifiers")
--local PartCutters = Package:WaitForChild("PartCutters")
local Runners = Package:WaitForChild("Runners")
local Stands = Package:WaitForChild("Stands")

local GuiBuilds = Package:WaitForChild("GuiBuilds")
local GuiComponents = GuiModules:WaitForChild("Components")

local BaseLauncher = require(UtilRepModules:WaitForChild("BaseLauncher"))
local ObjectGroup = require(UtilRepModules:WaitForChild("ObjectGroup"))
local Runtime = require(UtilRepModules:WaitForChild("Runtime"))
local Util = require(UtilRepModules:WaitForChild("Utility"))

local AreaAdapter = require(Adapters:WaitForChild("AreaAdapter"))
local CharAdapter = require(Adapters:WaitForChild("CharacterAdapter"))
local Hitbox = require(Adapters:WaitForChild("Hitbox"))

local BaseCameraFX = require(CameraFX:WaitForChild("BaseCameraFX"))
local Deathcam = require(CameraFX:WaitForChild("Deathcam"))

local BrowserLib = require(GuiModules:WaitForChild("BrowserLib"))

local Healthbar = require(GuiBuilds:WaitForChild("Healthbar"))
--local IntroText = require(GuiBuilds:WaitForChild("IntroText"))
local RandomTextwall1 = require(GuiBuilds:WaitForChild("RandomTextwall1"))
local SpeedTestMenu = require(GuiBuilds:WaitForChild("SpeedTestMenu"))

local GridMenu = require(GuiComponents:WaitForChild("GridMenu"))
local IconButton = require(GuiComponents:WaitForChild("IconButton"))
local MenuSet = require(GuiComponents:WaitForChild("MenuSet"))
local NpcDialog = require(GuiComponents:WaitForChild("NpcDialog"))

local MoverFinder = require(Movement:WaitForChild("MoverFinder"))

local NotifierToolkit = require(Notifiers:WaitForChild("NotifierToolkit"))
local Meter = require(Notifiers:WaitForChild("MeterNotification"))

local Portals = require(Runners:WaitForChild("Portals"))

local DestroyableStand = require(Stands:WaitForChild("DestroyableStand"))
local MultiplayerStand = require(Stands:WaitForChild("MultiplayerStand"))

local DeathFX = require(Package:WaitForChild("DeathFX"))
--local InteractiveRunner = require(Package:WaitForChild("InteractiveRunner"))
local ZipRunner = require(Package:WaitForChild("ZiplineRunner"))

local MusicPlayer = require(Sound:WaitForChild("MusicPlayer"))
local Swimmer = require(Liquids:WaitForChild("Swimmer"))
--local PartCutFinder = require(PartCutters:WaitForChild("CuttableFinder"))

--local Areas = workspace:WaitForChild("Areas")

local Launcher = {}

-- Starting area name.
local STARTING_AREA_NAME = "Lobby"

function Launcher.New()
	local Obj = BaseLauncher.New()
	Obj.InitializedAt = 0
	Obj.ClientObjects = ObjectGroup.New()
	Obj.MoverNames = {"JumpPad", "LaunchRamp"}

	local Player = Players.LocalPlayer
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local Camera = workspace.CurrentCamera
	
	Obj.BindToShutdown(Obj.ClientObjects.Dispose)

	-- Runs the client stuff.
	Obj.SetStarter(function()
		Obj.InitializedAt = os.time()

		-- Initialize GUI.
		local ScreenGui = Util.CreateInstance("ScreenGui", {
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 3,
			
			-- Important for proper Z-Index behavior
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			
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
		
		local PortalRunner = Portals.New(ScreenGui, NotifKit)
		local MapLoader = PortalRunner.GetLoader()
		
		-- Initialize the player's character adapter.
		local LocalCharAdapter = CharAdapter.New(Player)

		-- Get the lobby's area adapter
		local LobbyAdapter = AreaAdapter.New(workspace:WaitForChild(STARTING_AREA_NAME))
		
		--local TestHitbox = Hitbox.New()
		
		--print("c")
		local LobbyBGMSound = LobbyAdapter.GetInfo("MainBGM")
		--print("d")
		local LobbyBGM = MapLoader.MusicPlayer--MusicPlayer.New()
		
		local BGMAttributionText = BrowserLib.New("TextLabel", {
			Size = UDim2.new(0.5, 0, 0.02, 0),
			Position = UDim2.new(0.5, 0, 0.025, 0),
			TextTransparency = 0.5,
			TextStrokeTransparency = 0.5,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = "",
			ZIndex = 5,
			Parent = MainUi
		})
		
		local function ChangeMusicAttribution(Attribution: string)
			BGMAttributionText.Text = "Now playing: " .. Attribution
			--print("Now playing:", Attribution)
		end
		ChangeMusicAttribution(LobbyBGM.AssetInfo)
		LobbyBGM.AttributionChanged.Connect(ChangeMusicAttribution)
		
		--print("e")
		--LobbyBGM.BindHitbox(TestHitbox)
		--LobbyBGM.MusicMode = MusicPlayer.MusicMode.ByMusicZone
		LobbyBGM.FindMusicZones = true
		LobbyBGM.MainSound = LobbyBGMSound
		
		-- Fade out music on death
		--LocalCharAdapter.DeathEvent.Connect(function()
		--	LobbyBGM.MainSound = nil
		--	LobbyBGM.PlayMusicZones = false
		--end)

		-- Set the lobby lighting.
		LobbyAdapter.UseLighting(true)

		-- Initialize mechanics.
		local ObjSwimmer = Swimmer.New(Player)
		ObjSwimmer.SetWorkspaceUse(true)

		local ObjZipRunner = ZipRunner.New(Player)

		for i, v in pairs(Obj.MoverNames) do
			local Finder = MoverFinder.New(v, LocalCharAdapter)
			Obj.ClientObjects[v] = Finder
			Finder.Search()
			Finder = nil
		end

		-- Initalize cuttable parts.
		--local MainCutFinder = PartCutFinder.New(Areas)
		--MainCutFinder = nil

		-- Initialize death screen.
		local PlrDeathFx = DeathFX.New(LocalCharAdapter)
		--PlrDeathFx.SetParent(Camera)
		PlrDeathFx.Blur.Parent = Camera
		PlrDeathFx.Frame.Parent = MainUi

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
					AirMeter.Value = Air
					AirMeter.Dispose()
					AirMeter = nil
				end
			end
		end
		
		-- Portal runner testing
		--print("testing portals")
		
		
		-- Player stand testing
		--print("Testing player pvp stand")
		--local IntensifyBGMTest = "rbxassetid://6460316914"--5567767035" --//1492179112
		--local LocalPlrStand = DestroyableStand.New(LocalCharAdapter)
		----LocalPlrStand.ToggleTouchConnection(true)
		----LocalPlrStand.ToggleMoveRunner(true)
		--LocalPlrStand.LivesChanged.Connect(function(Lives)
		--	if Lives > 0 then
		--		NotifKit.NotifyText(Lives .. " stand lives left")
		--	elseif Lives == 0 then
		--		NotifKit.NotifyText("Your stand has been taken out. Don't die!")
		--		LobbyBGM.FadeToURL(IntensifyBGMTest) -- Music atmosphere test
		--	elseif Lives < 0 then
		--		NotifKit.NotifyText("Resetting stand lives for the sake of testing")
		--		LobbyBGM.MainSound = LobbyBGMSound
		--		LocalPlrStand.Lives = 3
		--	end
		--end)
		
		-- Initialize multiplayer stands
		--print("Starting multiplayer stands")
		--local MultiStand = MultiplayerStand.New()
		--MultiStand.IncludeLocalPlayer = false
		--MultiStand.SetAutomated(true)
		
		-- Hitbox testing
		--local HitboxTesterGui = BrowserLib.New("TextLabel", {
		--	Size = UDim2.new(0.75, 0, 0.1, 0),
		--	Position = UDim2.new(0.5, 0, 0.25, 0),
		--	Font = Enum.Font.Gotham,
		--	Text = "Not touching",
		--	Name = "HitboxTestLabel",
		--	Visible = false,
		--	Parent = MainUi
		--})

		--local HitboxTestParts = workspace:WaitForChild("HitboxTesters")
		--if HitboxTestParts ~= nil then
		--	for i, v in pairs(HitboxTestParts:GetChildren()) do
		--		if v:IsA("BasePart") then
		--			TestHitbox.ConnectPart(v, true)
		--		end
		--	end
		--else
		--	warn("No hitbox testing parts model was found in the Workspace.")
		--end
		--HitboxTestParts = nil

		--TestHitbox.OnHit.Connect(function(Index, HitRegion)
		--	HitboxTesterGui.Text = "Index: " .. tostring(Index) .. "\n HitPosition: " .. tostring(HitRegion.Center) .. "\n HitSize: " .. tostring(HitRegion.Size) .. "\n HitStatus: " .. tostring(HitRegion.Status)
		--end)

		--TestHitbox.OnHitStop.Connect(function()
		--	HitboxTesterGui.Text = "Not touching"
		--end)
		
		-- Healthbar testing
		local MainHealthbar = Healthbar.New(false)
		MainHealthbar.CirclesEnabled = false
		MainHealthbar.ShakeOnHealthLoss = true

		print("Connect test char added")
		local function OnCharSpawn(Char)
			--TestHitbox.BindToPart(nil)
			--LobbyBGM.PlayMusicZones = true
			
			--if LobbyBGM.MainSound ~= LobbyBGMSound then
			--	LobbyBGM.MainSound = LobbyBGMSound
			--end
			
			local RootPart = Char:WaitForChild("HumanoidRootPart")
			--TestHitbox.BindToPart(RootPart)
			--LobbyBGM.MusicZoneHitbox = RootPart
			--print("Root part binded to hitbox")
			
			MainHealthbar.Humanoid = Char:WaitForChild("Humanoid")
			print("Humanoid binded to healthbar")
		end
		
		local TestChar = Player.Character
		if TestChar ~= nil then
			OnCharSpawn(TestChar)
		end
		TestChar = nil
		
		Player.CharacterAdded:Connect(OnCharSpawn)
		
		MainHealthbar.Gui.Parent = MainUi
		
		-- Test GUI components
		print("Doing sequential gui testing")
		local TestMenuSet = MenuSet.New()
		TestMenuSet.GuiPosition = nil
		
		local TestGridMenu = GridMenu.New()
		TestGridMenu.IsUsingGrid = true
		TestGridMenu.BackImageTransparency = 0.75
		TestGridMenu.SetTitle("Menu")
		TestGridMenu.Gui.Size = UDim2.new(0.5, 0, 0.5, 0)
		TestGridMenu.Gui.ZIndex = 5
		
		-- Gui components that go into the menu set
		TestMenuSet.Add("Main", TestGridMenu)
		TestMenuSet.Add("Ping", SpeedTestMenu.New())
		TestMenuSet.Add("Rant", RandomTextwall1.New())
		
		local SpeedTestButton = IconButton.New()
		SpeedTestButton.SetText("Ping Test")
		
		TestGridMenu.AddComponent(SpeedTestButton)
		
		local TestMenuImage = Util.CreateInstance("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			
			Image = "rbxasset://textures/shadowblurmask.png",
			ScaleType = Enum.ScaleType.Crop,
		})
		
		TestGridMenu.SetImage(TestMenuImage:Clone())
		
		local TypeActions = NpcDialog.TypeActions
		local MultiNpcDialog = NpcDialog.New()
		MultiNpcDialog.UseContinueButton = true
		MultiNpcDialog.TapToFinishEnabled = false
		MultiNpcDialog.ClearWhenHidden = true
		--MultiNpcDialog.TextList = {
		--	"This is a copy of the blox fruits npc dialog system",
		--	"You heard that right, it's a copy, not some 'inspiration'",
		--	"k end of the testing thing"
		--}
		
		local function HideNpcDialog()
			task.wait(2)
			MultiNpcDialog.ClearOptions()
			MultiNpcDialog.Clear()
			MultiNpcDialog.SetVisible(false)
		end
		
		MultiNpcDialog.ActionMap = {
			{TypeActions.Write, "Useless service on your way!"},
			{TypeActions.Wait, 0.5},
			{TypeActions.Call, function()
				print("hi")
			end},
			{TypeActions.Write, " What would you like to do next?"},
			{TypeActions.SetOptions, {
				{
					Id = "OptionA1",
					Name = "Option A",
					ActionMap = {
						{TypeActions.Write, "You chose option A."},
						{TypeActions.Wait, 0.5},
						{TypeActions.Write, " Very well then, please proceed to do the first steps."},
						{TypeActions.Call, HideNpcDialog}
					}
				},

				{
					Id = "OptionB1",
					Name = "Option B",
					ActionMap = {
						{TypeActions.Write, "You chose option B."},
						{TypeActions.Wait, 0.5},
						{TypeActions.Write, " Very well then, please proceed to do the second steps."},
						{TypeActions.Call, HideNpcDialog}
					}
				},
			}
			},
		}
		MultiNpcDialog.Gui.Parent = MainUi
		
		local GridMenuButton1 = IconButton.New()
		GridMenuButton1.SetText("multi-text npc dialog test")
		GridMenuButton1.GetButton().Activated:Connect(function()
			TestMenuSet.HideAll()
			if MultiNpcDialog.Gui.Visible == false then
				print("testing multi-text npc thing")
				MultiNpcDialog.Pause()
				MultiNpcDialog.Clear()
				MultiNpcDialog.SetVisible(true)
				
				--MultiNpcDialog.StopTextList()
				--MultiNpcDialog.UseTextList()
				MultiNpcDialog.UseActionMap()
			end
		end)
		TestGridMenu.AddComponent(GridMenuButton1)
		
		TestGridMenu.AddComponent(IconButton.New())
		
		local IsTestingNpcDialog = false
		local NpcDialogTest = NpcDialog.New()
		NpcDialogTest.Gui.Parent = MainUi
		
		local GridMenuButton3 = IconButton.New()
		GridMenuButton3.SetRichTextEnabled(true)
		GridMenuButton3.SetText("<i>some</i> <b>npc dialog</b> test")
		GridMenuButton3.GetButton().Activated:Connect(function()
			TestMenuSet.HideAll()
			
			if not IsTestingNpcDialog then
				IsTestingNpcDialog = true
				
				print("testing npc dialog")
				
				NpcDialogTest.Clear()
				NpcDialogTest.NextString = "This is a test of the npc dialog thing copied from blox fruits"
				NpcDialogTest.ScrollSpeed = 30
				NpcDialogTest.SetVisible(true)
				NpcDialogTest.Type(NpcDialogTest.NextString:len())
				
				task.wait(5)
				NpcDialogTest.Clear()
				NpcDialogTest.SetVisible(false)
				
				IsTestingNpcDialog = false
			end
		end)
		TestGridMenu.AddComponent(GridMenuButton3)
		
		local SecondaryMenuButton = IconButton.New()
		SecondaryMenuButton.SetRichTextEnabled(true)
		SecondaryMenuButton.SetText("Help")
		TestGridMenu.AddComponent(SecondaryMenuButton)
		
		local function AddAspectRatioToMenu(Gui)
			local Arc = Instance.new("UIAspectRatioConstraint")
			Arc.AspectRatio = 1.5
			Arc.DominantAxis = Enum.DominantAxis.Height
			Arc.Parent = Gui
		end
		
		SpeedTestButton.GetButton().Activated:Connect(function()
			TestMenuSet.Show("Ping")
		end)
		
		SecondaryMenuButton.GetButton().Activated:Connect(function()
			TestMenuSet.Show("Rant")
		end)
		
		-- Mute button
		local DefaultMasterVolume = LobbyBGM.MasterVolume
		
		local MusicToggle = IconButton.New("Music: On")
		MusicToggle.GetButton().Activated:Connect(function()
			if LobbyBGM.MasterVolume <= 0 then
				LobbyBGM.MasterVolume = DefaultMasterVolume
				MusicToggle.SetText("Music: On")
			else
				LobbyBGM.MasterVolume = 0
				MusicToggle.SetText("Music: Off")
			end
		end)
		TestGridMenu.AddComponent(MusicToggle)
		
		local TestSetGui = TestMenuSet.Gui
		TestSetGui.Size = UDim2.new(0.5, 0, 0.5, 0)
		TestSetGui.ZIndex = 10
		AddAspectRatioToMenu(TestSetGui)
		TestSetGui.Parent = MainUi
		
		--print("showing menu in 5 seconds")
		--task.wait(5)
		--TestGridMenu.SetVisible(true)
		
		--print("hiding menu in 3 seconds")
		--task.wait(3)
		--TestGridMenu.SetVisible(false)
		
		print("displaying a button to re-toggle the menu")
		local TestMenuButton = IconButton.New()
		TestMenuButton.BackImageTransparency = 0.75
		TestMenuImage.Image = "rbxassetid://7108912646"
		TestMenuButton.SetImage(TestMenuImage:Clone())
		
		TestMenuButton.GetButton().Activated:Connect(function()
			if TestGridMenu.IsFadingIn() then
				TestMenuSet.HideAll()
			else
				TestMenuSet.Show("Main")
			end
		end)
		
		TestMenuButton.SetText("Menu")
		Util.ApplyProperties(TestMenuButton.Gui, {
			Size = UDim2.new(0.075, 0, 0.075, 0),
			Position = UDim2.new(0.075, 0, 0.5, 0),
			Parent = MainUi
		})
		TestMenuButton.SetVisible(true)
		
		--print("testing intro text")
		--local TestIntroText = IntroText.New("Bee Swarm Obby [Insane] by Onett")
		--local TestIntroDisplayed = false
		--TestIntroText.VisibleChanged.Sync = true
		--TestIntroText.Color = Color3.fromRGB(0, 58, 220)
		--TestIntroText.Gui.Parent = MainUi
		
		--print("Test interactives")
		--local TestInteractiveRunner = InteractiveRunner.New()
		--TestInteractiveRunner.AdaptInstance(Areas)
		--TestInteractiveRunner.RunAll()
		
		-- Test camera effects
		print("now testing deathcam")
		local DeathcamTest = Deathcam.New()
		DeathcamTest.ResetsCamera = true
		DeathcamTest.ChangesFov = true
		DeathcamTest.FocusedFov = 50
		DeathcamTest.Bind(LocalCharAdapter)
		
		--print("now testing camera effects")
		--local CameraFXTester = BaseCameraFX.New()
		--CameraFXTester.OffsetScale = 1
		
		--local Head
		
		--coroutine.wrap(function()
		--	while true do
		--		if Head ~= nil then
		--			CameraFXTester.FollowedCFrame = Head.CFrame
		--		end
				
		--		task.wait()
		--	end
		--end)()
		
		--print("Now testing for camera FX id:", CameraFXTester.GetRenderIndex())
		--CameraFXTester.Follow()
		
		--local function OnCharLoadForCamFX(Parts)
		--	Head = Player.Character:WaitForChild("Head")
		--end
		
		--if LocalCharAdapter.Parts ~= nil then
		--	OnCharLoadForCamFX(LocalCharAdapter.Parts)
		--end
		--LocalCharAdapter.RespawnEvent.Connect(OnCharLoadForCamFX)
		
		-- Register client objects
		local ClientObjects = Obj.ClientObjects
		if ClientObjects ~= nil then
			for i, v in pairs(
				{
					LobbyBGM, LobbyBGMSound, LobbyAdapter, PortalRunner
				}
				) do
				ClientObjects.Add(v)
			end
		end
		
		local LeaveEvent
		LeaveEvent = Players.PlayerRemoving:Connect(function(Left)
			if Left == Player then
				LeaveEvent:Disconnect()
				LeaveEvent = nil
				
				Obj.Shutdown()
				
				print("cleaned client objects at " .. DateTime.now():ToIsoDate())
			end
		end)

		-- Get rid of loading text and display place/build version
		task.spawn(function()
			local FadeTweenDur = 0.5
			local FadeTween = TweenInfo.new(FadeTweenDur, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

			Util.Tween(LoadingText, FadeTween, {TextTransparency = 1, TextStrokeTransparency = 1})
			Runtime.WaitForDur(FadeTweenDur)
			LoadingText.Text = "BUILD V" .. game.PlaceVersion
			Util.Tween(LoadingText, FadeTween, {TextTransparency = 0.5, TextStrokeTransparency = 0.5})
			
			FadeTween, FadeTweenDur = nil, nil
		end)
	end)

	return Obj
end

return Launcher