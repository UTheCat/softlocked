--[[
Runs interactives (literally just LocalPartScript)
This is for demo/debug, interactives should be initialized
using other modules with custom implementation as needed

By udev2192
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RepModules = ReplicatedStorage:WaitForChild("SoftlockedReplicated")

local ZiplineService = script.Parent:WaitForChild("ZiplineService")

local Adapters = RepModules:WaitForChild("Adapters")
local Interactives = RepModules:WaitForChild("MapHandles"):WaitForChild("Interactives")
local Utils = RepModules:WaitForChild("Utils")

local InstAdapter = require(Adapters:WaitForChild("InstanceCollector"))
local Object = require(Utils:WaitForChild("Object"))

local PlayerAdapter = require(ZiplineService:WaitForChild("PlayerAdapter"))
local BaseInteractive = require(Interactives:WaitForChild("BaseInteractive"))

local InteractiveRunner = {}

InteractiveRunner.ValueName = "Interactive"

function InteractiveRunner.New()
	local Obj = InstAdapter.New()
	local Stored = {}
	
	local function ToggleInteractive(Inst, IsEnabled)
		if Inst.ClassName == BaseInteractive.ValueClassName then
			local Interact = Stored[Inst]

			if IsEnabled and Interact == nil then
				local InteractClass = BaseInteractive.GetByName(Inst.Value)

				if InteractClass then
					-- Initialize and store
					Stored[Inst] = InteractClass.New(Inst)
				end
			elseif Interact then
				Stored[Inst] = nil
				Interact.Dispose()
			end
		end
	end
	
	Obj.SearchId = InteractiveRunner.ValueName
	
	function Obj.ShutdownAll()
		for i, v in pairs(Stored) do
			v.Shutdown()
		end
	end
	
	function Obj.RunAll()
		for i, v in pairs(Stored) do
			v.OnInitialize.Fire()
			v.OnStart.Fire()
		end
	end
	
	function Obj.Clear()
		for i, v in pairs(Stored) do
			v.Dispose()
		end
		
		Stored = {}
	end

	Obj.OnDisposal = function()
		-- Dispose other stuff.
		Obj.Clear()
	end

	-- Look for ziplines
	Obj.InstanceFound = function(inst)
		ToggleInteractive(inst, true)
	end
	Obj.InstanceRemoved = function(inst)
		ToggleInteractive(inst, false)
	end
	
	return Obj
end

return InteractiveRunner