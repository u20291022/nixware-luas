local sin, cos, pi = math.sin, math.cos, math.pi

local crosshair_convar = se.get_convar('crosshair')

local visuals_other_removals = ui.get_multi_combo_box('visuals_other_removals')
local visuals_other_force_crosshair = ui.get_check_box('visuals_other_force_crosshair')
local visuals_other_hitmarker = ui.get_check_box('visuals_other_hitmarker')

local crosshair_group = ui.add_combo_box('Group', 'crosshair_group', { 'Functions', 'Colors', 'Settings' }, 0)

local crosshair_show_default = ui.add_check_box('Show default', 'crosshair_show_default', false)

local crosshair_show_static_dot = ui.add_check_box('Show static dot', 'crosshair_show_static_dot', true)
local crosshair_show_recoil = ui.add_check_box('Show recoil', 'crosshair_show_recoil', true)
local crosshair_show_spread = ui.add_check_box('Show spread', 'crosshair_show_spread', true)

local crosshair_force_in_scope = ui.add_check_box('Force in scope', 'crosshair_force_in_scope', visuals_other_force_crosshair:get_value())
local crosshair_hit_marker = ui.add_check_box('Hit marker', 'crosshair_hit_marker', visuals_other_hitmarker:get_value())

local crosshair_center_color = ui.add_color_edit('Center circle', 'crosshair_center_color', true, color_t.new(255, 255, 255, 60))
local crosshair_center_hit_color = ui.add_color_edit('Center circle on hit', 'crosshair_center_hit_color', true, color_t.new(255, 255, 255, 10))

local crosshair_middle_color = ui.add_color_edit('Middle circle', 'crosshair_middle_color', true, color_t.new(255, 255, 255, 10))
local crosshair_middle_hit_color = ui.add_color_edit('Middle circle on hit', 'crosshair_middle_hit_color', true, color_t.new(255, 255, 255, 0))

local crosshair_animation_color = ui.add_color_edit('Animated circle', 'crosshair_animation_color', true, color_t.new(255, 255, 255, 30))
local crosshair_animation_hit_color = ui.add_color_edit('Animated circle on hit', 'crosshair_animation_hit_color', true, color_t.new(255, 125, 155, 75))

local crosshair_static_dot_color = ui.add_color_edit('Static dot', 'crosshair_static_dot_color', true, color_t.new(255, 255, 255, 170))
local crosshair_static_dot_hit_color = ui.add_color_edit('Static dot on hit', 'crosshair_static_dot_hit_color', true, color_t.new(255, 125, 155, 255))

local crosshair_hit_animation_on = ui.add_multi_combo_box('Hit animation on', 'crosshair_hit_animation_on', { 'Enemy', 'Team' }, { true, false })

local crosshair_segments = ui.add_slider_int('Segments', 'crosshair_segments', 3, 90, 60)
local crosshair_animation_speed = ui.add_slider_float('Animation speed', 'crosshair_animation_speed', 0.5, 15, 1)

local crosshair_size = ui.add_slider_float('Size', 'crosshair_size', 0.1, 5, 5)
local crosshair_width = ui.add_slider_int('Width', 'crosshair_width', 1, 5, 3)

local crosshair_static_dot_size = ui.add_slider_int('Static dot size', 'crosshair_static_dot_size', 1, 10, 3)

local show_functions = function (show)
  crosshair_force_in_scope:set_visible(show)
  crosshair_hit_marker:set_visible(show)

  crosshair_show_default:set_visible(show)
  crosshair_show_recoil:set_visible(show)
  crosshair_show_static_dot:set_visible(show)
  crosshair_show_spread:set_visible(show)
end

local show_colors = function (show)
  crosshair_static_dot_color:set_visible(show)
  crosshair_center_color:set_visible(show)
  crosshair_middle_color:set_visible(show)
  crosshair_animation_color:set_visible(show)

  crosshair_static_dot_hit_color:set_visible(show)
  crosshair_center_hit_color:set_visible(show)
  crosshair_middle_hit_color:set_visible(show)
  crosshair_animation_hit_color:set_visible(show)
end

local show_settings = function (show)
  crosshair_hit_animation_on:set_visible(show)
  crosshair_segments:set_visible(show)
  crosshair_animation_speed:set_visible(show)
  crosshair_size:set_visible(show)
  crosshair_width:set_visible(show)
  crosshair_static_dot_size:set_visible(show)
end

local show_ui_elements = function ()
  local current_group = crosshair_group:get_value()

  show_functions(current_group == 0)
  show_colors(current_group == 1)
  show_settings(current_group == 2)
end

local deg_to_rad = function (deg)
  return deg * (pi / 180)
end

