-- Finds cuttable parts that PartCutter can interact with.
-- By udev2192

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RepModules = ReplicatedStorage:WaitForChild("Modules")
local Adapters = RepModules:WaitForChild("Adapters")
local UtilRepModules = RepModules:WaitForChild("Utils")

local InstanceCollector = require(Adapters:WaitForChild("InstanceCollector"))
local Signal = require(UtilRepModules:WaitForChild("Signal"))

local PartCutters = script.Parent

local PartCutter = require(PartCutters:WaitForChild("PartCutter"))

ReplicatedStorage, RepModules, Adapters, UtilRepModules, PartCutters = nil, nil, nil, nil, nil

local CuttableFinder = {}

local function IsInstance(Obj)
	return typeof(Obj) == "Instance"
end

-- Constructs the finder for cuttable parts and returns it.
function CuttableFinder.New(Inst)
	assert(IsInstance(Inst), "Argument 1 must be an instance.")
	
	local Finder = InstanceCollector.New()
	local Cuttables = {}
	
	Finder.SearchId = "_Cuttable"
	
	-- Fired when a PartCut is found.
	Finder.PartCutFound = Signal.New()

	-- Fired when a PartCut is removed.
	Finder.PartCutRemoved = Signal.New()
	
	-- Removes and disposes a cuttable.
	function Finder.DisposeCuttable(Cut)
		local CutObj = Cuttables[Cut]
		
		if CutObj ~= nil then
			CutObj.Dispose()
		end
		
		Cuttables[Cut] = nil
		CutObj = nil
	end
	
	-- Removes all cuttables found and/or stored.
	function Finder.DisposeAllCuttables()
		for i, v in pairs(Cuttables) do
			Finder.DisposeCuttable(v)
		end
	end
	
	-- Connect events to found/removed parts.
	Finder.InstanceFound = function(Part)
		if IsInstance(Part) and Part:IsA("BasePart") then
			local Cutter = PartCutter.New(Part)
			Cutter.ToggleUpdater(true)
			
			Cuttables[Part] = Cutter
		end
	end
	
	Finder.InstanceRemoved = function(Part)
		if IsInstance(Part) and Part:IsA("BasePart") then
			Finder.DisposeCuttable(Part)
		end
	end
	
	Finder.AddDisposalListener(function()
		if Finder.PartCutFound ~= nil then
			Finder.PartCutFound.DisconnectAll()
		end
		
		if Finder.PartCutRemoved ~= nil then
			Finder.PartCutRemoved.DisconnectAll()
		end
	end)
	
	-- Search.
	Finder.AdaptInstance(Inst)
	
	return Finder
end

return CuttableFinder