--[[
Object/instance handler using metatables.
By: udev2192
]]--

export type ObjectPool = {
	Name: string,
	TypeName: string,
	
	SetProperty: (Name: string, Value: any, Updater: (NewValue: any) -> ()?) -> (),
	SetInstanceDestroy: (Enabled: boolean) -> (),
	AddDisposalListener: (Listener: () -> ()) -> (),
	RemoveDisposalListener: (Listener: () -> ()) -> (),
	ClearDisposalListeners: () -> (),
	Dispose: () -> (),
	
	OnUpdate: () -> ()?,
	OnDisposal: () -> ()?,
	
	[string]: any
};

local Object = {};
local Inherited = {};
local InheritedUpdaters = {};

Object.__index = Object;

--[[
Returns true if the specified class matches the object provided,
if it is an object.

Params:
TypeName <string> - The type's name.
Variant <variant> - Any value.

Returns:
<boolean> - Whether or not the type matches.
]]--
function Object.MatchesType(TypeName: string, Variant: any)
	return typeof(Variant) == "table" and TypeName == Variant.TypeName;
end

--[[
	Fires the specified callback with the provided arguments.
	
	Params:
	func <function> - The function to call.
	... <tuple> - The arguments to pass to the function.
]]--
function Object.FireCallback(func: (...any) -> (), ...: any)
	if typeof(func) == "function" then
		coroutine.wrap(func)(...);
	end
end

-- Constructor function for the object (anything outside one of these is static).
function Object.New(Type: string?): ObjectPool
	local Obj = {};
	local Updaters = {};
	local DisposalListeners = {};
	local InstanceDestroyEnabled = false;
	
	if typeof(Type) ~= "string" then
		Type = "";
	end
	
	Obj.Name = Type;
	Obj.TypeName = Type;
	
	-- This part loads inherited properties and their updaters.
	for i, v in pairs(Inherited) do
		Obj[i] = v;
		
		local f = InheritedUpdaters[i]
		if typeof(f) == "function" then
			Updaters[i] = f;
		end
	end
	
	-- The metatable takes care of the indexing.
	local Meta = setmetatable({}, {
		__index = function(t, k)
			if Obj ~= nil then
				return Obj[k];
			end
		end,
		
		__newindex = function(t, k, v)
			if Obj ~= nil then
				Obj[k] = v;

				if k ~= "OnUpdate" then -- To prevent accidental recursion
					-- Fire the event
					local UpdatedCallback = t.OnUpdate;
					if typeof(UpdatedCallback) == "function" then
						coroutine.wrap(UpdatedCallback)(k, v);
					end

					-- Run updater
					if Updaters ~= nil then
						local Updater = Updaters[k];
						if typeof(Updater) == "function" then
							Updater(v);
						end
					end
				end
			end
		end,
	})
	
	-- Asserts if the object has been Dispose()'d.
	local function AssertDisposed()
		assert(DisposalListeners ~= nil, "Object has already been disposed.");
	end
	
	--[[
	Callback that is fired when the object gets updated.
	This can happen through a property being initalized or set.
	]]--
	Obj.OnUpdate = nil;
	
	--[[
	Callback that is fired once the object is "disposed".
	This callback is called before the ones in the listener
	table so use this if you need to set a priority
	disposal callback.
	]]--
	Obj.OnDisposal = nil;
	
	--[[
	Sets a property and specifies what changing it does.
	Should be used for intializing a property.
	
	Params:
	Name <string> - The name of the property to update.
	Value <variant> - The new value of the property.
	Updater <function> - The callback to set (use nil for no callback).
	]]--
	function Obj.SetProperty(Name: string, Value: any, Updater: (...any) -> ()?)
		Obj[Name] = Value;
		
		local IsFunc = typeof(Updater) == "function";
		if Updater == nil or IsFunc then
			Updaters[Name] = Updater;
			
			-- Run the updater for initialization.
			if IsFunc then
				Updater(Value);
			end
		end
	end
	
	--[[
	Sets if this object destroys any object/instance
	that has the :Destroy() function.
	Disabled by default.
	
	Params:
	Enabled <boolean> - Whether or not to do the above.
	]]--
	function Obj.SetInstanceDestroy(Enabled: boolean)
		assert(typeof(Enabled) == "boolean", "Argument 1 must be a boolean.");
		
		InstanceDestroyEnabled = Enabled;
	end
	
	--[[
	Adds a listener function that is called when Dispose() is called.
	
	Params:
	Listener <function> - The function to add.
	]]--
	function Obj.AddDisposalListener(Listener: (...any) -> ())
		AssertDisposed();
		assert(typeof(Listener) == "function", "Argument 1 must be a function.");
		
		DisposalListeners[Listener] = Listener;
	end
	
	--[[
	Removes a listener that is called when Dispose() is called.
	
	Params:
	Listener <function> - The function to remove.
	]]--
	function Obj.RemoveDisposalListener(Listener: (...any) -> ())
		AssertDisposed();
		DisposalListeners[Listener] = nil;
	end
	
	--[[
	Removes all listeners from being called when Dispose() is called.
	]]--
	function Obj.ClearDisposalListeners()
		if DisposalListeners ~= nil then
			DisposalListeners = {};
		end
	end
	
	--[[
	Prepares the object for garbage collection.
	]]--
	function Obj.Dispose()
		Updaters = nil;
		
		-- Run the disposal callback
		local DisposeFunc = Obj.OnDisposal;
		if typeof(DisposeFunc) == "function" then
			-- Run as a non-coroutine, in case any values are still needed
			DisposeFunc();
		end
		
		-- Run the other disposal listeners.
		if DisposalListeners ~= nil then
			for i, v in pairs(DisposalListeners) do
				if typeof(v) == "function" then
					v();
				end
			end
		end
		
		-- Disconnect any Instance execution stuff.
		for i, v in pairs(Obj) do
			pcall(function() 
				local idxType = typeof(v);
				if idxType == "RBXScriptConnection" then
					v:Disconnect();
				elseif idxType == "Instance" and InstanceDestroyEnabled == true then
					v:Destroy();
				end
			end);
		end
		
		-- Destroy the metatable
		setmetatable(Obj, nil);
		Meta = nil;
		DisposalListeners = nil;
		InstanceDestroyEnabled = nil;
		
		-- The Obj table is garbage collected once the field holding
		-- an instance of this object is set to nil or another value
	end
	
	return Meta;
end

return Object;