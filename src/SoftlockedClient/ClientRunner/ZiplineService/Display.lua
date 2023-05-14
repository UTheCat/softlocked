-- The module that displays the zipline.
-- By: udev2192

-- Unused function archive:
--[[
	local function DrawByIndex(i1, i2)
		local s1 = Bezier.GetSegmentByIndex(i1)
		local s2 = Bezier.GetSegmentByIndex(i2)
		local point1 = s1.Point1
		local point2 = s2.Point2
		local CenterPos = (point1 + point2) / 2
		local cf = CFrame.new(CenterPos, point1)
		
		local Properties = {
			Anchored = true,
			CanCollide = false,
			Size = Vector3.new(ZIPLINE_THICKNESS, ZIPLINE_THICKNESS, (point2 - point1).Magnitude),
			CFrame = cf,
			--CFrame = CFrame.new(CenterPos.X, CenterPos.Y, CenterPos.Z) * GetLineOrientation(p1, p2);
			Transparency = Obj.Transparency,
			Material = Obj.Material,
			Color = Obj.Color
		}

		local Part = GetLineInternal(Properties)

		return Part
	end
]]--

local ZiplineService = script.Parent
local Object = require(ZiplineService:WaitForChild("Object"))

local Display = {}

local ZERO_VECTOR3 = Vector3.new(0, 0, 0)

local DEFAULT_MATERIAL = Enum.Material.Plastic
local DEFAULT_COLOR = Color3.fromRGB(0, 0, 0)
local DEFAULT_TRANSPARENCY = 0.5;

function GetLineOrientation(p1, p2)
	return CFrame.lookAt(p1, p2)
end

function GetLineInternal(PartProperties)
	local Line = Instance.new("Part")
	Line.Anchored = true -- Just in case
	for i, v in pairs(PartProperties) do
		--print(i, ":", v)
		Line[i] = v
	end

	return Line
end

-- Generates a 3d line for display as a Part.
function Display.GetLineFromPoints(PartProperties)
	return GetLineInternal(PartProperties)
end

