--[[
gui that loads a map from the server, initializes it,
and when done, asks the user if they wanna play it
]]--

local MapHandles = script.Parent.Parent
local RepModules = MapHandles.Parent
local GuiComponents = RepModules:WaitForChild("Gui"):WaitForChild("Components")
local RepUtils = RepModules:WaitForChild("Utils")

local GridMenu = require(GuiComponents:WaitForChild("GridMenu"))
local IconButton = require(GuiComponents:WaitForChild("IconButton"))
local MapLoader = require(MapHandles:WaitForChild("MapLoader"))
local TweenGroup = require(RepUtils:WaitForChild("TweenGroup"))

local CreateInstance: (ClassName: string, Properties: {}) -> Instance = require(RepUtils:WaitForChild("Utility")).CreateInstance

local MapPrompt = {}

function MapPrompt.CreateInfoLabel(Name: string, Size: UDim2, Position: UDim2): TextLabel
	return CreateInstance("TextLabel", {
		Name = Name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = Position,
		Size = Size,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,

		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		Font = Enum.Font.Gotham,

		TextTransparency = 1,
		TextStrokeTransparency = 1
	})
end

function MapPrompt.New(Loader: {})
	assert(typeof(Loader) == "table", "Argument 1 must be a Loader object.")
	
	local Prompt = GridMenu.New()
	local PromptTweenGroup = TweenGroup.New()
	local InfoTweenGroup = TweenGroup.New()
	
	local InfoStorage = {}
	local InfoLabels: {[string]: TextLabel} = {}
	
	local LoaderConnections = {}
	local IsFadingIn = false
	local PlayConnection: RBXScriptConnection
	
	Prompt.IsUsingGrid = false
	Prompt.SetTitle("MAP SELECT")
	Prompt.SetImage(CreateInstance("ImageLabel", {
		Name = "BgImage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		ScaleType = Enum.ScaleType.Crop,
		BackgroundTransparency = 1,
		ImageTransparency = 0,
		Image = "https://www.roblox.com/asset/?id=9618869998"
	}))
	
	Prompt.IsShowingInfo = false
	Prompt.InfoFrameHidePos = UDim2.new(0.4, 0, 0.554, 0)
	Prompt.InfoFrameShowPos = UDim2.new(0.5, 0, 0.554, 0)
	
	Prompt.StatsTweeningInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	Prompt.PlaySound = script:WaitForChild("PlayClick")
	
	local PromptFrame: Frame = Prompt.Gui
	PromptFrame.ZIndex = 3
	PromptFrame.Size = UDim2.new(0.5, 0, 0.5, 0)
	PromptFrame.Name = "MapPrompt"
	
	local PlayFade: Frame = CreateInstance("Frame", {
		Name = "PlayFadeScreen",
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0)
	})
	
	local LoadingText: TextLabel = CreateInstance("TextLabel", {
		Name = "LoadingText",
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0.5, 0, 0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundTransparency = 1,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		BorderSizePixel = 0,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.Gotham,
		TextScaled = true,
	})
	
	---
	local InfoFrame: Frame = CreateInstance("Frame", {
		Name = "Info",
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = Prompt.InfoFrameHidePos,
		Size = UDim2.new(0.8, 0, 0.55, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = PromptFrame
	})
	
	InfoLabels.Title = MapPrompt.CreateInfoLabel(
		"Title",
		UDim2.new(1, 0, 0.3, 0),
		UDim2.new(0.5, 0, 0.15, 0)
	)
	InfoLabels.Description = MapPrompt.CreateInfoLabel(
		"Description",
		UDim2.new(1, 0, 0.3, 0),
		UDim2.new(0.5, 0, 0.85, 0)
	)
	InfoLabels.Creators = MapPrompt.CreateInfoLabel(
		"Creators",
		UDim2.new(1, 0, 0.2, 0),
		UDim2.new(0.5, 0, 0.4, 0)
	)
	InfoLabels.Difficulty = MapPrompt.CreateInfoLabel(
		"Difficulty",
		UDim2.new(1, 0, 0.1, 0),
		UDim2.new(0.5, 0, 0.6, 0)
	)
	
	for i, v in pairs(InfoLabels) do
		v.Parent = InfoFrame
	end
	---
	
	LoadingText.Size = UDim2.new(0.8, 0, 0.2, 0)
	LoadingText.Name = "LoadingText"
	LoadingText.Text = "Loading..."
	LoadingText.Parent = PromptFrame
	
	local PlayButton = IconButton.New("PLAY")
	PlayButton.TweeningInfo = Prompt.StatsTweeningInfo
	
	local PlayInput: TextButton = PlayButton.GetButton()
	
	do
		local PlayButtonGui = PlayButton.Gui
		PlayButtonGui.Size = UDim2.new(0.9, 0, 0.1, 0)
		PlayButtonGui.Position = UDim2.new(0.5, 0, 0.9, 0)
		PlayButtonGui.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
		PlayButtonGui.Parent = PromptFrame
		
		local PlayButtonLabel: TextLabel = PlayButton.GetDisplayLabel()
		PlayButtonLabel.Font = Enum.Font.GothamSemibold
		PlayButtonLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
	
	Prompt.PlayFadeScreen = PlayFade
	
	local function DisconnectPlay()
		if PlayConnection then
			PlayConnection:Disconnect()
			PlayConnection = nil
		end
	end
	
	local function HideFadeFrame()
		PromptTweenGroup.Play(PlayFade, Prompt.TweeningInfo, {BackgroundTransparency = 1}, nil, function()
			PlayFade.Visible = false
		end)
	end
	
	local function ConnectError()
		LoaderConnections.Error = Loader.OnLoadError.Connect(function(Message: string)
			local Connection = LoaderConnections.Error
			if Connection then
				Connection.Disconnect()
				LoaderConnections.Error = nil
			end

			print("A Loader error occurred:", Message)
			LoadingText.Text = Message
			HideFadeFrame()
		end)
	end
	
	function Prompt.HideInfo()
		if Prompt.IsShowingInfo then
			Prompt.IsShowingInfo = false
			InfoTweenGroup.KillAll()

			local StatsTweeningInfo = Prompt.StatsTweeningInfo

			for i, v in pairs(InfoLabels) do
				InfoTweenGroup.Play(
					v,
					StatsTweeningInfo,
					{TextTransparency = 1, TextStrokeTransparency = 1}
				)
			end

			task.delay(StatsTweeningInfo.Time, function()
				if not Prompt.IsShowingInfo then
					InfoFrame.Visible = false
				end
			end)
		end
	end
	
	function Prompt.ShowInfo()
		if not Prompt.IsShowingInfo then
			Prompt.IsShowingInfo = true
			InfoTweenGroup.KillAll()

			local StatsTweeningInfo = Prompt.StatsTweeningInfo

			for i, v in pairs(InfoLabels) do
				v.TextTransparency = 1
				v.TextStrokeTransparency = 1
				
				InfoTweenGroup.Play(
					v,
					StatsTweeningInfo,
					{TextTransparency = 0, TextStrokeTransparency = 0}
				)
			end
			
			if Prompt.IsShowingInfo then
				InfoFrame.Position = Prompt.InfoFrameHidePos
				InfoTweenGroup.Play(
					InfoFrame,
					StatsTweeningInfo,
					{Position = Prompt.InfoFrameShowPos}
				)
				InfoFrame.Visible = true
			end
		end
	end
	
	function Prompt.DisplayMap(MapName: string, Launcher: {}?)
		Launcher = Launcher or Loader.GetMapLauncher(MapName)
		
		if MapName and Launcher and IsFadingIn then
			-- Hide loading text
			PromptTweenGroup.Play(LoadingText, Prompt.TweeningInfo, {TextStrokeTransparency = 1, TextTransparency = 1}, "LoadingTextFade", function()
				LoadingText.Visible = false
			end)
			
			-- Display map info
			local Difficulty = Launcher.Difficulty

			--InfoFrame.Text =
			--	"Name: <b>" .. Launcher.Name .. "</b><br/><br/>"
			--	.. "Created by: <b>" .. Launcher.Creators .. "</b><br/><br/>"
			--	.. "Description: " .. Launcher.Description .. "<br/><br/>"
			--	.. "Difficulty: <font color=\"#" .. Difficulty.Color:ToHex():upper() .. "\">" .. Difficulty.Name .. "</font>"
			--InfoFrame.Visible = true
			InfoLabels.Title.Text = Launcher.Name
			InfoLabels.Creators.Text = "By: " .. Launcher.Creators
			InfoLabels.Description.Text = Launcher.Description or ""
				
			local DifficultyLabel = InfoLabels.Difficulty
			DifficultyLabel.Text = Difficulty.Name .. " (" .. Difficulty.Index .. ")"
			DifficultyLabel.TextColor3 = Difficulty.Color
			Prompt.ShowInfo()

			--PromptTweenGroup.Play(InfoFrame, Prompt.TweeningInfo, {TextTransparency = 0})
			
			-- Connect play button
			DisconnectPlay()
			PlayConnection = PlayInput.Activated:Connect(function()
				DisconnectPlay()
				print("Now playing:", Launcher.Name)
				
				local MusicPlayer = Loader.MusicPlayer
				
				LoaderConnections.Begin = Loader.OnMapBegin.Connect(function()
					local Connection = LoaderConnections.Begin
					if Connection then
						Connection.Disconnect()
						LoaderConnections.Begin = nil
					end
					
					MusicPlayer.PlayMusicZones = true
					HideFadeFrame()
				end)
				
				MusicPlayer.PlayMusicZones = false
				MusicPlayer.FadeToSound(nil)
				
				local PlaySound = Prompt.PlaySound
				if PlaySound then
					PlaySound:Play()
				end
				
				Prompt.SetVisible(false)
				PlayFade.Visible = true
				PromptTweenGroup.Play(PlayFade, Prompt.TweeningInfo, {BackgroundTransparency = 0})
				task.wait(MapLoader.CooldownTime / 1000)
				Loader.StartMap(MapName)
			end)
			PlayButton.SetVisible(true)
		--else
		--	PromptTweenGroup.Play(InfoFrame, Prompt.TweeningInfo, {TextTransparency = 1})
		end
	end
	
	Prompt.VisibleChanged.Connect(function(IsVisible: boolean)
		IsFadingIn = IsVisible
		local Transparency
		if IsVisible then
			Transparency = 0
			LoadingText.Visible = true
		else
			Transparency = 1
			DisconnectPlay()
			PlayButton.SetVisible(false)
		end
		
		local TweeningInfo = Prompt.TweeningInfo
		if TweeningInfo then
			PromptTweenGroup.Play(LoadingText, TweeningInfo, {TextStrokeTransparency = Transparency, TextTransparency = Transparency}, "LoadingTextFade", function()
				if IsVisible == false and IsFadingIn == false and LoadingText.Visible then
					LoadingText.Visible = false
				end
			end)
			
			if IsVisible == false and IsFadingIn == false then
				--PromptTweenGroup.Play(InfoFrame, TweeningInfo, {TextTransparency = Transparency}, nil, function()
				--	if IsVisible == false and IsFadingIn == false then
				--		InfoFrame.Visible = false
				--	end
				--end)
				Prompt.HideInfo()
			end
		end
	end)
	
	--[[
	Gets this gui to load and prompt a map.
	
	Params:
	MapName <string> - The name of the map's model.
	]]--
	function Prompt.LoadMap(MapName: string)
		print("Requesting load for", MapName)
		
		local BeginConnection = LoaderConnections.Begin
		if BeginConnection then
			BeginConnection.Disconnect()
			BeginConnection = nil
		end
		
		local InitialInfo = Loader.GetMapLauncher(MapName)
		if InitialInfo then
			print("Map is already loaded and initialized, display info")
			Prompt.SetVisible(true)
			Prompt.DisplayMap(MapName, InitialInfo)
		else
			print("Map has not been loaded yet, request it from the server")
			LoadingText.Text = "Loading..."
			ConnectError()
			LoaderConnections.MapLoad = Loader.MapLoadFinished.Connect(function(Name: string)
				if Name == MapName then
					print(MapName, " loaded from the server, display the info")
					
					local Connection = LoaderConnections.MapLoad
					if Connection then
						Connection.Disconnect()
						LoaderConnections.MapLoad = nil
					end

					Prompt.DisplayMap(Name, InitialInfo)
				end
			end)
			
			Prompt.SetVisible(true)
			Loader.LoadMap(MapName)
		end
	end
	
	return Prompt
end

return MapPrompt