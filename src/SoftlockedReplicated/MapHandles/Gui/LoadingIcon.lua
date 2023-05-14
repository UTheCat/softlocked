--[[
loading icon with a little animation to go with it

]]--

local RunService = game:GetService("RunService")

local BaseComponent = require(game:GetService("ReplicatedStorage")
	:WaitForChild("SoftlockedReplicated")
	:WaitForChild("Gui")
	:WaitForChild("Components")
	:WaitForChild("BaseComponent")
)
local Util = BaseComponent.GetUtils()

local LoadingIcon = {}

function LoadingIcon.New()
	local Icon = BaseComponent.New("Frame")
	local Circles = {}
	
	Icon.VisibleChanged.Connect(function(IsVisible)
		
	end)
	
	return Icon
end

return LoadingIcon