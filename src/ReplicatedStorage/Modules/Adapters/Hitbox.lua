-- Provides a way of accurately getting events where
-- two parts collide with each other.
-- In other terms, this provides an accurate hitbox while
-- being somewhat laggy.

-- Thanks to Jukereise for figuring out hitbox logic for shapes other than a
-- box (which is used by the JToH music zone system they created).

-- By udev2192

local RunService = game:GetService("RunService")

local ModulePack = script.Parent.Parent

local Utils = ModulePack:WaitForChild("Utils")

local Object = require(Utils:WaitForChild("Object"))
local Signal = require(Utils:WaitForChild("Signal"))

local Hitbox = {}

local ZERO_VECTOR3 = Vector3.new(0, 0, 0)
local ZERO_CFRAME = CFrame.new(0, 0, 0)

local abs = math.abs -- To reduce the amount of indexing

-- Hitbox status of entry.
-- Status values go from least inside (smallest number)
-- to most inside (biggest number)
Hitbox.HitStatus = {
	NotTouching = 0,
	Touching = 1,
	CenterInside = 2,
	CompletelyInside = 3
}

local PartTypes = Enum.PartType

-- A part/hitbox's shape type. Some values are pulled from the Roblox supplied
-- Enumerator named "PartType" for convienence.
Hitbox.ShapeType = {
	Block = PartTypes.Block,
	Ball = PartTypes.Ball,
	Cylinder = PartTypes.Cylinder
}

PartTypes = nil

local function IsPart(Part)
	return typeof(Part) == "Instance" and Part:IsA("Part")
end

-- Returns the hypotenuse of a and b.
local function Hypotenuse(a, b)
	return (a^2 + b^2) ^ 0.5
end

-- Utility function that determines if a point is in bounds
-- with a hitbox.
-- Used by GetHitRegion()
local function IsInBounds(LocalPoint, ObjectSize, Offset, ShapeType)
	-- Offset compared size, smaller means more constrained
	ObjectSize = (ObjectSize + Offset) * 0.5
	
	-- Get local point and object size components
	-- Use absolute value for the LocalPoint so that
	-- negative numbers won't affect the bound results.
	local LocalX = abs(LocalPoint.X)
	local LocalY = abs(LocalPoint.Y)
	local LocalZ = abs(LocalPoint.Z)
	
	local SizeX = ObjectSize.X
	local SizeY = ObjectSize.Y
	local SizeZ = ObjectSize.Z
	
	local ValidTypes = Hitbox.ShapeType
	
	-- Use the corresponding formula to determine in-bounds status
	-- (Use less than or equal to for comparision accuracy)
	if ShapeType == ValidTypes.Block then
		-- Return the bounding status of the "box-shaped" 3d objects
		return LocalX <= SizeX and LocalY <= SizeY and LocalZ <= SizeZ
	elseif ShapeType == ValidTypes.Cylinder then
		-- In a Roblox cylinder, the non-circular coordinate is the X
		-- coordinate. Take that into account when finding the hypotenuse
		-- Use the object space Y-position to compare hypotenuse bounding status
		return LocalX <= SizeX and Hypotenuse(LocalY, LocalZ) <= SizeZ + (Offset.Z)
	elseif ShapeType == ValidTypes.Ball then
		-- Use the hypotenuse function for faster performance
		-- (Use x and z coordinates for that)
		-- If the hypotenuse is less than or equal to the Y size,
		-- mark it as "in bounds" and return true
		-- If that passes, then do the same, but this time, 
		-- compare the hypotenuse of y and z to x,
		-- then the hypotenuse of x and y to z
		
		--local XDist = abs(SizeY - LocalY)
		--local YDist = abs(SizeY - LocalY)
		--local ZDist = abs(SizeZ - LocalZ)
		
		-- The Y coordinate of ObjectSize / 2 will indicate radius
		--local Hypo = Hypotenuse(XDist, ZDist)
		-- Use local point coordinates, since that will determine offset
		-- from the center due to it being object space
		return Hypotenuse(LocalX, LocalZ) <= SizeY
			--and Hypotenuse(YDist, ZDist) <= SizeX
			--and Hypotenuse(XDist, YDist) <= SizeZ
	end
end

--local function IsInBounds(LocalPoint, HitSize, Offset)
--	local OffsetPoint = LocalPoint + Offset

--	return HitSize.X > OffsetPoint.X and HitSize.Y > OffsetPoint.Y and HitSize.Z > OffsetPoint.Z
--end

