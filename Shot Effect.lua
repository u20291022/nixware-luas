local ffi = require "ffi"
shotEffectColor = ui.add_color_edit('Shot Effect Color', 'shotEffectColor', false, color_t.new(255, 255, 255, 255))

ffi.cdef[[
    typedef struct { 
        float x,y,z; 
    } vec3_t; 
    
    struct BeamInfo_t {
        vec3_t position; 
		vec3_t angle;
		int entityIndex;
		const char* spriteName;
		float beamWidth;
		int beams;
		vec3_t color;
		float visibleTime;
		float radius;
    };
]]

drawBeam = ffi.cast('void(__thiscall*)(struct BeamInfo_t&)', client.find_pattern('client.dll', '55 8B EC 81 EC ? ? ? ? 56 57 8B F9 8B 47 18'))
client.register_callback('bullet_impact', function(event)
    local beamInfo = ffi.new('struct BeamInfo_t')
    beamInfo.position = { event:get_float('x', -1), event:get_float('y', -1), event:get_float('z', -1) }
    beamInfo.angle = { 0, 0, 0 }
    beamInfo.entityIndex = engine.get_local_player()
    beamInfo.spriteName = 'sprites/physbeam.vmt'
    beamInfo.beamWidth = 5
    beamInfo.beams = 10
    beamInfo.color = { shotEffectColor:get_value().r / 255.0, shotEffectColor:get_value().g / 255.0, shotEffectColor:get_value().b / 255.0 }
    beamInfo.visibleTime = 1
    beamInfo.radius = 10
    drawBeam(beamInfo)
end)