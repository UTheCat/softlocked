--[[
Provides a class that can be utilized to create effects
with the camera.

By udev2192
]]--

local ZERO_CFRAME = CFrame.new(0, 0, 0)
local DEFAULT_TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local FOLLOW_ID_PREFIX = "CameraFxFollowingId_"

local RunService = game:GetService("RunService")

local RepModules = game:GetService("ReplicatedStorage"):WaitForChild("SoftlockedReplicated")
local UtilRepModules = RepModules:WaitForChild("Utils")

local Object = require(UtilRepModules:WaitForChild("Object"))
local Signal = require(UtilRepModules:WaitForChild("Signal"))
local Util = require(UtilRepModules:WaitForChild("Utility"))

RepModules, UtilRepModules = nil, nil

-- Function pointer
local Lerp = Util.Lerp

local Camera = workspace.CurrentCamera

-- The rendering priority of the camera.
local CameraPriority = Enum.RenderPriority.Camera.Value

local BaseCameraFX = {}
BaseCameraFX.__index = BaseCameraFX

function BaseCameraFX.New()
	local Obj = Object.New("BaseCameraFX")
	local LastCFrame

	-- Name of the camera rendering priority for this instance.
	local RenderIndex = FOLLOW_ID_PREFIX .. os.clock()

	-- Tweening info used for field-of-view changes.
	Obj.FOVTweeningInfo = DEFAULT_TWEEN_INFO

	-- Destination CFrame for animation.
	Obj.FollowedCFrame = ZERO_CFRAME

	--[[
	The number used to multiply the difference between the current
	CFrame and the destination CFrame on every frame.
	In order to go towards the destination, this number must be
	less than 1.
	]]--
	Obj.OffsetScale = 0

	-- Called every camera render step to follow a moving object.
	local function FollowCFrameForStep(Delta)
		local Destination = Obj.FollowedCFrame
		local Scale = Obj.OffsetScale

		--if LastCFrame ~= nil then
			LastCFrame = Camera.CFrame
		--end

		if Destination ~= nil and LastCFrame ~= nil then
			if Scale > 0 then
				-- Ease via a "lerp".
				-- The goal is inversed to be able to
				-- lerp towards the Camera's CFrame
				Camera.CFrame = Destination:Lerp(LastCFrame, Scale * Delta)

				-- Set a beginning point so we can grab
				-- the previous CFrame later
				--LastCFrame = Camera.CFrame
			else
				-- Immediately set.
				Camera.CFrame = Destination
			end
		end
	end

	--[[
	Returns:
	
	<string>: The BindToRenderStep() string identifier used to
			  bind the camera follow function to happen after
			  camera following.
	]]--
	function Obj.GetRenderIndex()
		return RenderIndex
	end

	--[[
	Animates the camera to a new field of view.
	
	Params:
	NewFOV <number> - The field-of-view to animate to.
	]]--
	function Obj.TweenFOV(NewFOV)
		Util.Tween(Camera, Obj.FOVTweeningInfo, {FieldOfView = NewFOV})
	end

	--[[
	Stops the following of a moving object.
	]]--
	function Obj.StopFollowing()
		RunService:UnbindFromRenderStep(RenderIndex)
		LastCFrame = nil
	end

	--[[
	Makes the camera follow the CFrame under FollowedCFrame.
	]]--
	function Obj.Follow()
		FollowCFrameForStep(0)
		RunService:BindToRenderStep(RenderIndex, CameraPriority + 1, FollowCFrameForStep)
	end

	return Obj
end

return BaseCameraFX