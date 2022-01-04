local ffi = require "ffi"
ffi.cdef[[
    typedef struct _vec3_t {
        float x, y, z;
    } vec3_t;

    typedef struct _beam_info_t {
        int      m_type;
        void* m_start_ent;
        int      m_start_attachment;
        void* m_end_ent;
        int      m_end_attachment;
        vec3_t    m_start;
        vec3_t    m_end;
        int      m_model_index;
        const char  *m_model_name;
        int      m_halo_index;
        const char  *m_halo_name;
        float    m_halo_scale;
        float    m_life;
        float    m_width;
        float    m_end_width;
        float    m_fade_length;
        float    m_amplitude;
        float    m_brightness;
        float    m_speed;
        int      m_start_frame;
        float    m_frame_rate;
        float    m_red;
        float    m_green;
        float    m_blue;
        bool    m_renderable;
        int      m_num_segments;
        int      m_flags;
        vec3_t    m_center;
        float    m_start_radius;
        float    m_end_radius;
    } beam_info_t;
]]

local local_color = ui.add_color_edit('Local Color', 'local_color', true, color_t.new(255, 255, 255, 255))
local enemy_color = ui.add_color_edit('Enemy Color', 'enemy_color', true, color_t.new(255, 255, 255, 255))
local team_color  = ui.add_color_edit('Team Color',  'team_color', true, color_t.new(255, 255, 255, 255))
local visible     = ui.add_multi_combo_box('Show', 'visible_tracers', { 'Local', 'Enemy', 'Team' }, { false, false, false })
local beam_type   = ui.add_combo_box('Beam Type', 'shots_beam_type', { 'Purple Laser', 'Phys Beam', 'Radio', 'Light Glow' }, 0)

local match = client.find_pattern("client.dll", "B9 ? ? ? ? A1 ? ? ? ? FF 10 A1 ? ? ? ? B9")
local render_beams = ffi.cast('void**', ffi.cast("char*", match) + 1)[0] or error("render_beams is nil")
local render_beams_class = ffi.cast("void***", render_beams)
local render_beams_vtbl = render_beams_class[0]

local draw_beams_t = ffi.typeof("void(__thiscall*)(void*, void*)")
local create_beam_points_t = ffi.typeof("void*(__thiscall*)(void*, beam_info_t&)")

local draw_beams = ffi.cast(draw_beams_t, render_beams_vtbl[6]) or error("couldn't cast draw_beams_t", 2)
local create_beam_points = ffi.cast(create_beam_points_t, render_beams_vtbl[12]) or error("couldn't cast create_beam_points_t", 2)

local materials = {
    "sprites/purplelaser1.vmt",
    "sprites/physbeam.vmt",
    "sprites/radio.vmt",
    "sprites/light_glow02.vmt"
}

local beams_flag = bit32.bor(0x00000100, 0x00000200, 0x00008000)
local function create_beam(start, endpos, clr)
    local beam_info = ffi.new("beam_info_t")
    
    beam_info.m_flags = beams_flag
    beam_info.m_start = start
    beam_info.m_end = endpos
    beam_info.m_width = 2
    beam_info.m_end_width = 2
    beam_info.m_model_name = materials[beam_type:get_value() + 1]
    beam_info.m_red = clr[1] 
    beam_info.m_green = clr[2]
    beam_info.m_blue = clr[3]
    beam_info.m_brightness = clr[4]

    beam_info.m_type = 0
    beam_info.m_model_index = -1
    beam_info.m_halo_scale = 0
    beam_info.m_life = 2
    beam_info.m_fade_length = 1
    beam_info.m_amplitude = 2.3
    beam_info.m_speed = 0.6
    beam_info.m_start_frame = 0
    beam_info.m_frame_rate = 0
    beam_info.m_num_segments = 2
    beam_info.m_renderable = true

    local beam = create_beam_points(render_beams_class, beam_info) 
    if beam ~= nil then 
        draw_beams(render_beams, beam)
    end
end

local function get_eye_pos(player)
    local originOffset = se.get_netvar('DT_BaseEntity', 'm_vecOrigin')
    local viewOffset = 0x108
    local playerOrigin = player:get_prop_vector( originOffset )
    local playerView   = player:get_prop_vector( viewOffset )
    local playerEyePos = vec3_t.new( playerOrigin.x + playerView.x, playerOrigin.y + playerView.y, playerOrigin.z + playerView.z )
    return playerEyePos
end

local team_offset = se.get_netvar( 'DT_BaseEntity', "m_iTeamNum" )
client.register_callback('bullet_impact', function (event)
    local event_player = entitylist.get_entity_by_index(engine.get_player_for_user_id(event:get_int("userid", -1)))
    local local_team = entitylist.get_local_player():get_prop_int(team_offset)
    local event_player_team = event_player:get_prop_int(team_offset)
    local bullet_impact_pos = { event:get_float('x', 0), event:get_float('y', 0), event:get_float('z', 0) }
    local eye_pos = get_eye_pos( event_player )

    if local_team == event_player_team and event_player:get_index() ~= engine.get_local_player() and visible:get_value(2) then
        local color = team_color:get_value()
        if bullet_impact_pos[1] ~= 0 and bullet_impact_pos[2] ~= 0 and bullet_impact_pos[3] ~= 0 then
            create_beam( { eye_pos.x, eye_pos.y, eye_pos.z }, bullet_impact_pos, { color.r, color.g, color.b, color.a } )
        end
    end

    if local_team ~= event_player_team and visible:get_value(1) then
        local color = enemy_color:get_value()
        if bullet_impact_pos[1] ~= 0 and bullet_impact_pos[2] ~= 0 and bullet_impact_pos[3] ~= 0 then
            create_beam( { eye_pos.x, eye_pos.y, eye_pos.z }, bullet_impact_pos, { color.r, color.g, color.b, color.a } )
        end
    end

    if engine.get_local_player() == event_player:get_index() and visible:get_value(0) then
        local color = local_color:get_value()
        if bullet_impact_pos[1] ~= 0 and bullet_impact_pos[2] ~= 0 and bullet_impact_pos[3] ~= 0 then
            create_beam( { eye_pos.x, eye_pos.y, eye_pos.z }, bullet_impact_pos, { color.r, color.g, color.b, color.a } )
        end
    end

end)