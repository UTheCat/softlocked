--[[
For making jtoh-style portals work

Names in the "Portals" model should match with PortalData

By udev2192
]]--

local RepModules = game:GetService("ReplicatedStorage"):WaitForChild("SoftlockedReplicated")
local Utils = RepModules:WaitForChild("Utils")
local MapHandles = RepModules:WaitForChild("MapHandles")

local LocalPlayer = game:GetService("Players").LocalPlayer

local Object = require(
	Utils:WaitForChild("Object")
)
local TimeWaiter = require(Utils:WaitForChild("TimeWaiter"))
local TweenGroup = require(Utils:WaitForChild("TweenGroup"))

local MapLoader = require(MapHandles:WaitForChild("MapLoader"))
local MapLoadGui = require(
	MapHandles
	:WaitForChild("Gui")
	:WaitForChild("MapLoad")
)
local MapLoadPrompt = require(
	MapHandles
	:WaitForChild("Gui")
	:WaitForChild("MapPrompt")
)

local BaseComponent = require(
	RepModules
	:WaitForChild("Gui")
	:WaitForChild("Components")
	:WaitForChild("BaseComponent")
)

local Portals = {}
Portals.__index = Portals
Portals.ClassName = script.Name

Portals.TeleportPartName = "Teleport"

local PortalModel = workspace:WaitForChild("Portals")
assert(typeof(PortalModel) == "Instance", "Portals model is missing from Workspace.")

local TeleportSound = script:WaitForChild("TeleportSound")

--[[
Creates a SurfaceGui with a TextLabel for portal information

Returns:
<TextLabel> - The text label created
]]--
function Portals.CreateTextLabel(): TextLabel
	local Label: TextLabel = Instance.new("TextLabel")
	Label.AnchorPoint = Vector2.new(0.5, 0.5)
	Label.Size = UDim2.new(1, 0, 1, 0)
	Label.Position = UDim2.new(0.5, 0, 0.5, 0)
	Label.Font = Enum.Font.Cartoon
	Label.BackgroundTransparency = 1
	Label.BorderSizePixel = 0
	Label.TextScaled = true
	
	return Label
end

