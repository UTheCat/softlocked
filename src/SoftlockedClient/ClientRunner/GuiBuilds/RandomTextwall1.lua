--[[
A menu for measuring estimated internet speed.

By udev2192
]]--

local RepModules = game:GetService("ReplicatedStorage"):WaitForChild("Modules")

local Replicators = RepModules:WaitForChild("Replicators")

local SpeedTest = require(Replicators:WaitForChild("SpeedTest"))

local Components = game:GetService("ReplicatedStorage")
:WaitForChild("Modules")
:WaitForChild("Gui")
:WaitForChild("Components")

local BaseComponent = require(Components:WaitForChild("BaseComponent"))
local GridMenu = require(Components:WaitForChild("GridMenu"))
local IconButton = require(Components:WaitForChild("IconButton"))

local Util = BaseComponent.GetUtils()

RepModules, Replicators, Components = nil

local TextwallMenu = {}

function TextwallMenu.New()
	local Menu = GridMenu.New()
	Menu.IsUsingGrid = true
	Menu.BackImageTransparency = 0.75
	Menu.SetTitle("information")
	Menu.Gui.Size = UDim2.new(0.5, 0, 0.5, 0)
	Menu.Gui.ZIndex = 5

	Menu.BackTransparency = 0.5
	Menu.Rows = 1
	Menu.Columns = 1
	Menu.ContentPadding = UDim2.new(0, 0, 0, 0)
	Menu.UpdateLayout()

	local SecondaryMenuInfo = IconButton.New(
		[[<b>SOFTLOCKED</b>
		A bloated attempt at a tower fangame.
		
		This game has a lot of bugs!
		
		<b>Why did you make this?</b>
		idk
		
		Background comes from Obby and Glitching Practice since I'm too lazy to upload a new background.
		]])

	SecondaryMenuInfo.BackTransparency = 0.75
	SecondaryMenuInfo.SetRichTextEnabled(true)
	SecondaryMenuInfo.SetInputEnabled(false)
	Menu.AddComponent(SecondaryMenuInfo)
	
	Menu.SetImage(
		Util.CreateInstance(("ImageLabel"), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0.5, 0, 0.5, 0),

			BackgroundTransparency = 1,
			BorderSizePixel = 0,

			ScaleType = Enum.ScaleType.Crop,
			Image = "rbxassetid://6401417348"
		})
	)

	return Menu
end

return TextwallMenu