local angle_vectors = function (angles) 
  local cp, sp = cos(deg_to_rad(angles.pitch)), sin(deg_to_rad(angles.pitch))
  local cy, sy = cos(deg_to_rad(angles.yaw)), sin(deg_to_rad(angles.yaw))
  local cr, sr = cos(deg_to_rad(angles.roll)), sin(deg_to_rad(angles.roll))

  local forward = vec3_t.new(0, 0, 0)

  forward.x = cp * cy
  forward.y = cp * sy
  forward.z = -sp

  return forward
end

local net_view_offset = se.get_netvar('DT_BasePlayer', 'm_vecViewOffset[0]')
local net_team_num = se.get_netvar('DT_BaseEntity', 'm_iTeamNum')
local net_is_scoped = se.get_netvar('DT_CSPlayer', 'm_bIsScoped')
local net_aim_punch_angle = se.get_netvar('DT_BasePlayer', 'm_aimPunchAngle')
local net_active_weapon = se.get_netvar('DT_BaseCombatCharacter', 'm_hActiveWeapon')

local player_vtable = ffi.cast('int*', client.find_pattern('client.dll', '55 8B EC 83 E4 F8 83 EC 18 56 57 8B F9 89 7C 24 0C') + 0x47)[0]
local get_abs_origin = ffi.cast('float*(__thiscall*)(int)', ffi.cast('int*', player_vtable + 0x28)[0])

local get_hit_index = function ()
  local local_player = entitylist.get_local_player()

  if not local_player or not local_player:is_alive() then 
    return 0
  end

  local aim_punch_angle = local_player:get_prop_angle(net_aim_punch_angle)
  local new_angle = aim_punch_angle

  local show_recoil = crosshair_show_recoil:get_value()
  local remove_punch = visuals_other_removals:get_value(2)

  if show_recoil then
    new_angle = angle_t.new(aim_punch_angle.pitch * 2, aim_punch_angle.yaw * 2, aim_punch_angle.roll * 2)
  end

  if not show_recoil and remove_punch then
    new_angle = angle_t.new(0, 0, 0)
  end

  local view_angles = engine.get_view_angles()

  view_angles = angle_t.new(view_angles.pitch + new_angle.pitch, view_angles.yaw + new_angle.yaw, view_angles.roll + new_angle.roll)

  local trace_end = angle_vectors(view_angles)
  
  local abs_origin = get_abs_origin(local_player:get_address())
  local view_offset = local_player:get_prop_vector(net_view_offset)
  local trace_start = vec3_t.new(abs_origin[0] + view_offset.x, abs_origin[1] + view_offset.y, abs_origin[2] + view_offset.z)

  trace_end.x = trace_start.x + trace_end.x * 8192.0
  trace_end.y = trace_start.y + trace_end.y * 8192.0
  trace_end.z = trace_start.z + trace_end.z * 8192.0

  local mask_shot = 0x46004003

  local trace_out = trace.line(engine.get_local_player(), mask_shot, trace_start, trace_end)

  return trace_out.hit_entity_index
end

local get_inaccuracy = function (entity) return ffi.cast('float(__thiscall*)(void*)', entity[0][483])(entity) end

local get_spread_radius = function ()
  local local_player = entitylist.get_local_player()

  if not local_player or not local_player:is_alive() then
    return 0
  end

  local local_weapon_handle = local_player:get_prop_int(net_active_weapon)
  local local_weapon = entitylist.get_entity_from_handle(local_weapon_handle)
  local local_weapon_entity = ffi.cast('void***', local_weapon:get_address())

  if not local_weapon_entity then
    return 0
  end

  local inaccuracy_status, inaccuracy = pcall(get_inaccuracy, local_weapon_entity)

  if not inaccuracy_status then
    return 0
  end

  local radius = inaccuracy * 550

  return radius
end

local draw_arc = function (center_position, start_angle, end_angle, radius, width, color)
  start_angle, end_angle = deg_to_rad(start_angle), deg_to_rad(end_angle)

  local rotation = start_angle
  local step = 0.1 + (2 * math.pi) / crosshair_segments:get_value()

  while rotation < end_angle - 0.01 do
    local rotation_sin, rotation_cos = sin(rotation), cos(rotation)
    local next_rotation_sin, next_rotation_cos = sin(rotation + step), cos(rotation + step)

    local position = vec2_t.new(radius * rotation_cos + center_position.x, radius * rotation_sin + center_position.y)
    local next_position = vec2_t.new(radius * next_rotation_cos + center_position.x, radius * next_rotation_sin + center_position.y)
    
    local width_position = vec2_t.new((radius + width) * rotation_cos + center_position.x, (radius + width) * rotation_sin + center_position.y)
    local width_next_position = vec2_t.new((radius + width) * next_rotation_cos + center_position.x, (radius + width) * next_rotation_sin + center_position.y)

    if position.x ~= nil then
      renderer.filled_polygon({position, width_position, width_next_position, next_position}, color_t.new(color.r, color.g, color.b, color.a / 2))
    end

    rotation = rotation + (step - 0.1)
  end
end

