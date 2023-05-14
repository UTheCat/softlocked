--[[
This component provides a menu that has multiple options the user can select
via a grid of options.

Default UI scheme is designed for specific games

By udev2192
]]--

local ZERO_UDIM2 = UDim2.new(0, 0, 0, 0)
local PRIMARY_COMPONENT_ZINDEX = 3
local MENU_FRAME_ZINDEX = 1
local CLOSE_BUTTON_NAME = "CloseButton"

local Package = script.Parent
local BaseComponent = require(Package:WaitForChild("BaseComponent"))
local IconButton = require(Package:WaitForChild("IconButton"))
local Util = BaseComponent.GetUtils()

local GridMenu = {}
GridMenu.__index = GridMenu

-- The default name used for the GridMenu gui instance.
GridMenu.GuiName = script.Name

--[[
The color used by the closed button create in the
corresponding constructor.
]]--
GridMenu.CloseButtonColor = Color3.fromHSV(0, 1, 0.6)

GridMenu.CloseButtonCornerRadius = BaseComponent.DefaultCornerRadius
GridMenu.ContentFrameSize = UDim2.new(0.85, 0, 0.6, 0)
--GridMenu.CloseButtonAspectRatio = 1

-- The color gradient of the line at the top of the menu
GridMenu.HeaderLineGradient = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, 1)),
	ColorSequenceKeypoint.new(1, Color3.fromHSV(0, 0, 0.5))
})

-- Toggles a component/GUI instance's visibility.
local function ToggleGuiVisibility(Gui, IsVisible)
	if typeof(Gui) == "Instance" then
		Gui.Visible = IsVisible
	elseif typeof(Gui) == "table" and Gui.SetVisible ~= nil then
		Gui.SetVisible(IsVisible)
	end
end

-- Gets the GUI instance from a component.
local function GetGuiFromComponent(Component)
	if typeof(Component) == "Instance" then
		return Component
	elseif typeof(Component) == "table" and Component.Gui ~= nil then
		return Component.Gui
	else
		return nil
	end
end

