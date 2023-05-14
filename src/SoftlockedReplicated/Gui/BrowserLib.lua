--[[
BrowserLib.lua by udev2192

The module that contains all the functions to boost the efficiency of the Map Browser development

Make sure to put sizes and positions according to the anchor point Vector2.new(0.5,0.5)

This module is designed for client use

Revamped 9 March 2021 to be less confusing and more OOP based
]]--

local mod = {}

-- CONSTANTS --
local DEFAULT_FONT = Enum.Font.GothamBold -- When a font is not specified when applicable, this font will be applied
local UI_COLOR_SEQUENCE = ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(128, 0, 255)), ColorSequenceKeypoint.new(1,Color3.fromRGB(204, 0, 255))}) -- The color sequence of the UIGradients used by the text objects
local GRADIENT_ROTATION_INCREMENT = 0.5 -- How much rotating gradients rotate by for each frame
local TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- The TweenInfo used to Tween objects
local CORNER_RADIUS = 0 -- How much to round the corner of the GUI objects out of 1 (leave at 0 to turn this off)
local DEFAULT_LAYER = 2 -- The default ZIndex a GUI object is set to when one is not specified
---------------

-- Property Configuration --
local Defaults = {
	-- Format: ["Instance/Class name"] = {Properties}
	["TextButton"] = {
		AnchorPoint = Vector2.new(0.5,0.5),
		Size = UDim2.new(0.25,0,0.25,0),
		Position = UDim2.new(0.5,0,0.5,0),

		BackgroundColor3 = Color3.new(0,0,0),
		TextColor3 = Color3.new(1,1,1),
		Font = DEFAULT_FONT,
		Text = "Blank Text",
		TextScaled = true,
		BorderMode = Enum.BorderMode.Inset,
		BorderColor3 = Color3.new(1,1,1),
		BorderSizePixel = 2,
		ZIndex = DEFAULT_LAYER
	},

	["TextLabel"] = {
		AnchorPoint = Vector2.new(0.5,0.5),
		Size = UDim2.new(0.25,0,0.25,0),
		Position = UDim2.new(0.5,0,0.5,0),

		BackgroundTransparency = 1,
		TextColor3 = Color3.new(1,1,1),
		Font = DEFAULT_FONT,
		Text = "Blank Text",
		TextScaled = true,
		BorderMode = Enum.BorderMode.Inset,
		BorderSizePixel = 0,
		TextStrokeTransparency = 0,
		ZIndex = DEFAULT_LAYER
	},

	["TextBox"] = {
		AnchorPoint = Vector2.new(0.5,0.5),
		Size = UDim2.new(0.25,0,0.25,0),
		Position = UDim2.new(0.5,0,0.5,0),
		
		BackgroundTransparency = 1,
		TextColor3 = Color3.new(1,1,1),
		Font = DEFAULT_FONT,
		PlaceholderText = "Blank Placeholder Text",
		Text = "",
		TextScaled = true,
		BorderMode = Enum.BorderMode.Inset,
		BorderColor3 = Color3.new(1,1,1),
		BorderSizePixel = 0,
		ZIndex = DEFAULT_LAYER,
	},

	["Frame"] = {
		AnchorPoint = Vector2.new(0.5,0.5),
		Size = UDim2.new(0.25,0,0.25,0),
		Position = UDim2.new(0.5,0,0.5,0),

		BorderMode = Enum.BorderMode.Inset,
		BorderColor3 = Color3.new(1,1,1),
		BorderSizePixel = 2,
		BackgroundColor3 = Color3.new(1,1,1),
		BackgroundTransparency = 0.75,
		ClipsDescendants = true,
		ZIndex = DEFAULT_LAYER
	}
}
----------------------------

-- UI framework:
local ClickConnections = {} -- Stores the Activated connections for buttons
local GradientConnections = {} -- Stores the Stepped connections for GUI objects with rotating gradients
local TextBoxConnections = {} -- Stores the FocusLost connections when a function is binded to the FunctionOnInput

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ScreenGui = script.Parent

local RepModules = ReplicatedStorage:WaitForChild("SoftlockedReplicated")
local UtilModules = RepModules:WaitForChild("Utils")

-- Reference the utility library
local Util = UtilModules:WaitForChild("Utility")
if Util:IsA("ModuleScript") then
	Util = require(Util)
end

-- Apply property configurations:
for i, v in pairs(Defaults) do
	if typeof(v) == "table" then
		Util.SetPropertyDefaults(i, v)
	end