local get_crosshair_position = function ()
  local screen_size = engine.get_screen_size()
  local screen_center = vec2_t.new(screen_size.x / 2, screen_size.y / 2)

  if crosshair_show_recoil:get_value() then
    local local_player = entitylist.get_local_player()
    local aim_punch_angle = local_player:get_prop_angle(net_aim_punch_angle)

    local divided_screen_size = vec2_t.new(screen_size.x / 90, screen_size.y / 90)

    local remove_punch = visuals_other_removals:get_value(2)
    
    if remove_punch then
      aim_punch_angle.pitch = aim_punch_angle.pitch * 2
      aim_punch_angle.yaw = aim_punch_angle.yaw * 2
    end

    screen_center.x = screen_center.x - (divided_screen_size.x * aim_punch_angle.yaw)
    screen_center.y = screen_center.y + (divided_screen_size.y * aim_punch_angle.pitch)
  end

  return screen_center
end

local draw_crosshair = function (animation_value, colors)
  local screen_size = engine.get_screen_size()
  local screen_center = vec2_t.new(screen_size.x / 2, screen_size.y / 2)

  local show_spread = crosshair_show_spread:get_value()
  local show_static_dot = crosshair_show_static_dot:get_value()

  local width = crosshair_width:get_value()
  local size = crosshair_size:get_value() + 3 + (width / 10) + (show_spread and get_spread_radius() or 0)

  local static_dot_size = crosshair_static_dot_size:get_value()

  local crosshair_position = get_crosshair_position()

  draw_arc(crosshair_position, 0, 360, size, width, colors[1]) -- center layer

  draw_arc(crosshair_position, 0, 360, size + 3 + width, width, colors[2]) -- middle layer

  draw_arc(crosshair_position, 65  + animation_value, 115 + animation_value, size + 6 + (width * 2), width, colors[3]) -- animation layer
  draw_arc(crosshair_position, 245 + animation_value, 295 + animation_value, size + 6 + (width * 2), width, colors[3])
  draw_arc(crosshair_position, 155 + animation_value, 205 + animation_value, size + 6 + (width * 2), width, colors[3])
  draw_arc(crosshair_position, 335 + animation_value, 385 + animation_value, size + 6 + (width * 2), width, colors[3])

  if show_static_dot then
    renderer.circle(screen_center, static_dot_size, 30, true, colors[4])
  end
end

local animation_value = 0

client.register_callback('paint', function ()
  visuals_other_hitmarker:set_value(crosshair_hit_marker:get_value()) -- :$cool methods$:
  visuals_other_force_crosshair:set_value(crosshair_force_in_scope:get_value())
  
  show_ui_elements()

  if not engine.is_connected() then
    return
  end

  local local_player = entitylist.get_local_player()

  if not local_player:is_alive() or not engine.is_connected() or crosshair_show_default:get_value() then
    crosshair_convar:set_int(1)
  else
    crosshair_convar:set_int(0)
  end
  
  if not local_player:is_alive() then
    return
  end

  local local_player_scoped = local_player:get_prop_bool(net_is_scoped)
  local force_crosshair = visuals_other_force_crosshair:get_value()

  if not force_crosshair and local_player_scoped then
    return
  end
  
  local center_color = crosshair_center_color:get_value()
  local middle_color = crosshair_middle_color:get_value()
  local animation_color = crosshair_animation_color:get_value()
  local static_dot_color = crosshair_static_dot_color:get_value()

  local center_hit_color = crosshair_center_hit_color:get_value()
  local middle_hit_color = crosshair_middle_hit_color:get_value()
  local animation_hit_color = crosshair_animation_hit_color:get_value()
  local static_dot_hit_color = crosshair_static_dot_hit_color:get_value()

  local hit_index = get_hit_index()

  if hit_index > 0 then
    local hit_entity = entitylist.get_entity_by_index(hit_index)

    local hit_entity_team = hit_entity:get_prop_int(net_team_num)
    local local_player_team = local_player:get_prop_int(net_team_num)

    local use_hit_color_on_enemy = crosshair_hit_animation_on:get_value(0)
    local use_hit_color_on_team  = crosshair_hit_animation_on:get_value(1)

    local use_hit_color = (use_hit_color_on_enemy and hit_entity_team ~= local_player_team) or (use_hit_color_on_team and hit_entity_team == local_player_team) 

    if hit_entity_team == 2 or hit_entity_team == 3 then
      if use_hit_color then
        center_color = center_hit_color
        middle_color = middle_hit_color
        animation_color = animation_hit_color
        static_dot_color = static_dot_hit_color
      end
    end
  end

  local animation_speed = crosshair_animation_speed:get_value()

  animation_value = animation_value + animation_speed

  draw_crosshair(animation_value, {center_color, middle_color, animation_color, static_dot_color})

  if animation_value >= 360 then
    animation_value = 0
  end
end)

client.register_callback('unload', function ()
  crosshair_convar:set_int(1)
end)