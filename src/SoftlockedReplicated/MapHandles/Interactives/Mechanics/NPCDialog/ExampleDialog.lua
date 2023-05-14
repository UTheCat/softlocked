local TypeActions = require(
	game:GetService("ReplicatedStorage")
	:WaitForChild("SoftlockedReplicated")
	:WaitForChild("Gui")
	:WaitForChild("Components")
	:WaitForChild("NpcDialog")
).TypeActions

return {
	{TypeActions.Write, "The quick brown fox jumps over the lazy dog."},
	{TypeActions.Wait, 0.5},
	{TypeActions.Call, function()
		print("hi")
	end},
	{TypeActions.Write, " What would you like to do next?"},
	{TypeActions.SetOptions, {
		{
			Id = "OptionA1",
			Name = "Option A",
			ActionMap = {
				{TypeActions.Write, "You chose option A."},
				{TypeActions.Wait, 0.5},
				{TypeActions.Write, " Very well then, please proceed to do the first steps."},
			}
		},

		{
			Id = "OptionB1",
			Name = "Option B",
			ActionMap = {
				{TypeActions.Write, "You chose option B."},
				{TypeActions.Wait, 0.5},
				{TypeActions.Write, " Very well then, please proceed to do the second steps."},
			}
		},
	}
	},
}