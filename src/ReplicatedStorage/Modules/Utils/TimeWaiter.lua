-- An object that provides a duration-based wait but with further control.
-- This is based off of RunService.Heartbeat.
-- By udev2192

local RunService = game:GetService("RunService")

local Utils = script.Parent

local Object = require(Utils:WaitForChild("Object"))
local Signal = require(Utils:WaitForChild("Signal"))

Utils = nil

local TimeWaiter = {}

--[[
Splits a given number of seconds into minutes, seconds, and milliseconds

Params:
Seconds <number> - The amount of seconds
DecimalDigits <number> - Number of digits to use for decimals

Returns:
<number> - The number of minutes
<number> - The number of seconds
<number> - The number of decimal seconds
]]--
function TimeWaiter.FormatSpeedrunTimeIndividual(Seconds: number, DecimalDigits: number)
	local Minutes = math.floor(Seconds / 60)
	local NewSeconds = Seconds - math.floor(Minutes * 60)
	
	local FloorSeconds = math.floor(NewSeconds)
	local DecimalSeconds = NewSeconds - FloorSeconds
	
	--local DecimalTemp = NewSeconds * (10 ^ Precision)
	--local DecimalSeconds = DecimalTemp - math.floor(DecimalTemp)
	
	return Minutes, FloorSeconds, math.floor(DecimalSeconds * (10 ^ DecimalDigits))
end
--function TimeWaiter.GetSpeedrunTime(Seconds: number, Precision: number)
--	local Minutes = math.floor(Seconds / 60)
--	local NewSeconds = Seconds - math.floor(Minutes * 60)

--	return Minutes, NewSeconds, math.floor(NewSeconds * 10 ^ Precision)
--end

--[[
Splits a given number of seconds into minutes, seconds, and milliseconds,
then returning a formatted time string used for speedrunning

Params:
Seconds <number> - The amount of seconds
Precision <number> - Number of digits for milliseconds

Returns:
<string> - The formatted time
]]--
function TimeWaiter.FormatSpeedrunTime(Seconds: number, Precision: number)
	local Minutes = math.floor(Seconds / 60)
	local NewSeconds = Seconds - math.floor(Minutes * 60)
	--local FlooredSeconds = math.floor(Seconds)
	
	local ZeroAppend
	if NewSeconds < 10 then
		ZeroAppend = "0"
	else
		ZeroAppend = ""
	end

	return Minutes .. ":" .. ZeroAppend .. string.format("%." .. Precision .. "f", NewSeconds)
end

function TimeWaiter.New(Duration: number)
	local Waiter = Object.New("TimeWaiter")
	local IsWaiting = false

	-- The length of the next wait in seconds.
	Waiter.Duration = Duration or 0

	-- Cancels all waits being made.
	function Waiter.Cancel()
		IsWaiting = false
	end

	-- Halts the current thread for the registered
	-- duration in the Waiter.
	function Waiter.Wait()
		local Duration = Waiter.Duration or 0
		local Elapsed = 0
		local HasFullyWaited = false

		-- Wait for the duration.
		if Duration > 0 then
			IsWaiting = true
			while IsWaiting == true do
				Elapsed += RunService.Heartbeat:Wait()

				if Elapsed > Duration then
					break
				end
			end
		end

		-- Fire the signal.
		local Waited = Waiter.Waited
		if Waited ~= nil then
			Waited.Fire(Elapsed)
		end
		Waited = nil
	end

	-- Fired when a wait is cancelled.
	-- Params:
	-- Duration (number) - The amount of time waited when
	-- 					   it was cancelled.
	Waiter.Cancelled = Signal.New()

	-- Fired when a wait is over.
	-- Params:
	-- Duration (number) - The amount of time actually waited in seconds.
	Waiter.Waited = Signal.New()

	Waiter.OnDisposal = function()
		Waiter.Cancel()

		--local WaitedEvent = Waiter.Waited
		--if WaitedEvent ~= nil then
		--	WaitedEvent.DisconnectAll()
		--end
		--Waiter.Waited = nil
		--WaitedEvent = nil
		Waiter.Cancelled.DisconnectAll()
		Waiter.Waited.DisconnectAll()
	end

	return Waiter
end

return TimeWaiter