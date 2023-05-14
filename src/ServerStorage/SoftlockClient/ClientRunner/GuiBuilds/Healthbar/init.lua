--[[
A replacement for Roblox's original healthbar (which has been broken for almost a month)

Plus it's animated and doesn't do that red flash thing that might trigger users
with photosensitive epilepsy

Inspired by the healthbar currently being used in GreatBear's Noob Zone Towers

By udev2192
]]--

local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local BaseComponent = require(game:GetService("ReplicatedStorage")
	:WaitForChild("Modules")
	:WaitForChild("Gui")
	:WaitForChild("Components")
	:WaitForChild("BaseComponent")
)
local Util = BaseComponent.GetUtils()

local HealthLoseSound = script:WaitForChild("HealthLose")

local Healthbar = {}
Healthbar.__index = Healthbar

Healthbar.TextPrefix = ""
Healthbar.FullUDim = UDim.new(1, 0)
Healthbar.UIStrokeEnabled = false

function Healthbar.Lerp(a, b, t)
	return a + (b - a) * t
end

function Healthbar.RandomPercentage(Min, Max)
	return math.random(Min * 100, Max * 100) / 100
end

--[[
Toggles the default healthbar on or off.

Params:
Enabled <boolean> - Whether or not to use the default healthbar.

Returns:
<boolean> - If it was successful.
]]--
function Healthbar.ToggleDefault(Enabled)
	return pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, Enabled)
	end)
end

