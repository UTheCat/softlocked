-- Class for creating a basic text notification.
-- By udev2192

local BaseNotif = require(script.Parent:WaitForChild("BaseNotification"))
local Util = BaseNotif.GetUtils()

local TextNotification = {}
local GRADIENT_ENABLED = true

function TextNotification.New(Notifier, Text)
	local Label = Util.CreateInstance("TextLabel", {
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = Enum.Font.Gotham,
		TextScaled = true,
		Text = Text or ""
	})
	
	if GRADIENT_ENABLED == true then
		BaseNotif.ApplyGradient(Label)
	end
	
	local Notif = BaseNotif.New(Notifier, Label)
	Notif.TweenInfo = Notifier.PreferredTweenInfo
	Notif.ApplyDimensions(Label)
	
	-- Notification animator function
	Notif.SetAnimator(function(IsAppearing, Pos)
		local Transparency = 0
		if IsAppearing == true then
			Transparency = 0
		else
			Transparency = 1
		end
		
		local Info = Notif.TweenInfo or TweenInfo.new()
		local Tween = Util.Tween(Label, Info, {TextTransparency = Transparency, TextStrokeTransparency = Transparency, Position = Pos})
		
		if IsAppearing == false then
			BaseNotif.WaitForDur(Info.Time)
			Label:Destroy()
			Label = nil
		end
	end)
	
	return Notif
end

return TextNotification