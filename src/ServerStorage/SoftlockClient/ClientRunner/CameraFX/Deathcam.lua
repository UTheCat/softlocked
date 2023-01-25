--[[
For binding a character's death to focusing on its head.

By udev2192
]]--

local WAIT_FOR_CHILD_YIELD = 5
local DEFAULT_START_OFFSET = Vector3.zero--Vector3.new(0, 0, 20)

local Focuscam = require(script.Parent:WaitForChild("Focuscam"))
local Camera = workspace.CurrentCamera

local Deathcam = {}

function Deathcam.New()
	local CamFX = Focuscam.New()
	local IsAlive = false
	local CurrentChar
	
	CamFX.Name = script.Name
	
	--[[
	The name of the character part to focus on.
	]]--
	CamFX.FocusedPartName = "Head"
	
	--[[
	The position offset from the focused part to start from.
	]]--
	CamFX.StartingOffset = DEFAULT_START_OFFSET
	
	-- Handler function for character death.
	local function OnDeath()
		if IsAlive then
			IsAlive = false
			
			local Character = CurrentChar.Parts.Character

			if Character ~= nil then
				local PartName = CamFX.FocusedPartName
				local PartToFocus = Character:WaitForChild(PartName, WAIT_FOR_CHILD_YIELD)

				if PartToFocus ~= nil then
					CamFX.ViewingPosition = (Camera.CFrame + CamFX.StartingOffset).Position
					CamFX.Enable(PartToFocus)
				end
			end
		end
	end
	
	local function OnRespawn()
		CamFX.Disable()
		IsAlive = true
	end
	
	--[[
	Unbinds a character adapter from being focused on.
	]]--
	function CamFX.Unbind()
		if CurrentChar ~= nil then
			CurrentChar.DeathEvent.Disconnect(OnDeath)
			CurrentChar.RespawnEvent.Disconnect(OnRespawn)
		end
		
		CurrentChar = nil
		IsAlive = false
	end
	
	--[[
	Binds a character adapter to be focused on.
	
	Params:
	Char <CharacterAdapter> - The CharacterAdapter to bind.
	]]--
	function CamFX.Bind(Char)
		assert(typeof(Char) == "table", "Argument 1 must be a CharacterAdapter.")
		
		-- Unbind to prevent problems with multiple bindings.
		CamFX.Unbind()
		
		-- Reconnect.
		CurrentChar = Char
		Char.DeathEvent.Connect(OnDeath)
		Char.RespawnEvent.Connect(OnRespawn)
		
		IsAlive = true
	end
	
	CamFX.AddDisposalListener(CamFX.Unbind)
	
	return CamFX
end

return Deathcam