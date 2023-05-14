--[[
Provides an object that can be used to make a set of 
instance property defaults.

By udev2192
]]--

local Utils = script.Parent.Parent:WaitForChild("Utils")
local Object = require(Utils:WaitForChild("Object"))

Utils = nil

local BaseScheme = {}

-- Ensures that the same table is returned for every require()
-- made to this module.
BaseScheme.__index = BaseScheme

-- The module's scheme storage. Used for schemes that will apply
-- as a static set of defaults.
BaseScheme.StoredSchemes = {}

-- Removes a stored scheme.
function BaseScheme.RemoveScheme(Name)
	local OldScheme = BaseScheme.StoredSchemes[Name]
	if OldScheme ~= nil then
		OldScheme.Dispose()
	end
	BaseScheme.StoredSchemes[Name] = nil
	OldScheme = nil
end

-- Constructs a new scheme.
function BaseScheme.New(Name)
	assert(Name ~= nil, "Argument 1 cannot be nil.")
	
	-- Dispose the old scheme if it has an index match.
	BaseScheme.RemoveScheme(Name)
	
	local Obj = Object.New("BaseScheme")
	
	-- Store the new scheme for reference.
	BaseScheme.StoredSchemes[Name] = Obj

	-- Instance/object defaults. Keys added to this
	-- table should match the potential ClassName parameter
	-- of the member functions.
	Obj.Defaults = {}
	
	--[[
	-- Removes a defaults table from the scheme by ClassName.
	-- Params:
	-- ClassName (string) - The name of the class default table to store.
	function Obj.RemoveDefaultSet(ClassName)
		if Defaults ~= nil then
			Defaults[ClassName] = nil
		end
	end

	-- Adds a defaults table to the scheme by ClassName.
	-- Params:
	-- ClassName (string) - The name of the class default table to store.
	-- DefaultList (table) - The set of defaults to store for the class.
	function Obj.AddDefaultSet(ClassName, DefaultList)
		assert(typeof(DefaultList) == "table", "Argument 2 must be a table.")

		if Defaults ~= nil then
			Defaults[ClassName] = DefaultList
		end
	end

	-- Returns the defaults table stored under the provided class name.
	function Obj.GetDefaultSet(ClassName)
		if Defaults ~= nil then
			return Defaults[ClassName]
		end
	end
	]]--
	
	-- Attempts to set the instance/object's properties to apply defaults.
	-- Params:
	-- Inst (Object) - The instance/object/table to apply properties to.
	-- 				 - This can be any type of table.
	-- ClassName (string) - The instance's class name (ex. Part)
	-- Properties (table) - The properties that will override the
	-- 						scheme's set defaults.
	function Obj.ApplyProperties(Inst, ClassName, Properties)
		local DefaultProperties = Obj.Defaults

		-- Set defaults. If an override is detected for the property
		-- is detected, make that override. If the override is made,
		-- remove it from the override table so that the next loop
		-- doesn't repeat the override. (Duplicate overrides are prevented
		-- because we don't want a change listener to fire twice for the same
		-- change request)
		if DefaultProperties ~= nil then
			DefaultProperties = DefaultProperties[ClassName]
			
			if DefaultProperties ~= nil then
				for i, v in pairs(DefaultProperties) do
					-- Put override table in priority.
					-- If no override exists, grab from the defaults table.
					if Properties ~= nil then
						local Override = Properties[i]
						if Override ~= nil then
							Inst[i] = Override

							-- Remove from override table.
							Properties[i] = nil

							continue
						end
					end
					
					Inst[i] = v
				end
			end
		end

		-- Set override table properties that haven't
		-- been set yet
		if Properties ~= nil then
			for i, v in pairs(Properties) do
				Inst[i] = v
			end
		end
	end

	-- Creates and returns an Instance based on the scheme specified.
	-- Params:
	-- ClassName (string) - The instance's class name (ex. Part)
	-- Properties (table) - The properties that will override the
	-- 						scheme's set defaults.
	function Obj.MakeInstance(ClassName, Properties)
		local Inst = Instance.new(ClassName)
		Obj.ApplyProperties(Inst, ClassName, Properties)
		
		return Inst
	end
	
	Obj.OnDisposal = function()
		BaseScheme.RemoveScheme(Name)
	end

	return Obj
end

-- Gets a scheme by name.
-- If it doesn't exist, a new one is created with
-- the specified name and is returned.
-- For more efficient memory usage, this should be used
-- instead of the "New()" constructor.
function BaseScheme.GetScheme(Name)
	return BaseScheme.StoredSchemes[Name] or BaseScheme.New(Name)
end

return BaseScheme