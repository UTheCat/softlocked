--[[
NPC Dialogs as an interactive
]]--

local Interactives = script.Parent
local NPCDialogGui = require(
	Interactives.Parent.Parent
	:WaitForChild("Gui")
	:WaitForChild("Components")
	:WaitForChild("NpcDialog")
)
local BaseInteractive = require(Interactives.Parent:WaitForChild("BaseInteractive"))

local NPCDialog = {}
NPCDialog.__index = NPCDialog

function NPCDialog.New(Val: StringValue, MapLauncher: {})
	local Dialog = BaseInteractive.New()
	local Gui: NPCDialogGui
	local PromptStarter: ProximityPrompt
	
	function Dialog.OnStart()
		if Gui == nil then
			local ActionMap = require(Val:WaitForChild("Dialog"))

			Gui = NPCDialogGui.New()
			Gui.ActionMap = ActionMap
		end
	end
	
	function Dialog.OnShutdown()
		
	end
	
	--Dialog.OnStart.Connect(function()
		
	--end)
	
	--Dialog.OnShutdown.Connect(function()
		
	--end)
	
	return Dialog
end

return NPCDialog