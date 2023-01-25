--[[
A simplified version of the Hitbox class that only handles logic that involves
whether or not a point is inside certain parts

Using this over the Hitbox class saves on memory usage although if you need to
account for a part's size, the Hitbox class should be used instead

This is a test of the engine-supplied OverlapParams

By udev2192
]]--

local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local BaseInteractive = require(script.Parent.Parent
	:WaitForChild("Interactives")
	:WaitForChild("BaseInteractive")
)
local Object = BaseInteractive.GetObjectClass()
local Signal = BaseInteractive.GetSignalClass()

local abs = math.abs
local PartTypes = Enum.PartType

local PointHitbox = {}
PointHitbox.__index = PointHitbox
PointHitbox.ClassName = script.Name

export type Object3d = {
	CFrame: CFrame,
	Size: Vector3,
	Shape: Enum.PartType?
}

--[[
Returns the hypotenuse of two lengths

Params:
a <number> - The first length (usually the base of a triangle)
b <number> - The second length (usually the height of a triangle)

Returns:
<number> - The hypotenuse
]]--
function PointHitbox.Hypotenuse(a: number, b: number) : number
	return math.sqrt(a^2 + b^2)
end

--[[
Creates an Object3d for use by the functions provided here

Params:
CFrame <CFrame> - The CFrame of the object
Size <Vector3> - The size of the object
Shape <Enum.PartType?> - The object's part type, or nil if not applicable

Returns:
<Object3d> - The Object3d created.
]]--
function PointHitbox.NewObject3d(CFrame: CFrame, Size: Vector3, Shape: Enum.PartType?) : Object3d
	return {
		CFrame = CFrame,
		Size = Size,
		Shape = Shape
	}
end

--[[
Returns the distance of two vectors

Params:
Vect1 <Vector3> - The first vector
Vect2 <Vector3> - The second vector

Returns:
<number> - The distance
]]--
function PointHitbox.GetDistance(Vect1: Vector3, Vect2: Vector3) : number
	return (Vect2 - Vect1).Magnitude
end

--[[
Returns if a point in world space is inside a box

Params:
Point <Vector3> - The position of the point in world space
Box <Object3d> - The box to determine if the point is in

Returns:
<boolean> - If the point is in the box
]]--
function PointHitbox.IsPointInBox(Point: Vector3, Box: Object3d) : boolean
	local BoxSize = Box.Size
	local LocalPos = Box.CFrame:PointToObjectSpace(Point)

	return abs(LocalPos.X) <= BoxSize.X / 2 and abs(LocalPos.Y) <= BoxSize.Y / 2 and abs(LocalPos.Z) <= BoxSize.Z / 2
end

--[[
Returns whether or not a point is in a part of some sort

Params:
Point <Vector3> - The position of the point in world space
Part <Object3d> - The part to determine if the point is in

Returns:
<boolean> - If the point is in the part
]]--
function PointHitbox.IsPointInPart(Point: Vector3, Part: Object3d) : boolean
	if Part.Shape == PartTypes.Block then
		return PointHitbox.IsPointInBox(Point, Part)
	else
		return BaseInteractive.IsPointInside(Point, Part, Vector3.zero)
	end
end

function PointHitbox.IsHitboxInside(Hitbox: Object3d, PartToDetect: BasePart)
	local PartShape = PartToDetect.Shape
	local PartTypes = Enum.PartType

	local Params = OverlapParams.new()
	Params.FilterType = Enum.RaycastFilterType.Whitelist
	Params.FilterDescendantsInstances = {PartToDetect}
	Params.MaxParts = 1
	Params.CollisionGroup = PhysicsService:GetCollisionGroupName(PartToDetect.CollisionGroupId)

	local OverlapTable

	if PartShape == PartTypes.Block then
		OverlapTable = workspace:GetPartBoundsInBox(Hitbox.CFrame, Hitbox.Size, Params)
	elseif PartShape == PartTypes.Sphere then
		OverlapTable = workspace:GetPartBoundsInRadius(PartToDetect.CFrame.Position)
	else
		return BaseInteractive.IsPointInside(Hitbox.CFrame.Position, PartToDetect, Hitbox.Size)
	end

	if OverlapTable then
		return table.find(OverlapTable, PartToDetect) ~= nil
	else
		return false
	end
end

