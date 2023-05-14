-- This module provides a class that lays the foundation of a notification.
-- This is to be used with the Notifier class.

-- By udev2192

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RepModules = ReplicatedStorage:WaitForChild("SoftlockedReplicated")
local UtilRepModules = RepModules:WaitForChild("Utils")

local Object = require(UtilRepModules:WaitForChild("Object"))
local Util = require(UtilRepModules:WaitForChild("Utility"))

local Notifier = require(script.Parent:WaitForChild("Notifier"))

local BaseNotification = {}
local NotifierType = Notifier.TypeName

-- Color sequence from top to bottom
local DEFAULT_COLOR_SEQUENCE = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180))})

-- Convienence function for getting the utilities.
function BaseNotification.GetUtils()
	return Util
end

-- Convience wait function:
-- Waits for a specified amount of time in seconds.
-- Returns the time difference between the desired wait
-- and the actual wait.
function BaseNotification.WaitForDur(Duration)
	assert(typeof(Duration) == "number", "Argument 1 must be a number.")

	local Elapsed = 0
	while (Elapsed < Duration) do
		Elapsed += RunService.Heartbeat:Wait()
	end

	return Elapsed - Duration
end

-- Utility function for applying a gradient.
function BaseNotification.ApplyGradient(Gui, ColorSeq)
	assert(typeof(Gui) == "Instance", "Argument 1 must be an instance")
	
	ColorSeq = ColorSeq or DEFAULT_COLOR_SEQUENCE
	
	local Gradient = Util.CreateInstance("UIGradient", {
		Color = ColorSeq,
		Rotation = 90,
		Parent = Gui
	})
	
	return Gradient
end

function BaseNotification.New(NotifierObj, Gui)
	assert(Object.MatchesType(NotifierType, NotifierObj), "Argument 1 must be of type " .. NotifierType)
	assert(typeof(Gui) == "Instance" and Gui:IsA("GuiObject"), "Argument 2 must be a GuiObject")
	
	local Obj = Object.New("BaseNotification")
	
	-- Whether to destroy the Gui when Dispose() is called.
	Obj.AutoDestroyGui = false
	
	-- Applies the dimensions based off the Notifier's dimension properties.
	function Obj.ApplyDimensions()
		Gui.Size = NotifierObj.PreferredSize
		Gui.Position = NotifierObj.StartPosition
	end
	
	-- Returns a reference to the GuiObject associated.
	function Obj.GetGui()
		return Gui
	end
	
	-- Sets the animation/tweening function.
	-- Put nil as argument 1 to remove the function.
	function Obj.SetAnimator(Func)
		if typeof(Func) == "function" then
			NotifierObj.AddAnimatorFunc(Gui, Func)
		else
			NotifierObj.RemoveAnimatorFunc(Gui)
		end
	end
	
	-- Adds the notification to the Notifier.
	function Obj.Appear()
		NotifierObj.Add(Gui)
	end
	
	-- Use Dispose() to get rid of the notification (and animate it out,
	-- if applicable).
	Obj.OnDisposal = function()
		NotifierObj.Remove(Gui)
		
		-- Hide animation would be completed when this point is reached
		Obj.SetAnimator(nil)
		
		if Obj.AutoDestroyGui == true then
			Gui:Destroy()
		end
	end
	
	return Obj
end

return BaseNotification