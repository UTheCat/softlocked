-- Extends the Notfier class to provide some utility functions.
-- By udev2192

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UtilRepModules = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utils")

local Runtime = require(UtilRepModules:WaitForChild("Runtime"))

local Notifiers = script.Parent

local Notifier = require(Notifiers:WaitForChild("Notifier"))
local TextNotif = require(Notifiers:WaitForChild("TextNotification"))

local NotifierToolkit = {}

NotifierToolkit.__index = NotifierToolkit

function NotifierToolkit.New()
	local Toolkit = Notifier.New()
	
	-- Notifies notifications through a function styled like
	-- the one from Flood Escape 2 by Crazyblox Games.
	function Toolkit.NotifyText(Text, Color, Lifetime)
		Lifetime = Lifetime or 4
		
		local Notif = TextNotif.New(Toolkit, Text)

		local Gui = Notif.GetGui()
		Gui.TextColor3 = Color or Gui.TextColor3

		Toolkit.Add(Gui)
		
		coroutine.wrap(function()
			Runtime.WaitForDur(Lifetime)
			Notif.Dispose()
		end)()
		
		return Notif
	end
	
	return Toolkit
end

return NotifierToolkit