function Healthbar.New(ShowDefault)
	Healthbar.ToggleDefault(ShowDefault)

	local Bar = BaseComponent.New("Frame")

	-- For multiplying animation speed
	local DeltaMultiplier = Instance.new("NumberValue")
	DeltaMultiplier.Value = 1

	local OldMaxHealth = 100
	local OldHealth = OldMaxHealth
	
	local IsShaking = false

	local CurrentCircles = {}
	local HumanoidConnections = {}

	local CircleEffectRunner

	local HumanoidResponder
	local DeltaTween
	local OriginalShakePos

	local CurrentHumanoid
	
	Bar.TweeningInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	Bar.DeltaTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

	Bar.OutlineMinHealthColor = Color3.fromHSV(0, 0.75, 0.5)
	Bar.OutlineMaxHealthColor = Color3.fromHSV(0.3, 0.75, 0.5)

	Bar.BarMinHealthColor = Color3.fromHSV(0, 0.5, 0.85)
	Bar.BarMaxHealthColor = Color3.fromHSV(0.3, 0.5, 0.85)

	Bar.BackgroundColor = Color3.fromHSV(0.9, 0.9, 0.19)

	Bar.CircleMinTransparency = 0.5
	Bar.CircleMaxTransparency = 0.75
	Bar.CircleMinDiameter = 0.1
	Bar.CircleMaxDiameter = 0.35
	Bar.CircleMinSpeed = 0.25
	Bar.CircleMaxSpeed = 0.5
	Bar.CircleColor = Color3.new(1, 1, 1)

	--[[
	<number> - The delay between each circle creation in seconds
			   while the effect is running
	]]--
	Bar.CircleDelay = 0.2

	--[[
	<boolean> - Whether or not the healthbar will shake when health decreases
	]]--
	Bar.ShakeOnHealthLoss = false
	
	Bar.ShakeScaleOffset = 0.01
	Bar.PlayHealthLoseSound = true
	Bar.UseFlashbang = true

	local OutlineFrame = Bar.Gui
	OutlineFrame.Name = "Healthbar"
	OutlineFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	OutlineFrame.Size = UDim2.new(0.15, 0, 0.025, 0)
	OutlineFrame.Position = UDim2.new(0.85, 0, 0.025, 0)
	OutlineFrame.BackgroundTransparency = 1
	OutlineFrame.BorderSizePixel = 0
	OutlineFrame.ClipsDescendants = false

	Bar.CornerRadius = Healthbar.FullUDim
	
	-- Create a frame to use for the shake effect
	local ShakeFrame = OutlineFrame:Clone()
	ShakeFrame.Name = "HealthbarShakeFrame"
	ShakeFrame.Size = UDim2.new(1, 0, 1, 0)
	ShakeFrame.Position = UDim2.new(0.5, 0, 0.5, 0)

	--Bar.CornerRadius = Healthbar.FullUDim

	--HealthFrame.Size = UDim2.new(1, 0, 0.9, 0)
	--HealthFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	--HealthFrame.ZIndex = 2
	--HealthFrame.Parent = OutlineFrame

	-- Create the health frame's background
	local HealthBG = OutlineFrame:Clone()
	Util.ApplyProperties(HealthBG, {
		Name = "HealthBackground",
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		ZIndex = 1,

		BackgroundTransparency = 0,
		BorderSizePixel = 0
	})
	
	-- Create the bar to use the original as an outline
	-- (this will be the one that displays the actual health)
	local HealthFrame = OutlineFrame:Clone()
	HealthFrame.Name = "HealthMeter"
	HealthFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	HealthFrame.Size = UDim2.new(1, 0, 1, 0)
	HealthFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	HealthFrame.BackgroundTransparency = 0
	HealthFrame.BorderSizePixel = 0
	HealthFrame.ZIndex = 2

	-- Create a frame for the circle animation
	local CircleFrame = Util.CreateInstance("Frame", {
		Name = "CirclesFrame",

		ClipsDescendants = true,

		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.9, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),

		BackgroundTransparency = 1,
		BorderSizePixel = 0,

		ZIndex = 3,

		Parent = OutlineFrame
	})

	-- Create the text thing that will actually display
	-- the health
	local HealthText = Util.CreateInstance("TextLabel", {
		Name = "HealthText",

		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0.5, 0, 0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),

		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = Healthbar.TextPrefix .. OldHealth,

		TextStrokeTransparency = 1,
		Font = Enum.Font.GothamSemibold,

		ZIndex = 4
	})
	
	-- Set the UI parent here to prevent
	-- unintended cloning
	HealthText.Parent = ShakeFrame
	HealthFrame.Parent = ShakeFrame
	HealthBG.Parent = ShakeFrame
	ShakeFrame.Parent = OutlineFrame

	-- Use UIStroke to give it an outline
	local UIStroke
	if Healthbar.UIStrokeEnabled == true then
		UIStroke = Instance.new("UIStroke")
		UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		UIStroke.Thickness = 2
		UIStroke.Transparency = 0
		UIStroke.Parent = HealthBG
	end

	function Bar.ResetColor()
		if UIStroke then
			UIStroke.Color = Bar.OutlineMaxHealthColor
		end

		HealthFrame.BackgroundColor3 = Bar.BarMaxHealthColor
		HealthBG.BackgroundColor3 = Bar.BackgroundColor
	end

	function Bar.ClearCircles()
		for i, v in pairs(CurrentCircles) do
			v.Circle:Destroy()
		end

		CurrentCircles = {}
	end

	function Bar.AddCircle()
		local Diameter = Healthbar.RandomPercentage(Bar.CircleMinDiameter, Bar.CircleMaxDiameter)
		local Circle = Util.CreateInstance("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(Diameter, 0, Diameter, 0),
			Position = UDim2.new(0, 0, Healthbar.RandomPercentage(0, 1), 0),

			BackgroundTransparency = 1,
			BorderSizePixel = 0,

			BackgroundColor3 = Bar.CircleColor,

			Parent = CircleFrame
		})

		BaseComponent.AddCornerRadius(Circle, Healthbar.FullUDim)
		BaseComponent.AddAspectRatio(Circle, 1)

		table.insert(CurrentCircles, {
			Circle = Circle,
			XPosition = 0,
			Speed = Healthbar.RandomPercentage(Bar.CircleMinSpeed, Bar.CircleMaxSpeed),
			Transparency = Healthbar.RandomPercentage(Bar.CircleMinTransparency, Bar.CircleMaxTransparency)
		})
	end

	--[[
	Returns:
	<table> - A dictionary of the currently preferred health bar colors
	]]--
	function Bar.GetHealthbarColors()
		return {
			Meter = Bar.BarMinHealthColor:lerp(
				Bar.BarMaxHealthColor,
				math.min((Bar.Health or 1) / (Bar.MaxHealth or 1), 1)
			),

			Outline = Bar.OutlineMinHealthColor:lerp(
				Bar.OutlineMaxHealthColor,
				math.min((Bar.Health or 1) / (Bar.MaxHealth or 1), 1)
			)
		}
	end
	
	--[[
	Shakes the health bar
	]]--
	function Bar.Shake()
		DeltaMultiplier.Value = -2
		Util.Tween(DeltaMultiplier, Bar.DeltaTweenInfo, {Value = 1})

		-- Do the shake effect if enabled
		-- Since shaking is done until delta multiplier is
		-- greater than or equal to 0, don't run if
		-- it's still shaking

		-- Shaking is done by going in a rapid "square" rotation
		if IsShaking == false then
			IsShaking = true

			if OriginalShakePos == nil then
				OriginalShakePos = HealthBG.Position
			end

			local Offset = Bar.ShakeScaleOffset
			local Side = 1

			while IsShaking do
				local AnimMultiplier = DeltaMultiplier.Value

				if AnimMultiplier < 0 then

					local XMultiplier
					local YMultiplier

					if Side == 1 or Side == 2 then
						XMultiplier = -AnimMultiplier
					else
						XMultiplier = AnimMultiplier
					end

					if Side == 3 or Side == 4 then
						YMultiplier = -AnimMultiplier
					else
						YMultiplier = AnimMultiplier
					end

					if Side < 4 then
						Side += 1
					else
						Side = 1
					end

					-- Do offset
					ShakeFrame.Position = OriginalShakePos + UDim2.new(Offset * XMultiplier, 0, Offset * YMultiplier, 0)

					task.wait()
				else
					break
				end
			end

			HealthBG.Position = OriginalShakePos
			OriginalShakePos = nil

			IsShaking = false
		end
	end

	--[[
	Refreshes the health bar
	]]--
	function Bar.Refresh()
		local Health = Bar.Health
		local MaxHealth = Bar.MaxHealth

		if Health and MaxHealth and MaxHealth > 0 then
			local Percent = Health / MaxHealth
			local Colors = Bar.GetHealthbarColors()

			HealthText.Text = Healthbar.TextPrefix .. math.floor(Health)
			
			if Bar.UseFlashbang == true then
				HealthFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			end

			Util.Tween(HealthFrame, Bar.TweeningInfo, {
				Size = UDim2.new(Percent, 0, 1, 0),
				Position = UDim2.new(math.max(Percent / 2, 0), 0, 0.5, 0),
				BackgroundColor3 = Colors.Meter
			})

			if UIStroke then
				Util.Tween(UIStroke, Bar.TweeningInfo, {
					Color = Colors.Outline
				})
			end
		end
	end

	Bar.ResetColor()

	--[[
	<boolean> - Whether or not the circles effect is enabled
	]]--
	Bar.SetProperty("CirclesEnabled", false, function(Enabled)
		if Enabled then
			if CircleEffectRunner == nil then
				local Elapsed = 0
				local IsAnimating = false

				CircleEffectRunner = RunService.Heartbeat:Connect(function(Delta)
					if IsAnimating == false then
						IsAnimating = true

						local DeltaMultiplierValue = DeltaMultiplier.Value

						-- Only create new circles if they're going "forward"
						if DeltaMultiplierValue > 0 then
							Elapsed += Delta

							if Elapsed > Bar.CircleDelay then
								Elapsed = 0
								Bar.AddCircle()
							end
						end

						-- This is where the animation happens
						local Length = #CurrentCircles
						if Length > 0 then
							local AnimDelta = Delta * DeltaMultiplierValue
							--local CirclesToRemove = {}

							for i, v in pairs(CurrentCircles) do
								--local Current = v

								--if Current == nil or #CurrentCircles <= 0 then
								--	break
								--end

								local Circle = v.Circle

								local OldPos = Circle.Position
								local NewXPos = math.min(v.XPosition + (v.Speed * AnimDelta), 1)

								v.XPosition = NewXPos
								Circle.Position = UDim2.new(
									NewXPos,
									OldPos.X.Offset,
									OldPos.Y.Scale,
									OldPos.Y.Offset
								)

								if NewXPos < 1 and NewXPos > -2 then
									-- Full opacity is at halfway through the healthbar

									Circle.BackgroundTransparency = Healthbar.Lerp(v.Transparency, 1, math.abs(0.5 - NewXPos) / 0.5)
								else
									--table.insert(CirclesToRemove, i)
									Circle:Destroy()

									local Index = table.find(CurrentCircles, v)
									if Index ~= nil then
										table.remove(CurrentCircles, Index)
										--print("remove circle")
									end
								end
							end

							-- Remove after (to not disturb the loop)
							--for i, v in pairs(CirclesToRemove) do
							--	table.remove(CurrentCircles, v)
							--end
						end

						IsAnimating = false
					end
				end)
			end
		else
			if CircleEffectRunner then
				CircleEffectRunner:Disconnect()
				CircleEffectRunner = nil
			end

			Bar.ClearCircles()
		end
	end)

	local function SetHealthWithCheck(NewHealth, NewMaxHealth)
		local DoRefresh = false
		local DoShake = false
		
		if NewMaxHealth and NewMaxHealth ~= OldMaxHealth then
			OldMaxHealth = NewMaxHealth
			DoRefresh = true
		end
		
		if NewHealth and NewHealth ~= OldHealth then
			if NewHealth < OldHealth then
				if Bar.ShakeOnHealthLoss == true then
					DoShake = true
				end
				
				if HealthLoseSound and Bar.PlayHealthLoseSound == true then
					HealthLoseSound:Play()
				end
			end
			
			OldHealth = NewHealth
			DoRefresh = true
		end
		
		if DoRefresh then
			Bar.Refresh()
		end
		
		if DoShake then
			task.spawn(Bar.Shake)
		end
		
		--if NewHealth and NewHealth ~= OldHealth then
		--	OldMaxHealth = NewMaxHealth
		--	--Bar.MaxHealth = NewMaxHealth

		--	DoRefresh = true
			
		--	if NewHealth < OldHealth then
				
		--	end

		--	OldHealth = NewHealth
		--	Bar.Health = NewHealth
			
		--	DoRefresh = true
		--end
	end
	
	local function DisconnectHumanoidEvents()
		for i, v in pairs(HumanoidConnections) do
			v:Disconnect()
		end
		
		HumanoidConnections = {}
	end

	--[[
	<number> - Value to use as max health
	]]--
	Bar.SetProperty("MaxHealth", OldMaxHealth, function(NewMax)
		SetHealthWithCheck(nil, NewMax)
	end)

	--[[
	<number> - Value to use as current health
	]]--
	Bar.SetProperty("Health", OldHealth, function(Health)
		SetHealthWithCheck(Health, nil)
	end)

	--[[
	<Humanoid> - The humanoid to display health for
	]]--
	Bar.SetProperty("Humanoid", nil, function(Humanoid: Humanoid)
		Healthbar.ToggleDefault(ShowDefault)

		if Humanoid == nil then
			DisconnectHumanoidEvents()

			CurrentHumanoid = nil
		else
			if Humanoid ~= CurrentHumanoid then
				CurrentHumanoid = Humanoid
				Bar.Health = Humanoid.Health
				Bar.MaxHealth = Humanoid.MaxHealth

				DisconnectHumanoidEvents()
				table.insert(HumanoidConnections, Humanoid.HealthChanged:Connect(function(Health)
					--SetHealthWithCheck(Health, nil)
					Bar.Health = Health
				end))
				table.insert(HumanoidConnections, Humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function(MaxHealth)
					--SetHealthWithCheck(nil, MaxHealth)
					Bar.MaxHealth = MaxHealth
				end))
			end
		end
	end)

	Bar.AddDisposalListener(function()
		Bar.CirclesEnabled = false
		Bar.Humanoid = nil
		
		IsShaking = false

		DeltaMultiplier:Destroy()
	end)

	return Bar
end

return Healthbar