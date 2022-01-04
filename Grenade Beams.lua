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

local he_grenades_color         = ui.add_color_edit('HE Grenades Color', 'he_grenades_color', true, color_t.new(255, 255, 255, 255))
local smoke_grenades_color      = ui.add_color_edit('Smoke Grenades Color', 'smoke_grenades_color', true, color_t.new(255, 255, 255, 255))
local molotov_grenades_color    = ui.add_color_edit('Molotov Grenades Color', 'molotov_grenades_color', true, color_t.new(255, 255, 255, 255))
local visible                   = ui.add_multi_combo_box('Show', 'visible_grenades', { 'HE', 'Smoke', 'Molotov' }, { false, false, false })
local beam_type                 = ui.add_combo_box('Beam Type', 'grenades_beam_type', { 'Purple Laser', 'Phys Beam', 'Radio', 'Light Glow' }, 0)

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
    beam_info.m_life = 0.06
    beam_info.m_fade_length = 1
    beam_info.m_amplitude = 2.3
    beam_info.m_speed = 0.2
    beam_info.m_start_frame = 0
    beam_info.m_frame_rate = 0
    beam_info.m_num_segments = 2
    beam_info.m_renderable = true

    local beam = create_beam_points(render_beams_class, beam_info) 
    if beam ~= nil then 
        draw_beams(render_beams, beam)
    end
end

local origin_offset = se.get_netvar('DT_BaseEntity', 'm_vecOrigin')
local he_grenades_table = {}
client.register_callback('paint', function ()
    local he_grenades = entitylist.get_entities_by_class( 'CBaseCSGrenadeProjectile' )

    if not engine.is_connected() then
        for i = 1, #he_grenades_table do
            he_grenades_table[i] = nil
        end
    end

    if not visible:get_value(0) then
        return
    end

    for i = 1, #he_grenades do
        local grenade = he_grenades[i]
        local grenade_origin = grenade:get_prop_vector( origin_offset )
        local grenade_spawn_time = grenade:get_prop_float( 0x20 )

        if grenade_spawn_time == 0 and he_grenades_table[grenade:get_index()] and he_grenades_table[grenade:get_index()].rendered then
            he_grenades_table[grenade:get_index()] = nil
        end

        if not he_grenades_table[grenade:get_index()] then
            he_grenades_table[grenade:get_index()] = {}
            he_grenades_table[grenade:get_index()].origins = {}
            he_grenades_table[grenade:get_index()].rendered = false
            he_grenades_table[grenade:get_index()].prev_position = nil
            he_grenades_table[grenade:get_index()].prev_position_bool = false
        end

        if he_grenades_table[grenade:get_index()].prev_position ~= nil
        and he_grenades_table[grenade:get_index()].prev_position.x - grenade_origin.x == 0
        and he_grenades_table[grenade:get_index()].prev_position.y - grenade_origin.y == 0
        and he_grenades_table[grenade:get_index()].prev_position.z - grenade_origin.z == 0
        then
            if he_grenades_table[grenade:get_index()].prev_position_bool then
                he_grenades_table[grenade:get_index()].rendered = true
            end
            he_grenades_table[grenade:get_index()].prev_position_bool = true
        else
            he_grenades_table[grenade:get_index()].prev_position_bool = false
        end

        if he_grenades_table[grenade:get_index()] ~= nil and not he_grenades_table[grenade:get_index()].rendered then
            table.insert( he_grenades_table[grenade:get_index()].origins, grenade_origin )  
            for j = 1, #he_grenades_table[grenade:get_index()].origins do
                if j > 1 and j ~= #he_grenades_table[grenade:get_index()].origins then
                    local start_pos = he_grenades_table[grenade:get_index()].origins[j - 1]
                    local end_pos   = he_grenades_table[grenade:get_index()].origins[j]
                    local color     = he_grenades_color:get_value()
                    create_beam(
                        { start_pos.x, start_pos.y, start_pos.z },
                        { end_pos.x, end_pos.y, end_pos.z },
                        { color.r, color.g, color.b, color.a }
                    )
                end
            end
        end

        he_grenades_table[grenade:get_index()].prev_position = grenade_origin
    end
end)

