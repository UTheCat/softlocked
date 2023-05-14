--[[
A text button but with an icon and animation to go with it.

You can set if it's clickable (so there won't have to be a separate
class for the TextLabel variant)

The image itself is also able to be toggled.

By udev2192
]]--

local ZERO_UDIM2 = UDim2.new(0, 0, 0, 0)

local BaseComponent = require(script.Parent:WaitForChild("BaseComponent"))
local Util = BaseComponent.GetUtils()

local IconButton = {}
IconButton.__index = IconButton

local DefaultSounds = script:WaitForChild("DefaultSounds")

local function AssertBoolean(Value, ArgNum)
	assert(typeof(Value) == "boolean", "Argument " .. ArgNum .. " must be a boolean")
end

function IconButton.New(ButtonText)
	local Button = BaseComponent.New("Frame")
	local ButtonGui = Button.Gui
	local Theme = Button.GetTheme()
	
	local IsFadingIn = false
	local HoverEffectFadingIn = false
	local ClickEffectEnabled = false
	
	local ClickEffectConnections = {}
	
	local HoverEffectFrame: Frame
	
	-- The background transparency of the button when it's visible.
	Button.BackTransparency = 0
	
	Button.HoverEffectSizeOffset = UDim2.new(0.1, 0, 0.1, 0)
	Button.ClickSizeOffset = UDim2.new(0, 10, 0, 10)--UDim2.new(0.1, 0, 0.1, 0)
	Button.ClickEffectTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	
	Button.ClickSound = DefaultSounds:WaitForChild("Click")
	Button.HoverOnSound = DefaultSounds:WaitForChild("HoverOn")
	Button.HoverOffSound = nil
	
	Theme.ApplyProperties(ButtonGui, ButtonGui.ClassName, {
		Visible = false,
		Size = UDim2.new(0.5, 0, 0.1, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundTransparency = 1,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Name = script.Name
	})
	
	-- Create the GUI components that make up the button.
	local RealButton = Theme.MakeInstance("TextButton", {
		-- The actual button.
		Visible = true,
		
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		
		TextStrokeTransparency = 1,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		Name = "InputReceiver",
		
		ZIndex = 3,
		AutoButtonColor = false,
		ClipsDescendants = false,
		
		Parent = ButtonGui
	})
	
	local ButtonText = Theme.MakeInstance("TextLabel", {
		Size = UDim2.new(0.9, 0, 0.9, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Text = ButtonText or "BUTTON",
		Name = "ButtonText",
		
		ZIndex = 2,
		Parent = ButtonGui
	})
	
	local IconFrame = Theme.MakeInstance("ImageLabel", {
		Visible = false,
		Size = UDim2.new(0.3, 0, 0.5, 0),
		Position = UDim2.new(0.3, 0, 0.5, 0),
		ImageTransparency = 1,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ImageColor3 = ButtonText.TextColor3,
		ScaleType = Enum.ScaleType.Fit,
		Image = "",
		Name = "Icon",
		
		ZIndex = 2,
		Parent = ButtonGui
	})
	
	-- Give the button rounded corners
	--local UICorner = Theme.MakeInstance("UICorner", {
	--	CornerRadius = IconButton.DefaultCornerRadius,
	--	Parent = ButtonGui
	--})
	
	-- Visibility handler
	local function OnVisibleChanged(IsVisible)	
		local Transparency = 0
		local BGTransparency = 0
		local NewHeaderLineSize = nil
		local DestinationPos = nil

		-- Determine destination tween variables
		if IsVisible == true then
			Transparency = 0
			BGTransparency = Button.BackTransparency

			IsFadingIn = true
		else
			Transparency = 1
			BGTransparency = 1

			IsFadingIn = false
		end

		-- Animate
		local Info = Button.TweeningInfo
		if Info ~= nil then
			if IsFadingIn == true and IsVisible == true then
				ButtonGui.Visible = true
			end
			
			Util.Tween(ButtonGui, Info, {BackgroundTransparency = BGTransparency})
			Util.Tween(ButtonText, Info, {TextTransparency = Transparency, TextStrokeTransparency = 1})
			Util.Tween(IconFrame, Info, {ImageTransparency = Transparency})

			task.wait(Info.Time)

			if IsFadingIn == false and IsVisible == false then
				ButtonGui.Visible = false
			end
		end
	end
	
	--[[
	Returns:
	
	<TextButton> - The actual button that you can bind input to.
	]]--
	function Button.GetButton()
		return RealButton
	end
	
	--[[
	Returns:
	
	<TextLabel> - The display text label for the button.
	]]--
	function Button.GetDisplayLabel()
		return ButtonText
	end
	
	--[[
	Sets the text displayed on the button.
	
	Params:
	Text <string> - The text to display.
	]]--
	function Button.SetText(Text)
		ButtonText.Text = Text
	end
	
	--[[
	Sets the icon displayed via the specified url.
	
	Params:
	URL <Color3> - The URL of the image to display.
				   If this argument is nil, the image is hidden
				   and the button text is centered.
	]]--
	function Button.SetIcon(URL)
		if URL ~= nil then
			ButtonText.Size = UDim2.new(0.6, 0, 0.9, 0)
			ButtonText.Position = UDim2.new(0.6, 0, 0.5, 0)
			
			IconFrame.Image = URL
			IconFrame.Visible = true
		else
			IconFrame.Visible = false
			IconFrame.Image = ""
			
			ButtonText.Size = UDim2.new(0.9, 0, 0.9, 0)
			ButtonText.Position = UDim2.new(0.5, 0, 0.5, 0)
		end
	end
	
	--[[
	Sets the color of the UI components that make up the button.
	
	Params:
	NewColor <string> - The color to change to.
	]]--
	function Button.SetColor(NewColor)
		ButtonText.TextColor3 = NewColor
		IconFrame.ImageColor3 = NewColor
	end
	
	--[[
	Sets if rich text is enabled.
	
	Params:
	UseRichText <boolean> - Whether or not to use rich text.
	]]--
	function Button.SetRichTextEnabled(UseRichText)
		AssertBoolean(UseRichText, 1)
		
		ButtonText.RichText = UseRichText
	end
	
	--[[
	Sets if the button can take in input (including clicks).
	
	Params:
	IsEnabled <boolean> - Whether or not to use rich text.
	]]--
	function Button.SetInputEnabled(IsEnabled)
		AssertBoolean(IsEnabled, 1)
		
		RealButton.Visible = IsEnabled
	end
	
	local function SetClickFrameToMaxSize()
		Util.Tween(HoverEffectFrame, TweenInfo, {
			Size = RealButton.Size + Button.HoverEffectSizeOffset
		})
	end
	
	--[[
	<boolean> - Whether or not there is a hover and click animation
	]]--
	Button.SetProperty("ClickEffectEnabled", true, function(Enabled)
		if Enabled then
			if ClickEffectEnabled == false then
				ClickEffectEnabled = true
				
				table.insert(ClickEffectConnections, RealButton.MouseLeave:Connect(function()
					HoverEffectFadingIn = false
					
					if HoverEffectFrame then
						local TweeningInfo = Button.ClickEffectTweenInfo
						Util.Tween(HoverEffectFrame, TweeningInfo, {
							BackgroundTransparency = 1,
						})
						
						local Sound = Button.HoverOffSound
						if Sound then
							Sound:Play()
						end
						
						local Elapsed = 0
						local WaitTime = TweeningInfo.Time
						while true do
							if HoverEffectFadingIn == false and HoverEffectFrame and Elapsed < WaitTime then
								Elapsed += task.wait()
							else
								break
							end
						end

						if HoverEffectFadingIn == false and HoverEffectFrame then
							HoverEffectFrame:Destroy()
							HoverEffectFrame = nil
						end
					end
				end))
				
				table.insert(ClickEffectConnections, RealButton.MouseEnter:Connect(function()
					HoverEffectFadingIn = true
					
					if HoverEffectFrame == nil then
						HoverEffectFrame = BaseComponent.CreateButtonOverlay(RealButton, Button.CornerRadius)
						HoverEffectFrame.Parent = RealButton
					end
					
					Util.Tween(HoverEffectFrame, Button.ClickEffectTweenInfo, {
						BackgroundTransparency = 0.5
					})
					
					local Sound = Button.HoverOnSound
					if Sound then
						Sound:Play()
					end
				end))
				
				table.insert(ClickEffectConnections, RealButton.Activated:Connect(function()
					local ClickFrame = BaseComponent.CreateButtonOverlay(RealButton, Button.CornerRadius)
					ClickFrame.BackgroundTransparency = 0.5
					ClickFrame.Parent = RealButton
					
					local TweeningInfo = Button.ClickEffectTweenInfo
					Util.Tween(ClickFrame, TweeningInfo, {
						Size = RealButton.Size + Button.ClickSizeOffset,
						BackgroundTransparency = 1
					})
					
					local Sound = Button.ClickSound
					if Sound then
						Sound:Play()
					end
					
					task.wait(TweeningInfo.Time)
					ClickFrame:Destroy()
				end))
			end
		else
			if ClickEffectEnabled then
				for i, v in pairs(ClickEffectConnections) do
					v:Disconnect()
				end
				
				ClickEffectConnections = {}
				ClickEffectEnabled = false
			end
		end
	end)
	
	--Button.SetProperty("CornerRadius", BaseComponent.DefaultCornerRadius, function(Radius)
	--	UICorner.CornerRadius = Radius
	--end)
	
	Button.VisibleChanged.Connect(OnVisibleChanged)
	
	Button.AddDisposalListener(function()
		ButtonGui:Destroy()
		Button.ClickEffectEnabled = false
	end)
	
	return Button
end

return IconButton