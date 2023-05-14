--[[
timer

ui design comes mostly from Celeste by Extremely OK Games
]]--

local RunService = game:GetService("RunService")

local RepModules = game:GetService("ReplicatedStorage"):WaitForChild("SoftlockedReplicated")
local Utils = RepModules:WaitForChild("Utils")

local BaseComponent = require(
	RepModules
	:WaitForChild("Gui")
	:WaitForChild("Components")
	:WaitForChild("BaseComponent")
)

local TimeWaiter = require(Utils:WaitForChild("TimeWaiter"))
local TweenGroup = require(Utils:WaitForChild("TweenGroup"))

local Timer = {}

function Timer.New()
	local TimerFrameObj = BaseComponent.New("Frame")
	local Tweens = TweenGroup.New()
	local Runner: RBXScriptConnection
	
	TimerFrameObj.TweeningInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	TimerFrameObj.CornerRadius = nil
	
	--[[
	<number> - The timer's elapsed time in seconds
	]]--
	TimerFrameObj.ElapsedTime = 0
	
	local TimerFrame = TimerFrameObj.Gui
	
	local IsFadingIn = false
	
	TimerFrame.Visible = false
	TimerFrame.Name = "Timer"
	TimerFrame.AnchorPoint = Vector2.new(0, 0.5)
	TimerFrame.Size = UDim2.new(0, 200, 0, 36)
	TimerFrame.Position = UDim2.new(0, 0, 0, 72)
	TimerFrame.BackgroundTransparency = 1
	TimerFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	TimerFrame.BorderSizePixel = 0
	TimerFrame.ClipsDescendants = true
	
	local Background = TimerFrame:Clone()
	Background.AnchorPoint = Vector2.new(0.5, 1)
	Background.Size = UDim2.new(1, 0, 0.5, 0)
	Background.Position = UDim2.new(0.5, 0, 1, 0)
	Background.ZIndex = 1
	Background.Visible = true
	BaseComponent.AddGradientFade(
		Background,
		NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.75, 0),
			NumberSequenceKeypoint.new(1, 1)
		})
	)

	--local GradientLineTop = Instance.new("Frame")
	--GradientLineTop.AnchorPoint = Vector2.new(0.5, 0.5)
	--GradientLineTop.Size = UDim2.new(1, 0, 0.05, 0)
	--GradientLineTop.Position = UDim2.new(0.5, 0, 0, 0.025)
	--GradientLineTop.BackgroundTransparency = 1
	--GradientLineTop.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	--BaseComponent.AddGradientFade(GradientLineTop)

	--local GradientLineBottom = GradientLineTop:Clone()
	--GradientLineBottom.Position = UDim2.new(0.5, 0, 0.975, 0)
	
	local TimerText = Instance.new("TextLabel")
	TimerText.AnchorPoint = Vector2.new(0.5, 1)
	TimerText.Size = UDim2.new(0.5, 0, 0.75, 0)
	TimerText.Position = UDim2.new(0.3, 0, 1, 0)
	TimerText.BackgroundTransparency = 1
	TimerText.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	TimerText.TextStrokeTransparency = 1
	TimerText.TextTransparency = 1
	TimerText.TextColor3 = Color3.fromRGB(255, 255, 255)
	TimerText.TextScaled = false
	TimerText.TextSize = 27
	TimerText.Text = TimeWaiter.FormatSpeedrunTime(0, 3)
	TimerText.Font = Enum.Font.Highway
	TimerText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	TimerText.TextStrokeTransparency = 1
	TimerText.ZIndex = 2
	TimerText.TextXAlignment = Enum.TextXAlignment.Right
	TimerText.TextYAlignment = Enum.TextYAlignment.Bottom
	TimerText.Text = ""
	
	local TimerTextMs = TimerText:Clone()
	TimerTextMs.Size = UDim2.new(0.3, 0, 0.45, 0)
	TimerTextMs.Position = UDim2.new(0.71, 0, 0.92, 0)
	TimerTextMs.TextXAlignment = Enum.TextXAlignment.Left
	TimerTextMs.TextColor3 = Color3.fromRGB(230, 230, 230)
	TimerTextMs.TextSize = 10
	
	--GradientLineBottom.Parent = TimerFrame
	--GradientLineTop.Parent = TimerFrame
	TimerText.Parent = TimerFrame
	TimerTextMs.Parent = TimerFrame
	Background.Parent = TimerFrame
	
	TimerFrameObj.Label = TimerText
	
	function TimerFrameObj.SetText(Minutes: number, Seconds: number, Milliseconds: number)
		TimerText.Text = Minutes .. ":" .. string.format("%.2d", Seconds)
		TimerTextMs.Text = "." .. string.format("%.3d", Milliseconds)
	end
	
	TimerFrameObj.VisibleChanged.Connect(function(IsVisible)
		IsFadingIn = IsVisible
		
		local Transparency
		local TextTransparency
		local LineTransparency = 0
		
		Tweens.KillAll()
		if IsVisible then
			Transparency = 0.5
			TextTransparency = 0
			LineTransparency = 0
			
			TimerFrame.Visible = true
		else
			Transparency = 1
			TextTransparency = 1
			LineTransparency = 1
		end
		
		local TweeningInfo = TimerFrameObj.TweeningInfo
		if TweeningInfo then
			--local LineProperties = {BackgroundTransparency = LineTransparency}
			local TextProperties = {
				TextTransparency = TextTransparency,
				TextStrokeTransparency = TextTransparency
			}
			local Hide
			if IsVisible then
				TimerFrame.Visible = true
			else
				Hide = function()
					if IsFadingIn == false then
						TimerFrame.Visible = false
					end
				end
			end
			
			--Tweens.Play(GradientLineTop, TweeningInfo, LineProperties)
			--Tweens.Play(GradientLineBottom, TweeningInfo, LineProperties)
			Tweens.Play(TimerText, TweeningInfo, TextProperties)
			Tweens.Play(TimerTextMs, TweeningInfo, TextProperties)
			Tweens.Play(Background, TweeningInfo, {BackgroundTransparency = Transparency}, nil, Hide)
			
			--LineProperties = nil
		else
			TimerFrame.Visible = IsVisible and IsFadingIn
		end
	end)
	
	function TimerFrameObj.Pause()
		if Runner then
			Runner:Disconnect()
			Runner = nil
		end
	end
	
	function TimerFrameObj.Start()
		if Runner == nil then
			Runner = RunService.Heartbeat:Connect(function(Delta: number)
				local NewTime = TimerFrameObj.ElapsedTime + Delta
				TimerFrameObj.ElapsedTime = NewTime
				
				TimerFrameObj.SetText(TimeWaiter.FormatSpeedrunTimeIndividual(NewTime, 3))
			end)
		end
	end
	
	TimerFrameObj.AddDisposalListener(Tweens.Dispose)
	
	return TimerFrameObj
end

return Timer