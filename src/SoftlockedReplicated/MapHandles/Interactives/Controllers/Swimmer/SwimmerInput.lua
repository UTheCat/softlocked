-- A utility module that provides an object
-- for detecting swimmer client input.

-- THIS VERSION IS DEPRECATED, USE THE ONE IN REPLICATEDSTORAGE INSTEAD

-- By udev2192

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextAction = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local RepModules = ReplicatedStorage:WaitForChild("SoftlockedReplicated")
local UtilRepModules = RepModules:WaitForChild("Utils")

local Object = require(UtilRepModules:WaitForChild("Object"))
local Util = require(UtilRepModules:WaitForChild("Utility"))

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui", 25)
assert(typeof(PlayerGui) == "Instance", "The PlayerGui couldn't be found.")

local InputChangeConnection = nil
local Platform = nil -- The type of device the player is on.
local SwimmerInput = {}
local InputChangeFuncs = {}

local InputLockVals = {
	[true] = Enum.ContextActionResult.Sink,
	[false] = Enum.ContextActionResult.Pass
}

local FULL_RADIUS = UDim.new(1, 0)

local INPUT_IDS = {
	[Enum.UserInputType.Touch] = "Mobile",
	[Enum.UserInputType.Keyboard] = "PC",
	[Enum.UserInputType.Accelerometer] = "VR"
}

-- Returns the type of device the player is on
function SwimmerInput.GetPlatform(LastInput)
	LastInput = LastInput or UserInputService:GetLastInputType()

	if table.find(UserInputService:GetConnectedGamepads(), LastInput) then -- True if one of the gamepad slots are connected.
		return "Console"
	else
		return INPUT_IDS[LastInput] or "PC" -- Use the PC platform as a last result
	end
end

function SwimmerInput.ToggleInputChangeEvent(Enabled)
	if Enabled == true then
		InputChangeConnection = UserInputService.LastInputTypeChanged:Connect(function(Last)
			Platform = SwimmerInput.GetPlatform(Last)

			-- Fire any input change callbacks
			for i, v in pairs(InputChangeFuncs) do
				if typeof(v) == "function" then
					v()
				end
			end
		end)
	else
		if InputChangeConnection ~= nil then
			InputChangeConnection:Disconnect()
			InputChangeConnection = nil
		end
	end
end

local function AddARC(Gui, Ratio)
	assert(typeof(Gui) == "Instance", "Argument 1 must be an instance.")

	local Arc = Util.CreateInstance("UIAspectRatioConstraint", {
		DominantAxis = Enum.DominantAxis.Height,
		AspectRatio = Ratio or 1,
		Parent = Gui
	})

	return Arc
end

local function MakeCircular(Gui)
	assert(typeof(Gui) == "Instance", "Argument 1 must be an instance.")
	
	local Corner = Util.CreateInstance("UICorner", {
		CornerRadius = FULL_RADIUS,
		Parent = Gui
	})

	return Corner
end

-- For grabbing the mobile jump button located on a mobile screen
local function GetMobileJumpButton()
	-- Check to see if the player is on mobile (cause that should be the only time the jump button appears)
	if Platform == "Mobile" then
		local function WarnButtonMissing(Location)
			warn("The mobile jump button could not be found. The location of the jump button might have changed. The jump button failed to locate at: " .. tostring(Location))
		end

		-- Find the jump button and return it if found
		if PlayerGui then
			local JumpButton = PlayerGui:WaitForChild("TouchGui", 5)
			if JumpButton then
				JumpButton = JumpButton:WaitForChild("TouchControlFrame", 5)
				if JumpButton then
					JumpButton = JumpButton:WaitForChild("JumpButton", 5)
					if JumpButton and JumpButton:IsA("GuiButton") then
						if JumpButton:IsA("GuiButton") then
							return JumpButton
						else
							WarnButtonMissing(JumpButton:GetFullName() .. " (meaning the supposed object was found but however, it isn't a GuiButton).")
						end
					else
						WarnButtonMissing(JumpButton:GetFullName())
					end
				else
					WarnButtonMissing(JumpButton:GetFullName())
				end
			else
				WarnButtonMissing(JumpButton:GetFullName())
			end

			JumpButton = nil
		else
			WarnButtonMissing(PlayerGui:GetFullName())
		end

		-- Return nil if anything in the jump button path is missing
		WarnButtonMissing = nil
		return nil
	else
		return nil
	end
end

-- Initalize input.
Platform = SwimmerInput.GetPlatform()
SwimmerInput.ToggleInputChangeEvent(true)

