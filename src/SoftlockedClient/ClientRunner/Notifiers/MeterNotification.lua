-- Provides a GUi that appears as a notification that indicates a value with a limit
-- By udev2192

local BaseNotif = require(script.Parent:WaitForChild("BaseNotification"))
local Util = BaseNotif.GetUtils()

local MeterNotification = {}
local ZERO_UDIM2 = UDim2.new(0, 0, 0, 0)
local DEFAULT_COLOR = Color3.fromRGB(100, 100, 100)
local DEFAULT_TWEEN_INFO = TweenInfo.new()
local GRADIENTS_ENABLED = true
local DEFAULT_METER_NAME = "Meter"

MeterNotification.TypeName = "MeterNotification"

-- Utility function for creating a UI frame
local function MakeFrame(Color, FrameSize)
	return Util.CreateInstance("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = FrameSize or ZERO_UDIM2,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		BackgroundColor3 = Color or DEFAULT_COLOR,
		ClipsDescendants = true,
		Name = MeterNotification.TypeName
	})
end

function MeterNotification.New(Notifier, MeterName, BarColor, BackgroundColor, TextColor)
	-- Create the meter frame
	local Frame = MakeFrame(BarColor, Notifier.PreferredSize)
	
	-- This is the progress bar
	local Bar = MakeFrame(BackgroundColor, UDim2.new(0, 0, 1, 0))
	Bar.Position = UDim2.new(0.5, 0, 0.5, 0)
	Bar.Parent = Frame
	
	local TextBar = Util.CreateInstance("TextLabel", {
		TextColor3 = TextColor or Color3.fromRGB(255, 255, 255),
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Font = Enum.Font.Gotham,
		TextScaled = true,
		Text = DEFAULT_METER_NAME,
		Parent = Frame
	})
	
	--local Corner = Util.CreateInstance("UICorner", {
	--	CornerRadius = UDim.new(1, 0),
	--	Parent = Frame
	--})
	
	--local BarCorner = Util.CreateInstance("UICorner", {
	--	CornerRadius = UDim.new(1, 0),
	--	Parent = Bar
	--})
	
	Util.CreateInstance("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.25, 0.25),
			NumberSequenceKeypoint.new(0.75, 0.25),
			NumberSequenceKeypoint.new(1, 1)
		}),
		
		Parent = Bar
	})
	
	local Obj = BaseNotif.New(Notifier, Frame)
	
	-- Updates the meter
	local function UpdateMeter()
		local Name = Obj.MeterName or DEFAULT_METER_NAME
		local NumValue = Obj.Value or 0
		local MaxValue = Obj.MaxValue or 1
		
		local Size = 0 -- Percentage
		
		if MaxValue > 0 then
			Size = NumValue / MaxValue
		else
			-- To avoid problems with dividing by 0
			Size = 0
		end
		
		-- Round if necessary
		if Obj.IsRounding == true then
			NumValue = math.floor(NumValue)
			MaxValue = math.floor(MaxValue)
		end
		
		-- Update visuals
		TextBar.Text = Name .. ": " .. NumValue .. "/" .. MaxValue
		Bar.Size = UDim2.new(Size, 0, 1, 0)
		--Bar.Position = UDim2.new(Size / 2, 0, 0.5, 0)
		
		Name, NumValue, MaxValue, Size = nil, nil, nil, nil
	end
	
	-- Sets the corner radius of the frame
	function Obj.SetCornerRadius(udim)
		if Corner ~= nil then
			Corner.CornerRadius = udim
		end
		
		if BarCorner ~= nil then
			BarCorner.CornerRadius = udim
		end
	end
	
	-- Sets the color of the progress bar
	function Obj.SetProgressColor(color)
		if Bar ~= nil then
			Bar.BackgroundColor3 = color
		end
	end
	
	-- Sets the color of the background bar
	function Obj.SetBackgroundColor(color)
		if Frame ~= nil then
			Frame.BackgroundColor3 = color
		end
	end
	
	-- Sets the color of the text
	function Obj.SetTextColor(color)
		if TextBar ~= nil then
			TextBar.TextColor3 = color
		end
	end
	
	-- The name of the meter
	Obj.SetProperty("MeterName", MeterName or DEFAULT_METER_NAME, UpdateMeter)
	
	-- The number value associated with the meter
	Obj.SetProperty("Value", 0, UpdateMeter)
	
	-- The maximum number value associated with the meter
	Obj.SetProperty("MaxValue", 1, UpdateMeter)
	
	-- If numbers displayed are rounded
	Obj.SetProperty("IsRounding", true, UpdateMeter)
	
	-- Tweening info for animating the meter
	Obj.TweenInfo = Notifier.PreferredTweenInfo
	
	Obj.ApplyDimensions()
	
	if GRADIENTS_ENABLED == true then
		BaseNotif.ApplyGradient(Bar)
		BaseNotif.ApplyGradient(TextBar)
	end
	
	-- Meter animator
	Obj.SetAnimator(function(IsAppearing, Pos)
		local Transparency = 0
		
		if IsAppearing == true then
			Transparency = 0
		else
			Transparency = 1
		end
		
		local Info = Obj.TweenInfo or DEFAULT_TWEEN_INFO
		
		-- Animate
		Util.Tween(Frame, Info, {Position = Pos})
		Util.Tween(Bar, Info, {BackgroundTransparency = Transparency})
		Util.Tween(TextBar, Info, {TextStrokeTransparency = Transparency, TextTransparency = Transparency})
		
		if IsAppearing == false then
			-- Destroy GUI after the animation completes
			BaseNotif.WaitForDur(Info.Time)
			
			Frame:Destroy() -- Other UI components of the meter get destroyed here too
			Corner, TextBar, Bar, Frame, BarCorner = nil, nil, nil, nil, nil
		end
	end)
	
	return Obj
end

return MeterNotification