function Display.New()
	local Obj = Object.New("ZiplineDisplay")
	Obj.Parts = Instance.new("Model")
	--Obj.Segments = {}

	-- Amount of points one displayed point would actually represent.
	-- This means higher number = better performance.
	Obj.PartGroupSize = 20

	Obj.SetProperty("Material", DEFAULT_MATERIAL, function(material)
		for i, v in ipairs(Obj.Parts:GetChildren()) do
			if v:IsA("BasePart") then
				v.Material = material
			end
		end
	end)
	Obj.SetProperty("Color", DEFAULT_COLOR, function(color)
		for i, v in ipairs(Obj.Parts:GetChildren()) do
			if v:IsA("BasePart") then
				v.Color = color
			end
		end
	end)
	Obj.SetProperty("Transparency", DEFAULT_COLOR, function(transparency)
		for i, v in ipairs(Obj.Parts:GetChildren()) do
			if v:IsA("BasePart") then
				v.Transparency = transparency
			end
		end
	end)
	Obj.SetProperty("Thickness", 1, function(thickness)
		for i, v in ipairs(Obj.Parts:GetChildren()) do
			if v:IsA("BasePart") then
				v.Size = Vector3.new(thickness, thickness, v.Size.Z)
			end
		end
	end)

	-- Draws the zipline display using the beziers provided in the array.
	function Obj.Refresh(beziers)
		local Thickness = Obj.Thickness
		local GroupSize = Obj.PartGroupSize
		local model = Obj.Parts

		if Thickness ~= nil and GroupSize ~= nil then
			for i, bezier in ipairs(beziers) do
				local Segments = bezier.GetAllSegments()
				--Obj.Segments = Segments

				-- The last segment with GroupSize
				-- taken into account.
				local LastSegment = nil
				
				local TotalMagnitude = 0

				-- The last part group center position.
				--local LastCenterPos = nil

				-- Generate the parts
				local NumSegments = #Segments
				local FinalIndex = NumSegments - GroupSize + 1

				for i, v in ipairs(Segments) do
					local p1 = nil
					local p2 = nil
					local Magnitude = nil
					local HasReachedEnd = false

					-- Get the last end point from the info in the bezier
					local NextEndPoint = Segments[i + math.floor(GroupSize * 0.5)]

					-- Calculate size, then mark the center as the position
					-- of placement (to group segment parts)
					-- If the index is at one of the ends, cap the group sizing
					-- so that it doesn't go beyond the control points.
					if i >= FinalIndex then
						HasReachedEnd = true
						
						if NextEndPoint ~= nil and LastSegment ~= nil then
							-- Calculate the beginning of the last segment
							--p1 = Segments[i - math.floor(ZipPrecision)].Point2
							--local LastSegment = Segments[i - math.floor(ZipPrecision)]
							local SegmentPoint1 = LastSegment.Point1
							local SegmentPoint2 = LastSegment.Point2
							
							p1 = ((SegmentPoint1 + SegmentPoint2) / 2) + ((SegmentPoint2 - SegmentPoint1) * (GroupSize * 0.5)) --+ ((LastSegment.Point2 - LastSegment.Point1) * (GroupSize / 2))
						elseif i == 1 then
							p1 = bezier.BeginningPoint
						else
							break
						end
						
						if p1 ~= nil then
							p2 = bezier.EndPoint
							--print(bezier.EndPoint)
							--print(GroupSize, "min", (v.Point1 - p2).Magnitude)
							--p1 = p2 - ((v.Point2 - v.Point1) * math.min(GroupSize, (v.Point1 - p2).Magnitude))
							--p1 = (v.Point2 - p2)

							--LastSegment = NextEndPoint
							Magnitude = (p2 - p1).Magnitude--bezier.TotalDist - TotalMagnitude --
							--print("End magnitude:", Magnitude)
						else
							break
						end
					elseif i == 1 then
						p1 = bezier.BeginningPoint
						p2 = NextEndPoint and NextEndPoint.Point1 or bezier.EndPoint --p1 + ((v.Point2 - v.Point1) * math.min(GroupSize, (v.Point2 - p1).Magnitude))
						--p2 = (v.Point2 - p1)

						Magnitude = (p2 - p1).Magnitude
						--print("Beginning magnitude", Magnitude)
					elseif (i % GroupSize) == 0 then
						p1 = v.Point1
						p2 = v.Point2

						Magnitude = (p2 - p1).Magnitude * GroupSize
						
						-- Add the index by the group size.
						-- to reduce the amount of iterations.
						-- Cap at the final index to make sure we don't skip
						-- the ending segment.
						
						-- Subtraction by 1 is needed because of the increment
						-- that happens on the next index.
						i = math.min(i + GroupSize - 1, FinalIndex - 1)
					else
						continue
					end
					
					TotalMagnitude += Magnitude

					--local p1 = v.Point1
					--local p2 = v.Point2

					local CenterPos = (p1 + p2) / 2
					--LastCenterPos = CenterPos

					LastSegment = v --- ((v.Point2 - v.Point1) * math.min(GroupSize, (v.Point1 - p2).Magnitude)) --v.Point2 - p2--CenterPos + (p2 / 2)

					local Properties = {
						Anchored = true,
						CanCollide = false,
						Size = Vector3.new(Thickness, Thickness, Magnitude),
						CFrame = CFrame.new(CenterPos, p1),
						--CFrame = CFrame.new(CenterPos.X, CenterPos.Y, CenterPos.Z) * GetLineOrientation(p1, p2);
						Transparency = Obj.Transparency,
						Material = Obj.Material,
						Color = Obj.Color
					}

					local Part = GetLineInternal(Properties)

					if typeof(Part) == "Instance" and Part:IsA("BasePart") then
						Part.Parent = model
					end

					if HasReachedEnd == true then
						break
					end
				end
				

				-- Would get rid of a ton of lag if this worked lol:
				--[[
				for i = 1, GroupSize, NumSegments do
					local Segment = Segments[i]
					
					if Segment ~= nil then
						local p1 = nil
						local p2 = nil

						-- Calculate size, then mark the center as the position
						-- of placement (to group segment parts)
						if i == 1 then
							p1 = bezier.BeginningPoint
							p2 = p1 + ((Segment.Point2 - Segment.Point1) * GroupSize)
						elseif i == NumSegments then
							p2 = bezier.EndPoint
							p1 = p2 - ((Segment.Point2 - Segment.Point1) * GroupSize)
						else
							p1 = Segment.Point1
							p2 = Segment.Point2
						end

						--local p1 = v.Point1
						--local p2 = v.Point2

						local CenterPos = (p1 + p2) / 2

						local Properties = {
							Anchored = true,
							CanCollide = false,
							Size = Vector3.new(Thickness, Thickness, Segment.Magnitude * GroupSize),
							CFrame = CFrame.new(Segment.CenterPos, p1),
							--CFrame = CFrame.new(CenterPos.X, CenterPos.Y, CenterPos.Z) * GetLineOrientation(p1, p2);
							Transparency = Obj.Transparency,
							Material = Obj.Material,
							Color = Obj.Color
						}

						local Part = GetLineInternal(Properties)

						if typeof(Part) == "Instance" and Part:IsA("BasePart") then
							Part.Parent = model
						end
					end
				end
				]]--
			end
		end
	end

	-- Displays the bezier (display properties should be set first)
	--function Obj.DisplayBezier(bezier)
	--	if bezier == nil then
	--		bezier = Obj.Bezier
	--	end

	--	Obj.Bezier = bezier
	--	Obj.Refresh(bezier)
	--end

	Obj.OnDisposal = function()
		if Obj.Parts ~= nil then
			Obj.Parts:Destroy()
		end
	end

	return Obj
end

return Display