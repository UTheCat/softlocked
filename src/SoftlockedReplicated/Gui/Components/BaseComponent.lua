--[[
This acts as a base container/interface for a UI component.

Hiding/showing handling functions can be binded to signals
that are provided.

By udev2192
]]--

local UI_CORNER_CLASS_NAME = "UICorner"

local RepModules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")
local UtilRepModules = RepModules:WaitForChild("Utils")
local Themes = script.Parent.Parent:WaitForChild("Themes")

local Object = require(UtilRepModules:WaitForChild("Object"))
local Signal = require(UtilRepModules:WaitForChild("Signal"))
local Utils = require(UtilRepModules:WaitForChild("Utility"))

local BaseComponent = {}
BaseComponent.__index = BaseComponent

export type Component = Object.ObjectPool & {
	Gui: GuiObject,
	TweeningInfo: TweenInfo,
	HandleBeforeDispose: boolean,
	AutoDestroyGui: boolean,
	BackImageTransparency: number,
	CornerRadius: UDim?,
	
	GetTheme: () -> {},
	GetBackground: () -> ImageLabel,
	SetVisible: (IsVisible: boolean) -> (),
	SetImage: (Image: ImageLabel, DestroyLast: boolean) -> (),
	
	VisibleChanged: Signal.Signal,
}

BaseComponent.BgImageDefaultZIndex = 2
BaseComponent.DefaultTheme = "Wavy"

BaseComponent.AspectRatioDominantAxis = Enum.DominantAxis.Height

-- For reference
BaseComponent.DefaultCornerRadius = UDim.new(0, 10)
BaseComponent.DefaultGradientFade = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.25, 0.25),
	NumberSequenceKeypoint.new(0.75, 0.25),
	NumberSequenceKeypoint.new(1, 1)
})

--[[
Returns:
<table> - The table of general utility functions
]]--
function BaseComponent.GetUtils()
	return Utils
end

--[[
Calculates a cell size to be used with a UIGridLayout
based on the number of rows, columns, and the cell padding

Params:
Rows <number> - The desired number of rows
Columns <number> - The desired number of columns
Padding <UDim2> - THe desired content padding
]]--
function BaseComponent.GetGridItemSize(Rows: number, Columns: number, Padding: number): UDim2
	return UDim2.new(
		(1 / math.max(Rows, 1)) - Padding.X.Scale,
		-Padding.X.Offset,
		(1 / math.max(Columns, 1)) - Padding.Y.Scale,
		-Padding.Y.Offset
	)
end

--[[
Adds a UIGradient fade to the specified GUI component

Params:
Ui <Instance> - The UI object to apply the gradient to
Transparency <NumberSequence?> - The transparency sequence to use

Returns:
<UIGradient> - The UIGradient created
]]--
function BaseComponent.AddGradientFade(Ui: Instance?, Transparency: NumberSequence?): UIGradient
	return Utils.CreateInstance("UIGradient", {
		Transparency = Transparency or BaseComponent.DefaultGradientFade,
		Parent = Ui
	})
end

--[[
Applies a UI corner to the UI component provided.

Params:
Ui <Instance> - The component to apply a UI corner to.
Radius <UDim> - The radius to apply.

Returns:
<UIAspectRatioConstraint> - The aspect ratio constraint used.
]]--
function BaseComponent.AddCornerRadius(Ui: Instance, Radius: UDim): UICorner
	return Utils.CreateInstance("UICorner", {
		CornerRadius = Radius or BaseComponent.DefaultCornerRadius,
		Parent = Ui
	})
end

--[[
Applies an aspect ratio to a UI component.

Params:
Ui <Instance> - The component to apply an aspect ratio to.
Ratio <number> - The aspect ratio of the component (from 0-1).

Returns:
<UIAspectRatioConstraint> - The aspect ratio constraint used.
]]--
function BaseComponent.AddAspectRatio(Ui: Instance, Ratio: number): UIAspectRatioConstraint
	return Utils.CreateInstance("UIAspectRatioConstraint", {
		DominantAxis = BaseComponent.AspectRatioDominantAxis,
		AspectRatio = Ratio,
		Parent = Ui
	})