--[[
Constructs a new instance of the portal runner

Params:
ScreenGui <ScreenGui> - The screen gui to apply a loading screen to
NotifKit <NotifierKit> - The notifier kit to use in case an error happens
]]--
function Portals.New(ScreenGui: ScreenGui, NotifKit: {})
	local Runner = Object.New(Portals.ClassName)
	local Gui = MapLoadGui.New()
	local Loader = MapLoader.ClientCreate(ScreenGui)
	local Prompt = MapLoadPrompt.New(Loader)
	local Tweens = TweenGroup.New()
	
	local MusicPlayer = Loader.MusicPlayer
	
	Gui.Replicator = Loader
	Portals.Prompt = Prompt
	
	local IsLoading = false
	
	local TouchConnection: RBXScriptConnection
	local SpawnConnection: RBXScriptConnection
	local DeathConnection: RBXScriptConnection
	
	local FadeFrame: Frame = Instance.new("Frame")
	FadeFrame.Visible = false
	FadeFrame.Name = "PortalRunnerFadeFrame"
	FadeFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	FadeFrame.Size = UDim2.new(1, 0, 1, 0)
	FadeFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	FadeFrame.BackgroundTransparency = 1
	FadeFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	
	Runner.FadeTweenInfo = TweenInfo.new(Gui.TweeningInfo.Time, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	Runner.ErrorColor = Color3.fromRGB(220, 0, 0)
	
	function Runner.HideFadeFrame()
		Tweens.KillAll()
		Tweens.Play(FadeFrame, Gui.TweeningInfo, {
			BackgroundTransparency = 1
		}, nil, function()
			FadeFrame.Visible = false
		end)
	end
	
	local function OnLoadEnd()
		Runner.HideFadeFrame()
		IsLoading = false
	end
	
	Prompt.VisibleChanged.Connect(function(IsVisible)
		if not IsVisible then
			task.wait(Prompt.TweeningInfo.Time)
			
			if Prompt.Gui.Visible == false then
				OnLoadEnd()
			end
		end
	end)
	
	local function OnError(Message: string)
		assert(typeof(Message) == "string", "Argument 1 must be a string")
		
		NotifKit.NotifyText(Message, Runner.ErrorColor)
		OnLoadEnd()
	end
	
	local function OnTouch(OtherPart: BasePart)
		if IsLoading == false and Loader.IsPlayingMap() == false and Loader.IsInWinPlace() == false then
			if OtherPart.Name == Portals.TeleportPartName then
				local TouchedPortal = OtherPart.Parent
				if TouchedPortal and TouchedPortal.Parent == PortalModel then
					if not IsLoading then
						IsLoading = true
						Tweens.KillAll()

						TeleportSound:Play()
						--FadeFrame.Visible = true
						--Tweens.Play(FadeFrame, Runner.FadeTweenInfo, {
						--	BackgroundTransparency = 0
						--}, nil, function()
						--	Gui.LoadMap(PortalModel.Name)
						--end)
						Prompt.LoadMap(TouchedPortal.Name)
					end
				end
			end
		end
	end
	
	local function DisconnectVisibleChanged()
		
	end
	
	local function ConnectVisibleChanged()
		
	end
	
	local function DisconnectTouch()
		if TouchConnection then
			TouchConnection:Disconnect()
			TouchConnection = nil
		end
	end
	
	local function DisconnectDeath()
		if DeathConnection then
			DeathConnection:Disconnect()
			DeathConnection = nil
		end
	end
	
	local function ConnectTouch(Char: Model)
		local RootPart: BasePart = Char:WaitForChild("HumanoidRootPart")
		
		if RootPart then
			if TouchConnection == nil then
				TouchConnection = RootPart.Touched:Connect(OnTouch)
			end
		end
	end
	
	local function ConnectDeath(Char: Model)
		local Humanoid: Humanoid = Char:WaitForChild("Humanoid")
		
		if Humanoid and DeathConnection == nil then
			DeathConnection = Humanoid.HealthChanged:Connect(function(Health)
				if Health <= 0 then
					DisconnectDeath()
					DisconnectTouch()

					MusicPlayer.MainSound = nil
					MusicPlayer.PlayMusicZones = false

					if IsLoading then
						Loader.CancelLoad()
						Loader.CancelStart()
					end
				end
			end)
		end
	end
	
	local function OnSpawn(Char: Model)
		if Loader.IsPlayingMap() then
			Loader.EndMap(false)
		end
		
		if Char and TouchConnection == nil then
			DisconnectTouch()
			DisconnectDeath()
			ConnectTouch(Char)
			ConnectDeath(Char)
			
			Loader.ExitWinPlace()
			
			MusicPlayer.MusicZoneHitbox = Char:WaitForChild("HumanoidRootPart")
			MusicPlayer.PlayMusicZones = true
			
			local LobbyMainMusic = Loader.LobbyMainMusic
			if MusicPlayer.MainSound ~= LobbyMainMusic then
				MusicPlayer.MainSound = LobbyMainMusic
			end
		end
	end
	
	function Runner.GetLoader()
		return Loader
	end
	
	Loader.OnLoadError.Connect(OnError)
	Loader.OnMapBegin.Connect(function()
		--DisconnectTouch()
		OnLoadEnd()
	end)
	Loader.OnMapEnd.Connect(function()
		local Char = LocalPlayer.Character
		
		if Char and TouchConnection == nil then
			ConnectTouch(Char)
		end
	end)
	
	local InitCharacter = LocalPlayer.Character
	if InitCharacter then
		task.spawn(OnSpawn, InitCharacter)
	end
	SpawnConnection = LocalPlayer.CharacterAdded:Connect(OnSpawn)
	
	--local ValidTeleports = {}
	
	--for i, v in pairs(PortalData) do
	--	local Portal = PortalModel:WaitForChild(i)
		
	--	if Portal then
	--		--local NameBox: BasePart = Portal:WaitForChild("Name")
	--		--local Teleport: BasePart = Portal:WaitForChild("Teleport")
	--		--local CreatorsBox: BasePart = Portal:WaitForChild("Creators")
	--		--local Particles: ParticleEmitter = Portal:WaitForChild("Particles")
			
	--		--if NameBox and Teleport and CreatorsBox then
	--		--	table.insert(ValidTeleports, Teleport)
				
	--		--	local Diff = v.Difficulty
	--		--	local DiffColor = Diff.Color
	--		--	Teleport.Color = DiffColor
	--		--	Particles.Color = ColorSequence.new(DiffColor)
	--		--end
			
	--		local Teleport = Portal:WaitForChild("Teleports")
	--	end
	--end
	
	FadeFrame.ZIndex = 1
	Gui.Gui.ZIndex = 2
	FadeFrame.Parent = ScreenGui
	Gui.Gui.Parent = ScreenGui
	
	Loader.TimerGui.Parent = ScreenGui
	Prompt.PlayFadeScreen.Parent = ScreenGui
	Prompt.Gui.Parent = ScreenGui
	
	Runner.OnDisposal = function()
		if SpawnConnection then
			SpawnConnection:Disconnect()
			SpawnConnection = nil
		end
		
		if TouchConnection then
			TouchConnection:Disconnect()
			TouchConnection = nil
		end
		
		Gui.Dispose()
		Tweens.Dispose()
		FadeFrame:Destroy()
	end
	
	return Runner
end

return Portals