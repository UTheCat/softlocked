-- This class lays the foundation of notifications that appear somewhere
-- on the user's screen.
-- This class is used for a group of notifications and handles positioning.

-- By udev2192

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RepModules = ReplicatedStorage:WaitForChild("Modules")
local UtilRepModules = RepModules:WaitForChild("Utils")

local Object = require(UtilRepModules:WaitForChild("Object"))
local Signal = require(UtilRepModules:WaitForChild("Signal"))

local Notifier = {}
local PREFERRED_SIZE_ADDEND = UDim2.new(0.3, 0, 0, 0)

local Abs = math.abs

Notifier.__index = Notifier
Notifier.TypeName = "Notifier"

local function AbsoluteUDim2Value(Udim)
	return UDim2.new(Abs(Udim.X.Scale), Abs(Udim.X.Offset), Abs(Udim.Y.Scale), Abs(Udim.Y.Offset))
end

local function MultiplyUDim2(Udim, Multiplier)
	local ScaleX = Udim.X.Scale * Multiplier
	local OffsetX = Udim.X.Offset * Multiplier
	local ScaleY = Udim.Y.Scale * Multiplier
	local OffsetY = Udim.Y.Offset * Multiplier
	
	return UDim2.new(ScaleX, OffsetX, ScaleY, OffsetY)
end

function Notifier.New()
	local Obj = Object.New(Notifier.TypeName)
	local GuiList = {} -- Gui array
	local TweenFuncs = {}
	
	local NotifFrame = Instance.new("Frame")
	NotifFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	NotifFrame.Size = UDim2.new(1, 0, 1, 0)
	NotifFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	NotifFrame.BackgroundTransparency = 1
	NotifFrame.BorderSizePixel = 0
	NotifFrame.Name = Notifier.TypeName .. "Frame"
	
	-- Starting position where the notifications are created.
	-- Use this point for the start of a tween for the most
	-- recent notification.
	Obj.StartPosition = UDim2.new(0.5, 0, 0.85, 0)
	
	-- How much each notification is "shoved by" on the screen.
	-- This affects the most recent notification too.
	Obj.MovePosition = UDim2.new(0, 0, -0.05, 0)
	
	-- Reference value that indicates the size each notification should be
	-- so that they fit onto a list with equal spacing.
	Obj.PreferredSize = AbsoluteUDim2Value(Obj.MovePosition) + PREFERRED_SIZE_ADDEND
	
	-- Reference number for notification animation time
	Obj.PreferredAnimationTime = 0.25
	
	-- Reference number for notification tweening info
	Obj.PreferredTweenInfo = TweenInfo.new(Obj.PreferredAnimationTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	-- Whether or not to destroy instances in GuiList when Dispose() is called.
	Obj.AutoDestroy = true
	
	-- Returns a reference to GuiList.
	function Obj.GetGuiList()
		return GuiList
	end
	
	-- Returns a reference to the Notifier's frame instance.
	function Obj.GetFrame()
		return NotifFrame
	end
	
	-- Sets the notifier frame's parenting instance.
	function Obj.SetParent(Inst)
		NotifFrame.Parent = Inst
	end
	
	-- Sets the Z-Index property of the notifier's frame
	function Obj.SetLayer(Layer)
		NotifFrame.ZIndex = Layer
	end
	
	-- Returns the preferred UDIm2 position of the Gui if it is added
	-- to the group.
	function Obj.GetPosition(Gui)
		local Index = table.find(GuiList, Gui)
		
		if Index ~= nil then
			return Obj.StartPosition + MultiplyUDim2(Obj.MovePosition, Index + 1)
		end
	end
	
	-- Calls the notification GUI animators.
	local function CallGuiAnimators(GuiAffected, IsAppearing)
		for i, v in ipairs(GuiList) do
			local Func = TweenFuncs[v]
			
			if typeof(Func) == "function" then
				-- So the only gui that is animating out is GuiAffected,
				-- if IsApppearing is false
				if v == GuiAffected and IsAppearing == false then
					IsAppearing = false
				else
					IsAppearing = true
				end
				
				coroutine.wrap(Func)(IsAppearing, Obj.GetPosition(v))
			end
			
			Func = nil
		end
	end
	
	-- Binds a function for animating the GUI for the notification.
	-- Function (arg 2) format: function(IsAppearing, Position)
	function Obj.AddAnimatorFunc(Gui, Func)
		TweenFuncs[Gui] = Func
	end
	
	-- Removes a function for animating the GUI for the notification.
	function Obj.RemoveAnimatorFunc(Gui)
		TweenFuncs[Gui] = nil
	end
	
	-- Adds the specified GUI object to the list and returns its
	-- preffered UDim2 position on the list.
	function Obj.Add(Gui)
		local Index = 1
		table.insert(GuiList, Index, Gui)
		
		Gui.Parent = NotifFrame
		
		local PreferredPos = Obj.StartPosition + MultiplyUDim2(Obj.MovePosition, Index)
		Obj.GuiAdded.Fire(Gui, PreferredPos)
		
		CallGuiAnimators(Gui, true)
		
		return PreferredPos
	end
	
	-- Removes the specified GUI from the UI list.
	-- The Gui must be Destroy()ed externally for it to go away.
	function Obj.Remove(Gui)
		local Index = table.find(GuiList, Gui)
		
		if Index ~= nil then			
			-- Remove from the list
			table.remove(GuiList, Index)
			local OutPosition = Obj.StartPosition + MultiplyUDim2(Obj.MovePosition, Index + 2)
			Obj.GuiRemoved.Fire(Gui, OutPosition)
			
			CallGuiAnimators(Gui, false)
			
			-- Call the animator for the notification going out
			local Func = TweenFuncs[Gui]
			if typeof(Func) == "function" then
				coroutine.wrap(Func)(false, OutPosition)
			end
			
			OutPosition, Func = nil, nil
			Obj.RemoveAnimatorFunc(Gui)
		end
	end
	
	-- Fires when a GUI component is added.
	-- Params:
	-- Gui - The GUI instance added.
	-- Position - The preferred UDim2 position of the UI.
	Obj.GuiAdded = Signal.New()
	
	-- Fires when a GUI component is removed.
	-- Params:
	-- Gui - The GUI instance removed.
	-- Position - The preffered UDim2 position to animate to.
	Obj.GuiRemoved = Signal.New()
	
	Obj.OnDisposal = function()
		Obj.GuiAdded.DisconnectAll()
		Obj.GuiRemoved.DisconnectAll()
		
		if Obj.AutoDestroy == true then
			NotifFrame:Destroy()
			NotifFrame = nil
			
			for i, v in pairs(GuiList) do
				if typeof(v) == "Instance" then
					v:Destroy()
				end
			end
		end
		
		TweenFuncs = nil
		GuiList = nil
	end
	
	return Obj
end

return Notifier