--[[
Attempts to accurately detect whether or not Part 1 is overlapping Part 2.

Params:
Part1 <table> - Any 3d object with CFrame, Size, and Shape properties
Part2 <table> - Any 3d object with CFrame, Size, and Shape properties

Returns:
<boolean> - If they overlap
]]--
function PointHitbox.DoPartsOverlap(Part1: Object3d, Part2: Object3d) : boolean	
	--if Part1.Shape == PartTypes.Block then
	local Part1Size = Part1.Size

	if Part1Size == Vector3.zero then
		--return PointHitbox.IsPointInPart(Part1.CFrame.Position, Part2)
		return BaseInteractive.IsPointInside(Part1.CFrame.Position, Part2, Vector3.zero)
	else
		--local Pos = Part1.CFrame.Position
		--local PosX = Pos.X
		--local PosY = Pos.Y
		--local PosZ = Pos.Z
		--local PartCFrame = Part1.CFrame
		--local HalfSizeX = Part1Size.X / 2
		--local HalfSizeY = Part1Size.Y / 2
		--local HalfSizeZ = Part1Size.Z / 2

		return PointHitbox.IsHitboxInside(Part1, Part2)
		-- Find a more accurate way to do this because if the side points fall out,
		-- then even if the center of the hitbox is touching, it will still think it's not
		-- Also try not to use OverlapParams later on
		--local Max

		-- minecraft
		--PointHitbox.IsPointInPart(PartCFrame:PointToWorldSpace(Vector3.new(-HalfSizeX, -HalfSizeY, -HalfSizeZ)), Part2)
		--or PointHitbox.IsPointInPart(PartCFrame:PointToWorldSpace(Vector3.new(HalfSizeX, -HalfSizeY, -HalfSizeZ)), Part2)
		--or PointHitbox.IsPointInPart(PartCFrame:PointToWorldSpace(Vector3.new(-HalfSizeX, HalfSizeY, -HalfSizeZ)), Part2)
		--or PointHitbox.IsPointInPart(PartCFrame:PointToWorldSpace(Vector3.new(-HalfSizeX, -HalfSizeY, HalfSizeZ)), Part2)
		--or PointHitbox.IsPointInPart(PartCFrame:PointToWorldSpace(Vector3.new(HalfSizeX, -HalfSizeY, HalfSizeZ)), Part2)
		--or PointHitbox.IsPointInPart(PartCFrame:PointToWorldSpace(Vector3.new(HalfSizeX, HalfSizeY, -HalfSizeZ)), Part2)
		--or PointHitbox.IsPointInPart(PartCFrame:PointToWorldSpace(Vector3.new(-HalfSizeX, HalfSizeY, HalfSizeZ)), Part2)
		--or PointHitbox.IsPointInPart(PartCFrame:PointToWorldSpace(Vector3.new(HalfSizeX, HalfSizeY, HalfSizeZ)), Part2)

		--PointHitbox.IsPointInPart(Vector3.new(PosX - HalfSizeX, PosY, PosY - HalfSizeY, PosZ - HalfSizeZ), Part2)
		--or PointHitbox.IsPointInPart(Vector3.new(PosX + HalfSizeX, PosY, PosY - HalfSizeY, PosZ - HalfSizeZ), Part2)
		--or PointHitbox.IsPointInPart(Vector3.new(PosX - HalfSizeX, PosY, PosY + HalfSizeY, PosZ - HalfSizeZ), Part2)
		--or PointHitbox.IsPointInPart(Vector3.new(PosX - HalfSizeX, PosY, PosY - HalfSizeY, PosZ + HalfSizeZ), Part2)
		--or PointHitbox.IsPointInPart(Vector3.new(PosX + HalfSizeX, PosY, PosY + HalfSizeY, PosZ - HalfSizeZ), Part2)
		--or PointHitbox.IsPointInPart(Vector3.new(PosX + HalfSizeX, PosY, PosY - HalfSizeY, PosZ + HalfSizeZ), Part2)
		--or PointHitbox.IsPointInPart(Vector3.new(PosY + HalfSizeY, PosY, PosY + HalfSizeY, PosZ - HalfSizeZ), Part2)
		--or PointHitbox.IsPointInPart(Vector3.new(PosY + HalfSizeY, PosY, PosY + HalfSizeY, PosZ + HalfSizeZ), Part2)
	end
	--end
end

