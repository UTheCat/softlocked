--[[
A frame with a customizable gradient.

By udev2192
]]--

local ZERO_UDIM2 = UDim2.new(0, 0, 0, 0)

local BaseComponent = require(script.Parent:WaitForChild("BaseComponent"))

local GradientFrame = {}
GradientFrame.__index = GradientFrame
GradientFrame.UiClassName = "Frame"
GradientFrame.GradientClassName = "UIGradient"

--[[
<table> - A set of gradient transparency presets for convienence.
]]--
GradientFrame.TransparencyPresets = {
	Underline = NumberSequence.new(
		{
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.25, 0),
			NumberSequenceKeypoint.new(0.75, 0),
			NumberSequenceKeypoint.new(1, 1)
		}
	)
}

function GradientFrame.New()
	local Frame = BaseComponent.New(GradientFrame.UiClassName)
	local Theme = BaseComponent.GetTheme()

	local FrameGui = Frame.Gui

	local CurrentGradient

	Theme.ApplyProperties(FrameGui, {
		Visible = false
	})

	--[[
	Stamps a clone of the provided UIGradient onto
	the frame
	
	Params:
	Gradient <UIGradient> - The UIGradient to attach.
							Pass nil to this argument to
							get rid of the gradient.
	IsCloning <boolean> - If the clone of the gradient will be used
						  (optional, defaults to true)
	]]--
	function Frame.SetGradient(Gradient, IsCloning)
		if IsCloning == nil then
			IsCloning = true
		end

		if Gradient ~= nil then
			if CurrentGradient ~= nil then
				Frame.SetGradient(nil)
			end

			local Used

			if IsCloning == true then
				Used = Gradient:Clone()
			else
				Used = Gradient
			end

			CurrentGradient = Used
			Used.Parent = FrameGui
		else
			CurrentGradient:Destroy()
			CurrentGradient = nil
		end
	end

	--[[
	Stamps a UIGradient onto the frame using a ColorSequence.
	
	Params:
	Color <ColorSequence> - The color sequence to use.
	
	Returns:
	<UIGradient> - The UIGradient made
	]]--
	function Frame.SetGradientColor(Color)
		local Gradient = Instance.new("UIGradient")
		Gradient.Color = Color

		Frame.SetGradient(Gradient, false)

		return Gradient
	end

	return Frame
end

return GradientFrame