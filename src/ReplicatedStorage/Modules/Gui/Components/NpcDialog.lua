--[[
Displays a GUI that can be used to display an NPC dialog

By udev2192
]]--

local UIComponents = script.Parent

local BaseComponent = require(UIComponents:WaitForChild("BaseComponent"))
local IconButton = require(UIComponents:WaitForChild("IconButton"))

local UtilRepModules = UIComponents.Parent.Parent:WaitForChild("Utils")

local Signal = require(
	UtilRepModules
	:WaitForChild("Signal")
)

local Util = BaseComponent.GetUtils()
local TweenGroup = require(UtilRepModules:WaitForChild("TweenGroup"))

local NpcDialog = {}
NpcDialog.__index = NpcDialog

NpcDialog.ClassName = script.Name
NpcDialog.DefaultBackgroundColor = Color3.fromRGB(0, 0, 0)

--[[
<table> - Dialog context actions by string
]]--
NpcDialog.ContextActions = {
	Start = "Start",
	Continue = "...",
	SkipToEnd = "Skip to End",
	Close = "Leave"
}

--[[
<NpcDialog.TypeActions> - A list of typing actions for the grapheme animation
]]--
NpcDialog.TypeActions = {
	Write = 1,
	Wait = 2,
	Call = 3,
	SetOptions = 4
}

function NpcDialog.Lerp(a, b, t)
	return a + (b - a) * t
end

