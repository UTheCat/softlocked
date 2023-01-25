--[[
GUI for loading maps

By udev2192
]]--

local MapHandles = script.Parent.Parent

local BaseInteractive = require(MapHandles:WaitForChild("Interactives"):WaitForChild("BaseInteractive"))
local BaseComponent = require(MapHandles.Parent
	:WaitForChild("Gui")
	:WaitForChild("Components")
	:WaitForChild("BaseComponent")
)
local Utils = BaseInteractive.GetGeneralUtils()
local TweenGroup = BaseInteractive.GetTweenGroupClass()
local Scheduler = require(BaseInteractive.GetUtilPackage():WaitForChild("Scheduler"))

local LoadStatus = require(MapHandles:WaitForChild("MapLoader")).Status

local MapLoad = {}
MapLoad.ClassName = script.Name

function MapLoad.New()
	local LoadGui = BaseComponent.New("Frame")
	local Tweens = TweenGroup.New()
	local TweenScheduler = Scheduler.New()
	
	TweenScheduler.Sync = true
	
	local PrimaryFrame: Frame = LoadGui.Gui
	local IsFadingIn = false
	local OriginalPositions: {GuiObject: UDim2} = {}
	
	local IsLoadingMap = false
	local CurrentlyLoadingMap: string
	local CurrentMapInfoName: string

	LoadGui.CornerRadius = nil
	LoadGui.TweeningInfo = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	LoadGui.HideTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	LoadGui.BarMoveTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	LoadGui.PositionOffset = UDim2.new(0, 0, 0.1, 0)
	LoadGui.VisibleTweenName = "VisibilityTweens"
	LoadGui.BarMoveTweenName = "BarMove"
	LoadGui.TweenDelay = 0.1
	
	PrimaryFrame.Visible = false
	PrimaryFrame.Size = UDim2.new(1, 0, 1, 0)
	PrimaryFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	PrimaryFrame.BackgroundTransparency = 1
	PrimaryFrame.BorderSizePixel = 0
	PrimaryFrame.Name = "MapLoadGuiFrame"
	
	-- Loading meter position at full percent
	LoadGui.LoadingBarPos = UDim2.new(0.5, 0, 0.5, 0)
	
	--[[
	<MapLoader> - The client replicator used by the gui
	]]--
	LoadGui.Replicator = nil
	
	local LoadingImage: ImageLabel = Utils.CreateInstance("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		
		ImageTransparency = 1,
		BackgroundTransparency = 1,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		
		ScaleType = Enum.ScaleType.Crop,
		Parent = PrimaryFrame
	})
	
	local MapInfoLabel: TextLabel = Utils.CreateInstance("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0.8, 0, 0.1, 0),
		Position = UDim2.new(0.5, 0, 0.225, 0),

		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		Text = "Map Name [Difficulty] by Creators",
		
		Font = Enum.Font.Gotham,

		Parent = PrimaryFrame
	})
	
	local LoadingStatusFrame: Frame = Utils.CreateInstance("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0.8, 0, 0.1, 0),
		Position = UDim2.new(0.5, 0, 0.6, 0),

		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		
		Parent = PrimaryFrame
	})
	
	local StatusText: Frame = Utils.CreateInstance("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0.5, 0, 1, 0),
		Position = UDim2.new(0.25, 0, 0.5, 0),

		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		Text = "Loading...",
		TextXAlignment = Enum.TextXAlignment.Left,

		Font = Enum.Font.Gotham,

		Parent = LoadingStatusFrame
	})
	
	local PercentText: Frame = Utils.CreateInstance("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0.5, 0, 1, 0),
		Position = UDim2.new(0.75, 0, 0.5, 0),

		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		TextTransparency = 1,
		TextStrokeTransparency = 1,

		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Right,

		Font = Enum.Font.Gotham,

		Parent = LoadingStatusFrame
	})
	
	local LoadingMeter: Frame = Utils.CreateInstance("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0.8, 0, 0.05, 0),
		Position = UDim2.new(0.5, 0, 0.71, 0),

		BackgroundTransparency = 1,
		BackgroundColor3 = Color3.fromRGB(26, 0, 66),
		BorderSizePixel = 0,

		Parent = PrimaryFrame
	})
	
	local LoadingBar: Frame = Utils.CreateInstance("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 0, 1, 0),
		Position = LoadGui.LoadingBarPos,

		BackgroundTransparency = 1,
		BackgroundColor3 = Color3.fromRGB(98, 0, 255),
		BorderSizePixel = 0,

		Parent = LoadingMeter
	})
	
	BaseComponent.AddCornerRadius(LoadingMeter, UDim.new(1, 0)):Clone().Parent = LoadingBar
	
	local function GetLoadMeterPos(Percent: number)
		local Pos = LoadGui.LoadingBarPos
		return UDim2.new(Pos.X.Scale * Percent, Pos.X.Offset, Pos.Y.Scale, Pos.Y.Offset)
	end
	
	local function ResetComponentPos()
		local HideOffset = LoadGui.PositionOffset
		
		for i, v in pairs(OriginalPositions) do
			i.Position = v - HideOffset
		end
	end
	
	function LoadGui.SetLoadMeterPercent(Percent: number)
		local BarMoveTweenName = LoadGui.BarMoveTweenName
		Tweens.Kill(BarMoveTweenName)
		PercentText.Text = tostring(math.floor(Percent * 100)) .. "%"
		Tweens.Play(LoadingBar, LoadGui.BarMoveTweenInfo, {
			Size = UDim2.new(Percent, 0, 1, 0),
			Position = GetLoadMeterPos(Percent)
		}, BarMoveTweenName)
	end
	
	for i, v in pairs(PrimaryFrame:GetChildren()) do
		if v:IsA("GuiObject") and v ~= LoadingImage then
			OriginalPositions[v] = v.Position
		end
	end
	ResetComponentPos()
	
	LoadGui.VisibleChanged.Sync = true
	LoadGui.VisibleChanged.Connect(function(IsVisible: boolean)
		TweenScheduler.Pause()
		
		local VisibileTweenName = LoadGui.VisibleTweenName
		Tweens.Kill(VisibileTweenName)
		
		--local StartTransparency
		local Transparency = 0
		local PosOffset
		local TweeningInfo
		
		if IsVisible then
			IsFadingIn = true
			--StartTransparency = 1
			Transparency = 0
			
			PosOffset = UDim2.new(0, 0, 0, 0)
			TweeningInfo = LoadGui.TweeningInfo
			
			if PrimaryFrame.Visible == false then
				ResetComponentPos()
			end
		else
			IsFadingIn = false
			Transparency = 1
			
			PosOffset = LoadGui.PositionOffset
			TweeningInfo = LoadGui.HideTweenInfo
		end
		
		if IsVisible and IsFadingIn then
			PrimaryFrame.Visible = true
		end
		
		-- Tween moving objects
		
		--for i: GuiObject, v: UDim2 in pairs(OriginalPositions) do
		--	local Properties = {}
		--	if i.ClassName == "TextLabel" then
		--		Properties.TextTransparency = Transparency
		--		Properties.TextStrokeTransparency = Transparency
				
		--		if StartTransparency then
		--			i.TextTransparency = StartTransparency
		--			i.TextStrokeTransparency = StartTransparency
		--		end
		--	elseif i == LoadingMeter then
		--		Properties.BackgroundTransparency = Transparency
				
		--		if StartTransparency then
		--			i.BackgroundTransparency = StartTransparency
		--		end
		--	end

		--	i.Position = v + PosOffset
		--	Tweens.Play(i, TweeningInfo, Properties, VisibileTweenName)
		--end
		
		-- Tween others
		local TweenDelay = LoadGui.TweenDelay
		TweenScheduler.Schedule = {
			[0] = function()
				Tweens.Play(LoadingImage, TweeningInfo, {
					BackgroundTransparency = Transparency,
					ImageTransparency = Transparency
				}, VisibileTweenName)
				Tweens.Play(MapInfoLabel, TweeningInfo, {
					TextTransparency = Transparency,
					TextStrokeTransparency = Transparency,
					Position = OriginalPositions[MapInfoLabel] + PosOffset
				}, VisibileTweenName)
			end,
			
			[TweenDelay] = function()
				Tweens.Play(LoadingStatusFrame, TweeningInfo, {
					Position = OriginalPositions[LoadingStatusFrame] + PosOffset
				}, VisibileTweenName)
				Tweens.Play(StatusText, TweeningInfo, {
					TextTransparency = Transparency,
					TextStrokeTransparency = Transparency,
				}, VisibileTweenName)
				Tweens.Play(PercentText, TweeningInfo, {
					TextTransparency = Transparency,
					TextStrokeTransparency = Transparency
				}, VisibileTweenName)
			end,
			
			[TweenDelay * 2] = function()
				Tweens.Play(LoadingMeter, TweeningInfo, {
					BackgroundTransparency = Transparency,
					Position = OriginalPositions[LoadingMeter] + PosOffset
				}, VisibileTweenName)
				Tweens.Play(LoadingBar, TweeningInfo, {
					BackgroundTransparency = Transparency
				}, VisibileTweenName, function()
					if IsVisible == false and IsFadingIn == false then
						PrimaryFrame.Visible = false
						ResetComponentPos()
					end
				end)
			end
		}
		
		TweenScheduler.Time = 0
		TweenScheduler.Resume()
	end)
	
	-- table where: [signal name] = function()
	local Listeners
	
	local function DisconnectListeners()
		local Replicator = LoadGui.Replicator

		if Replicator then
			for i, v in pairs(Listeners) do
				Replicator[i].Disconnect(v)
			end
		end
	end

	local function ConnectListeners()
		local Replicator = LoadGui.Replicator

		if Replicator then
			for i, v in pairs(Listeners) do
				Replicator[i].Connect(v)
			end
		end
	end
	
	local function EndLoad()
		DisconnectListeners()
		IsLoadingMap = false
		LoadGui.SetVisible(false)
	end
	
	local function ResetLoadingStats()
		LoadingBar.Size = UDim2.new(0, 0, 1, 0)
		LoadingBar.Position = GetLoadMeterPos(0)
		StatusText.Text = "Preparing"
		PercentText.Text = "0%"
	end
	
	local function ChangeMapLabel(Info: {})
		if Info then
			local Name = Info.Name
			
			if Name and Name ~= CurrentMapInfoName then
				CurrentMapInfoName = Name

				local Diff = Info.Difficulty
				MapInfoLabel.Text = Info.Name .. " [" .. Diff.Name .. "] by " .. Info.Creators
				MapInfoLabel.TextColor3 = Diff.Color
			end
		end
	end
	
	Listeners = {
		OnLoadError = EndLoad,
		
		StatusChanged = function(Status: string, Info: {})
			StatusText.Text = Status
			
			ChangeMapLabel(Info)
			
			if (Status == LoadStatus.WaitingForInitialize or Status == LoadStatus.Starting) then
				LoadGui.SetLoadMeterPercent(1)
				
				if PrimaryFrame.Visible == false then
					LoadGui.SetVisible(true)
				end
			end
		end,
		
		DescendantLoaded = function(Loaded: number, MaxLoad: number)
			LoadGui.SetLoadMeterPercent(Loaded / MaxLoad)
		end,
		
		MapLoadFinished = function(MapName: string)
			local Replicator = LoadGui.Replicator
			if Replicator and IsLoadingMap and MapName == CurrentlyLoadingMap then
				Replicator.StartMap(CurrentlyLoadingMap)
			else
				EndLoad()
			end
		end,
		
		MapReceived = function(Info: {})
			ResetLoadingStats()
			ChangeMapLabel(Info)
			
			LoadGui.SetVisible(true)
		end,
		
		OnMapBegin = EndLoad
	}
	
	--[[
	Gets this gui to load a map.
	
	Params:
	MapName <string> - The name of the map's model.
	]]--
	function LoadGui.LoadMap(MapName: string)
		if IsLoadingMap == false then
			IsLoadingMap = true
			CurrentlyLoadingMap = MapName
			
			local Replicator = LoadGui.Replicator
			
			ConnectListeners()
			if Replicator.IsMapLoaded(MapName) then
				-- For tweening purposes
				--Tweens.Kill(LoadGui.BarMoveTweenName)
				--LoadingBar.Size = UDim2.new(0, 0, 1, 0)
				--LoadingBar.Position = GetLoadMeterPos(0)
				
				--LoadGui.SetLoadMeterPercent(1)
				--LoadGui.SetVisible(true)
				ResetLoadingStats()
				
				ChangeMapLabel(Replicator.GetMapLauncher(MapName))
				LoadGui.SetVisible(true)
				Replicator.StartMap(MapName)
			else
				Replicator.LoadMap(MapName)
			end
		end
	end
	
	LoadGui.AddDisposalListener(function()
		DisconnectListeners()
		IsLoadingMap = false
		
		TweenScheduler.Dispose()
		Tweens.Dispose()
	end)
	
	return LoadGui
end

return MapLoad