end

--[[
Fades to a certain text color for a text-based GUI component

Params:
TextObject <GuiObject> - The text based component to fade
Color <Color3> - The destination text color.
Duration <number> - How long to do the fade

Returns:
<BaseTween> - The tween created
]]--
function BaseComponent.FadeTextColor(TextObject: GuiObject, Color: Color3, Duration: number): Tween
	return Utils.Tween(
		TextObject,
		TweenInfo.new(Duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{TextColor3 = Color}
	)
end

--[[
Creates a frame that can be used as a button overlay for hover/click effects

Params:
Button <GuiObject> - The GuiObject to use when creating the overlay
Radius <UDim> (optional) - If specified, creates a UICorner to go with
						   the overlay using this argument as the radius

Returns:
<Frame> - The overlay created
]]--
function BaseComponent.CreateButtonOverlay(Button: GuiObject, Radius: UDim?) : Frame
	local Frame = Utils.CreateInstance("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),

		BackgroundTransparency = 1,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0
	})
	
	if Radius then
		BaseComponent.AddCornerRadius(Frame, Radius)
	end
	
	return Frame
end

--[[
Constructs the BaseComponent.

Params:
ClassName (string) - The name of the instance/class to construct
ThemeName (string) (optional) - The name of the theme used to construct
							  	the instance/class.
							  	
Returns:
<BaseComponent> - The constructed object
]]--
function BaseComponent.New(ClassName: string, ThemeName: string?): Component
	assert(typeof(ClassName) == "string", "Argument 1 must be a string.")

	ThemeName = ThemeName or BaseComponent.DefaultTheme

	local Obj = Object.New("BaseComponent")

	-- Create the GUI based on the theme provided.
	local UsedTheme = require(Themes:WaitForChild(ThemeName))

	local IsFadingIn = false
	
	local FrameCorner
	local BackgroundImage
	local BGImageCorner

	--[[
	The GUI created from initialization.
	]]--
	Obj.Gui = UsedTheme.MakeInstance(ClassName)

	--[[
	The object's preferred tweening info/animation style.
	]]--
	Obj.TweeningInfo = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

	--[[
	If the hiding animation is played when
	the object is being disposed.
	]]--
	Obj.HandleBeforeDispose = true

	--[[
	If the GUI is destroyed when Dispose()
	is called. This waits for the hide animation
	to be finished if it will be played during
	object disposal.
	]]--
	Obj.AutoDestroyGui = true

	--[[
	<number> - How transparent the background image is.
	]]--
	Obj.BackImageTransparency = 0.5
	
	--[[
	<UDim?> - The dimensions of the UI's corner radius.
	]]--
	Obj.SetProperty("CornerRadius", BaseComponent.DefaultCornerRadius, function(Radius)
		if Radius == nil or Radius == UDim.new(0, 0) then
			if FrameCorner ~= nil then
				FrameCorner:Destroy()
				FrameCorner = nil
			end
		else
			local Gui = Obj.Gui
			if Gui ~= nil then
				local Corner = Gui:FindFirstChildOfClass(UI_CORNER_CLASS_NAME)
					or Instance.new(UI_CORNER_CLASS_NAME)
				FrameCorner = Corner
				
				if Corner ~= nil then
					Corner.CornerRadius = Radius
					Corner.Parent = Gui
				end
			end
		end
		
		if BGImageCorner ~= nil then
			BGImageCorner.CornerRadius = Radius
		end
	end)

	--[[
	Fired when the GUI is requested to be visible or invisble.
	
	Params:
	Visible (boolean) - Whether the GUI is being requested for
						visibility or not.
	]]--
	Obj.VisibleChanged = Signal.New()

	--[[
	Returns the GUI scheme associated.
	]]--
	function Obj.GetTheme()
		return UsedTheme
	end
	
	--[[
	Returns:
	<ImageLabel> - The ImageLabel used as the background. If none is
				   currently set, nil is returned.
	]]--
	function Obj.GetBackground()
		return BackgroundImage
	end

	--[[
	Toggles the GUI's visibility and fires it.
	
	Params:
	IsVisible (boolean) - Whether or not to make the GUI visible.
	]]--
	function Obj.SetVisible(IsVisible)
		local Gui = Obj.Gui
		local VisibleChanged = Obj.VisibleChanged

		if Gui ~= nil and VisibleChanged ~= nil then
			if IsVisible == true then
				--Gui.Visible = true
				IsFadingIn = true
				VisibleChanged.Fire(true)
			else
				IsFadingIn = false
				VisibleChanged.Fire(false)
				--Gui.Visible = false
			end

			if BackgroundImage ~= nil then
				if IsVisible == IsFadingIn then
					local BGTransparency

					if IsFadingIn == true then
						BGTransparency = Obj.BackImageTransparency or 0
					else
						BGTransparency = 1
					end

					local TweeningInfo = Obj.TweeningInfo

					if TweeningInfo ~= nil then
						coroutine.wrap(function()
							if IsVisible == IsFadingIn and IsFadingIn == true then
								BackgroundImage.Visible = true
							end

							local Tween = Utils.Tween(
								BackgroundImage,
								TweeningInfo,
								{ImageTransparency = BGTransparency}
							)

							task.wait(TweeningInfo.Time)

							-- See if it animated back before
							-- toggling visibility
							if IsVisible == IsFadingIn and IsFadingIn == false then
								BackgroundImage.Visible = false
								BackgroundImage.ImageTransparency = 1
							end
						end)()
					else
						if IsVisible == IsFadingIn then
							BackgroundImage.ImageTransparency = BGTransparency
						end
					end 
				end
			end
		end

		Gui, VisibleChanged = nil, nil
	end

	--[[
	Sets the ImageLabel instance to use as a background.
	If an ImageLabel is provided, its ZIndex, Transparency,
	and Parent properties will be overriden.
	
	A UI corner will also be added to the ImageLabel.
	
	Params:
	Image <ImageLabel> - The image label instance to use.
						 Specify with nil the current one.
	DestroyLast <boolean> - Whether or not to destroy the
							last background image.
	]]--
	function Obj.SetImage(Image, DestroyLast)
		assert(Image == nil or (typeof(Image) == "Instance" and Image:IsA("ImageLabel")), "Argument 1 must be an ImageLabel or nil.")

		local LastImage

		if Image ~= nil then
			if DestroyLast == true then
				LastImage = BackgroundImage
			end

			BackgroundImage = Image
			BGImageCorner = BaseComponent.AddCornerRadius(Image, BaseComponent.DefaultCornerRadius)

			Image.ZIndex = BaseComponent.BgImageDefaultZIndex

			local Gui = Obj.Gui
			if Gui ~= nil then
				if Gui.Visible == true then
					Image.ImageTransparency = Obj.BackImageTransparency or 0
					Image.Visible = true
				else
					Image.ImageTransparency = 1
					Image.Visible = false
				end

				Image.Parent = Gui
			end
		elseif BackgroundImage ~= nil then
			BackgroundImage.Parent = nil
			BackgroundImage, BGImageCorner = nil
		end

		if DestroyLast == true then
			LastImage = LastImage or BackgroundImage

			if LastImage ~= nil then
				LastImage:Destroy()
			end
		end
	end

	Obj.OnDisposal = function()
		if Obj.HandleBeforeDispose == true then
			Obj.SetVisible(false)
		end

		local VisibleChanged = Obj.VisibleChanged
		if VisibleChanged ~= nil then
			VisibleChanged.DisconnectAll()
		end
		VisibleChanged = nil
		
		Obj.SetImage(nil)

		if Obj.AutoDestroyGui == true then
			local Gui = Obj.Gui
			if Gui ~= nil then
				Gui:Destroy()
			end
			Gui = nil
		end

		UsedTheme = nil
	end

	return Obj
end

return BaseComponent