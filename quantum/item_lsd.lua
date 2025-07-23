Quantum.LSD = {}
local LSD = Quantum.LSD
local game = Game()

function LSD:GetShaderParams(shaderName)
    if shaderName == 'quantum_LSD' then
		local params = { 
			Enabled = 1,--5 * math.sin(game:GetFrameCount() / (1.0 * 30.0)),
			Time = game:GetFrameCount() / 30.0
			}
		return params;
	end
end
Quantum:AddCallback(ModCallbacks.MC_GET_SHADER_PARAMS, LSD.GetShaderParams)