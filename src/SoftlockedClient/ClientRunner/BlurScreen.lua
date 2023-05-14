-- Provides an object that displays a blur screen.
-- By udev2192

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ORIGINAL_RESPAWN_TIME = Players.RespawnTime
--local DEFAULT_BLUR_COLOR = Color3.new(1, 1, 1)

local RepModules = ReplicatedStorage:WaitForChild("SoftlockedReplicated")
local Adapters = RepModules:WaitForChild("Adapters")
local UtilRepModules = RepModules:WaitForChild("Utils")

local Object = require(UtilRepModules:WaitForChild("Object"))
local Runtime = require(UtilRepModules:WaitForChild("Runtime"))
local Util = require(UtilRepModules:WaitForChild("Utility"))

local DeathFX = {}
DeathFX.DefaultTweenInfo = TweenInfo.new(math.min(0.5, ORIGINAL_RESPAWN_TIME), Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

function DeathFX.New()
	local Obj = Object.New("BlurScreen")
	local IsFadingIn = false
	
	Obj.TweenInfo = DeathFX.DefaultTweenInfo
	Obj.FadeInAfter = ORIGINAL_RESPAWN_TIME - Obj.TweenInfo.Time - 0.1
	--Obj.Color = DEFAULT_BLUR_COLOR
	
	Obj.Blur = Util.CreateInstance("BlurEffect", {
		Enabled = false,
		Size = 0
	})
	--Obj.ColorCorrection = Util.CreateInstance("ColorCorrectionEffect", {
	--	Enabled = false,
	--	TintColor = Obj.Color,
	--	Brightness = 0
	--})
	Obj.Frame = Util.CreateInstance("Frame", {
		Visible = false,
		
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		
		BackgroundTransparency = 1,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		
		ZIndex = 1
	})

	-- Sets the parent property of the blur effect instances
	-- to the one specified.
	--function Obj.SetParent(Inst)
	--	local Blur = Obj.Blur
	--	local ColorCorrection = Obj.ColorCorrection

	--	if Blur ~= nil and ColorCorrection ~= nil then
	--		Blur.Parent = Inst
	--		ColorCorrection.Parent = Inst
	--	end
	--end

	-- Fades in the blur screen.
	function Obj.FadeIn()
		local Blur = Obj.Blur
		local Frame = Obj.Frame
		--local ColorCorrection = Obj.ColorCorrection

		if Blur ~= nil and Frame ~= nil then
			IsFadingIn = true
			Blur.Enabled = true
			Frame.Visible = true
			
			local ti = Obj.TweenInfo
			Util.Tween(Blur, ti, {Size = 64})
			--Util.Tween(ColorCorrection, ti, {Brightness = 1})
			Util.Tween(Frame, ti, {BackgroundTransparency = 0})
			ti = nil
		end
	end

	-- Fades out the blur screen.
	function Obj.FadeOut()
		local Blur = Obj.Blur
		local Frame = Obj.Frame

		if Blur ~= nil and Frame ~= nil then
			IsFadingIn = false
			
			--ColorCorrection.TintColor = Obj.Color
			local ti = Obj.TweenInfo
			Util.Tween(Blur, ti, {Size = 0})
			--Util.Tween(ColorCorrection, ti, {Brightness = 0})
			Util.Tween(Frame, ti, {BackgroundTransparency = 1})
			
			-- Wait before disabling so the animation can finish
			Runtime.WaitForDur(ti.Time)
			ti = nil
			
			-- Disable FX
			if IsFadingIn == false then
				Blur.Enabled = false
				Frame.Visible = false
			end
		end
	end
	
	-- Initialize
	Obj.SetInstanceDestroy(true)

	return Obj
end

return DeathFX