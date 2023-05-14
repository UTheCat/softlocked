--[[
Bezier.lua by udev2192

Handles operations with bezier curves

Some variable names are derived from algebra for readability.

Thanks to Roblox for providing the necessary functions:
https://developer.roblox.com/en-us/articles/Bezier-curves
]]--

local Object = require(script.Parent.Parent:WaitForChild("BaseInteractive")).GetObjectClass()

local Bezier = {}

local function Hypotenuse(a, b)
	return (a^2 + b^2) ^ 0.5
end

local function GetLengthInternal(numPoints, func, dataType, ...)
	local Total, Ranges, Sums, IntToTime = 0, {}, {}, {}
	local IsVector = string.match(dataType, "Vector", 1)
	
	for i = 0, numPoints - 1, 1 do
		local p1, p2 = func(i / numPoints, ...), func((i + 1) / numPoints, ...)
		local distance = nil;
		if IsVector then
			distance = (p2 - p1).magnitude
		else
			distance = Hypotenuse(p1, p2);
		end
		
		local CenterPosition = (p1 + p2) / 2

		Ranges[Total] = {
			Distance = distance,
			Point1 = p1,
			Point2 = p2,
			Magnitude = (p2 - p1).Magnitude,
			CenterPos = CenterPosition,
			Direction = CFrame.new(CenterPosition, p1) * CFrame.Angles(0, math.pi, 0)
		}
		
		table.insert(Sums, Total)
		Total += distance
	end

	return Total, Ranges, Sums
end

function Bezier.Lerp(a, b, c) -- For interpolation
	return a + (b - a) * c
end

function Bezier.Calculate(t, PointsTable)
	assert(typeof(PointsTable) == "table", "Argument #2 must be a table.")
	
	-- t specifies time/alpha (between 0-1)
	-- PointsTable specifies each point
	if typeof(PointsTable) == "table" then
		if #PointsTable >= 2 then
			
		else
			warn("Argument #2 must have at least 2 indexes/points.")
			return 0
		end
	else
	end
end

function Bezier.Linear(t, p0, p1)
	return (1 - t) * p0 + t * p1
end

function Bezier.Quadratic(t, p0, p1, p2)
	return (1 - t)^2 * p0 + 2 * (1 - t) * t * p1 + t^2 * p2
end

function Bezier.Cubic(t, p0, p1, p2, p3)
	return (1 - t)^3 * p0 + 3 * (1 - t)^2 * t * p1 + 3 * (1 - t) * t^2 * p2 + t^3 * p3
end

-- Segment length calculator (in a single dimension)
function Bezier.GetLengths(numPoints, func, ...)
	return GetLengthInternal(numPoints, func, "number", ...)
end

-- For Vector3 segment length calculation
function Bezier.GetVect3Lengths(numPoints, func, ...)
	return GetLengthInternal(numPoints, func, "Vector3", ...)
end

-- Constructs and returns a new bezier
function Bezier.New(calcFunc, numPoints, ...)
	local Obj = Object.New("BezierCurve")
	
	function Obj.RecalculateAll(func, numPointsRedo, ...)
		local TotalDist, RangesList, DistancesList = Bezier.GetVect3Lengths(numPointsRedo, func, ...)
		local Points = {...}
		
		Obj.BeginningPoint = Points[1]
		Obj.EndPoint = Points[#Points]
		
		Obj.SetProperty("Func", calcFunc, nil)
		Obj.SetProperty("NumPoints", numPoints, nil)
		Obj.SetProperty("Points", Points, nil)

		Obj.SetProperty("TotalDist", TotalDist, nil) -- Total travel distance.
		Obj.SetProperty("Ranges", RangesList, nil)
		Obj.SetProperty("Distances", DistancesList, nil)
		
		return TotalDist, RangesList, DistancesList
	end
	
	-- For initialization
	Obj.RecalculateAll(calcFunc, numPoints, ...)
	
	-- Resets the path to the specified Vector3 points
	function Obj.SetPoints(...)
		return Obj.RecalculateAll(Obj.Func, Obj.NumPoints, ...)
	end
	
	-- Gets the index of the curve.
	-- Use if percentage isn't a factor.
	function Obj.GetSegmentByIndex(pos)
		return Obj.Ranges[pos]
	end
	
	-- Returns the distance by the provided array index,
	-- if it exists.
	--function Obj.GetDistanceByIndex(Index)
	--	return Obj.Distances[Index]
	--end
	
	-- Gets a segment based on the percentage of the curve.
	function Obj.GetSegmentByTime(timePos)
		local t, near = timePos * Obj.TotalDist, 0
		local DistTable = Obj.Distances
		
		for _, i in ipairs(DistTable) do
			if (t - i) >= 0 then
				near = i
			else
				break
			end 
		end
		
		local pointsSet = Obj.Ranges[near]
		
		if typeof(pointsSet) == "table" then
			local percent = (t - near) / pointsSet.Distance
			return pointsSet, percent -- {point1, point2, ...}, offset
		else
			return
		end
	end
	
	-- Returns an array of all segments
	function Obj.GetAllSegments()
		--local NumPoints = Obj.NumPoints
		--local Increment = 1/NumPoints
		--
		--local Set = {}
		--for i = 0, 1, Increment do
		--	local Segment = Obj.GetSegmentByTime(i)
		--	if Segment ~= nil then
		--		table.insert(Set, Segment)
		--	end
		--end
		
		--return Set
		
		--return Obj.Ranges
		
		local Segments = {}
		local Ranges = Obj.Ranges
		local Distances = Obj.Distances
		if Distances ~= nil then
			for i, v in ipairs(Distances) do
				local val = Ranges[v]
				if val ~= nil then
					table.insert(Segments, val)
				end
			end
		end
		
		return Segments
	end
	
	return Obj
end

-- Returns a lerped value on the bezier set (this is for arc length parameterization).
function Bezier.LerpCombined(Time, Beziers)
	local TotalDist, Sums = 0, {}

	-- Find the sum of all bezier curves
	for i, v in ipairs(Beziers) do
		table.insert(Sums, TotalDist)
		TotalDist += v.TotalDist
	end

	-- Pinpoint the position on the combined bezier with the provided time
	local t, near, CurrentBezier = TotalDist * Time, 0, Beziers[1]
	for i, v in ipairs(Sums) do
		if (t - v) >= 0 then
			near, CurrentBezier = v, Beziers[i]
		else
			break
		end
	end

	-- Find the percent traveled on the overall bezier
	local Percentage = (t - near) / CurrentBezier.TotalDist

	-- Interpolate using the percentage
	local FoundSegment = CurrentBezier.GetSegmentByTime(Percentage)
	local a, b, c = FoundSegment.Point1, FoundSegment.Point2, Percentage

	return Bezier.Lerp(a, b, c), FoundSegment
end

return Bezier