-- Finds movers using InstanceCollectors and binds them to
-- their corresponding modules
-- By udev2192

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RepModules = ReplicatedStorage:WaitForChild("SoftlockedReplicated")

local Adapters = RepModules:WaitForChild("Adapters")
local Utils = RepModules:WaitForChild("Utils")

local Object = require(Utils:WaitForChild("Object"))
local InstanceCollector = require(Adapters:WaitForChild("InstanceCollector"))

local MoverModules = script.Parent

local MoverFinder = {}
MoverFinder.__index = MoverFinder

-- Instance collection prefix.
-- Ex: "_ExampleMover"
MoverFinder.Prefix = "_"

MoverFinder.DefaultSearchInstance = workspace:WaitForChild("Areas")

local function IsPart(Part)
	return typeof(Part) == "Instance" and Part:IsA("Part")
end

-- Constructor
-- Note: Module is the module instance itself
function MoverFinder.New(Name, CharAdapter)
	assert(typeof(Name) == "string", "Argument 1 must be a string.")
	assert(typeof(CharAdapter) == "table", "Argument 2 must be a CharacterAdapter.")
	
	local Mod = MoverModules:WaitForChild(Name, 5)
	
	if typeof(Mod) == "Instance" and Mod:IsA("ModuleScript") then
		Mod = require(Mod)
		
		local Obj = Object.New("MoverFinder")
		local MoverCollector = InstanceCollector.New()
		MoverCollector.SearchId = MoverFinder.Prefix .. Name
		
		local Movers = {}
		
		Obj.NextSearchInstance = MoverFinder.DefaultSearchInstance
		
		-- Dispose()s a single mover.
		function Obj.ClearMover(Part)
			local Mover = Movers[Part]
			
			if Mover ~= nil and Mover.Dispose ~= nil then
				Mover.Dispose()
			end
			
			Movers[Part] = nil
			Mover = nil
		end
		
		-- Garbage collects the found movers.
		function Obj.ClearAllMovers()
			for i, v in pairs(Movers) do
				Obj.ClearMover(v)
			end
		end
		
		-- Searches for the movers.
		function Obj.Search()
			local Keyword = MoverFinder.Prefix .. Name
			MoverCollector.AdaptInstance(Obj.NextSearchInstance)
		end
		
		MoverCollector.InstanceFound = function(Inst)
			if IsPart(Inst) == true then
				-- Add the mover.
				Movers[Inst] = Mod.New(Inst, CharAdapter)
			end
		end
		
		MoverCollector.InstanceRemoved = function(Inst)
			Obj.ClearMover(Inst)
		end
		
		Obj.OnDisposal = function()
			MoverCollector.Dispose()
			MoverCollector = nil
			
			Obj.ClearAllMovers()
			Movers = nil
			
			Mod = nil
		end
		
		return Obj
	else
		Mod = nil
		error("Couldn't find the mover module named:", Name)
	end
end

return MoverFinder