-- Constructs a HitRegion.
function Hitbox.NewHitResult(HitSize, Position, Status)
	local HitStatus = Hitbox.HitStatus
	
	return {
		Size = HitSize, -- Size of the interfering region
		Center = Position, -- The center of the interference
		Status = Status, -- The inteference's hit status
		
		-- "Zone" in these explainations mean the box that the
		-- the Hitbox is trying to interfere with:
		
		-- If the hitbox isn't touching the zone at all
		NotTouching = Status == Hitbox.NotTouching,
		
		-- If the hitbox is touches the zone
		IsTouching = Status >= HitStatus.Touching,
		
		-- If the center of the hitbox is inside the zone
		CenterInside = Status >= HitStatus.CenterInside,
		
		-- If the hitbox is completely inside the zone
		CompletelyInside = Status >= HitStatus.CompletelyInside
	}
end

-- Determines if CFrame1 is inside Region 2.
-- Size2 and CFrame2 are components of Region 2.
-- Returns a HitRegion.
function Hitbox.GetHitRegion(Size1, CFrame1, Size2, CFrame2, ShapeType)
	-- So orientation is taken into account
	-- Size1 is added to account for the size of part1
	local LocalPoint = CFrame2:PointToObjectSpace(CFrame1.Position)
	
	-- Get hit region
	local HalvedSize2 = Size2 / 2
	local HitSizeX = HalvedSize2.X - math.abs(LocalPoint.X)
	local HitSizeY = HalvedSize2.Y - math.abs(LocalPoint.Y)
	local HitSizeZ = HalvedSize2.Z - math.abs(LocalPoint.Z)
	
	--local function IsInBounds(Diff)
	--	if typeof(Diff) ~= "Vector3" then
	--		Diff = Vector3.new(0,0,0)
	--	end

	--	local FuncPoint = LocalPoint + Diff -- For detection offsetting
	--	return math.abs(FuncPoint.X) < Size2.X/2 and math.abs(FuncPoint.Y) < Size2.Y/2 and math.abs(FuncPoint.Z) < Size2.Z/2
	--end
	
	--print(HitSizeX, HitSizeY, HitSizeZ)
	
	-- Convert the interfering size to a Vector3.
	local HitSizeVector = Vector3.new(math.min(HitSizeX, Size1.X), math.min(HitSizeY, Size1.Y), math.min(HitSizeZ, Size1.Z))

	-- Get interference center.
	local HitCFrame = (CFrame1.Position + CFrame2.Position) / 2
	
	-- Get hit status by offsetting the compared Vector3 components.
	local HalvedSize1 = Size1 / 2
	local HitStatus = Hitbox.HitStatus
	if IsInBounds(LocalPoint, Size2, -HalvedSize1, ShapeType) then
		HitStatus = HitStatus.CompletelyInside
	elseif IsInBounds(LocalPoint, Size2, ZERO_VECTOR3, ShapeType) then
		HitStatus = HitStatus.CenterInside
	elseif IsInBounds(LocalPoint, Size2, HalvedSize1, ShapeType) then
		HitStatus = HitStatus.Touching
	else
		HitStatus = HitStatus.NotTouching
		--print("not touching")
	end
	
	return Hitbox.NewHitResult(HitSizeVector, HitCFrame, HitStatus)
end

--function Hitbox.GetPartTouchStates(BasePart1, BasePart2)
--	if (Hitbox.IsBasePart(BasePart1) or typeof(BasePart1) == "Instance" and BasePart1:IsA("Camera"))and Hitbox.IsBasePart(BasePart2) then
--		local Point = BasePart2.CFrame:PointToObjectSpace(BasePart1.CFrame.Position)
--		local function IsInBounds(Diff)
--			if typeof(Diff) ~= "Vector3" then
--				Diff = Vector3.new(0,0,0)
--			end

--			local LocalPoint = Point + Diff -- For detection offsetting
--			return math.abs(LocalPoint.X) < BasePart2.Size.X/2 and math.abs(LocalPoint.Y) < BasePart2.Size.Y/2 and math.abs(LocalPoint.Z) < BasePart2.Size.Z/2
--		end

--		-- Construct the table of part interaction types
--		local Interactions = {
--			-- Adding the size of BasePart1 halved detects if it's completely inside
--			-- Same the other way around, subtracting it instead will see if it's at least touching it
--			IsInside = IsInBounds(BasePart1.Size/2),
--			IsPointInside = IsInBounds(),
--			IsTouching = IsInBounds(-(BasePart1.Size/2))
--		}

