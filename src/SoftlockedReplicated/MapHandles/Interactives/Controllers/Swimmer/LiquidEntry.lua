-- Provides an object that handles liquid entry (as a group).
-- By udev2192

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RepModules = ReplicatedStorage:WaitForChild("Modules")
local UtilRepModules = RepModules:WaitForChild("Utils")

local Object = require(UtilRepModules:WaitForChild("Object"))
local Signal = require(UtilRepModules:WaitForChild("Signal"))
local Util = require(UtilRepModules:WaitForChild("Utility"))

local LiquidAdapter = require(script.Parent:WaitForChild("LiquidAdapter"))

local LiquidEntry = {}
local CFRAME_PROPERTY_NAME = "CFrame"

-- Checks if the specified object has the CFrame property.
local function HasCFrame(Obj)
	return Util.IsInstance(Obj) and Util.IsProperty(Obj, CFRAME_PROPERTY_NAME)
end

function LiquidEntry.New()
	local Obj = Object.New("LiquidEntryHandler")
	local Interacting = {} -- Table of interacting parts
	local ActiveBodies = {}
	local CurrentBodies = {}
	local Registered = {} -- Registered liquid adapters
	
	-- Handles body entry internally.
	local function HandleEntry(Part, Body, Entered)
		-- Check if the interacting part is registered
		if typeof(ActiveBodies[Part]) == "table" then
			-- Fire the signal for the most recent body that was entered/exited
			if Entered == true then
				table.insert(ActiveBodies[Part], Body)
			else
				local Index = table.find(ActiveBodies[Part], Body)
				if Index ~= nil then
					table.remove(ActiveBodies[Part], Index)
				end
			end
		end
	end
	
	-- Retoggles for all registered bodies
	local function TogglePartInteraction(Part, IsInteracting)
		for i, v in pairs(Registered) do
			v.SetInteractingPart(Part, IsInteracting)
		end
	end
	
	function Obj.AddInteractingPart(Part)
		assert(HasCFrame(Part), "The object in Argument 1 must have the CFrame property.")
		
		table.insert(Interacting, Part)
		ActiveBodies[Part] = {}
		
		TogglePartInteraction(Part, true)
	end
	
	function Obj.RemoveInteractingPart(Part)
		TogglePartInteraction(Part, false)
		
		local Index = table.find(Interacting, Part)
		
		if Index ~= nil then
			table.remove(Interacting, Index)
		end
		
		ActiveBodies[Part] = nil
		Index = nil
	end
	
	function Obj.DisconnectAllInteractions()
		for i, v in pairs(Interacting) do
			Obj.RemoveInteractingPart(v)
		end
	end
	
	-- Registers/deregisters a liquid BasePart.
	function Obj.ToggleLiquidRegistry(Body, IsRegistered)
		if IsRegistered == true then
			-- Register if not already registered
			if Registered[Body] == nil then
				local Adapter = LiquidAdapter.New(Body)		
				Registered[Body] = Adapter
				for i, v in pairs(Interacting) do
					Adapter.SetInteractingPart(v)
				end
				--print("a")
				Adapter.EntryStatusChanged = function(Part, Entered)
					--print("b")
					if Util.IsInstance(Part) then
						--print("c")
						HandleEntry(Part, Adapter, Entered)
					end
				end
			end
		else
			-- De-register
			local Adapter = Registered[Body]
			if Adapter ~= nil then
				Adapter.Dispose()
			end

			Registered[Body] = nil
			Adapter = nil
		end
	end
	
	function Obj.RemoveAllLiquids()
		for i, v in pairs(Registered) do
			Obj.ToggleLiquidRegistry(i, false)
		end
	end
	
	Obj.BodyEntryChanged = Signal.New()
	
	Obj.OnDisposal = function()
		Obj.DisconnectAllInteractions()
		Obj.RemoveAllLiquids()
	end
end

return LiquidEntry