local smoke_grenades_table = {}
client.register_callback('paint', function ()
    local smoke_grenades = entitylist.get_entities_by_class( 'CSmokeGrenadeProjectile' )

    if not engine.is_connected() then
        for i = 1, #smoke_grenades_table do
            smoke_grenades_table[i] = nil
        end
    end

    if not visible:get_value(1) then
        return
    end

    for i = 1, #smoke_grenades do
        local grenade = smoke_grenades[i]
        local grenade_origin = grenade:get_prop_vector( origin_offset )
        local grenade_spawn_time = grenade:get_prop_float( 0x20 )

        if grenade_spawn_time == 0 and smoke_grenades_table[grenade:get_index()] and smoke_grenades_table[grenade:get_index()].rendered then
            smoke_grenades_table[grenade:get_index()] = nil
        end

        if not smoke_grenades_table[grenade:get_index()] then
            smoke_grenades_table[grenade:get_index()] = {}
            smoke_grenades_table[grenade:get_index()].origins = {}
            smoke_grenades_table[grenade:get_index()].rendered = false
            smoke_grenades_table[grenade:get_index()].prev_position = nil
            smoke_grenades_table[grenade:get_index()].prev_position_bool = false
        end

        if smoke_grenades_table[grenade:get_index()].prev_position ~= nil
        and smoke_grenades_table[grenade:get_index()].prev_position.x - grenade_origin.x == 0
        and smoke_grenades_table[grenade:get_index()].prev_position.y - grenade_origin.y == 0
        and smoke_grenades_table[grenade:get_index()].prev_position.z - grenade_origin.z == 0
        then
            if smoke_grenades_table[grenade:get_index()].prev_position_bool then
                smoke_grenades_table[grenade:get_index()].rendered = true
            end
            smoke_grenades_table[grenade:get_index()].prev_position_bool = true
        else
            smoke_grenades_table[grenade:get_index()].prev_position_bool = false
        end

        if smoke_grenades_table[grenade:get_index()] ~= nil and not smoke_grenades_table[grenade:get_index()].rendered then
            table.insert( smoke_grenades_table[grenade:get_index()].origins, grenade_origin )  
            for j = 1, #smoke_grenades_table[grenade:get_index()].origins do
                if j > 1 and j ~= #smoke_grenades_table[grenade:get_index()].origins then
                    local start_pos = smoke_grenades_table[grenade:get_index()].origins[j - 1]
                    local end_pos   = smoke_grenades_table[grenade:get_index()].origins[j]
                    local color     = smoke_grenades_color:get_value()
                    create_beam(
                        { start_pos.x, start_pos.y, start_pos.z },
                        { end_pos.x, end_pos.y, end_pos.z },
                        { color.r, color.g, color.b, color.a }
                    )
                end
            end
        end

        smoke_grenades_table[grenade:get_index()].prev_position = grenade_origin
    end
end)

local molotov_grenades_table = {}
client.register_callback('paint', function ()
    local molotov_grenades  = entitylist.get_entities_by_class( 'CMolotovProjectile' )

    if not engine.is_connected() then
        for i = 1, #molotov_grenades_table do
            molotov_grenades_table[i] = nil
        end
    end

    if not visible:get_value(2) then
        return
    end

    for i = 1, #molotov_grenades do
        local grenade = molotov_grenades[i]
        local grenade_origin = grenade:get_prop_vector( origin_offset )
        local grenade_spawn_time = grenade:get_prop_float( 0x20 )

        if molotov_grenades_table[grenade:get_index()] and grenade_spawn_time - molotov_grenades_table[grenade:get_index()].spawn_time > 2 then
            molotov_grenades_table[grenade:get_index()] = nil
        end

        if not molotov_grenades_table[grenade:get_index()] then
            molotov_grenades_table[grenade:get_index()] = {}
            molotov_grenades_table[grenade:get_index()].origins = {}
            molotov_grenades_table[grenade:get_index()].rendered = false
            molotov_grenades_table[grenade:get_index()].prev_position = nil
            molotov_grenades_table[grenade:get_index()].prev_position_bool = false
            molotov_grenades_table[grenade:get_index()].spawn_time = grenade_spawn_time
        end

        if molotov_grenades_table[grenade:get_index()].prev_position ~= nil
        and molotov_grenades_table[grenade:get_index()].prev_position.x - grenade_origin.x == 0
        and molotov_grenades_table[grenade:get_index()].prev_position.y - grenade_origin.y == 0
        and molotov_grenades_table[grenade:get_index()].prev_position.z - grenade_origin.z == 0
        then
            if molotov_grenades_table[grenade:get_index()].prev_position_bool then
                molotov_grenades_table[grenade:get_index()].rendered = true
            end
            molotov_grenades_table[grenade:get_index()].prev_position_bool = true
        else
            molotov_grenades_table[grenade:get_index()].prev_position_bool = false
        end

        if molotov_grenades_table[grenade:get_index()] ~= nil and not molotov_grenades_table[grenade:get_index()].rendered then
            table.insert( molotov_grenades_table[grenade:get_index()].origins, grenade_origin )  
            for j = 1, #molotov_grenades_table[grenade:get_index()].origins do
                if j > 1 and j ~= #molotov_grenades_table[grenade:get_index()].origins then
                    local start_pos = molotov_grenades_table[grenade:get_index()].origins[j - 1]
                    local end_pos   = molotov_grenades_table[grenade:get_index()].origins[j]
                    local color     = molotov_grenades_color:get_value()
                    create_beam(
                        { start_pos.x, start_pos.y, start_pos.z },
                        { end_pos.x, end_pos.y, end_pos.z },
                        { color.r, color.g, color.b, color.a }
                    )
                end
            end
        end

        molotov_grenades_table[grenade:get_index()].prev_position = grenade_origin
    end
end)