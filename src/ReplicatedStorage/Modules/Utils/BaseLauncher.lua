-- The base class used to initialize a game, whether that would be
-- from the server or the client.
-- The Launchers package is to keep things under the same place file,
-- which makes it easier to develop the game.

-- By udev2192

local Object = require(script.Parent:WaitForChild("Object"))

local BaseLauncher = {}

-- Removes the server object from the table
-- in which they are stored and attempts
-- to do methods for garbage collection.
function BaseLauncher.DestroyObject(Var)
	if typeof(Var) == "table" and typeof(Var.Dispose) == "function" then
		Var.Dispose()
	elseif typeof(Var) == "Instance" then
		Var:Destroy()
	elseif typeof(Var) == "RBXScriptConnection" then
		Var:Disconnect()
	end

	Var = nil
end

function BaseLauncher.New()
	local Obj = Object.New("BaseLauncher")
	local StartFunc = nil
	local ShutdownFunc = nil
	local StoredObjects = {} -- Object storage
	
	-- Timestamp in seconds that Start() was called
	Obj.StartedAt = 0
	
	--[[
	Whether or not to garbage collect stored objects
	when Shutdown() is called.
	]]--
	Obj.AutoDestroy = true
	
	-- Resets the number stored in StartedAt and
	-- calls the start function.
	function Obj.Start()
		Obj.StartedAt = os.time()
		if typeof(StartFunc) == "function" then
			StartFunc()
		end
	end
	
	-- Sets the start/initializer function.
	function Obj.SetStarter(Func)
		if Func ~= nil then
			assert(typeof(Func) == "function", "Argument 1 must be a function.")
			StartFunc = Func
		else
			StartFunc = nil
		end
	end
	
	-- Binds a shutdown function that runs when Shutdown() is called
	-- before it clears everything.
	function Obj.BindToShutdown(Func)
		if Func ~= nil then
			assert(typeof(Func) == "function", "Argument 1 must be a function.")
			ShutdownFunc = Func
		else
			ShutdownFunc = nil
		end
	end
	
	--[[
	Stores an object so that it can be removed once
	the launcher is requested to clear it.
	
	Params:
	Var <variant> - Any value.
	]]--
	function Obj.StoreObjectForDisposal(Var)
		table.insert(StoredObjects, Var)
	end
	
	-- Clears all stored objects put in from
	-- store object for removal.
	function Obj.ClearStoredObjects()
		StoredObjects = {}
	end
	
	--[[
	Attempts to garbage collect each value scheduled for garbage
	collection via StoreObjectForDisposal, then clears the table.
	]]--
	function Obj.DestroyStoredObjects()
		for i, v in pairs(StoredObjects) do
			BaseLauncher.DestroyObject(v)
			StoredObjects[i] = nil
		end
	end
	
	
	-- Shuts the launcher down.
	function Obj.Shutdown()
		-- Call the shutdown function.
		if typeof(ShutdownFunc) == "function" then
			ShutdownFunc()
		end
		
		-- Clear everything.
		Obj.SetStarter(nil)
		Obj.BindToShutdown(nil)
		
		if Obj.AutoDestroy == true then
			Obj.DestroyStoredObjects()
		else
			Obj.ClearStoredObjects()
		end
	end
	
	Obj.OnDisposal = Obj.Shutdown
	
	return Obj
end

return BaseLauncher