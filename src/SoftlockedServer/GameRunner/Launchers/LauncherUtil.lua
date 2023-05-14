-- The set of utility functions for the server launchers.
-- All game states will be handled under the same place file.
-- By udev2192

-- The name of the client package.
local CLIENT_PACKAGE_NAME = "SoftlockClient"

-- LaunchMode attribute name for the client package.
local CLIENT_MODE_ATTRIBUTE = "LaunchMode"

local Players = game:GetService("Players")
local ClientPackage = game:GetService("ServerStorage"):WaitForChild(CLIENT_PACKAGE_NAME)

local LauncherUtil = {}
LauncherUtil.ClientPackResettable = false

-- Initialize client package
ClientPackage.ResetOnSpawn = LauncherUtil.ClientPackResettable
ClientPackage.IgnoreGuiInset = true

function LauncherUtil.IsPlayer(Player)
	return typeof(Player) == "Instance" and Player:IsA("Player")
end

function LauncherUtil.IsPlayerInGame(Player)
	return LauncherUtil.IsPlayer(Player) and Player.Parent == Players
end

-- Sets the LaunchMode attribute of the client package
function LauncherUtil.SetLaunchMode(Mode)
	ClientPackage:SetAttribute(CLIENT_MODE_ATTRIBUTE, Mode)
end

-- Distributes the client package to the player instance provided.
function LauncherUtil.GiveClientPack(Player)
	if typeof(ClientPackage) == "Instance" then
		if LauncherUtil.IsPlayer(Player) == true then
			coroutine.wrap(function()
				local PlayerGui = Player:WaitForChild("PlayerGui")
				if typeof(PlayerGui) == "Instance" then
					local ClientPackClone = ClientPackage:Clone()
					if ClientPackClone:IsA("ScreenGui") then
						ClientPackClone.Parent = PlayerGui
					end

					ClientPackClone = nil
				end

				PlayerGui = nil
			end)()
		end
	end
end

-- Kicks all the players in the server.
function LauncherUtil.KickEveryone(Message)
	if typeof(Message) ~= "string" then
		Message = ""
	end
	
	for i, v in pairs(Players:GetPlayers()) do
		if LauncherUtil.IsPlayer(v) == true then
			v:Kick(Message)
		end
	end
end

return LauncherUtil