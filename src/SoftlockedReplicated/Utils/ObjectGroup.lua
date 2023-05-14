-- A utility object for storing a group of objects.

local Object = require(script.Parent:WaitForChild("Object"))

local ObjectGroup = {}

function ObjectGroup.New()
	local Obj = Object.New("ObjectGroup")
	local Objects = {}
	
	-- If Clean() is called when Dispose() is called.
	Obj.CleansOnDisposal = true
	
	-- Adds an object to the group.
	function Obj.Add(Var)
		Objects[Var] = Var
	end
	
	-- Removes an object to the group.
	function Obj.Remove(Var)
		Objects[Var] = nil
	end
	
	-- Attempts to garbage collect all objects stored in the group.
	function Obj.Clean()
		for i, v in pairs(Objects) do
			Objects[i] = nil
			
			-- Attempt further garbage collection
			if typeof(v) == "table" and typeof(v.Dispose) == "function" then
				v.Dispose()
			elseif typeof(v) == "Instance" then
				v:Destroy()
			elseif typeof(v) == "RBXScriptConnection" then
				v:Disconnect()
			end
			
			i, v = nil, nil
		end
	end
	
	Obj.OnDisposal = function()
		if Obj.CleansOnDisposal == true then
			Obj.Clean()
		else
			for i, v in pairs(Objects) do
				Obj.Remove(v)
			end
		end
	end
	
	return Obj
end

return ObjectGroup