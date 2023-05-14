--[[
Displays a banner that is intended to introduce the user to something as a title

By udev2192
]]--

local BaseComponent = require(game:GetService("ReplicatedStorage")
	:WaitForChild("Modules")
	:WaitForChild("Gui")
	:WaitForChild("Components")
	:WaitForChild("BaseComponent")
)
local Util = BaseComponent.GetUtils()

local IntroText = {}
IntroText.__index = IntroText
IntroText.ClassName = script.Name

function IntroText.New(OriginalText: string?)
	local Intro = BaseComponent.New("Frame")
	
	Intro.CornerRadius = nil
	Intro.ShownSizeXScale = 1
	Intro.HiddenSizeXScale = 0
	Intro.TextShownPositionOffset = UDim2.new(0, 0, 0.1, 0)
	Intro.TextHidePosition = UDim2.new(0.5, 0, 0.3875, 0)
	
	local Gui: Frame = Intro.Gui
	local Theme = Intro.GetTheme()
	
	local IsFadingIn = false
	
	Theme.ApplyProperties(Gui, Gui.ClassName, {
		Visible = false,
		
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0.5, 0, 0.075, 0),
		Position = UDim2.new(0.5, 0, 0.1, 0),

		Name = "IntroTextFrame",

		BackgroundTransparency = 1,
		BorderSizePixel = 0
	})
	
	local FrameText: TextLabel = Theme.MakeInstance("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 0, 0.975, 0),
		Position = Intro.TextHidePosition,
		
		BackgroundTransparency = 1,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		BorderSizePixel = 0,
		
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		Text = OriginalText or "",
		
		Parent = Gui
	})
	
	local GradientLine: Frame = Theme.MakeInstance("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 2),
		Position = UDim2.new(0.5, 0, 1, -1),

		BackgroundTransparency = 1,
		BorderSizePixel = 0,

		Parent = Gui
	})
	
	BaseComponent.AddGradientFade(Gui)
	BaseComponent.AddGradientFade(GradientLine)
	
	Intro.SetProperty("Color", Color3.fromRGB(255, 255, 255), function(NewColor)
		GradientLine.BackgroundColor3 = NewColor
		Gui.BackgroundColor3 = NewColor
		FrameText.BackgroundColor3 = NewColor
		FrameText.TextColor3 = NewColor
	end)
	
	Intro.FrameText = FrameText
	
	Intro.VisibleChanged.Connect(function(IsVisible)
		local TweeningInfo = Intro.TweeningInfo
		
		if TweeningInfo then
			local BgTransparency
			local Transparency
			local TextPos
			
			if IsVisible and IsFadingIn == false then
				IsFadingIn = true
				BgTransparency = 0.5
				Transparency = 0
				TextPos = Intro.TextHidePosition + Intro.TextShownPositionOffset
				
				Gui.Visible = true
			elseif IsVisible == false then
				IsFadingIn = false
				BgTransparency = 1
				Transparency = 1
				TextPos = Intro.TextHidePosition
			end
			
			Util.Tween(Gui, TweeningInfo, {BackgroundTransparency = BgTransparency})
			Util.Tween(FrameText, TweeningInfo, {
				TextTransparency = Transparency,
				--TextStrokeTransparency = Transparency,
				Position = TextPos
			})
			Util.Tween(GradientLine, TweeningInfo, {BackgroundTransparency = Transparency})
			
			task.wait(TweeningInfo.Time)
			
			if IsVisible == false and IsFadingIn == false then
				Gui.Visible = false
			end
		end
	end)
	
	return Intro
end

return IntroText