function PointHitbox.New()
	local Hit = Object.New(PointHitbox.ClassName)

	local Runner: RBXScriptConnection

	--[[
	<boolean> - Whether or not the point is inside the hit region
	]]--
	Hit.IsEntered = false

	--[[
	<array> - The list of parts that the point/hitbox is touching
	]]--
	Hit.EnteredParts = {}

	--[[
	<array> - The list of parts to determine if the point/hitbox is touching them
	]]--
	Hit.ScannedParts = {}

	--[[
	<CFrame> - The CFrame of the hitbox
	]]--
	Hit.CFrame = CFrame.identity

	--[[
	<Vector3> - The size of the hitbox
	]]--
	Hit.Size = Vector3.zero

	--[[
	<Enum.PartType> - The part/shape type of the hitbox
	]]--
	Hit.Shape = PartTypes.Block

	--[[
	<boolean> - Whether or not to account for the hitbox's size
	]]--
	Hit.ApplySize = true

	--[[
	<boolean> - Whether or not to apply the size negated.
				This is useful for determining if the hitbox
				is completely inside a part.
	]]--
	--Hit.NegateSize = false

	--[[
	<BasePart> - If specified, this part's position (and size if wanted) will be
				 used
	]]--
	Hit.BindedPart = nil

	--[[
	<table> - Any 3d object with a Position property that's used as a "detection center"
	]]--
	Hit.DetectionPart = nil

	--[[
	<number> - The maximum distance that the hitbox center can be from the detection part's
			   center in order to calculate hit status. If this distance is greater, then
			   the hitbox is assumed to be no longer hitting the part.
	]]--
	Hit.DetectionRadius = 0

	--[[
	Performs an entry scan to determine if the point is inside
	This will also fire the EntryChanged event, in case the entry
	status has changed during the operation
	
	Returns:
	<boolean> - Whether or not the point is within the hit region
	]]--
	function Hit.Scan()
		local BindedPart: BasePart = Hit.BindedPart
		local CFrame: CFrame
		local Size: Vector3
		local Shape: Enum.PartType

		if BindedPart then
			local PartCFrame = BindedPart.CFrame
			if PartCFrame then
				CFrame = PartCFrame
			end

			if Hit.ApplySize == true then
				local PartSize = BindedPart.Size

				if PartSize then
					Size = PartSize
				else
					Size = Vector3.zero
				end

				if BindedPart:IsA("Part") then
					local PartShape = BindedPart.Shape

					if PartShape then
						Shape = PartShape
					end
				else
					Shape = PartTypes.Block
				end
			else
				Size = Vector3.zero
				Shape = PartTypes.Block
			end
		else
			CFrame = Hit.CFrame
			Shape = PartTypes.Block

			if Hit.ApplySize == true then
				Size = Hit.Size
			else
				Size = Vector3.zero
			end
		end

		if Hit.ApplySize == true then
			if BindedPart then
				local PartSize = BindedPart.Size

				if PartSize then
					Size = PartSize
				else
					Size = Vector3.zero
				end
			else
				Size = Hit.Size
			end
		else
			Size = Vector3.zero
		end

		--if Hit.NegateSize == true then
		--	Size *= -1
		--end

		-- Determine whether or not the positions are close enough
		-- to move onto accurate hit detection
		-- If not, assume that the hitbox is outside the hit region
		local DetectionPart = Hit.DetectionPart

		if DetectionPart then
			local Radius = Hit.DetectionRadius
			if Radius <= 0 or PointHitbox.GetDistance(CFrame.Position, DetectionPart.Position) > Radius then
				if Hit.IsEntered == true and #Hit.EnteredParts > 0 then
					Hit.EnteredParts = {}
					Hit.IsEntered = false
					Hit.EntryChanged.Fire(false)
				end

				return false
			end
		end

		local Entered = {}
		local HitboxToUse = PointHitbox.NewObject3d(CFrame, Size, Shape)

		for i, v in pairs(Hit.ScannedParts) do
			if PointHitbox.DoPartsOverlap(HitboxToUse, v) then
				table.insert(Entered, v)
			end
		end

		-- Detect whether or not entry status has changed
		local IsEntered = Hit.IsEntered
		local Changed
		if IsEntered == true and #Entered <= 0 then
			Hit.IsEntered = false
			IsEntered = false

			Changed = true
		elseif IsEntered == false and #Entered > 0 then
			Hit.IsEntered = true
			IsEntered = true

			Changed = true
		else
			Changed = false
		end

		-- This comes first for thread safety
		Hit.EnteredParts = Entered

		if Changed then
			Hit.EntryChanged.Fire(IsEntered)
		end

		return IsEntered
	end

	--[[
	Stops entry detection
	]]--
	function Hit.Stop()
		if Runner then
			Runner:Disconnect()
			Runner = nil
		end
	end

	--[[
	Starts entry detection
	]]--
	function Hit.Start()
		if Runner == nil then
			Runner = RunService.Heartbeat:Connect(Hit.Scan)
		end
	end

	--[[
	Fired when the point entry status changes
	
	Params:
	IsEntered <boolean> - Whether or not the point is inside the hit region
	]]--
	Hit.EntryChanged = Signal.New()

	Hit.OnDisposal = function()
		Hit.Stop()
		Hit.EntryChanged.DisconnectAll()
	end

	return Hit
end

return PointHitbox