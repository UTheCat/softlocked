--[[
Locks an instance's property to a certain value.

By udev2192
]]--

local Object = require(script.Parent.Parent:WaitForChild("Interactives"):WaitForChild("BaseInteractive")).GetObjectClass()

local PropertyLock = {}
PropertyLock.__index = PropertyLock
PropertyLock.ClassName = script.Name

function PropertyLock.New(Inst: Instance)
	local Lock = {}
	
	local OriginalProperties = {}
	local LockedProperties = {}
	
	-- We can't use Instance.Changed since ValueBase exists
	local ChangeSignals = {}
	
	local function ResetProperty()
		--OriginalProperties[Property] = Inst[Property]
		--Inst[Property] = LockedProperties[Property]
		
		for i, v in pairs(LockedProperties) do
			local New = Inst[i]
			if v ~= New then
				OriginalProperties[i] = New
				Inst[i] = v
			end
		end
	end
	
	--[[
	Lets a locked property be changed again and changes the value
	of the property back to the most recent external change
	
	Params:
	Property <string> - The property to release/unlock
	]]--
	function Lock.Release(Property: string)
		local Connection = ChangeSignals[Property]
		if Connection then
			Connection:Disconnect()
			ChangeSignals[Property] = nil
		end
		
		if LockedProperties[Property] then
			LockedProperties[Property] = nil
		end
		
		Inst[Property] = OriginalProperties[Property]
	end
	
	--[[
	Unlocks every property that was locked by this object
	]]--
	function Lock.ReleaseAll()
		for i, v in pairs(LockedProperties) do
			Lock.Release(i)
		end
	end
	
	--[[
	Locks a property of the provided instance to a certain value
	
	Params:
	Property <string> - The property to set
	Value <any> - The value of the property to lock to
	]]--
	function Lock.Set(Property: string, Value: any)
		assert(typeof(Property) == "string", "Argument 1 must be a string")
		
		if LockedProperties[Property] == nil then
			LockedProperties[Property] = Value
			OriginalProperties[Property] = Inst[Property]
			
			Inst[Property] = Value
		end
		
		if ChangeSignals[Property] == nil then
			ChangeSignals[Property] = Inst:GetPropertyChangedSignal(Property):Connect(ResetProperty)
		end
	end
	
	return Lock
end

return PropertyLock