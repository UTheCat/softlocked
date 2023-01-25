-- Serves as an access point to get the "Object" class.
-- Useful in case the location of the class needs to change.
-- By udev2192

local ObjectGetter = {}

local Utils = script.Parent:WaitForChild("Utils")

-- Returns the "Object" class.
function ObjectGetter.GetClass()
	return require(Utils:WaitForChild("Object"))
end

return ObjectGetter