-- This class carves holes from the PartCuts that are binded to it.
-- This is what makes the moveable GBJs.
-- Thanks to this devforum post for help with the cutting logic:
-- https://devforum.roblox.com/t/consume-everything-how-greedy-meshing-works/452717

-- Essentially, this is greedy meshing that uses raycasts

-- By udev2192

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RepModules = ReplicatedStorage:WaitForChild("SoftlockedReplicated")
local UtilRepModules = RepModules:WaitForChild("Utils")

local Object = require(UtilRepModules:WaitForChild("Object"))

local PartCutter = {}

-- Minimum part size in all dimensions
local MINIMUM_SIZE = 0.05

local function IsVector3(Obj)
	return typeof(Obj) == "Vector3"
end

local function IsPart(Part)
	return typeof(Part) == "Instance" and Part:IsA("BasePart")
end

-- Determines if the position is within the bounds of the box
local function IsInBox(Position, Box)
	return math.abs(Position.X) < Box.Size.X/2 and math.abs(Position.Y) < Box.Size.Y/2 and math.abs(Position.Z) < Box.Size.Z/2
end

function PartCutter.New(Part)
	assert(IsPart(Part), "Argument 1 must be a BasePart.")
	
	local Obj = Object.New("PartCutter")
	local CutRunner = nil
	
	-- The table of part cuts.
	local PartCuts = {}
	
	-- Part filling folder instance.
	local FillFolder = Instance.new("Folder")
	FillFolder.Name = "PartFills"
	FillFolder.Parent = Part
	
	-- The x and z size of each slice/voxel of the parts.
	-- Higher number = better performance
	-- Applied on next refresh.
	Obj.VoxelSize = 1
	
	-- Checks if the position is cut by the PartCuts stored.
	local function IsCut(Position)
		for i, v in pairs(PartCuts) do
			if IsInBox(Position, v) then
				return true
			end
		end
		
		return false
	end
	
	
	-- Cuts the part into pieces so that
	-- the cuts can be made.
	--local function SlicePart(Part)
	--	assert(IsPart(Part), "Argument 1 must be a BasePart.")
		
	--	-- Slice the part.
	--	local VoxelSize = Obj.VoxelSize or 1
	--	local PartSize = Part.Size
	--	local XSize = PartSize.X
	--	local SizeIndex = 0
		
	--	-- Store occupied dimensions (these are voxels
	--	-- that will have geometry/be filled).
	--	local Occupied = {}
		
	--	-- Generate the heightmap from the PartCuts
	--	for i, v in pairs(PartCuts) do
			
	--	end
		
		
	--	for i = 0, XSize, VoxelSize do
	--		-- Break if the remainder has been reached.
	--		if XSize - i < VoxelSize then
	--			break
	--		end
	--	end
	--end
	
	-- Gets the map of the PartCuts. If the entry
	-- of the table returns true, the voxel will
	-- be filled, otherwise it won't.
	function Obj.GetMap()
		assert(IsPart(Part), "No part has been binded, therefore the map couldn't be generated.")
		
		local VoxelSize = Obj.VoxelSize or 1
		assert(VoxelSize >= MINIMUM_SIZE, "VoxelSize must be at least " .. MINIMUM_SIZE .. " studs.")
		
		-- Occupied voxels
		local Occupied = {}

		-- Get the part's corners
		local PartSize = Part.Size
		local PartPos = Part.Position
		local PartPosDiff = PartSize / 2
		local PartBegin = PartPos - PartPosDiff
		local PartEnd = PartPos + PartPosDiff
		
		-- Generate the map by iterating through the voxels by column
		local function GetColumnMap(XPos)
			-- Occupied column voxels
			local ColumnOccupied = {}

			for i = PartBegin.Z, PartEnd.Z, VoxelSize do
				-- Generate a Vector3 for position comparison
				local ComparedVector = Vector3.new(XPos, PartPos.Y, i)
				
				-- Determine if there's a collision for each cut.
				-- If there isn't one, mark it as occupied
				-- so it can be filled.
				local IsFilled = true
				for i, v in pairs(PartCuts) do
					-- Break on first cut "collision"
					if IsInBox(ComparedVector, v) == true then
						IsFilled = false
						break
					end
				end
				
				-- Register fill status.
				ColumnOccupied[i] = IsFilled
			end
		end
		
		for i = PartBegin.X, PartEnd.X, VoxelSize do
			local Remaining = PartEnd.X - i
			
			if Remaining >= VoxelSize then
				Occupied[i] = GetColumnMap(i)
			else
				-- Account for the remainder, then break
				local RemainderIndex = i + Remaining
				Occupied[RemainderIndex] = GetColumnMap(RemainderIndex)
				
				break
			end
		end 
		
		return Occupied, {
			Beginning = PartBegin,
			End = PartEnd
		}
	end
	
	-- Adds a part slice segment to the fill folder by
	-- properties table.
	local function AddSliceFill(SliceInfo)
		local PartClone = Part:Clone()

		for i, v in pairs(SliceInfo) do
			PartClone[i] = v
		end

		PartClone.Parent = FillFolder

		return PartClone
	end

	-- Removes all the slices from the fill folder.
	local function RemoveAllSlices()
		if FillFolder ~= nil then
			for i, v in pairs(FillFolder:GetChildren()) do
				v:Destroy()
			end
		end
	end
	
	-- Refreshes the generation of the sliced part.
	function Obj.Refresh()
		-- Generation height-map
		local Map, Corners = Obj.GetMap()
		
		-- Voxel size
		local VoxelSize = Obj.VoxelSize or 1
		
		-- Get the maximum-possible extent for the
		-- current segment from the algorithm for
		-- best performance.
		local XSize = 0
		local YSize = Part.Size.Y
		local ZSize = 0
		
		local XPos = 0
		local YPos = Part.Position.Y
		local ZPos = 0
		
		-- Greedy meshing dimensions (these will be the fill segment properties)
		local Dimensions = {}
		
		-- Function for adding (checks that the size is valid before doing so)
		local function Add(FillSize, FillPos)
			if FillSize.X >= MINIMUM_SIZE and FillSize.Y >= MINIMUM_SIZE and FillSize.Z >= MINIMUM_SIZE then
				table.insert(Dimensions, {
					Size = FillSize,
					Position = FillPos
				})
			end
		end
		
		local function AddIndex()
			Add(Vector3.new(XSize, YSize, ZSize), Vector3.new(XPos, YPos, ZPos))
		end
		
		-- Toggles position shift to account for size
		local function TogglePosChange(IsChanged)
			local Multiplier = 1
			
			if IsChanged == true then
				Multiplier = 1
			else
				Multiplier = -1
			end
			
			XPos += (XSize / 2) * Multiplier
			ZPos += (ZSize / 2) * Multiplier
		end
		
		-- If the entire column could be completed without
		-- colliding, add the full z-size.
		for i, v in pairs(Map) do
			local HasCollided = false
			
			-- To strech the XSize as much as possible
			XSize += 1
			XPos = Corners.Beginning.X + (i - 1)
			
			for i2, v2 in pairs(v) do
				ZPos = Corners.Beginning.Z + (i - 1)
				
				if v2 == true then
					-- Voxel is occupied, move on
					ZSize += VoxelSize
				else
					-- Add the slice now that a cut collision
					-- has been reached
					HasCollided = true
					
					TogglePosChange(true)
					AddIndex()
					TogglePosChange(false)
				end
			end
			
			-- Add the remaining slice fill and reset the sizing
			-- before moving onto the next column
			-- (if a collision was reached for this column)
			if HasCollided == false then
				TogglePosChange(true)
				AddIndex()
				TogglePosChange(false)
				
				-- Reset x-size for new column
				XSize = 0
			end
			
			ZSize = 0
		end
		
		-- Fill slices after dimensions have been found for stability
		local AddedSlices = {}
		for i, v in pairs(Dimensions) do
			table.insert(AddedSlices, AddSliceFill(v))
		end
		
		-- Remove the old slices
		for i, v in pairs(FillFolder:GetChildren()) do
			if table.find(AddedSlices, v) == nil then
				v:Destroy()
			end
		end
	end
	
	-- Toggles the per-frame updater for the part cutter.
	function Obj.ToggleUpdater(IsRunning)
		if IsRunning == true then
			-- Disconnect previous runner.
			Obj.ToggleUpdater(false)
			
			-- Reconnect.
			CutRunner = RunService.Heartbeat:Connect(Obj.Refresh)
		else
			if CutRunner ~= nil then
				CutRunner:Disconnect()
				CutRunner = nil
			end
		end
	end
	
	-- Adds a PartCut to be accounted by the slicing algorithm.
	function Obj.AddCut(Cut)
		assert(IsVector3(Cut.Size) and IsVector3(Cut.Position), "Argument 1 object must have both Size and Position properties.")
		
		table.insert(PartCuts, Cut)
	end
	
	-- Removes a PartCut from being accounted by the slicing algorithm.
	function Obj.RemoveCut(Cut)
		local Index = table.find(PartCuts, Cut)
		
		if Index ~= nil then
			table.remove(PartCuts, Index)
		end
		
		Index = nil
	end
	
	Obj.OnDisposal = function()
		Obj.ToggleUpdater(false)
		
		for i, v in pairs(PartCuts) do
			Obj.RemoveCut(v)
		end
		
		PartCuts = nil
		
		FillFolder:Destroy()
		FillFolder = nil
	end
	
	return Obj
end

return PartCutter