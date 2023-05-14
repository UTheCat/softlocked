--[[
A menu for measuring estimated internet speed.

By udev2192
]]--

local RepModules = game:GetService("ReplicatedStorage"):WaitForChild("SoftlockedReplicated")

local Replicators = RepModules:WaitForChild("Replicators")

local SpeedTest = require(Replicators:WaitForChild("SpeedTest"))

local Components = game:GetService("ReplicatedStorage")
:WaitForChild("SoftlockedReplicated")
:WaitForChild("Gui")
:WaitForChild("Components")

local BaseComponent = require(Components:WaitForChild("BaseComponent"))
local GridMenu = require(Components:WaitForChild("GridMenu"))
local IconButton = require(Components:WaitForChild("IconButton"))

local BaseReplicator = require(Replicators:WaitForChild("BaseReplicator"))
local Util = BaseComponent.GetUtils()

--RepModules, Replicators, Components = nil

local LocalPlayer = game:GetService("Players").LocalPlayer

local SpeedTestMenu = {}

function SpeedTestMenu.New()
	local Menu = GridMenu.New()
	local SpeedTester = SpeedTest.New()

	local IsCurrentlyTesting = false
	local IsAnimatingText = false
	local IsUpdatingTime = false
	local IsFadingIn = false
	
	local CurrentRequestId = 0
	local CurrentSecondsTimestamp = 0

	local CurrentColorTween

	-- Set timeout
	SpeedTester.Timeout = 3000

	Menu.ErrorColor = Color3.fromHSV(0, 0.75, 1)
	Menu.SuccessColor = Color3.fromHSV(0.4, 0.75, 1)
	Menu.MeasureButtonTextColor = Color3.fromHSV(0, 0, 1)
	Menu.MeasureButtonText = "Measure"
	Menu.StatusFadeDuration = 1
	Menu.DotsUpdateDelay = 0.1

	Menu.SetTitle("test your internet")
	Menu.Gui.Name = "PingTest"

	Menu.LastTimestamp = 0

	local StatsLabel = IconButton.New()
	local StatsLabelGui = StatsLabel.Gui

	StatsLabel.BackTransparency = 0.5

	StatsLabel.SetInputEnabled(false)
	StatsLabel.SetRichTextEnabled(true)

	StatsLabel.SetText("Press <i>measure</i> to start polling your internet speed")

	StatsLabelGui.Size = UDim2.new(0.8, 0, 0.45, 0)
	StatsLabelGui.Position = UDim2.new(0.5, 0, 0.275, 0)
	
	local TimeLabel: TextLabel = Util.CreateInstance("TextLabel",
		{
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0.8, 0, 0.05, 0),
			Position = UDim2.new(0.5, 0, 0.75, 0),
			
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Font = Enum.Font.Gotham,
			Text = "",
			TextScaled = true,
			TextStrokeTransparency = 1,
			
			Name = "CurrentTimeLabel",
			Parent = Menu.Gui
		}
	)

	local MeasureButton = IconButton.New()
	MeasureButton.SetText("Measure")

	local MeasureButtonLabel = MeasureButton.Gui
	MeasureButtonLabel.Size = UDim2.new(0.75, 0, 0.2, 0)
	MeasureButtonLabel.Position = UDim2.new(0.5, 0, 0.9, 0)
	MeasureButtonLabel = nil

	local MeasureButtonDisplay = MeasureButton.GetDisplayLabel()
	MeasureButtonDisplay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)

	local function CancelColorFade()
		if CurrentColorTween ~= nil then
			CurrentColorTween:Destroy()
			CurrentColorTween = nil
		end
	end

	local function ResetStatusColor()
		CancelColorFade()
		CurrentColorTween = BaseComponent.FadeTextColor(MeasureButtonDisplay, Menu.MeasureButtonTextColor, Menu.StatusFadeDuration)
	end

	Menu.SetProperty("MeasureButtonTextColor", Menu.MeasureButtonTextColor, function(Color)
		MeasureButtonDisplay.TextColor3 = Color
	end)

	-- Event stuff
	SpeedTester.ResponseReceived.Connect(function(Response)
		if IsCurrentlyTesting == true then
			--print("response received from speed test")

			local Error = Response.Error
			local RequestId = tostring(Response.RequestId)
			local NextColor

			if Error == nil then
				StatsLabel.SetText("Total ping from replicator: " .. BaseReplicator.GetCurrentTime() - StatsLabel.LastTimestamp .. " ms"
					.. "\n Engine calculated ping: " .. (LocalPlayer:GetNetworkPing() * 1000) .. " ms"
					.. "\n Request ID: " .. RequestId
					.. "\n Data: " .. tostring(Response.Data[1])
				)
				NextColor = Menu.SuccessColor
			else
				StatsLabel.SetText(
					tostring(Error.Message) .. " (Request ID = " .. RequestId .. ")"
					.. "\nTry again in " .. string.format("%.2f", SpeedTester.CooldownRemaining) .. " seconds"
				)
				NextColor = Menu.ErrorColor
			end

			IsAnimatingText = false

			-- Delay is needed here to prevent problems caused by threading
			task.wait()

			CancelColorFade()
			MeasureButtonDisplay.MaxVisibleGraphemes = -1
			MeasureButtonDisplay.Text = Menu.MeasureButtonText
			MeasureButtonDisplay.TextColor3 = NextColor
			ResetStatusColor()

			IsCurrentlyTesting = false
		end
	end)

	MeasureButton.GetButton().Activated:Connect(function()
		if IsCurrentlyTesting == false then
			IsCurrentlyTesting = true
			IsAnimatingText = true

			--print("now testing speed")
			StatsLabel.SetText("Checking")

			-- Make the request
			CurrentRequestId += 1
			local LastTimestamp = BaseReplicator.GetCurrentTime()
			StatsLabel.LastTimestamp = LastTimestamp
			SpeedTester.Request(BaseReplicator.CreateRequestParams(
				1, -- request id
				true,
				LastTimestamp,
				nil
				)
			)

			-- Animate the button
			local Dots = 1
			MeasureButtonDisplay.MaxVisibleGraphemes = Dots
			MeasureButtonDisplay.Text = "..."

			while true do
				if IsCurrentlyTesting == true and IsAnimatingText == true then
					if Dots < 3 then
						Dots += 1
					else
						Dots = 1
					end

					MeasureButtonDisplay.MaxVisibleGraphemes = Dots
					task.wait(Menu.DotsUpdateDelay)
				else
					break
				end
			end
		end
	end)

	Menu.AddComponent(StatsLabel)
	Menu.AddComponent(MeasureButton)

	Menu.SetImage(
		Util.CreateInstance(("ImageLabel"), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0.5, 0, 0.5, 0),

			BackgroundTransparency = 1,
			BorderSizePixel = 0,

			ScaleType = Enum.ScaleType.Crop,
			Image = "rbxassetid://13447335131"
		})
	)
	
	Menu.VisibleChanged.Connect(function(IsVisible: boolean)
		local Transparency = 0
		
		IsFadingIn = IsVisible
		if IsVisible then
			Transparency = 0
			
			if IsUpdatingTime == false then
				IsUpdatingTime = true
				
				task.spawn(function()
					while IsUpdatingTime do
						local Current = DateTime.now()
						local Seconds = Current.UnixTimestamp

						if Seconds > CurrentSecondsTimestamp then
							CurrentSecondsTimestamp = Seconds
							TimeLabel.Text = Current:ToIsoDate()
						end

						task.wait()
					end
				end)
			end
		else
			IsUpdatingTime = false
			Transparency = 1
		end
		
		local TweeningInfo = Menu.TweeningInfo
		if TweeningInfo then
			Util.Tween(TimeLabel, TweeningInfo, {TextTransparency = Transparency})
		end
	end)

	Menu.AddDisposalListener(function()
		SpeedTester.Dispose()
		IsUpdatingTime = false
	end)

	return Menu
end

return SpeedTestMenu