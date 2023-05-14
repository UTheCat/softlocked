--[[
Softlocked's info menu

By UTheDev
]]--

local Info = require(game:GetService("ReplicatedStorage"):WaitForChild("SoftlockedReplicated"):WaitForChild("Info"))

--local Replicators = RepModules:WaitForChild("Replicators")

--local SpeedTest = require(Replicators:WaitForChild("SpeedTest"))

local Components = game:GetService("ReplicatedStorage")
:WaitForChild("SoftlockedReplicated")
:WaitForChild("Gui")
:WaitForChild("Components")

local BaseComponent = require(Components:WaitForChild("BaseComponent"))
local GridMenu = require(Components:WaitForChild("GridMenu"))
local IconButton = require(Components:WaitForChild("IconButton"))

local Util = BaseComponent.GetUtils()

RepModules, Replicators, Components = nil

local InfoMenu = {}

function InfoMenu.New()
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
		An open source obby-runner.

		Source code is available at UTheDev/softlocked
		]]

		.. "\nVersion: " .. Info.Version
	
	)

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

return InfoMenu