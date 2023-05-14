-- Provides an object that shows a death screen.
-- By udev2192

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RepModules = ReplicatedStorage:WaitForChild("Modules")
local Adapters = RepModules:WaitForChild("Adapters")
local UtilRepModules = RepModules:WaitForChild("Utils")

local ClientRunner = script.Parent

local BlurScreen = require(ClientRunner:WaitForChild("BlurScreen"))
local Runtime = require(UtilRepModules:WaitForChild("Runtime"))

local DeathFX = {}

local CHAR_ADAPTER_CLASS_NAME = "CharacterAdapter"

function DeathFX.New(ObjCharAdapter: CharacterAdapter)
	assert(typeof(ObjCharAdapter) == "table" and ObjCharAdapter.TypeName == CHAR_ADAPTER_CLASS_NAME, "Argument 1 must be a CharacterAdapter.")
	
	local Obj = BlurScreen.New()
	Obj.Name = "DeathFX"
	
	-- If the death screen will flash on death.
	Obj.Enabled = true
	
	-- Internal callback connections
	local function OnDeath()
		if Obj.Enabled == true then
			Runtime.WaitForDur(Obj.FadeInAfter)
			Obj.FadeIn()
		end
	end
	
	ObjCharAdapter.DeathEvent.Connect(OnDeath)
	ObjCharAdapter.RespawnEvent.Connect(Obj.FadeOut)

	Obj.AddDisposalListener(function()
		ObjCharAdapter.DeathEvent.Disconnect(OnDeath)
		ObjCharAdapter.RespawnEvent.Disconnect(Obj.FadeOut)
	end)
	
	return Obj
end

return DeathFX