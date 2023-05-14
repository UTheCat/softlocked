--[[
Schedules events to happen in a particular timestamp

By udev2192
]]--

local Object = require(script.Parent:WaitForChild("Object"))

local Scheduler = {}
Scheduler.__index = Scheduler
Scheduler.ClassName = script.Name

function Scheduler.New()
	local Scheduler = Object.New(Scheduler.ClassName)
	
	-- Table that holds scheduled functions those
	-- not called yet.
	-- This is for reducing the amount of iterations done by
	-- the scheduler
	local Queue = {}
	local IsRunning = false
	
	--[[
	<{[number]: () -> ()}> - Table that holds the schedule.
							 [timestamp] = function
	]]--
	Scheduler.Schedule = {}
	
	--[[
	<number> - Current timestamp of the scheduler in seconds
			   This usually won't end exactly at the
			   last timestamp due to task.wait() returning
			   different values based on processing speed
	]]--
	Scheduler.Time = 0
	
	--[[
	<boolean> - Whether or not to call scheduled functions
				synchronously
	]]--
	Scheduler.Sync = false
	
	--[[
	<boolean> - Whether or not the timer stops after calling the last item
	]]--
	Scheduler.StopAtLast = true
	
	--[[
	Returns:
	<boolean> - Whether or not the scheduler is currently running
	]]--
	function Scheduler.IsRunning()
		return IsRunning
	end
	
	--[[
	Pauses the execution of the scheduler
	]]--
	function Scheduler.Pause()
		Queue = {}
		IsRunning = false
	end
	
	--[[
	Resumes the execution of the scheduler
	]]--
	function Scheduler.Resume()
		if IsRunning == false then
			IsRunning = true
			
			local CurrentTime = Scheduler.Time
			for i, v in pairs(Scheduler.Schedule) do
				assert(typeof(i) == "number", "Schedule indexes must be numbers")
				assert(typeof(v) == "function", "Schedule values must be functions")
				
				table.insert(Queue, {i, v})
			end
			CurrentTime = nil
			
			while true do
				if IsRunning == false or (#Queue <= 0 and Scheduler.StopAtLast == true) then
					Scheduler.Pause()
					break
				end
				
				local Time = Scheduler.Time
				local Sync = Scheduler.Sync
				
				for i, v in pairs(Queue) do
					if v[1] <= Time then
						table.remove(Queue, i)
						
						if Sync then
							v[2]()
						else
							task.spawn(v[2])
						end
					end
				end
				
				if IsRunning then
					Scheduler.Time += task.wait()
				else
					break
				end
			end
		end
	end
	
	Scheduler.OnDisposal = Scheduler.Pause
	
	return Scheduler
end

return Scheduler