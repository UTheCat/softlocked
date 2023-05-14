-- Utility module that basically wraps RunService.
-- By udev2192

local RunService = game:GetService("RunService")

local Runtime = {}

-- Waits for a specified amount of time in seconds.
-- Returns the time difference between the desired wait
-- and the actual wait.
function Runtime.WaitForDur(Duration: number)
	assert(typeof(Duration) == "number", "Argument 1 must be a number.")
	
	local Elapsed = 0
	while (Elapsed < Duration) do
		Elapsed += RunService.Heartbeat:Wait()
	end
	
	return Elapsed - Duration
end

-- Returns the frames per second
function Runtime.GetFramerate()
	return 1 / RunService.Heartbeat:Wait()
end

return Runtime