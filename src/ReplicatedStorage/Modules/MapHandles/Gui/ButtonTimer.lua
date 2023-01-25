--[[
remake of the button part of the GUIScript included in the JToH kit

original script written by Jukereise and Gammattor
remade by udev2192
]]--

local ButtonTimer = {}

ButtonTimer.Resources = {
	DefaultLayout = script:WaitForChild("DefaultLayout")
}

function ButtonTimer.DeattachGlobal()
	if _G.AttachTimer then
		_G.AttachTimer = nil
	end
end

function ButtonTimer.New(ScreenGui: ScreenGui)
	local Timer = {}
	local RunningTimers = {}
	local Frame = Instance.new("Frame")
	Frame.Name = "ButtonFrame"
	Frame.BackgroundTransparency = 1
	Frame.BorderSizePixel = 0
	Frame.AnchorPoint = Vector2.new(0.5, 0.5)
	Frame.Size = UDim2.new(1, 0, 1, 0)
	Frame.Position = UDim2.new(0.5, 0, 0.5, 0)

	local DefaultLayout = ButtonTimer.Resources.DefaultLayout:Clone()
	DefaultLayout.Name = "Layout"
	DefaultLayout.Parent = Frame

	DefaultLayout = nil

	Timer.Gui = Frame

	function Timer.Attach(Button: {}, Label: TextLabel?, Time: number?)
		Label = Label or Instance.new("TextLabel")
		local Color: Color3 = Button.Color
		
		Label.AnchorPoint = Vector2.new(0.5, 0.5)
		Label.Size = UDim2.new(1, 0, 1, 0)
		Label.Position = UDim2.new(0.5, 0, 0.5, 0)
		Label.BackgroundTransparency = 1
		Label.TextStrokeTransparency = 0
		Label.BorderSizePixel = 0
		Label.TextColor3 = Color
		Label.TextStrokeColor3 = Color3.new(1 - Color.r, 1 - Color.g, 1 - Color.b)
		Label.TextTransparency = 0
		Label.Font = Enum.Font.SourceSansBold
		Label.TextScaled = true
		Label.Parent = Frame
		
		local NewTimer = {}
		local RoundedTime = 0
		
		NewTimer.DestroyAtEnd = true
		NewTimer.Label = Label
		NewTimer.IsRunning = false
		NewTimer.TimeLeft = Time or 0
		
		function NewTimer.Dispose()
			NewTimer.IsRunning = false
			Label:Destroy()
			
			local Index = table.find(RunningTimers, NewTimer)
			
			if Index then
				table.remove(RunningTimers, Index)
			end
		end
		
		function NewTimer.Start()
			if NewTimer.IsRunning == false then
				NewTimer.IsRunning = true

				while NewTimer.IsRunning and NewTimer.TimeLeft > 0 do
					--local NewTime = math.max(NewTimer.TimeLeft - , 0)
					local Delta = task.wait()
					
					if NewTimer.IsRunning then
						local NewTime = math.max(NewTimer.TimeLeft - Delta, 0)
						NewTimer.TimeLeft = NewTime
						
						-- for optimization
						local NewRoundedTime = math.ceil(NewTime)
						if NewRoundedTime ~= RoundedTime then
							RoundedTime = NewRoundedTime
							Label.Text = NewRoundedTime
						end
					end
				end
				
				if NewTimer.DestroyAtEnd then
					NewTimer.Dispose()
				end
				
				if NewTimer.TimeLeft <= 0 then
					local OnFinish = NewTimer.OnFinish
					if OnFinish then
						OnFinish()
					end
				end
			end
		end
		
		table.insert(RunningTimers, NewTimer)
		
		return NewTimer
	end

	function Timer.AttachGlobal()
		function _G:AttachTimer(Button: {}, Label: TextLabel?)
			return Timer.Attach(Button, Label)
		end
	end

	function Timer.Dispose()
		Frame:Destroy()
		
		for i, v in pairs(RunningTimers) do
			v.Dispose()
		end
	end
	
	Frame.Parent = ScreenGui
	
	return Timer
end

return ButtonTimer