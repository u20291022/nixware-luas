
function draw_circle( radius, origin, color, outline, outline_color, is_molotov, molotov_entity )

    local circle_step = math.pi * 2 / 30

    local prev_screen_position, prev_screen_position_m = vec2_t.new(0, 0), vec2_t.new(0, 0)
    local vec_points = {}

    local time_left
    if is_molotov then
        time_left = math.max((((molotov_entity:get_prop_float(0x20) + 7) - globalvars.get_current_time()) / 7) * (math.pi*2 + 0.1), 0)
    end

    if is_molotov then
        local rotation_m = 0
        while rotation_m < time_left do
            local position = vec3_t.new( radius * math.cos(rotation_m) + origin.x, radius * math.sin(rotation_m) + origin.y, origin.z )
            local screen_position_m = se.world_to_screen( position )

            if screen_position_m.x ~= nil then

                if prev_screen_position_m.x ~= 0 and outline then
                    renderer.line( vec2_t.new( prev_screen_position_m.x, prev_screen_position_m.y ), vec2_t.new( screen_position_m.x, screen_position_m.y ), color_t.new( outline_color.r, outline_color.g, outline_color.b, 255 ) )
                end

                prev_screen_position_m.x, prev_screen_position_m.y = screen_position_m.x, screen_position_m.y
            end

            rotation_m = rotation_m + circle_step
        end
    end

    local rotation = 0
    while rotation < ((math.pi*2)+0.1) do
        local position = vec3_t.new( radius * math.cos(rotation) + origin.x, radius * math.sin(rotation) + origin.y, origin.z )
        local screen_position = se.world_to_screen( position )

        if screen_position.x ~= nil then
            table.insert( vec_points, screen_position )

            if prev_screen_position.x ~= 0 and outline and not is_molotov then
                renderer.line( vec2_t.new( prev_screen_position.x, prev_screen_position.y ), vec2_t.new( screen_position.x, screen_position.y ), color_t.new( outline_color.r, outline_color.g, outline_color.b, 255 ) )
            end

            prev_screen_position.x, prev_screen_position.y = screen_position.x, screen_position.y
        end

        rotation = rotation + circle_step
    end

    renderer.filled_polygon(vec_points, color)

end

function lerp_pos(x1, y1, z1, x2, y2, z2, percentage)
	local x = (x2 - x1) * percentage + x1
	local y = (y2 - y1) * percentage + y1
	local z = (z2 - z1) * percentage + z1
	return x, y, z
end

m_outline_col = ui.add_color_edit( "moltov outline color", "moltov_outline_color", false, color_t.new( 255, 0, 0, 255 ) )
m_circle_col = ui.add_color_edit( "moltov circle color", "moltov_circle_color", true, color_t.new( 255, 0, 0, 45 ) )

client.register_callback( "paint", function()

	local inferno = entitylist.get_entities_by_class_id(100)

    for j = 1, #inferno do

        local molotov = inferno[ j ]
        local origin  = molotov:get_prop_vector( se.get_netvar("DT_BaseEntity", "m_vecOrigin") )

        local cells = {}; local cell_max_1, cell_max_2
        local maximum_distance = 0

        local firecount, fire_is_burning = molotov:get_prop_int( se.get_netvar( "DT_Inferno", "m_fireCount" ) ), ffi.cast( "bool*", molotov:get_address() + se.get_netvar( "DT_Inferno", "m_bFireIsBurning" ) )
        local x_delta, y_delta, z_delta = ffi.cast( "int*", molotov:get_address() + se.get_netvar( "DT_Inferno", "m_fireXDelta" ) ), ffi.cast( "int*", molotov:get_address() + se.get_netvar( "DT_Inferno", "m_fireYDelta" ) ), ffi.cast( "int*", molotov:get_address() + se.get_netvar( "DT_Inferno", "m_fireZDelta" ) )


        for i = 1, firecount do
            if fire_is_burning[i] then
                table.insert( cells, { x_delta[i], y_delta[i], z_delta[i] } )
            end
        end

        for i = 1, #cells do
            for ii = 1, #cells do
                local distance = math.sqrt( ( cells[ii][1] - cells[i][1] )^2 + ( cells[ii][2] - cells[i][2] )^2 )

                if distance > maximum_distance then
                    maximum_distance = distance
                    cell_max_1, cell_max_2 = cells[i], cells[ii]
                end
            end
        end

        if cell_max_1 ~= nil and cell_max_2 ~= nil then

            local center_x_delta, center_y_delta, center_z_delta = lerp_pos(cell_max_1[1], cell_max_1[2], cell_max_1[3], cell_max_2[1], cell_max_2[2], cell_max_2[3], 0.5)
            local center_x, center_y, center_z = origin.x + center_x_delta, origin.y + center_y_delta, origin.z + center_z_delta

            draw_circle( maximum_distance/2 + 40, vec3_t.new( center_x, center_y, center_z ), m_circle_col:get_value(), true, m_outline_col:get_value(), true, molotov )

        end

    end

end)

s_outline_col = ui.add_color_edit( "smoke outline color", "smoke_outline_color", false, color_t.new( 0, 0, 0, 255 ) )
s_circle_col = ui.add_color_edit( "smoke circle color", "smoke_circle_color", true, color_t.new( 0, 0, 0, 45 ) )

client.register_callback( "paint", function()

	local smokes = entitylist.get_entities_by_class_id(157)

    for i = 1, #smokes do

        local smoke = smokes[i]

        local origin  = smoke:get_prop_vector( se.get_netvar("DT_BaseEntity", "m_vecOrigin") )
        local smoke_effect = smoke:get_prop_bool( se.get_netvar( "DT_SmokeGrenadeProjectile", "m_bDidSmokeEffect" ) )

        if smoke_effect then
            draw_circle( 140, origin, s_circle_col:get_value(), true, s_outline_col:get_value() )
        end

    end

end)