function NpcDialog.New()
	local Dialog = BaseComponent.New("Frame")
	local Gui = Dialog.Gui
	local Theme = Dialog.GetTheme()

	local CornerRadii = {}
	local DialogOptions = {}
	
	--local OptionButtons = {}
	--local OptionButtonEvents = {}

	-- [character #] = duration in seconds
	--local Delays = {}
	local CompiledActionMap = {}
	local ActionMapOptionIds = {}

	-- Names originally assigned to each option
	-- (order matters so the RemoveOption function works)
	local OptionButtonIds = {}

	local IsWritingGraphemes = false
	local IsUsingTextList = false
	local IsUsingActionMap = false
	local IsUsingContinueButton = false
	local IsFadingIn = false

	local DestinationGraphemeCount = 0
	local TotalMaxGraphemes = 0
	local TextListIndex = 0

	local CurrentTextList
	local DialogTextClickEvent
	local ActionMapFullString

	Dialog.FrameSize = UDim2.new(1, 0, 0.25, 0)
	Dialog.FramePosition = UDim2.new(0.5, 0, 0.75, 0)
	Dialog.HiddenSizeOffset = UDim2.new(-0.075, 0, -0.075, 0)
	Dialog.BackTransparency = 0.5
	Dialog.MinColumns = 5
	Dialog.OptionsPadding = UDim2.new(0.1, 0, 0.1, 0)
	Dialog.ClearWhenHidden = true
	
	--[[
	<string?> - The id of the last selected option
	]]--
	Dialog.LastAnswerId = nil

	Gui.Visible = false
	Gui.AnchorPoint = Vector2.new(0.5, 0.5)
	Gui.Size = Dialog.FrameSize
	Gui.Position = Dialog.FramePosition

	Gui.BackgroundColor3 = NpcDialog.DefaultBackgroundColor
	Gui.BackgroundTransparency = 1
	Gui.BorderSizePixel = 0
	Gui.Name = NpcDialog.ClassName

	BaseComponent.AddAspectRatio(Gui, 2.75)

	local DialogTextBG = Theme.MakeInstance("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0.63, 0, 1, 0),
		Position = UDim2.new(0.315, 0, 0.5, 0),

		BackgroundTransparency = 1,
		BackgroundColor3 = NpcDialog.DefaultBackgroundColor,
		BorderSizePixel = 0,

		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Text = "",

		AutoButtonColor = false,

		Parent = Gui
	})

	local OptionsFrame = Theme.MakeInstance("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0.33, 0, 1, 0),
		Position = UDim2.new(0.835, 0, 0.5, 0),

		BackgroundTransparency = 1,
		BackgroundColor3 = NpcDialog.DefaultBackgroundColor,
		BorderSizePixel = 0,

		Name = "OptionsFrame",

		Parent = Gui
	})

	local OptionsGridHandler = Theme.MakeInstance("UIGridLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,

		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,

		CellPadding = Dialog.OptionsPadding,
		CellSize = BaseComponent.GetGridItemSize(1, Dialog.MinColumns, Dialog.OptionsPadding),

		Parent = OptionsFrame
	})

	local DialogText = Theme.MakeInstance("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.9, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0),

		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,

		BorderSizePixel = 0,
		MaxVisibleGraphemes = 0,

		BackgroundTransparency = 1,
		TextStrokeTransparency = 1,
		TextTransparency = 1,

		Font = Enum.Font.Gotham,

		Parent = DialogTextBG
	})

	-- Extra rounded corners
	for i, v in pairs({DialogTextBG, OptionsFrame}) do
		table.insert(CornerRadii, BaseComponent.AddCornerRadius(v, Dialog.CornerRadius))
	end

	local function HideGui()
		Gui.Visible = false

		Gui.BackgroundTransparency = 1
		Gui.Size = Dialog.FrameSize + Dialog.HiddenSizeOffset
	end

	HideGui()

	--[[
	<number> - The scrolling speed of the dialog in
			   characters per second.
	]]--
	Dialog.ScrollSpeed = 30

	--[[
	<array> - An array of strings to type when scrolling
			  through the dialog. This is useful for
			  text-only dialogs, where the only option
			  is continuing to the next bit of text
	]]--
	Dialog.TextList = {}
	
	Dialog.CharacterTypeSound = script:WaitForChild("CharacterTypeSound")

	--[[
	<string> - The next string to display on the dialog
	]]--
	Dialog.SetProperty("NextString", "", function(NewString)
		TotalMaxGraphemes = string.len(NewString)
		DialogText.Text = NewString
	end)

	--[[
	<array> - The currently used action map. This is intended to be set
			  using values from Dialog.ActionMap
	]]--
	Dialog.SetProperty("CurrentActionMap", {}, function(Map: {{[number]: any}})
		DialogText.MaxVisibleGraphemes = 0
		DialogText.Text = ""
		ActionMapFullString = ""
		--Delays = {}
		CompiledActionMap = {}

		local Length = #Map

		if Length > 0 then
			local Write = NpcDialog.TypeActions.Write

			for i, v in ipairs(Map) do
				if v[1] == Write then
					local Str = v[2]
					ActionMapFullString ..= Str
					--elseif v[1] == Wait then
					--	table.insert(Delays, {NextString:len(), v[2]})
					--	ActionMapFullString ..= NextString
					--	NextString = ""
					table.insert(CompiledActionMap, {Write, Str:len()})
				else
					table.insert(CompiledActionMap, v)
				end
			end
		end
	end)
	
	--[[  
	<array>
	A list of actions for the npc dialog to iterate over using
	UseActionMap().
	
	An example usage of ActionMap would be:
	local CurrentDialog = NpcDialog.New()
	local Actions = NpcDialog.TypeActions
	CurrentDialog.ActionMap = {
		{Actions.Write, "Hello!"}
		{Actions.Wait, 0.5}
		{Actions.Write, " This is an example of a dialog with a delay."}
	}
	CurrentDialog.UseActionMap()
	]]--
	Dialog.SetProperty("ActionMap", {}, function(Map: {{[number]: any}})
		Dialog.CurrentActionMap = Map
	end)

	--[[
	Sets the corner radius of the components used by the dialog
	
	Params:
	Radius <UDim> - The radius dimensions to use.
	]]--
	function Dialog.SetCornerRadius(Radius)
		Dialog.CornerRadius = Radius
	end

	--[[
	Stops the typing "animation"
	]]--
	function Dialog.Pause()
		IsUsingActionMap = false
		IsWritingGraphemes = false
	end

	--[[
	Clears the NPC dialog text
	]]--
	function Dialog.Clear()
		DestinationGraphemeCount = 0
		DialogText.MaxVisibleGraphemes = 0
	end

	--local function RefreshOptionLayout()
	--	for i, v in ipairs(OptionButtons) do
	--		local Button = v.Button

	--		if Button then
	--			Button.Gui.LayoutOrder = i
	--		end
	--	end
	--end
	
	local function RemoveOptionByIndex(Index: number, Table: {})
		if Table == nil then
			Table = DialogOptions[Index]
			
			if Table == nil then
				return
			end
		end
		
		table.remove(DialogOptions, Index)
		
		Table.Connection:Disconnect()
		Table.Button.Dispose()
	end
	
	--[[
	Removes a dialog option and destroys it
	
	Params:
	Id <string> - The option's string identifier
	]]--
	function Dialog.RemoveOption(Id)
		assert(typeof(Id) == "string", "Argument 1 must be a string")
		
		for i, v in ipairs(DialogOptions) do
			if Id == v.Id then
				RemoveOptionByIndex(i, v)
				break
			end
		end

		--local Connection = OptionButtonEvents[Id]
		--if Connection then
		--	Connection:Disconnect()

		--	OptionButtonEvents[Id] = nil
		--	Connection = nil
		--end

		--local Index = table.find(OptionButtonIds, Id)
		----print(Name, 1)
		--if Index then
		--	--print(Name, 2)
		--	OptionButtons[Index].Dispose()

		--	table.remove(OptionButtons, Index)
		--	table.remove(OptionButtonIds, Index)
		--end
	end

	--[[
	Removes all currently stored options
	]]--
	function Dialog.ClearOptions()	
		--while #OptionButtonIds > 0 do
		--	Dialog.RemoveOption(OptionButtonIds[1])
		--end
		while #DialogOptions > 0 do
			RemoveOptionByIndex(1)
		end
	end

	--[[
	Creates a dialog option using an IconButton
	(Please use this in a synchronized thread since RemoveOption()
	might break if you don't)
	
	Params:
	Id <string> - An internal identifier for the option
	Name <string> - The option's name/text
	Order <number> (optional) - The order to place the button from top-left
								to bottom-right. If left unspecified, the
								button will be placed at the bottom-right
	
	Returns:
	<IconButton> - The button created
	]]--
	function Dialog.AddOption(Id: string, Name: string, Order: number?, Callback: () -> ()?)
		assert(typeof(Id) == "string", "Argument 1 must be a string")
		assert(typeof(Name) == "string", "Argument 2 must be a string")
		assert(Order == nil or typeof(Order) == "number", "Argument 3 must be a number or nil")
		assert(Callback == nil or typeof(Callback) == "function", "Argument 4 must be a function or nil")

		-- Important to check we're not creating
		-- a duplicate option to prevent problems with
		-- RemoveOption()
		--assert(table.find(OptionButtonIds, Id) == nil, "The option by the name of '" .. Name .. "' already exists")

		local Option = IconButton.New(Name)
		local IsClicked = false
		Option.AutoDestroyGui = true
		Option.CornerRadius = Dialog.CornerRadius
		
		local OptionTable = {
			Id = Id,
			Button = Option,
			Connection = Option.GetButton().Activated:Connect(function()
				if not IsClicked then
					IsClicked = true
					Dialog.LastAnswerId = Id
					Dialog.OptionSelected.Fire(Id)

					if Callback then
						Callback()
					end

					IsClicked = false
				end
			end)
		}
		
		if Order then
			table.insert(DialogOptions, Order, OptionTable)
		else
			table.insert(DialogOptions, OptionTable)
		end
		
		Option.Gui.Parent = OptionsFrame

		--if Order then
		--	table.insert(OptionButtonIds, Order, Id)
		--	table.insert(OptionButtons, Order, Option)
		--else
		--	table.insert(OptionButtonIds, Id)
		--	table.insert(OptionButtons, Option)
		--end
		
		-- For easy listener binding to Dialog.ActionRequested

		--RefreshOptionLayout()
		--Option.Gui.Parent = OptionsFrame

		return Option
	end
	
	--[[
	Hides the dialog options
	]]--
	function Dialog.HideOptions()
		for i, v in ipairs(DialogOptions) do
			local Button = v.Button

			if Button then
				Button.SetVisible(false)
			end
		end
	end
	
	--[[
	Shows the dialog options
	]]--
	function Dialog.ShowOptions()
		for i, v in ipairs(DialogOptions) do
			local Button = v.Button

			if Button then
				Button.Gui.LayoutOrder = i
				Button.SetVisible(true)
			end
		end
	end

	--[[
	Returns:
	<boolean> - If the typing animation is currently being played
	]]--
	function Dialog.IsTyping()
		return IsWritingGraphemes
	end

	--[[
	Returns:
	<number> - The current number of characters typed
	]]--
	function Dialog.GetCharactersTyped()
		return DialogText.MaxVisibleGraphemes
	end

	--[[
	Skips to the end of the typing sequence
	]]--
	function Dialog.FinishTyping()
		Dialog.Pause()
		DialogText.MaxVisibleGraphemes = TotalMaxGraphemes
	end

	--[[
	"Types" some text onto the dialog.
	
	Params:
	NumGraphemes <number> - The amount of graphemes to type next.
	]]--
	function Dialog.Type(NumGraphemes)
		assert(typeof(NumGraphemes) == "number", "Argument 1 must be a number.")

		local PromptedString = Dialog.NextString

		if PromptedString then
			DestinationGraphemeCount = math.floor(math.min(DestinationGraphemeCount + NumGraphemes, TotalMaxGraphemes))
		end

		if not IsWritingGraphemes then
			IsWritingGraphemes = true

			local CurrentGraphemes = DialogText.MaxVisibleGraphemes
			local CharTypeSound = Dialog.CharacterTypeSound

			while IsWritingGraphemes do
				local NextString = Dialog.NextString

				if NextString then
					CurrentGraphemes = math.min(
						math.ceil(CurrentGraphemes + (Dialog.ScrollSpeed * task.wait())),
						DestinationGraphemeCount
					)

					if IsWritingGraphemes then
						DialogText.MaxVisibleGraphemes = math.min(CurrentGraphemes, DestinationGraphemeCount)
						
						if CharTypeSound and CharTypeSound.IsLoaded == true and CharTypeSound.TimeLength > 0 then
							local Sound: Sound = CharTypeSound:Clone()
							Sound.Name = "Playing_" .. CharTypeSound.Name
							Sound.Looped = false
							Sound.Parent = script
							
							if Sound.IsLoaded then
								Sound:Play()
								Sound.Ended:Connect(function()
									Sound:Destroy()
									Sound = nil
								end)
							end
						end
					else
						break
					end

					if CurrentGraphemes >= DestinationGraphemeCount then
						break
					end
				else
					break
				end
			end

			IsWritingGraphemes = false
		end
	end
	
	local function ClearActionMapOptions()
		for i, v in pairs(ActionMapOptionIds) do
			Dialog.RemoveOption(v)
		end
		ActionMapOptionIds = {}
	end

	--[[
	Pauses the proceeding of the dialog
	specified by the ActionMap array
	]]--
	--function Dialog.StopActionMap()
	--	IsUsingActionMap = false
	--	Dialog.Pause()
	--end

	--[[
	Goes through the actions in the current ActionMap array
	]]--
	function Dialog.UseCurrentActionMap(ActionMap: {})
		ClearActionMapOptions()
		Dialog.Pause()
		
		Dialog.Clear()
		Dialog.NextString = ActionMapFullString

		-- Type, then wait if needed
		--local TypedChars = 0

		if #CompiledActionMap > 0 then
			IsUsingActionMap = true
			
			local TypeActions = NpcDialog.TypeActions
			local Write = TypeActions.Write
			local Wait = TypeActions.Wait
			local Call = TypeActions.Call
			local SetOptions = TypeActions.SetOptions
			TypeActions = nil

			--for i, v in ipairs(ActionMap) do
			--	local FirstNumChars = v[1]
			--	local Delay = v[2]

			--	TypedChars += FirstNumChars

			--	Dialog.Type(FirstNumChars)

			--	local Elapsed = 0
			--	while IsUsingActionMap and Elapsed <= Delay do
			--		Elapsed += task.wait()
			--	end

			--	if IsUsingActionMap == false then
			--		break
			--	end
			--end

			--if IsUsingActionMap and TypedChars < TotalMaxGraphemes then
			--	Dialog.Type(TotalMaxGraphemes - TypedChars)
			--end

			for i, v in ipairs(CompiledActionMap) do
				local Act = v[1]
				if Act == Write then
					Dialog.Type(v[2])
				elseif Act == Wait then
					local Delay = v[2]
					local Elapsed = 0
					
					while IsUsingActionMap and Elapsed <= Delay do
						Elapsed += task.wait()
					end
				elseif Act == Call then
					v[2]()
				elseif Act == SetOptions then
					Dialog.ClearOptions()
					
					--print("set options", #v[2])
					
					for i2, v2 in ipairs(v[2]) do
						local ActionMap = v2.ActionMap
						
						if ActionMap then
							local Id = v2.Id
							table.insert(ActionMapOptionIds, Id)
							Dialog.AddOption(Id, v2.Name, nil, function()
								Dialog.HideOptions()
								Dialog.CurrentActionMap = ActionMap
								Dialog.UseCurrentActionMap()
							end)
							--print("added action map:", Id, ", table size is now", #ActionMapOptionIds)
						end
					end
					
					if #DialogOptions > 0 then
						--print("try showing options")
						Dialog.ShowOptions()
					end
				end
				
				if IsUsingActionMap == false then
					ClearActionMapOptions()
					return
				end
			end
			
			IsUsingActionMap = false
		end
	end
	
	--[[
	Uses the master action map.
	See Dialog.ActionMap for details
	]]--
	function Dialog.UseActionMap()
		Dialog.Pause()
		Dialog.Clear()
		
		Dialog.CurrentActionMap = Dialog.ActionMap
		Dialog.UseCurrentActionMap()
	end

	local function OnTextListStep(Action)
		if Action == NpcDialog.ContextActions.Continue then
			if IsWritingGraphemes then
				Dialog.FinishTyping()
			else
				TextListIndex += 1

				if TextListIndex <= #CurrentTextList then
					Dialog.Pause()
					Dialog.Clear()
					Dialog.NextString = CurrentTextList[TextListIndex]
					Dialog.Type(TotalMaxGraphemes)
				else
					Dialog.StopTextList()
					Dialog.SetVisible(false)
				end
			end
		end
	end

	--[[
	Cancels the proceeding of the dialog
	specified by the TextList array
	]]--
	function Dialog.StopTextList()
		Dialog.ActionRequested.Disconnect(OnTextListStep)
		IsUsingTextList = false
	end

	--[[
	Goes through the text specified in the TextList property
	]]--
	function Dialog.UseTextList()
		local TextList = Dialog.TextList
		assert(typeof(TextList) == "table", "TextList property must be an array.")

		if IsUsingTextList == false and #TextList > 0 then
			IsUsingTextList = true

			TextListIndex = 0
			CurrentTextList = TextList

			Dialog.ActionRequested.Connect(OnTextListStep)
			Dialog.ActionRequested.Fire(NpcDialog.ContextActions.Continue)
		end
	end

	--[[
	Goes through 
	]]--

	--[[
	Returns:
	<TextLabel> - The text container used by the dialog
	]]--
	function Dialog.GetTextLabel()
		return DialogText
	end

	--[[
	<boolean> - If the continue button is enabled
	]]--
	Dialog.SetProperty("UseContinueButton", false, function(IsEnabled)
		if IsEnabled then
			if not IsUsingContinueButton then
				IsUsingContinueButton = true
				
				local Continue = NpcDialog.ContextActions.Continue
				Dialog.AddOption(Continue, Continue)
			end
		else
			if IsUsingContinueButton then
				Dialog.RemoveOption(NpcDialog.ContextActions.Continue)
				IsUsingContinueButton = false
			end
		end
	end)

	--[[
	<boolean> - If clicking the dialog text label finishes the typing
				animation and/or fires the "continue" action
	]]--
	Dialog.SetProperty("TapToFinishEnabled", false, function(IsEnabled)
		if IsEnabled then
			if not DialogTextClickEvent then
				local IsClicked = false

				DialogTextClickEvent = DialogTextBG.Activated:Connect(function()
					if not IsClicked then
						IsClicked = true

						if not IsUsingTextList then
							Dialog.FinishTyping()
						end

						Dialog.ActionRequested.Fire(NpcDialog.ContextActions.Continue)
						IsClicked = false
					end
				end)
			end
		else
			if DialogTextClickEvent then
				DialogTextClickEvent:Disconnect()
				DialogTextClickEvent = nil
			end
		end
	end)

	--[[
	Fired when a dialog action is requested
	
	Params:
	Action <string> - A numeric identifier used to determine which
					  action to use (see NpcDialog.ContextActions)
	]]--
	Dialog.ActionRequested = Signal.New()
	
	--[[
	Fired when a dialog option is selected
	
	Params:
	Id <string> - The option's string identifier
	]]--
	Dialog.OptionSelected = Signal.New()

	local function OnVisibleChanged(IsVisible)
		local NewTransparency
		local NewBgTransparency
		local NewSize

		if IsVisible then
			NewTransparency = 0
			NewBgTransparency = Dialog.BackTransparency
			NewSize = Dialog.FrameSize

			IsFadingIn = true
		else
			NewTransparency = 1
			NewBgTransparency = 1
			NewSize = Dialog.FrameSize + Dialog.HiddenSizeOffset

			IsFadingIn = false

			Dialog.ActionRequested.Fire(NpcDialog.ContextActions.Close)
			if Dialog.ClearWhenHidden then
				ClearActionMapOptions()
				Dialog.Pause()
				Dialog.Clear()
			end
		end

		-- To do: finish the look and animations lol
		local TweeningInfo = Dialog.TweeningInfo

		if IsVisible and IsFadingIn then
			Gui.Visible = true
		end

		if TweeningInfo then
			local BgFade = {
				BackgroundTransparency = NewBgTransparency
			}

			Util.Tween(Gui, TweeningInfo, {
				Size = NewSize,
			})

			Util.Tween(DialogTextBG, TweeningInfo, BgFade)
			Util.Tween(OptionsFrame, TweeningInfo, BgFade)

			--for i, v in pairs(OptionButtons) do
			--	task.spawn(v.SetVisible, IsVisible)
			--end
			Dialog.HideOptions()

			Util.Tween(DialogText, TweeningInfo, {
				TextTransparency = NewTransparency
			})

			task.wait(TweeningInfo.Time)
		end

		if IsVisible == false and IsFadingIn == false then
			HideGui()
		end
	end

	Dialog.VisibleChanged.Connect(OnVisibleChanged)
	Dialog.AddDisposalListener(function()
		Dialog.Pause()
		Dialog.Clear()
		Dialog.ClearOptions()
		
		Gui:Destroy()
	end)

	return Dialog
end

return NpcDialog