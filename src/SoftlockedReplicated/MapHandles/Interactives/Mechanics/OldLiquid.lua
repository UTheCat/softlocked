-- This module provides an object that turns a BasePart
-- into a liquid body.
-- For best results, this should be on the client.

-- By udev2192

local RunService = game:GetService("RunService")
local Collections = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RepModules = ReplicatedStorage:WaitForChild("SoftlockedReplicated")
local UtilRepModules = RepModules:WaitForChild("Utils")

local Object = require(UtilRepModules:WaitForChild("Object"))
local Util = require(UtilRepModules:WaitForChild("Utility"))

local LiquidAdapter = {}
local AwaitingDisposal = {} -- LiquidAdapters that get disposed when Parent = nil.

local DestroyListener = nil
local WSCache = nil -- Workspace cache folder for this module.

LiquidAdapter.CollectionId = "LiquidAdapterParts"
LiquidAdapter.WorkspaceCacheName = "LiquidWSCache"

-- The default liquid state.
LiquidAdapter.DefaultLiquidState = "water"

LiquidAdapter.DisplayYSize = 0.01
LiquidAdapter.DisplayTransparency = 0.5
LiquidAdapter.DisplayPartName = "LiquidDisplay"

local function IsTableBlank(Table)
	for i, v in pairs(Table) do
		-- Return true since if this runs once, it's not blank.
		return false
	end
	
	-- Otherwise, return true
	return true
end

-- Toggles Adapter disposal on part removal.
local function ToggleRemovalWait(Adapter, IsWaiting)
	local Part = Adapter.GetBodyPart()

	if IsWaiting == true then
		AwaitingDisposal[Part] = Adapter
	else
		AwaitingDisposal[Part] = nil
	end
end

-- Toggles the CollectionService listener for Instance removal.
local function ToggleRemoveListener(IsActivated)
	if IsActivated == true then
		-- Disconnect the previous destroy listener, just in case.
		ToggleRemoveListener(false)

		-- Connect.
		DestroyListener = Collections:GetInstanceRemovedSignal(LiquidAdapter.CollectionId):Connect(function(inst)
			local Adapter = AwaitingDisposal[inst]

			-- Dispose on removal.
			if Adapter ~= nil then
				Adapter.Dispose()
			end

			Adapter = nil
		end)
	else
		if DestroyListener ~= nil then
			DestroyListener:Disconnect()
		end

		DestroyListener = nil
	end
end

local function ToggleWorkspaceCache(Enabled)
	if Enabled == true then
		WSCache = Util.CreateInstance("Folder", {
			Name = LiquidAdapter.WorkspaceCacheName,
			Parent = workspace
		})
	else
		if Util.IsInstance(WSCache) then
			WSCache:Destroy()
			WSCache = nil
		end
	end
end

ToggleRemoveListener(true)
ToggleWorkspaceCache(true)

