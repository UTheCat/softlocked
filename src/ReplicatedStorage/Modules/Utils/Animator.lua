-- A module for tweening instance properties
-- By udev2192

local TweenService = game:GetService("TweenService")

local Utils = script.Parent
local Object = require(Utils:WaitForChild("Object"))

local Animator = {}
Animator.__index = Animator

-- Constructor
function Animator.New(Inst)
	assert(typeof(Inst) == "Instance", "Argument 1 must be an Instance.")
	
	local Obj = Object.New("Animator")
	local CurrentTween = nil
	
	local function DestroyTween()
		if CurrentTween ~= nil then
			CurrentTween:Destroy()
		end
		CurrentTween = nil
	end
	
	-- The next instance to tween
	Obj.Instance = Inst
	
	-- The TweenInfo of the next tween
	Obj.TweenInfo = TweenInfo.new()
	
	-- Returns the currently playing tween.
	-- If nothing is tweening, nil is returned.
	function Obj.GetPlayingTween()
		return CurrentTween
	end
	
	-- Tweens to the specified properties
	function Obj.Tween(Properties)
		local Info = Obj.TweenInfo
		if Info ~= nil and Info.Time > 0 then
			DestroyTween()

			CurrentTween = TweenService:Create(Obj.Instance, Info, Properties)
			
			CurrentTween.Completed:Connect(function()
				-- This disconnects the .Completed connection
				-- because the instance will get destroyed
				DestroyTween()
			end)
			
			CurrentTween:Play()

			return CurrentTween
		end
		Info = nil
	end
	
	Obj.OnDisposal = function()
		DestroyTween()
	end
	
	return Obj
end

return Animator