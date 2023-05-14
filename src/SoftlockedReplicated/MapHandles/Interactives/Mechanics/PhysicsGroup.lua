--[[
Physics group intended for leaving parts unanchored only when certain conditions are met.
This is basically here for performance reasons and is intended for use on the client.

By udev2192
]]--

local PhysicsGroup = {}

local Interactives = script.Parent.Parent
local InteractiveUtil = Interactives.Parent:WaitForChild("Util")

local BaseInteractive = require(Interactives:WaitForChild("BaseInteractive"))
local PointHitbox = require(InteractiveUtil:WaitForChild("PointHitbox"))
local PropertyLock = require(InteractiveUtil:WaitForChild("PropertyLock"))

PhysicsGroup.SimulateZoneName = "SimulateZone"
PhysicsGroup.AnchoredProperty = "Anchored"

PhysicsGroup.SimulateOnLoadAttribute = "SimulateOnLoad"
PhysicsGroup.ShowOnSimulateAttribute = "ShowOnSimulate"

--[[
<table {string}> - List of ClassNames that can be hidden when outside of a simulation zone
]]--
PhysicsGroup.PartVisuals = {"Beam", "ParticleEmitter", "Fire", "Trail"}

function PhysicsGroup.New(Val: StringValue, MapLauncher: {})
	local Interact = BaseInteractive.New()

	local AnchorLocks = {}
	local DescendantParts = {}
	local OptimizedVisuals = {} -- Beams, ParticleEmitters, etc.

	local EntryDetector

	-- The original parts folder
	local PartsFolder
	local PartsFolderParent

	-- The parts folder that will actually be used
	local PartsFolderClone

	local function ClearAnchorLocks()
		for i, v in pairs(AnchorLocks) do
			v.ReleaseAll()
		end

		AnchorLocks = {}
	end
	
	local function CheckSimulationZone(IsEntered)
		if IsEntered then
			-- Set parts back to their original anchor values
			ClearAnchorLocks()
		else
			-- Anchor all parts in the parts folder
			-- and lock it as "anchored"
			for i, v in pairs(DescendantParts) do
				local AnchorLock = PropertyLock.New(v)
				table.insert(AnchorLocks, AnchorLock)
				AnchorLock.Set(PhysicsGroup.AnchoredProperty, true)
			end
		end
		
		-- Enable/disable part visuals as needed
		for i, v in pairs(OptimizedVisuals) do
			v.Enabled = IsEntered
		end
	end
	
	local function OnRespawn(Parts)
		if EntryDetector then
			EntryDetector.BindedPart = Parts.RootPart
		end
	end
	
	function Interact.OnInitialize()
		PartsFolder = Val.Parent:WaitForChild("Parts", 5)

		if PartsFolder then
			-- Put parts into the workspace only when needed
			PartsFolderParent = PartsFolder.Parent
			PartsFolder.Parent = nil
		else
			error("Parts folder is missing. PhysicsGroup will not appear in Workspace as intended.")
		end
	end
	
	function Interact.OnStart()
		if PartsFolder and PartsFolderClone == nil then
			PartsFolderClone = PartsFolder:Clone()
			DescendantParts = {}
			OptimizedVisuals = {}

			local VisualNames = PhysicsGroup.PartVisuals
			local SimulateOnLoad = PhysicsGroup.SimulateOnLoadAttribute
			local ShowOnSimulate = PhysicsGroup.ShowOnSimulateAttribute

			for i, v in pairs(PartsFolderClone:GetDescendants()) do
				if v:IsA("BasePart") then
					table.insert(DescendantParts, v)

					-- Unanchor or disable if requested
					if v:GetAttribute(SimulateOnLoad) == true then
						v.Anchored = false
					end
				elseif v:GetAttribute(ShowOnSimulate) == true and table.find(VisualNames, v.ClassName) ~= nil then
					table.insert(OptimizedVisuals, v)
					v.Enabled = false
				end
			end

			local SimulateZone = Val.Parent:FindFirstChild("SimulateZone")

			if SimulateZone then
				local SimulateParts = SimulateZone:GetChildren()

				if #SimulateParts > 0 then
					EntryDetector = PointHitbox.New()
					EntryDetector.ApplySize = false
					local CharHandle = BaseInteractive.GetCharacterHandle()

					if CharHandle then
						local BindedPart = CharHandle.Parts.RootPart

						for i, v in pairs(SimulateParts) do
							if v:IsA("BasePart") then
								table.insert(EntryDetector.ScannedParts, v)
							end
						end

						EntryDetector.EntryChanged.Connect(CheckSimulationZone)

						if BindedPart then
							EntryDetector.BindedPart = BindedPart
							CheckSimulationZone(EntryDetector.Scan())
						end

						CharHandle.LoadedEvent.Connect(OnRespawn)
						EntryDetector.Start()
					else
						warn("Character handle not found")
					end
				end
			end

			-- Add the group to the workspace
			PartsFolderClone.Parent = PartsFolderParent
		end
	end
	
	function Interact.OnShutdown()
		local CharHandle = BaseInteractive.GetCharacterHandle()
		if CharHandle then
			CharHandle.LoadedEvent.Disconnect(OnRespawn)
		end

		if EntryDetector then
			EntryDetector.Dispose()
			EntryDetector = nil
		end

		ClearAnchorLocks()
		DescendantParts = {}
		OptimizedVisuals = {}

		-- Get rid of the clone, now that it's no longer needed
		if PartsFolderClone then
			PartsFolderClone:Destroy()
			PartsFolderClone = nil
		end
	end
	
	function Interact.OnDispose()
		Interact.OnShutdown()
		
		if PartsFolder then
			PartsFolder.Parent = PartsFolderParent
			PartsFolder, PartsFolderParent = nil
		end
	end

	--Interact.OnInitialize.Connect(function()
		
	--end)

	--Interact.OnStart.Connect(function()
		
	--end)

	--Interact.OnShutdown.Connect(function()
		
	--end)

	--Interact.AddDisposalListener(function()
		
	--end)

	return Interact
end

return PhysicsGroup