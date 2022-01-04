local snow_flakes = {}

local add_snow_flake = function (screen_width)
  local flake = {}

  flake.time = globalvars.get_current_time()
  flake.pos = vec2_t.new(math.random(5, screen_width - 5), 0)
  flake.radius = 3 + math.random(4)
  flake.alpha = math.random(160)
  flake.speed = math.random(3) + 2

  table.insert(snow_flakes, flake)
end

local only_in_menu = ui.add_check_box('Only in Menu', 'snow_only_in_menu', true)

local main = function ()
  local curr_time = globalvars.get_current_time()
  local screen_size = engine.get_screen_size()

  add_snow_flake(screen_size.x) 
  
  for index = 1, #snow_flakes do
    local flake = snow_flakes[index]

    if (curr_time - flake.time) > 6 then
      table.remove(snow_flakes, index)
    end

    if not only_in_menu:get_value() or (only_in_menu:get_value() and ui.is_visible()) then
      renderer.circle(flake.pos, flake.radius, 60, true, color_t.new(255, 255, 255, flake.alpha))
    end

    flake.pos.y = math.min(screen_size.y, flake.pos.y + flake.speed)
  end
end

client.register_callback('paint', main)