function GridMenu.New()
	local Menu = BaseComponent.New("Frame")
	local IsFadingIn = false
	
	local CloseButtonInit = IconButton.New("X")
	local CloseConnection
	local IsClosing = false
	
	local DefaultCornerRadius = BaseComponent.DefaultCornerRadius

	Menu.CloseButton = CloseButtonInit
	
	-- The contents in the content frame.
	local Contents = {}
	
	local ContentFrameSize = GridMenu.ContentFrameSize
	
	-- If the menu will override a GUI instance's
	-- layout order.
	Menu.OverridesLayoutOrder = true
	
	-- The next size of the line displayed at the top.
	Menu.HeaderLineSize = UDim2.new(ContentFrameSize.X.Scale, ContentFrameSize.X.Offset, 0.01, 0)
	
	-- The next position of the menu frame.
	Menu.FramePosition = UDim2.new(0.5, 0, 0.5, 0)
	
	-- The position offset of the menu frame when it gets hidden.
	Menu.FrameHideOffset = UDim2.new(0, 0, 0, 0)--UDim2.new(0, 0, 0.1, 0)
	
	-- Background image transparency when the menu is made visible.
	Menu.BackImageTransparency = 0.5
	
	Menu.CornerRadius = UDim.new(0, 10)
	
	Menu.Rows = 2
	Menu.Columns = 5
	Menu.ContentPadding = UDim2.new(0.05, 0, 0.05, 0)
	
	local function GetHiddenHeaderLineSize()
		local LineSize = Menu.HeaderLineSize or ZERO_UDIM2
		
		return UDim2.new(0, 0, LineSize.Y.Scale, LineSize.Y.Offset)
	end
	
	local function GetFrameHiddenPos()
		return Menu.FramePosition + Menu.FrameHideOffset
	end
	
	local function ToggleCloseVisible(IsVisible)
		local CloseButton = Menu.CloseButton
		if CloseButton ~= nil then
			CloseButton.SetVisible(Menu.ShowsCloseButton and IsVisible)
		end
	end
	
	Menu.SetProperty("ShowsCloseButton", true, function(IsVisible)
		IsVisible = IsVisible and IsFadingIn
		
		CloseButtonInit.Gui.Visible = IsVisible
	end)
	
	-- Create the GUI components
	local MenuFrame = Menu.Gui
	MenuFrame.Visible = false
	MenuFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MenuFrame.BackgroundTransparency = 1
	MenuFrame.ClipsDescendants = true
	MenuFrame.ZIndex = MENU_FRAME_ZINDEX
	MenuFrame.Name = GridMenu.GuiName
	MenuFrame.Position = GetFrameHiddenPos()
	assert(MenuFrame ~= nil, "The GUI from the BaseComponent is missing.")
	
	local Theme = Menu.GetTheme()
	
	local TitleLabel = Theme.MakeInstance("TextLabel", {
		Font = Enum.Font.GothamBold,
		Size = UDim2.new(ContentFrameSize.X.Scale, ContentFrameSize.X.Offset, 0.1, 0),
		Position = UDim2.new(0.5, 0, 0.15, 0),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		BackgroundTransparency = 1,
		Text = "Title",
		Name = "Title",
		
		TextXAlignment = Enum.TextXAlignment.Left,
		
		ZIndex = PRIMARY_COMPONENT_ZINDEX,
		
		Parent = MenuFrame
	})
	
	local HeaderLine = Theme.MakeInstance("Frame", {
		Size = GetHiddenHeaderLineSize(),
		Position = UDim2.new(0.5, 0, 0.25, 0),
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0,
		Name = "HeaderLine",
		
		ZIndex = PRIMARY_COMPONENT_ZINDEX,
		
		Parent = MenuFrame
	})
	
	local CloseButtonGui = CloseButtonInit.Gui
	if CloseButtonGui ~= nil then
		ToggleCloseVisible(false)
		CloseButtonGui.BackgroundColor3 = GridMenu.CloseButtonColor

		CloseButtonGui.AnchorPoint = Vector2.new(0.5, 0.5)
		CloseButtonGui.Size = UDim2.new(0.1, 0, 0.1, 0)
		CloseButtonGui.Position = UDim2.new(0.9, 0, 0.125, 0)
		
		--BaseComponent.AddAspectRatio(CloseButtonGui, GridMenu.CloseButtonAspectRatio)

		CloseButtonGui.ZIndex = PRIMARY_COMPONENT_ZINDEX

		CloseButtonGui.Name = CLOSE_BUTTON_NAME

		CloseConnection = CloseButtonInit.GetButton().Activated:Connect(function()
			if IsClosing == false then
				IsClosing = true

				Menu.SetVisible(false)

				IsClosing = false
			end
		end)
		
		BaseComponent.AddCornerRadius(CloseButtonGui, GridMenu.CloseButtonCornerRadius)

		CloseButtonGui.Parent = Menu.Gui
	else
		error("Close button IconButton is missing the .Gui property.")
	end

	CloseButtonInit = nil
	
	-- Initialize the frame that display the buttons/labels
	local ContentFrame = Theme.MakeInstance("Frame", {
		Size = GridMenu.ContentFrameSize,
		Position = UDim2.new(0.5, 0, 0.6, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Name = "ContentFrame",
		
		ZIndex = PRIMARY_COMPONENT_ZINDEX,
		
		Parent = MenuFrame
	})
	
	-- Apply a grid layout to the content frame
	local Layout = Theme.MakeInstance("UIGridLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,

		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center
	})
	
	Menu.ContentFrame = ContentFrame
	
	--[[
	Updates the layout of the content frame.
	]]--
	function Menu.UpdateLayout()
		local Padding = Menu.ContentPadding
		Layout.CellPadding = Padding
		Layout.CellSize = BaseComponent.GetGridItemSize(Menu.Rows, Menu.Columns, Padding)
	end
	
	Menu.UpdateLayout()
	
	--[[
	<boolean> - If the grid layout is currently being used.
	]]--
	Menu.SetProperty("IsUsingGrid", false, function(IsUsing)
		if IsUsing == true then
			Menu.UpdateLayout()
			Layout.Parent = ContentFrame
		else
			if Layout.Parent ~= nil then
				Layout.Parent = nil
			end
		end
	end)
	
	-- Apply a gradient to the animation line
	Theme.MakeInstance("UIGradient", {
		Color = GridMenu.HeaderLineGradient,
		Rotation = 0,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1)
		}),
		Parent = HeaderLine
	})
	
	-- Give the menu rounded corners
	local MenuCorner = BaseComponent.AddCornerRadius(MenuFrame, DefaultCornerRadius)
	
	DefaultCornerRadius, ContentFrameSize = nil
	
	-- Refreshes the stored components' layout order.
	local function RefreshLayoutOrder()
		if Menu.OverridesLayoutOrder == true then
			for i, v in pairs(Contents) do
				local Gui = GetGuiFromComponent(v)
				
				if Gui ~= nil then
					Gui.LayoutOrder = i
				end
				
				Gui = nil
			end
		end
	end
	
	-- Visibility handler
	local function OnVisibleChanged(IsVisible)	
		local Transparency
		local NewImageTransparency
		local NewHeaderLineSize
		local DestinationPos
		local DestinationOffsetted = GetFrameHiddenPos()
		
		-- Determine destination tween variables
		if IsVisible == true then
			Transparency = 0
			NewImageTransparency = Menu.BackImageTransparency or 0
			
			NewHeaderLineSize = Menu.HeaderLineSize
			DestinationPos = Menu.FramePosition
			
			IsFadingIn = true
		else
			Transparency = 1
			NewImageTransparency = 1
			
			NewHeaderLineSize = GetHiddenHeaderLineSize()
			DestinationPos = GetFrameHiddenPos()
			
			IsFadingIn = false
		end
		
		-- Animate
		local Info = Menu.TweeningInfo
		if Info ~= nil then
			if IsFadingIn == true and IsVisible == true then
				MenuFrame.Visible = true
			end
			
			ToggleCloseVisible(IsVisible)
			
			Util.Tween(MenuFrame, Info, {Position = DestinationPos, BackgroundTransparency = Transparency})
			Util.Tween(HeaderLine, Info, {Size = NewHeaderLineSize})
			Util.Tween(TitleLabel, Info, {TextTransparency = Transparency})
			
			--if BackgroundImage ~= nil then
			--	Util.Tween(BackgroundImage, Info, {ImageTransparency = NewImageTransparency})
			--end
			
			for i, v in pairs(Contents) do
				ToggleGuiVisibility(v, IsVisible)
			end
			
			task.wait(Info.Time)
			
			if IsFadingIn == false and IsVisible == false then
				MenuFrame.Visible = false
				MenuFrame.Position = DestinationOffsetted
			end
		end
	end
	
	--[[
	Returns:
	<boolean> - If the GUI is currently trying to be shown.
	]]--
	function Menu.IsFadingIn()
		return IsFadingIn
	end
	
	--[[
	Sets the title displayed at the top of the menu.
	
	Params:
	Title <string> - The title to display.
	]]--
	function Menu.SetTitle(Title)
		assert(typeof(Title) == "string", "Argument 1 must be a string.")
		
		TitleLabel.Text = Title
	end
	
	--[[
	Adds a component to the content frame.
	
	Params:
	Component <variant> - The component or GUI instance to add.
	LayoutOrder <number> - An optional argument that specifies
						   the component to add's layout order.
	]]--
	function Menu.AddComponent(Component, LayoutOrder)
		if typeof(LayoutOrder) == "number" then
			table.insert(Contents, LayoutOrder, Component)
		else
			table.insert(Contents, Component)
		end
		
		RefreshLayoutOrder()
		GetGuiFromComponent(Component).Parent = ContentFrame
	end
	
	--[[
	Destroys the close button used and disconnects the
	event code used to make it work.
	]]--
	function Menu.DestroyCloseButton()
		local CloseButton = Menu.CloseButton
		if CloseButton ~= nil then
			CloseButton.Dispose()
			CloseButton = nil
		end

		if CloseConnection ~= nil then
			CloseConnection:Disconnect()
			CloseConnection = nil

			IsClosing = nil
		end
	end
	
	--[[
	Removes a component from the content frame.
	
	Params:
	Component <variant> - The component or GUI instance to remove.
	]]--
	function Menu.RemoveComponent(Component)
		local Index = table.find(Contents, Component)
		if Index ~= nil then
			-- Maually remove from the table to preserve
			-- the layout order of other components.
			Contents[Index] = nil
		end
		
		GetGuiFromComponent(Component).Parent = nil
		RefreshLayoutOrder()
	end
	
	Menu.VisibleChanged.Connect(OnVisibleChanged)
	
	Menu.AddDisposalListener(function()
		Menu.VisibleChanged.Disconnect(OnVisibleChanged)
		Menu.DestroyCloseButton()
		
		-- Only destroy Layout and MenuFrame because
		-- it contains all the other UI components
		-- used to make the menu.
		Layout:Destroy()
		MenuFrame:Destroy()
		
		-- Then, garbage collect the GUI.
		MenuFrame, TitleLabel, HeaderLine, ContentFrame = nil, nil, nil, nil
	end)
	
	return Menu
end

return GridMenu