-- Object constructor.
function SwimmerInput.New()
	local SwimInputEnabled = false

	local Connections = {}
	local GuiObjects = {}

	local Obj = Object.New("SwimmerInputHandler")
	Obj.Keybinds = {
		PC = {
			SwimUp = Enum.KeyCode.Space,
			SwimDown = Enum.KeyCode.LeftShift
		},

		Console = {
			SwimUp = Enum.KeyCode.ButtonA,
			SwimDown = Enum.KeyCode.ButtonB
		}
	}

	-- The mobile dive button.
	Obj.DiveButton = nil

	Obj.DiveButtonFont = Enum.Font.GothamBold
	Obj.DiveButtonText = "Dive"

	-- Keybinding priority for this object's input listener.
	Obj.KeybindPriority = 10000

	-- Sets if the ContextAction listener locks the input of the swim keybinds
	-- to itself.
	Obj.IsSinkingInput = false

	-- The most recent swimming direction.
	Obj.SwimDirection = nil

	local function DestroyInstances()
		for i, v in pairs(Connections) do
			if typeof(v) == "RBXScriptConnection" then
				v:Disconnect()
			end
		end

		for i, v in pairs(GuiObjects) do
			if typeof(v) == "Instance" then
				v:Destroy()
			end
		end
	end

	-- Returns true if the key specified is a swimming keybind
	local function IsSwimKey(Key)
		local Keys = Obj.Keybinds[Platform]
		if typeof(Keys) == "table" then
			for i2, v2 in pairs(Keys) do
				if Key == v2 then
					return true
				end
			end
		end
	end

	-- Internally handles swim input
	local function ChangeSwimDirection(Dir)
		Obj.SwimDirection = Dir
		Object.FireCallback(Obj.DirectionChanged, Dir)
	end
	
	-- Returns the vertical direction (up or down) as a string corresponding to the keys being pressed.
	local function GetCurrentSwimKey()
		for i, Platform in pairs(Obj.Keybinds) do
			if Platform ~= nil then
				local SwimUpKey = Platform.SwimUp
				local SwimDownKey = Platform.SwimDown

				if SwimUpKey ~= nil and SwimDownKey ~= nil then
					if UserInputService:IsKeyDown(SwimUpKey) then
						return "up"
					elseif UserInputService:IsKeyDown(SwimDownKey) then
						return "down"
					end
				end
			end
		end

		return nil -- Return nil if there is no swimming key (for a vertical direction) being held down
	end
	
	-- Internally handles swimming key presses
	local function HandleSwimKeybinds(InputName, InputState, InputObject) -- Used by ContextAction:BindActionAtPriority() inside Client.ToggleSwimming()
		-- Returning Enum.ContextActionResult.Sink prevents any other input receivers from getting that input
		local KeyCode = InputObject.KeyCode
		if IsSwimKey(KeyCode) then
			
			-- Determine whether to let input pass.
			local Result = InputLockVals[Obj.IsSinkingInput]
			
			-- Handle input.
			if InputState == Enum.UserInputState.Begin then
				-- Determine the direction to swim in based on the key press based on the input name
				if InputName == "SwimUpKeybinds" then
					ChangeSwimDirection("up")
				elseif InputName == "SwimDownKeybinds" then
					ChangeSwimDirection("down")
				else
					return Enum.ContextActionResult.Pass
				end
			elseif InputState == Enum.UserInputState.End then
				--if IsSwimKey(KeyCode) then -- Determine if it's a swimming keybind that was let go of
				--	-- Before setting the SwimDirection to nil, make sure the player is not trying to swim in another vertical direction (by checking if a key for the reverse direction is not being held)
				--	local SwimKey = GetCurrentSwimKey()
				--	if SwimKey == nil then
				--		ChangeSwimDirection(nil)
				--	else
				--		SwimKey = string.lower(tostring(SwimKey))
				--		if SwimKey == "up" then
				--			ChangeSwimDirection("up")
				--		elseif SwimKey == "down" then
				--			ChangeSwimDirection("down")
				--		end
				--	end
				--	SwimKey = nil
				--end
				
				return Enum.ContextActionResult.Pass
			else
				return Enum.ContextActionResult.Pass
			end
			
			return Result
		else
			return Enum.ContextActionResult.Pass
		end
	end
	
	-- For binding/connecting input for the user to swim up or down
	function Obj.ToggleSwimmingInput(Enabled)
		if Enabled == true then
			if SwimInputEnabled == true then
				-- Disconnect previous input event connections if found
				Obj.ToggleSwimmingInput(false)
			end

			SwimInputEnabled = true

			-- Handle input
			if Platform == "Mobile" then
				local function WarnButtonMissing()
					warn("The mobile jump button could not be found so you won't be able to swim up or down.")
				end

				-- Find the jump button
				if PlayerGui then
					local JumpButton = GetMobileJumpButton()
					if JumpButton and typeof(JumpButton) == "Instance" and JumpButton:IsA("GuiButton") then
						-- Connect swimming up to the jump button
						Connections["MobileSwimUp"] = JumpButton.MouseButton1Down:Connect(function(IsJumping)
							ChangeSwimDirection("up")
						end)

						Connections["MobileStopSwimmingUp"] = JumpButton.MouseButton1Up:Connect(function(IsJumping)
							if Obj.SwimDirection == "up" then
								ChangeSwimDirection(nil)
							end
						end)

						-- Connect swimming down to the dive button created here
						local Button = Util.CreateInstance("TextButton", {
							Size = JumpButton.Size,
							Position = JumpButton.Position - UDim2.new(0,0,JumpButton.Size.Y.Scale + 0.05,JumpButton.Size.Y.Offset), -- Make the dive button on top of the jump button
							Font = Obj.DiveButtonFont or Enum.Font.SourceSansBold,
							TextScaled = true,
							TextColor3 = Color3.new(1,1,1),
							TextTransparency = 0.75,
							Text = Obj.DiveButtonText or "",
							BackgroundColor3 = Color3.new(0,0,0),
							BorderSizePixel = 0,
							BackgroundTransparency = 0.5
						})

						AddARC(Button, 1)
						MakeCircular(Button)

						-- Connect the diving event and load the button
						GuiObjects.DiveButton = Button
						if GuiObjects.DiveButton ~= nil then -- Just in case
							Connections["MobileSwimDown"] = Button.MouseButton1Down:Connect(function() -- To swim down
								ChangeSwimDirection("down")
							end)
							Connections["MobileStopSwimmingDown"] = Button.MouseButton1Up:Connect(function() -- To stop swimming down
								if Obj.SwimDirection == "down" then
									ChangeSwimDirection(nil)
								end
							end)
							Button.Parent = JumpButton.Parent
						end

						Button = nil
					end

					JumpButton = nil
				end

				WarnButtonMissing = nil
			else

				-- Provide a connection (for those not on mobile) to stop swimming in a vertical direction.
				-- This is used to fix a jumping bug.
				Connections["StopSwimmingVertically"] = UserInputService.InputEnded:Connect(function(Input)
					local KeyCode = Input.KeyCode
					
					if Input.UserInputState == Enum.UserInputState.End and IsSwimKey(KeyCode) then -- Determine if it's a swimming keybind that was let go of
						-- Before setting the SwimDirection to nil, make sure the player is not trying to swim in another vertical direction (by checking if a key for the reverse direction is not being held)
						local SwimKey = GetCurrentSwimKey()
						if SwimKey == nil then
							ChangeSwimDirection(nil)
						else
							SwimKey = string.lower(tostring(SwimKey))
							if SwimKey == "up" then
								ChangeSwimDirection("up")
							elseif SwimKey == "down" then
								ChangeSwimDirection("down")
							end
						end
						SwimKey = nil
					end
					
					KeyCode = nil
				end)

				-- Bind input for swimming vertically
				local Keybinds = Obj.Keybinds
				if Keybinds ~= nil then
					ContextAction:BindActionAtPriority("SwimDownKeybinds", HandleSwimKeybinds, false, Obj.KeybindPriority, Keybinds.PC.SwimDown, Keybinds.Console.SwimDown)
					ContextAction:BindActionAtPriority("SwimUpKeybinds", HandleSwimKeybinds, false, Obj.KeybindPriority, Keybinds.PC.SwimUp, Keybinds.Console.SwimUp)
				end
				Keybinds = nil
			end
		else
			SwimInputEnabled = false

			-- Disconnect and destroy ways of input used for swimming (if the player is no longer in any water)
			DestroyInstances()

			ContextAction:UnbindAction("SwimDownKeybind")
			ContextAction:UnbindAction("SwimUpKeybind")
		end
	end

	-- Disconnect and destroy everything on disposal.
	Obj.OnDisposal = function()
		InputChangeFuncs[Obj] = nil
		Obj.ToggleSwimmingInput(false)

		DestroyInstances()

		Connections = nil
		GuiObjects = nil
	end

	-- Invoked when a swimming input direction is received.
	-- Parameters:
	-- Direction - Either: "up", "down", or nil
	Obj.DirectionChanged = nil

	InputChangeFuncs[Obj] = function()
		Obj.ToggleSwimmingInput(SwimInputEnabled)
	end

	return Obj
end

return SwimmerInput