end

-- Make some constants accessible by other scripts/modules
mod.ColorSequence = UI_COLOR_SEQUENCE
mod.ModuleFont = DEFAULT_FONT

-- Functions/methods (new):
function mod.ApplyFinishes(Object) -- Applies finishing touches to the provided instance
	if typeof(Object) == "Instance" then
		-- Apply the gradient
		local Gradient = Instance.new("UIGradient") -- Add the gradient to make a cool ui effect
		Gradient.Color = UI_COLOR_SEQUENCE
		Gradient.Rotation = 90
		Gradient.Parent = Object

		-- Apply the corner radius
		if CORNER_RADIUS > 0 then
			local Corner = Instance.new("UICorner")
			Corner.CornerRadius = UDim.new(CORNER_RADIUS, 0)
			Corner.Parent = Object
		end

		-- Return the redesigned GUI object
		return Object
	else
		warn("Object type must be an Instance.")
		return nil
	end
end

function mod.RotateGradient(Object, IsRotating) -- Rotates the ui gradient for the specified gui object an even cooler effect
	if Object ~= nil and Object:IsA("GuiObject") then
		if IsRotating ~= nil and typeof(IsRotating) == "boolean" then
			local Gradient = Object:WaitForChild("UIGradient", 4)
			if Gradient then
				if IsRotating then
					GradientConnections[Object] = RunService.Stepped:Connect(function()
						Gradient.Rotation = Gradient.Rotation + GRADIENT_ROTATION_INCREMENT
					end)
				else
					if GradientConnections[Object] ~= nil then
						GradientConnections[Object]:Disconnect()
						GradientConnections[Object] = nil
					end
				end
			else
				warn("Couldn't find a UIGradient in the specified GUI object.")
			end
		else
			warn("IsRotating (argument 2) isn't specified or isn't a boolean (true/false).")
		end
	else
		warn("The object (argument 1) isn't specified or isn't a GUI object.")
	end
end

function mod.New(Type, Properties) -- Constructs a recognized Instance by this UI framework
	-- Please use this over the old constructors as this one is much more simplified
	if typeof(Defaults[Type]) == "table" then
		-- Make the object
		local Object = Util.CreateInstance(Type, Properties)

		-- Finish off the object
		mod.ApplyFinishes(Object)

		-- Return the finished object
		return Object
	else
		warn(tostring(Type) .. " isn't recognized by this version of BrowserLib.")
	end
end

return mod

