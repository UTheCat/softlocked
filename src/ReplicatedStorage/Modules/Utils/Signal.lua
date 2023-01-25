--[[
Bindable event alternative cause boblox.

By udev2192
]]--

local Utils = script.Parent
local Object = require(Utils:WaitForChild("Object"))

local SignalClass = {}

export type SignalConnection = {
	Callback: (...any) -> (),
	Disconnect: () -> ()
}

export type Signal = {
	Sync: boolean,
	Disconnect: (f: (...any) -> ()) -> (),
	Connect: (f: (...any) -> ()) -> SignalConnection,
	DisconnectAll: () -> (),
	Fire: (...any) -> ()
}

SignalClass.__index = SignalClass

-- Constructor
function SignalClass.New(): Signal
	local Obj = {}
	
	-- The list of listener functions.
	local Listeners = {}
	
	--[[
	<boolean> - Whether or not listeners are called from the
				same thread.
	]]--
	Obj.Sync = false
	
	--[[
	Disconnects a function from the signal.
	
	Params:
	f <function> - The function to disconnect.
	]]--
	function Obj.Disconnect(f)
		local Index = table.find(Listeners, f)

		if Index ~= nil then
			table.remove(Listeners, Index)
		end
	end
	
	--[[
	Connects a function to the signal.
	
	Params:
	f <function> - The function to connect.
	
	Returns:
	<SignalConnection> - A table with a function for disconnecting the listener.
	]]--
	function Obj.Connect(f)
		assert(typeof(f) == "function", "Argument 1 must be a function.")
		
		local t = {
			Callback = f,
			Disconnect = function()
				Obj.Disconnect(f)
			end
		}
		
		table.insert(Listeners, t)
		return t
	end
	
	--[[
	Disconnects all the listeners currently connected.
	]]--
	function Obj.DisconnectAll()
		Listeners = {}
	end
	
	--[[
	Calls all the listeners currently connected.
	If Obj.Sync is false, they will all
	be called in separate threads.
	
	Params:
	Args <tuple> - the arguments to pass to the listeners.
	]]--
	function Obj.Fire(...)
		if Listeners ~= nil then
			local Sync = Obj.Sync
			
			for i, v in pairs(Listeners) do
				if Sync == true then
					v.Callback(...)
				else
					task.spawn(v.Callback, ...)
				end
			end
		end
	end
	
	return Obj
end

return SignalClass