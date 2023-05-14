--[[
Bezier.lua by udev2192

Handles operations with bezier curves

Updated in 2022 for performance improvements

Thanks to Roblox for referencing some of the math functions:
https://developer.roblox.com/en-us/articles/Bezier-curves
]]--

type PossibleCalcTypes = number | Vector3

local Bezier = {}

-- For interpolation
function Bezier.Lerp(a, b, t)
	return a + (b - a) * t
end

-- For inverse interpolation
-- c is what you wanna convert back into time,
-- which is a value that can be used with Bezier.Lerp
function Bezier.InverseLerp(a, b, c)
	return (c - a)/(b - a)
end

function Bezier.Linear(t, p0, p1)
	return p0 + (p1 - p0) * t
	--return (1 - t) * p0 + t * p1
end

function Bezier.Quadratic(t, p0, p1, p2)
	return (1 - t)^2 * p0 + 2 * (1 - t) * t * p1 + t^2 * p2
end

function Bezier.Cubic(t, p0, p1, p2, p3)
	return (1 - t)^3 * p0 + 3 * (1 - t)^2 * t * p1 + 3 * (1 - t) * t^2 * p2 + t^3 * p3
end

--[[
Calculates the course of a new bezier curve and returns it.

Params:
Degree <number> - Calculation degree (linear, quadratic, or cubic)
				  (any number between 1 and 3)
NumSegments <number> - Number of segments to calculate
					(exceeding 1800 may cause a crash on some devices)
Points <{number | Vector3}> - Numbers or Vector3s to calculate points for
							  (should range between 2 to 4 for best results)
]]--
function Bezier.New(Degree: number, NumSegments: number, Points: {PossibleCalcTypes})
	local p0 = Points[1]
	local p1 = Points[2]
	local p2
	local p3
	local f -- Math function used for calculating the bezier
	
	if Degree == 1 then
		f = Bezier.Linear
	elseif Degree == 2 then
		p2 = Points[3]
		f = Bezier.Quadratic
	elseif Degree == 3 then
		p2 = Points[3]
		p3 = Points[4]
		f = Bezier.Cubic
	else
		error("Degree (argument 1) must be between 1 and 3.")
	end
	
	local NewBz = {}
	local Result: {PossibleCalcTypes} = {}
	
	-- Calculate the bezier segments
	local SegmentIndex = 0
	while SegmentIndex <= NumSegments do
		table.insert(Result, f(SegmentIndex / NumSegments, p0, p1, p2, p3))
		SegmentIndex += 1
	end
	
	-- Provide functions to do things with the segments
	
	--[[
	Gets and returns the resulting segments.
	The number of items in this array is the specified
	number of segments plus 1
	
	Returns:
	<{number | Vector3}> - The resulting segments
	]]--
	function NewBz.GetAllSegments(): {PossibleCalcTypes}
		return Result
	end
	
	--[[
	Returns a segment from the given time (0-1)
	
	Params:
	Time <number> - The time
	
	Returns:
	<number | Vector3> - The resulting segment
	]]--
	function NewBz.Lerp(Time: number): PossibleCalcTypes
		return Result[math.floor(Time * SegmentIndex)]
	end
	
	--[[
	"Smoothly" interpolates through the segments by getting
	two calculated values, then interpolating themselves.
	
	Params:
	Time <number> - The time
	
	Returns:
	<number | Vector3> - The resulting segment
	]]--
	function NewBz.SmoothLerp(Time: number): PossibleCalcTypes
		if Time <= 0 then
			return Result[1]
		elseif Time <= 1 then
			local FirstIndex = math.floor(Time * SegmentIndex)
			local SecondIndex = FirstIndex + 1
			
			local FirstResult = Result[FirstIndex]
			local SecondResult = Result[SecondIndex]
			if FirstResult and SecondResult then
				--print(Result[FirstIndex])
				--print(Bezier.InverseLerp(FirstIndex / SegmentIndex, SecondIndex / SegmentIndex, Time))
				return Bezier.Lerp(
					FirstResult,
					SecondResult,
					Bezier.InverseLerp(FirstIndex / SegmentIndex, SecondIndex / SegmentIndex, Time)--Bezier.InverseLerp(FirstIndex, SecondIndex, Time)
				)
			else
				return FirstResult or SecondResult or Result[1]
			end
		else
			return Result[SegmentIndex]
		end
	end
	
	return NewBz
end

return Bezier