--[[
Old functions/methods (please don't use any of these as they are much harder to use):
function mod.MakeButton(Text, Size, Position)
	local Button = Util.CreateInstance("TextButton", {
		-- Make the UI object
		Text = Text,
		Size = Size,
		Position = Position
	})
	
	mod.ApplyFinishes(Button)
	
	return Button
end

function mod.MakeLabel(Text, Size, Position)
	local Label = Util.CreateInstance("TextButton", {
		-- Make the UI object
		Text = Text,
		Size = Size,
		Position = Position
	})

	mod.ApplyFinishes(Label)
	
	return Label
end

function mod.MakeTextBox(PlaceholderText, Size, Position, Parent, FunctionOnInput, Layer, Font)
	-- FunctionOnInput should account for the first parameter that is passed to it, which is the text entered
	local TextBox = Instance.new("TextBox") -- Make the TextBox
	TextBox.AnchorPoint = Vector2.new(0.5,0.5)
	TextBox.Size = Size
	TextBox.Position = Position
	TextBox.BackgroundTransparency = 1
	TextBox.TextColor3 = Color3.new(1,1,1)
	TextBox.Font = Font or DEFAULT_FONT
	TextBox.PlaceholderText = PlaceholderText or "Blank Placeholder Text"
	TextBox.Text = ""
	TextBox.TextScaled = true
	TextBox.BorderMode = Enum.BorderMode.Inset
	TextBox.BorderColor3 = Color3.new(1,1,1)
	TextBox.BorderSizePixel = 0
	TextBox.ZIndex = Layer or DEFAULT_LAYER

	if CORNER_RADIUS > 0 then
		local Corner = Instance.new("UICorner")
		Corner.CornerRadius = UDim.new(CORNER_RADIUS, 0)
		Corner.Parent = TextBox
	end
	
	if FunctionOnInput ~= nil then
		if typeof(FunctionOnInput) == "function" then
			TextBox.FocusLost:Connect(function()
				local TextBoxText = TextBox.Text
				FunctionOnInput(TextBoxText)
				TextBoxText = nil
			end)
		else
			warn("When choosing to specify the FunctionOnInput (argument 5), make sure it is a function and that the first argument of that function will have the text entered passed to")
		end
	end

	TextBox.Parent = Parent or ScreenGui
	return TextBox
end

function mod.BindFunction(Button, FunctionWhenClicked)
	if Button ~= nil and Button:IsA("TextButton") then
		if FunctionWhenClicked ~= nil and typeof(FunctionWhenClicked) == "function" then
			ClickConnections[Button] = Button.Activated:Connect(FunctionWhenClicked) -- Bind the specified function
		else
			warn("FunctionWhenClick (argument 2) isn't specified or isn't a function so the button will do nothing.")
		end
	else
		warn("The Button specified (argument 1) isn't provided or isn't a TextButton.")
	end
end

function mod.UnbindFunction(Button)
	if Button ~= nil and Button:IsA("TextButton") then
		if ClickConnections[Button] ~= nil then
			ClickConnections[Button]:Disconnect()
			ClickConnections[Button] = nil
		end
	else
		warn("The button isn't specified in the first and only argument or the object provided isn't a TextButton.")
	end
end

function mod.UnbindFunctionOnInput(TextBox)
	if TextBox ~= nil and TextBox:IsA("TextBox") then
		if TextBoxConnections[TextBox] ~= nil then
			TextBoxConnections[TextBox]:Disconnect()
			TextBoxConnections[TextBox] = nil
		end
	else
		warn("The TextBox isn't specified in the first and only argument or the object provided isn't a TextBox.")
	end
end

function mod.MakeFrame(Size, Position, Parent, Layer, AddColor)
	local Frame = Instance.new("Frame") -- Make the Frame
	Frame.AnchorPoint = Vector2.new(0.5,0.5)
	Frame.Size = Size
	Frame.Position = Position
	Frame.BorderMode = Enum.BorderMode.Inset
	Frame.BorderColor3 = Color3.new(1,1,1)
	Frame.BorderSizePixel = 2
	if AddColor then
		Frame.BackgroundColor3 = Color3.new(1,1,1)
	else
		Frame.BackgroundColor3 = Color3.new(0,0,0)
	end
	Frame.BackgroundTransparency = 0.75
	Frame.ClipsDescendants = true
	Frame.ZIndex = Layer or DEFAULT_LAYER
	
	if AddColor then
		local Gradient = Instance.new("UIGradient") -- Add the gradient to make a cool ui effect
		Gradient.Color = UI_COLOR_SEQUENCE
		Gradient.Rotation = 90
		Gradient.Parent = Frame
	end

	if CORNER_RADIUS > 0 then
		local Corner = Instance.new("UICorner")
		Corner.CornerRadius = UDim.new(CORNER_RADIUS, 0)
		Corner.Parent = Frame
	end
	
	Frame.Parent = Parent or ScreenGui
	return Frame
end

function mod.AddARC(GuiObject, Ratio)
	-- Add an AspectRatioConstraint to a GUIObject which is needed in certain UI design cases
	if GuiObject:IsA("GuiBase") then
		local AspectRatioConstraint = Instance.new("UIAspectRatioConstraint")
		AspectRatioConstraint.AspectRatio = Ratio or 1
		AspectRatioConstraint.DominantAxis = Enum.DominantAxis.Height
		AspectRatioConstraint.Parent = GuiObject

		return AspectRatioConstraint
	end
end

function mod.Tween(Object, PropertiesToTween, DelayThread) -- The DelayThread should be true/false and specifes whether the tween delays the current thread or not
	if Object ~= nil then
		if PropertiesToTween ~= nil and typeof(PropertiesToTween) == "table" then
			if DelayThread == nil or typeof(DelayThread) == "boolean" then
				local Tween = TweenService:Create(Object, TWEEN_INFO, PropertiesToTween)
				local function PlayTween()
					Tween:Play()
					Tween.Completed:Wait()
					Tween:Destroy()
					Tween = nil
				end
				if DelayThread then
					PlayTween()
				else
					coroutine.wrap(PlayTween)()
				end
				return Tween
			else
				warn("When specified, the DelayThread argument (argument 3) should be a boolean (true/false) detailing whether to yield the current thread while the tween is playing or not")
			end
		else
			warn("PropertiesToTween (argument 2) isn't specified or isn't a table of object properties to tween.")
		end
	else
		warn("The Object (argument 1) isn't specified")
	end
end
--]]