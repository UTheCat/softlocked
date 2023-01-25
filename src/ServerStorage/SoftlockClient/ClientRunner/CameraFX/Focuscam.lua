--[[
Creates a camera effect that focuses onto a certain part
through an animation.

By udev2192
]]--

local ZERO_VECTOR3 = Vector3.new(0, 0, 0)

local RunService = game:GetService("RunService")

local BaseCameraFX = require(script.Parent:WaitForChild("BaseCameraFX"))

local Camera = workspace.CurrentCamera

local Focuscam = {}

function Focuscam.New()
	local CamFX = BaseCameraFX.New()
	local IsFocused = false
	local FollowedPart
	local FollowConnection
	
	local DefaultFOV = Camera.FieldOfView
	
	CamFX.Name = script.Name
	
	--[[
	Sets if the calling Disable() resets the
	camera mode back to the provided defaults.
	]]--
	CamFX.ResetsCamera = false
	
	--[[
	The original camera mode to switch back to when
	Disable() is called.
	]]--
	CamFX.OriginalMode = Enum.CameraType.Custom
	
	--[[
	The original field-of-view to tween back to when Disable()
	is called.
	]]--
	CamFX.OriginalFov = DefaultFOV
	
	--[[
	The field-of-view to focus to when Enable() is called.
	]]--
	CamFX.FocusedFov = DefaultFOV
	
	--[[
	If focusing changes the field-of-view.
	]]--
	CamFX.ChangesFov = false
	
	--[[
	The position to look at a certain point from.
	]]--
	CamFX.ViewingPosition = ZERO_VECTOR3
	
	DefaultFOV = nil
	
	local function DisconnectRunner()
		if FollowConnection ~= nil then
			FollowConnection:Disconnect()
			FollowConnection = nil
		end
	end
	
	-- Sets the camera to adjust to look at the
	-- followed part's CFrame.
	local function UpdateForFrame()
		if FollowedPart ~= nil then
			CamFX.FollowedCFrame = CFrame.lookAt(CamFX.ViewingPosition, FollowedPart.Position)
		end
	end
	
	--[[
	Toggles the focus effect off and resets to
	camera defaults if told to do so.
	]]--
	function CamFX.Disable()
		DisconnectRunner()
		CamFX.StopFollowing()
		
		if CamFX.ResetsCamera == true then
			CamFX.TweenFOV(CamFX.OriginalFov)
			Camera.CameraType = CamFX.OriginalMode
		end
	end
	
	--[[
	Toggles the focus effect onto a certain part.
	
	Params:
	Part <variant> - Anything that has a .Position property.
	]]--
	function CamFX.Enable(Part)
		Camera.CameraType = Enum.CameraType.Scriptable
		
		DisconnectRunner()
		FollowedPart = Part
		UpdateForFrame()
		FollowConnection = RunService.Heartbeat:Connect(UpdateForFrame)
		
		CamFX.Follow()
		
		if CamFX.ChangesFov == true then
			CamFX.TweenFOV(CamFX.FocusedFov)
		end
	end
	
	CamFX.AddDisposalListener(CamFX.Disable)
	
	return CamFX
end

return Focuscam