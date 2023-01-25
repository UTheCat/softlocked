local smooth = script.Parent:WaitForChild("Smooth")
if smooth.Value then
	require(script.NoclipScriptSmoothOn)()
else
	require(script.NoclipScriptSmoothOff)()
end