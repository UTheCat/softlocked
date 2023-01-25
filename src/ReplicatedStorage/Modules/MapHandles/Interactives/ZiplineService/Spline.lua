--[[
A utility module for cubic spline interpolation.

See: https://en.wikipedia.org/wiki/Spline_interpolation
]]--

local ZiplineService = script.Parent
local Object = require(ZiplineService:WaitForChild("Object"))

local Spline = {}

local function Hypotenuse(a, b)
	return (a^2 + b^2) ^ 0.5
end

function Spline.Lerp(a, b, c) -- For interpolation
	return a + (b - a) * c
end

-- Formula
function Spline.Interpolate(numPoints, t, a, b)
	return ((1 - (t * numPoints)) * a) + ((t * numPoints) * b) + ((t * numPoints) * ((1 - (t * numPoints))) * (((1 - (t * numPoints)) * a) * (t * numPoints * b)))
end

function Spline.GetVector3(numPoints, t, v1, v2)
	assert(typeof(v1) == "Vector3", "Argument 3 must be a Vector3.")
	assert(typeof(v2) == "Vector3", "Argument 4 must be a Vector3.")
	
	local x = Spline.Interpolate(numPoints, t, v1.X, v2.X)
	local y = Spline.Interpolate(numPoints, t, v1.Y, v2.Y)
	local z = Spline.Interpolate(numPoints, t, v1.Z, v2.Z)
	
	return Vector3.new(x, y, z)
end

function Spline.GetLength(IsVector3, PointArgs)
	local Total, Ranges, Sums = 0, {}, {}
	local numPoints = #PointArgs
	
	local func = nil
	if IsVector3 then
		func = Spline.GetVector3
	else
		func = Spline.Interpolate
	end
	
	for i = 0, numPoints - 1, 1 do
		local p1, p2 = func(numPoints, i / numPoints, PointArgs[1], PointArgs[numPoints]), func(numPoints, i / numPoints, PointArgs[1], PointArgs[numPoints])
		local distance = nil;
		if IsVector3 then
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

function Spline.NewVector3(points)
	assert(typeof(points) == "table", "Argument 1 must be an array.")
	
	local Obj = Object.New("Spline")
	
	-- Refreshes the spline's calculations
	function Obj.Refresh()
		local TotalDist, RangesList, DistancesList = Spline.GetLength(true, Obj.PointsArray)
		
		Obj.SetProperty("TotalDist", TotalDist, nil) -- Total travel distance.
		Obj.SetProperty("Ranges", RangesList, nil)
		Obj.SetProperty("Distances", DistancesList, nil)
	end
	
	-- Resets the path to the specified Vector3 points
	function Obj.SetPoints(newPoints)
		Obj.PointsArray = newPoints
	end

	-- Gets the index of the curve.
	-- Use if percentage isn't a factor.
	function Obj.GetSegmentByIndex(pos)
		return Obj.Ranges[pos]
	end

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
		local NumPoints = Obj.NumPoints
		local Increment = 1/NumPoints

		local Set = {}
		for i = 0, 1, Increment do
			local Segment = Obj.GetSegmentByTime(i)
			if Segment ~= nil then
				table.insert(Set, Segment)
			end
		end

		return Set
	end
	
	-- Initialize
	Obj.SetProperty("NumPoints", #points, Obj.Refresh)
	Obj.SetProperty("PointsArray", points, Obj.Refresh)
	Obj.Refresh()
	
	return Obj
end

-- Returns a lerped value on the spline set (this is for arc length parameterization).
function Spline.LerpCombined(Time, Beziers)
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

	return Spline.Lerp(a, b, c), FoundSegment
end

return Spline