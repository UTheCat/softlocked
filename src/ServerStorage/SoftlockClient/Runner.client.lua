-- Starts the game's client runner.
-- By udev2192

-- Launcher attribute name.
local LAUNCH_ATTRIBUTE_NAME = "LaunchMode"

local ClientPakcage = script.Parent

-- Start the client stuff.
local ClientRunner = require(ClientPakcage:WaitForChild("ClientRunner"))
local ClientRunnerObj = ClientRunner.Run(script.Parent:GetAttribute(LAUNCH_ATTRIBUTE_NAME))

-- Garbage collect.
ClientPakcage, ClientRunner, ClientRunnerObj, LAUNCH_ATTRIBUTE_NAME = nil, nil, nil, nil