--		-- Garbage collect and return the interaction types
--		IsInBounds = nil
--		return Interactions
--	else
--		return nil
--	end
--end

-- Primary hitbox constructor.
function Hitbox.New(Size)
	local Box = Object.New("Hitbox")

	-- RunService.Heartbeat connections
	local HitRunners = {}
	local HitStatuses = {} -- Hit statuses for each connected box
	local TouchDebounces = {} -- For binded part .Touched
	local CurrentlyTouched = {} -- Stores length of touch (for .Touched)
	local TouchConnections = {} -- For connected parts that will use .Touched
	local DisconnectDebounce = {}
	local WeldRunner = nil
	local BindedPart = nil
	local BindedPartTouch = nil -- Binded part .Touched event

	Box.Size = Size or ZERO_VECTOR3
	Box.CFrame = ZERO_CFRAME
	
	-- The hitbox's last hit status.
	-- Indicated by Hitbox.HitStatus
	Box.HitStatus = Hitbox.HitStatus.NotTouching
	
	-- If the Box.OnHit signal will fire.
	-- Set to false to save on loop usage.
	Box.FireHitSignal = true
	
	-- How long to wait to disconnect a hit detection
	-- listener for parts connected via .Touched
	Box.TouchStopDelay = 0.5
	
	-- The hitbox's ShapeType.
	Box.Shape = Enum.PartType.Block

	-- Internal hitbox intercept connection.
	local function ToggleConnect(BoxToConnect, IsConnected)
		if IsConnected == true then
			assert(BoxToConnect.Size ~= nil and BoxToConnect.CFrame ~= nil, "Argument 1 must contain Size and CFrame properties.")
			
			-- Disconnect previous box connections.
			if HitRunners[BoxToConnect] ~= nil then
				ToggleConnect(BoxToConnect, false)
			end
			
			-- Connect.
			HitRunners[BoxToConnect] = RunService.Heartbeat:Connect(function(Delta)
				local ConnectedBoxSize = BoxToConnect.Size
				local HitResult = Hitbox.GetHitRegion(Box.Size, Box.CFrame, ConnectedBoxSize, BoxToConnect.CFrame, BoxToConnect.Shape)
				local HitStatus = HitResult.Status
				local NotTouching = Hitbox.HitStatus.NotTouching
				local OldHitStatus = HitStatuses[BoxToConnect]

				HitStatuses[BoxToConnect] = HitStatus

				-- Signal status change if it happened
				if OldHitStatus ~= HitStatus then
					Box.HitStatusChanged.Fire(BoxToConnect, HitResult)
				end

				-- Mark time increase for connected parts via .Touched
				local ConnectedToTouched = false
				if TouchConnections[BoxToConnect] == true and CurrentlyTouched ~= nil then
					ConnectedToTouched = true
					
					if CurrentlyTouched[BoxToConnect] == nil then
						CurrentlyTouched[BoxToConnect] = Delta
					else
						CurrentlyTouched[BoxToConnect] += Delta
					end
				end

				if HitResult ~= nil and HitResult.Status ~= NotTouching then
					-- If the box is connected via .Touched, reset the disconnection timer
					CurrentlyTouched[BoxToConnect] = 0
					
					-- A hit was detected for the frame, so fire
					Box.HitStatus = HitStatus

					if Box.FireHitSignal == true then
						local HitSignal = Box.OnHit
						if HitSignal ~= nil then
							Box.OnHit.Fire(BoxToConnect, HitResult)
						end
						HitSignal = nil
					end
				else
					DisconnectDebounce[BoxToConnect] = true

					Box.HitStatus = NotTouching

					-- Disconnect the corresponding RunService listener,
					-- if it's binded to .Touched
					local TouchStopDelay = Box.TouchStopDelay or 0
					if TouchConnections ~= nil and TouchConnections[BoxToConnect] == true then
						-- Check that the touch has stopped long enough before disconnecting
						local TouchDur = CurrentlyTouched[BoxToConnect]
						--print("Touch duration:", TouchDur)
						if TouchStopDelay <= 0 or (TouchDur ~= nil and TouchDur > TouchStopDelay) then
							ToggleConnect(BoxToConnect, false)
							CurrentlyTouched[BoxToConnect] = nil
							TouchDebounces[BoxToConnect] = nil
						end
					end

					-- Signal touch end, if not done already
					if OldHitStatus ~= NotTouching then
						Box.OnHitStop.Fire(BoxToConnect)
					end

					DisconnectDebounce[BoxToConnect] = nil
				end

				HitResult = nil
			end)
		else
			local Runner = HitRunners[BoxToConnect]
			if Runner ~= nil then
				Runner:Disconnect()
			end

			HitRunners[BoxToConnect] = nil
			Runner = nil
			
			CurrentlyTouched[BoxToConnect] = nil
			
			--print("disconnect")
		end
	end
	
	-- Returns a part's hit status to the hitbox,
	-- or nil if it isn't connected.
	-- Params:
	-- Part - The part or box to check the hit status of.
	function Box.GetHitStatus(Part)
		return HitStatuses ~= nil and HitStatuses[Part]
	end
	
	-- Checks if the hitbox is binded to a part.
	function Box.IsBindedToPart()
		return IsPart(BindedPart)
	end
	
	-- Disconnects a BasePart's interference.
	-- Params:
	-- Part - The part to disconnect.
	function Box.DisconnectPart(Part)
		if TouchConnections ~= nil then
			TouchConnections[Part] = nil
		end
		
		if HitStatuses ~= nil then
			HitStatuses[Part] = nil
		end
		
		ToggleConnect(Part, false)
	end
	
	-- Listens to a BasePart's interference.
	-- Params:
	-- Part - The part connected.
	-- IsConnecting - If it's listening to interference.
	-- UseTouchEvent - If the RunService hit detector for the part turns on
	-- 				   only when Part.Touched fires. This means once the
	--				   part stops touching, the hit detector will turn off
	-- 				   and only turn on if it's still connected and
	-- 				   .Tocuhed fires.
	function Box.ConnectPart(Part, UseTouchEvent)
		HitStatuses[Part] = Hitbox.HitStatus.NotTouching
		
		if UseTouchEvent == true then
			assert(IsPart(Part) == true, "Argument 1 must be a BasePart.")
			--assert(IsPart(BindedPart) == true, "No BasePart has been binded. Use BindToPart() to do so.")
			
			TouchConnections[Part] = true
		else
			ToggleConnect(Part, true)
		end
	end

	-- Binds this hitbox to a BasePart's position and size.
	-- Params:
	-- Part - The part to weld to (or nil to stop welding)
	function Box.BindToPart(Part)
		if IsPart(Part) == true then
			Box.BindToPart(nil)

			-- Reconnect
			WeldRunner = RunService.Heartbeat:Connect(function()
				Box.CFrame = Part.CFrame
				Box.Size = Part.Size
				Box.Shape = Part.Shape
			end)
			
			-- Do the .Touched connection for parts that
			-- turn on its interference listener with it
			BindedPartTouch = Part.Touched:Connect(function(OtherPart)
				if TouchDebounces[OtherPart] == nil and TouchConnections[OtherPart] == true and DisconnectDebounce[OtherPart] == nil then
					TouchDebounces[OtherPart] = true
					ToggleConnect(OtherPart, true)
				end
			end)
		else
			-- Disconnect
			if BindedPartTouch ~= nil then
				BindedPartTouch:Disconnect()
			end
			BindedPartTouch = nil
			
			if WeldRunner ~= nil then
				WeldRunner:Disconnect()
			end
			WeldRunner = nil
			
			BindedPart = nil
		end
	end
	
	-- Fires when the hit status of the hitbox changes
	-- for a particular connected part.
	-- Params:
	-- Index - The Hitbox or BasePart that had its hit status changed
	-- Result - The new hit result of the index (includes hit status)
	Box.HitStatusChanged = Signal.New()

	-- Fires every frame that there is an interfering region
	-- (and if this signal is enabled).
	-- Params:
	-- Index - The Hitbox or BasePart that interfered.
	-- HitResult - The hit results of the hit (see NewHitResults() for details).
	Box.OnHit = Signal.New()
	
	-- Fires when the hitbox stops interfering with a region.
	-- Params:
	-- Index - The Hitbox or BasePart that stopped touching.
	Box.OnHitStop = Signal.New()

	Box.OnDisposal = function()
		-- Disconnect binded part and its .Touched event
		Box.BindToPart(nil)
		
		-- Disconnect parts.
		for i, v in pairs(HitRunners) do
			ToggleConnect(i, false)
		end
		HitRunners = nil
		TouchConnections = nil
		
		-- Dispose.
		Box.OnHit.DisconnectAll()
		Box.OnHitStop.DisconnectAll()
		Box.HitStatusChanged.DisconnectAll()
		
		CurrentlyTouched = nil
		HitStatuses = nil
	end

	return Box
end

return Hitbox