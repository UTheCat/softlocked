-- Default configuration values for the ziplines.

local ConfigDefaults = {}

ConfigDefaults.Values = {
	RideSpeed = 16, -- How fast the player rides the zipline (in studs per second).
	Thickness = 0.5, -- Zipline thickness (in studs).
	GenerationMode = 2, -- Zipline generation formula.
	Precision = 50, -- How precise zipline generation should be.
	DisplayPrecision = 0.5, -- How precise the zipline path should be.
	Volume = 0.5, -- Volume that the zipline sounds play at for the zipline.
	CanJumpToDismount = true, -- If the player can jump to dismount the zipline.
	DisplaysPath = true, -- If a path (in parts) for the zipline is generated.
	DisplaysRider = true, -- If the rider part is displayed.
	GrabSound = "rbxassetid://12222054", -- Played when the zipline is grabbed.
	RideSound = "rbxassetid://12222076", -- Loop played during zipline ride.
	ReleaseSound = "rbxassetid://11900833" -- Played when the zipline is released.
}

-- Returns the default from the values list if the
-- argument 2 is nil or the type is mismatched.
function ConfigDefaults.FillValue(ValueName, Val)
	local Default = ConfigDefaults.Values[ValueName]
	
	if Default ~= nil then
		if typeof(Val) == typeof(Default) then
			return Val
		else
			return Default
		end
	else
		warn(ValueName, "is an invalid zipline attribute.")
		return nil
	end
end

return ConfigDefaults