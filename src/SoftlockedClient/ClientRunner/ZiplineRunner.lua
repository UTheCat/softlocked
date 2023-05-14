-- Runs the zipline package for ziplines in the workspace.
-- By udev2192

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RepModules = ReplicatedStorage:WaitForChild("SoftlockedReplicated")

local ZiplineService = script.Parent:WaitForChild("ZiplineService")

local Adapters = RepModules:WaitForChild("Adapters")
local Utils = RepModules:WaitForChild("Utils")

local InstAdapter = require(Adapters:WaitForChild("InstanceCollector"))
local Object = require(Utils:WaitForChild("Object"))

local PlayerAdapter = require(ZiplineService:WaitForChild("PlayerAdapter"))
local Zipline = require(ZiplineService:WaitForChild("Zipline"))

local Areas = workspace --:WaitForChild("Areas")

local ZipRunner = {}

function ZipRunner.New(Player)
	assert(typeof(Player) == "Instance" and Player:IsA("Player"), "Argument 1 must be a player instance.")
	
	local Obj = Object.New("ZiplineCollector")
	local ZipCollector = InstAdapter.New()
	local ObjPlrAdapter = PlayerAdapter.New(Player)
	
	local Ziplines = {}
	
	-- Toggles zipline registry.
	local function ToggleZiplineRegistry(Inst, Enabled)
		if Enabled == true then
			if typeof(Inst) == "Instance" and Inst:IsA("Model") then
				local Zip = Zipline.New(Inst)
				Ziplines[Inst] = Zip
				Zip.ModelParent = Inst
			end
		else
			local Zip = Ziplines[Inst]
			if Zip ~= nil then
				Zip.Dispose()
			end
			Ziplines[Inst] = nil
			Zip = nil
		end
	end
	
	-- The part of the name to look for when registering a zipline.
	Obj.Keyword = "_Zipline"
	
	-- Disposes all the ziplines.
	function Obj.DisposeAll()
		for i, v in pairs(Ziplines) do
			if v.Dispose ~= nil then
				v.Dispose()
			end
		end
	end
	
	Obj.OnDisposal = function()
		-- Dispose other stuff.
		ZipCollector.Dispose()
		ZipCollector = nil
		
		ObjPlrAdapter.Dispose()
		ObjPlrAdapter = nil
		
		Obj.DisposeAll()
	end
	
	-- Look for ziplines
	ZipCollector.InstanceFound = function(inst)
		ToggleZiplineRegistry(inst, true)
	end
	ZipCollector.InstanceRemoved = function(inst)
		ToggleZiplineRegistry(inst, false)
	end
	ZipCollector.SearchId = Obj.Keyword
	ZipCollector.AdaptInstance(Areas)
end

return ZipRunner