function LiquidAdapter.New(Part)
	assert(Util.IsBasePart(Part), "Argument 1 must be a BasePart.")

	local Obj = Object.New("LiquidAdapter")
	local Interacting = {}
	local DisplayRunner = nil
	local DisplayPart = nil

	-- So EntryStatusChanged only fires on change
	-- for each specific part.
	local RecordedIsInside = {}
	
	Obj.StateChangeEvent = nil
	Obj.FrameEvent = nil
	Obj.StateId = "State"
	Obj.StateInstance = Part:FindFirstChild(Obj.StateId)
	
	-- Current water state
	Obj.State = LiquidAdapter.DefaultLiquidState

	-- Toggles the RunService.Heartbeat listener.
	local function ToggleRunEvent(Enabled)
		if Enabled == true then
			Obj.FrameEvent = RunService.Heartbeat:Connect(function()
				-- Do "is inside" checks for each part.
				for i, v in pairs(Interacting) do
					local IsInside = Util.IsInBasePart(v, Part)
					
					if RecordedIsInside[v] ~= IsInside then
						RecordedIsInside[v] = IsInside

						-- Fire the callback.
						Object.FireCallback(Obj.EntryStatusChanged, v, IsInside)
					end
				end
			end)
		else
			-- Disconnect the event.
			local FrameEvent = Obj.FrameEvent
			if FrameEvent ~= nil then
				FrameEvent:Disconnect()
			end

			Obj.FrameEvent = nil
			FrameEvent = nil
		end
	end

	-- Sets if the specified part's entry is listened to.
	local function SetIsInsideEvent(InteractingPart, Enabled)
		if Enabled == true then
			Interacting[InteractingPart] = InteractingPart
		else
			Interacting[InteractingPart] = nil
		end
		
		-- Connect when there's an interacting part,
		-- and disconnect when there are none.
		if IsTableBlank(Interacting) == true then
			ToggleRunEvent(false)
		else
			ToggleRunEvent(true)
		end
	end
	
	local function AdaptStateChanged(StringVal, Enabled)
		if StringVal ~= nil and Enabled == true then
			-- Do disconection, just in case.
			AdaptStateChanged(nil, false)
			
			-- Reconnect.
			Obj.State = StringVal.Value
			Obj.StateChangedEvent = StringVal.Changed:Connect(function(val)
				Obj.State = val
			end)
		else
			local ChangeEvent = Obj.StateChangedEvent
			if ChangeEvent ~= nil then
				ChangeEvent:Disconnect()
			end
			
			Obj.StateChangedEvent = nil
			ChangeEvent = nil
		end
	end
	
	local function HandleStateVal(inst, Enabled)
		if Util.IsInstance(inst) and inst:IsA("StringValue") then
			if inst.Name == Obj.StateId and Enabled == true then
				if Enabled == true then
					Obj.StateInstance = inst
					AdaptStateChanged(inst, true)
				else
					AdaptStateChanged(inst, false)
					Obj.StateInstance = nil
				end
			end
		end
	end
	
	-- Refreshes the display part.
	local function UpdateDisplay()
		local DisplayPartRef = DisplayPart
		if DisplayPartRef ~= nil then
			local PartSize = Part.Size
			
			DisplayPart.CFrame = Part.CFrame + (Part.Size / 2)
			DisplayPart.Size = Vector3.new(PartSize.X, LiquidAdapter.DisplayYSize, PartSize.Z)
			DisplayPartRef.Color = Part.Color
			DisplayPartRef.Material = Part.Material
			
			PartSize = nil
		end
		
		DisplayPartRef = nil
	end

	-- Sets the part that can interact with the liquid body.
	function Obj.SetInteractingPart(Other, Enabled)
		assert(Util.IsInstance(Other) and (Util.IsBasePart(Other) or Other:IsA("Camera")), "Argument 1 must be a BasePart or a Camera")

		SetIsInsideEvent(Other, Enabled)
	end
	
	-- Sets if the water body's dimensions are displayed via an overlay at the top.
	function Obj.SetTopDisplay(Enabled)
		if Enabled == true then
			-- Disconnect previous connections
			Obj.SetTopDisplay(false)
			
			-- Create the display part
			DisplayPart = Instance.new("Part")
			DisplayPart.Anchored = true
			DisplayPart.CanCollide = false
			DisplayPart.Transparency = LiquidAdapter.DisplayTransparency
			DisplayPart.Name = LiquidAdapter.DisplayPartName
			DisplayPart.Parent = WSCache
			
			-- Reconnect the top display
			DisplayRunner = RunService.Heartbeat:Connect(UpdateDisplay)
		else
			if DisplayRunner ~= nil then
				DisplayRunner:Disconnect()
				DisplayRunner = nil
			end
			
			if DisplayPart ~= nil then
				DisplayPart:Destroy()
				DisplayPart = nil
			end
		end
	end

	-- Returns the part associated with the adapter.
	function Obj.GetBodyPart()
		return Part
	end

	-- Sets if the object disposes itself once the water body is
	-- removed from the DataModel, which is when Parent = nil.
	Obj.SetProperty("DisposeOnDestroy", true, function(val)
		ToggleRemovalWait(Obj, val)
	end)

	-- Callback that fires when the interacting part
	-- enters or exits the liquid body.
	-- Paramters:
	-- Part - The instance that had its entry status changed.
	-- IsInside - If the interacting part is now inside the body.
	Obj.EntryStatusChanged = nil
	
	Obj.OnDisposal = function()
		-- Disconnect all interacting parts
		for i, v in pairs(Interacting) do
			Obj.SetInteractingPart(v, false)
		end
		
		Obj.SetTopDisplay(false)
	end
	
	HandleStateVal(Obj.StateInstance, true)
	
	-- Connect to state instance add/remove
	Obj.StateAdded = Part.ChildAdded:Connect(function(c)
		HandleStateVal(c, true)
	end)
	Obj.StateRemove = Part.ChildRemoved:Connect(function(c)
		HandleStateVal(c, false)
	end)

	return Obj
end

return LiquidAdapter