--[[
Provides a GUI-based structure that can hold multiple instances of the GridMenu.

In other words, this makes sets of menus much easier to handle. This is because
it makes sure only one gui frame is displayed at a time.

By udev2192
]]--

local BaseComponent = require(script.Parent:WaitForChild("BaseComponent"))

local MenuSet = {}
MenuSet.__index = MenuSet
MenuSet.ClassName = script.Name
MenuSet.GuiClassName = "Frame"

local function AssertString(ArgNum, String)
	assert(typeof(String) == "string", "Argument " .. ArgNum .. " must be a string.")
end

function MenuSet.New()
	local Set = BaseComponent.New(MenuSet.GuiClassName)
	local Gui = Set.Gui
	
	Gui.Name = MenuSet.ClassName
	Gui.ClipsDescendants = false
	Gui.BackgroundTransparency = 1
	
	-- Stored gui components
	local Stored = {}
	local Listeners = {}
	
	-- Shown gui ids
	local Shown = {}
	
	--[[
	<boolean> - Whether or not to limit the frames shown at a certain time
				to 1.
	]]--
	Set.SingleFrameOnly = true
	
	--[[
	<string> - The string identifier of the
			   menu being shown.
			   If none are being shown,
			   this field is nil.
	]]--
	Set.ShownId = nil
	
	--[[
	<Vector2> - A specific anchor point to enforce.
			  	Leave this value as nil to not enforce this.
	]]--
	Set.GuiAnchorPoint = Vector2.new(0.5, 0.5)
	
	--[[
	<UDim2> - A specific GUI size to enforce.
			  Leave this value as nil to not enforce this.
	]]--
	Set.GuiSize = UDim2.new(1, 0, 1, 0)
	
	--[[
	<UDim2> - A specific GUI position to enforce.
			  Leave this value as nil to not enforce this.
	]]--
	Set.GuiPosition = UDim2.new(0.5, 0, 0.5, 0)
	
	--[[
	Params:
	<string> - The string identifier that refers to the menu
			   requesting to be hidden.
	]]--
	function Set.Hide(Name)
		local Component = Stored[Name]

		if Component ~= nil then
			Set.ShownId = nil

			local ShowIndex = table.find(Shown, Name)
			if ShowIndex ~= nil then
				table.remove(Shown, ShowIndex)
			end

			Component.SetVisible(false)
		end
	end

	--[[
	Hides all of the currently shown menus.
	]]--
	function Set.HideAll()
		for i, v in pairs(Shown) do
			Set.ShownId = nil
			Set.Hide(v)
		end
	end

	--[[
	Params:
	<string> - The string identifier that refers to the menu
			   requesting to be shown.
	]]--
	function Set.Show(Name)
		local Component = Stored[Name]

		if Component ~= nil then
			-- Hide the previous
			if Set.SingleFrameOnly == true then
				local LastId = Set.ShownId
				if LastId ~= nil then
					Set.Hide(LastId)
				end
			end

			-- Show the current
			table.insert(Shown, Name)
			Set.ShownId = Name
			Component.SetVisible(true)
		end
	end
	
	--[[
	Removes a component from the set.
	
	Params:
	<string> - The string identifier that refers
			   to the component being removed.
	]]--
	function Set.Remove(Name)
		Stored[Name] = nil
		
		local Connection = Listeners[Name]
		if Connection ~= nil then
			Connection:Disconnect()
			Listeners[Name] = nil
			Connection = nil
		end
	end
	
	--[[
	Adds a component to the set. The specified
	component will get reparented to the gui set's frame.
	
	Params:
	<string> - The string identifier for the gui.
	<BaseComponent> - The component itself.
	]]--
	function Set.Add(Name, NewGui)
		AssertString(1, Name)
		assert(typeof(NewGui) == "table" and NewGui.SetVisible ~= nil, "Argument 2 must be a BaseComponent.")
		
		Stored[Name] = NewGui
		
		local CloseButton = NewGui.CloseButton
		if CloseButton ~= nil then
			Listeners[Name] = CloseButton.GetButton().Activated:Connect(function()
				Set.Hide(Name)
			end)
		end
		
		local ActualGui = NewGui.Gui
		if ActualGui ~= nil then
			local Anchor = Set.GuiAnchorPoint
			local Size = Set.GuiSize
			local Pos = Set.GuiPosition
			
			if Anchor ~= nil then
				ActualGui.AnchorPoint = Anchor
			end
			if Size ~= nil then
				ActualGui.Size = Size
			end
			if Pos ~= nil then
				ActualGui.Position = Pos
			end
			
			ActualGui.Parent = Gui
		end
	end
	
	Set.AddDisposalListener(Set.HideAll)
	
	return Set
end

return MenuSet