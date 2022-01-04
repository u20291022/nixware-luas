local APISilentCall, APISilentCallResult = pcall(require, 'api')
local API = APISilentCall and APISilentCallResult or error('API not found!', 2)

local inRechargeOffset = ffi.cast('uint32_t*', (client.find_pattern('client.dll', 'C6 87 ? ? ? ? ? 8B 06 8B CE FF 90') + 2))[0]
local function canShoot()
  local localPlayer = entitylist.get_local_player()

  local localWeapon = API.getWeapon()
  local localWeaponAmmo = localWeapon:get_prop_int( se.get_netvar( 'DT_BaseCombatWeapon', 'm_iClip1' ) )
  local isWeaponRecharging = ffi.cast('bool*', localWeapon:get_address() + inRechargeOffset)[0]

  local localWeaponName = ffi.string(API.getWeaponData().weaponName)
  local isLocalWeaponKnife = localWeaponName == 'weapon_knife'

  local localWeaponNextPrimaryAttack = localWeapon:get_prop_float( se.get_netvar( 'DT_BaseCombatWeapon', 'm_flNextPrimaryAttack' ) )
  local serverTime = localPlayer:get_prop_int( se.get_netvar( 'DT_BasePlayer', 'm_nTickBase' ) ) * globalvars.get_interval_per_tick()

  return localWeaponNextPrimaryAttack <= serverTime and ((localWeaponAmmo > 0 and not isWeaponRecharging) or isLocalWeaponKnife)
end

local function isThrowingGrenade()
  local localWeapon = API.getWeapon()

  local localWeaponThrowTime = localWeapon:get_prop_float( se.get_netvar( 'DT_BaseCSGrenade', 'm_fThrowTime' ) )
  local localWeaponType = API.getWeaponData().weaponType
  local isLocalWeaponGrenade = localWeaponType == 9

  return localWeaponThrowTime >= 0.1 and isLocalWeaponGrenade
end

local function getReloadingTime(  )
  local localPlayer = entitylist.get_local_player()
  
  local reloadingTime = localPlayer:get_prop_float( se.get_netvar( 'DT_BaseCombatCharacter', 'm_flNextAttack' ) ) - globalvars.get_current_time()
  if reloadingTime <= 0.0 then
    reloadingTime = 0.0
  end

  return reloadingTime
end

local function inUse(cmd)
  return API.band(cmd.buttons, 32)
end

local function isReturning( cmd )
  if API.isFreezeTime() then
    return true
  end

  if API.getMoveType() == 0 or API.getMoveType() == 8 or API.getMoveType() == 9 then
    return true
  end

  if inUse(cmd) then
    return true
  end
  
  if isThrowingGrenade() then
    return true
  end

  if entitylist.get_local_player():get_prop_bool( se.get_netvar('DT_CSPlayer', 'm_bIsDefusing') ) then
    return true
  end

  if API.band(cmd.buttons, 1) or
    (API.band(cmd.buttons, 2048) and API.getWeaponData().weaponType == 0) and 
    canShoot() and getReloadingTime() <= 0.1
    then return true
  end

  return false
end

local inverter_bind = ui.add_key_bind('Inverter', 'fake_flick_inverter', 0, 2)
local auto_inverter = ui.add_check_box('Auto Invert', 'fake_flick_auto_inverter', false)
local flick_delta   = ui.add_slider_int('Flick Delta', 'fake_flick_delta', 46, 180, 95)
local flick_ticks   = ui.add_slider_int('Flick Ticks', 'fake_flick_ticks', 10, 64, 64)

local get_inverter_side = function ()
  return inverter_bind:is_active() and -1 or 1
end

local flicked = false
local auto_side = 1
local auto_inverter_delay = 0.0

local get_auto_inverter_side = function ()
  local current_time = globalvars.get_current_time()

  if current_time + 1 < auto_inverter_delay then
    auto_inverter_delay = current_time
  end

  if auto_inverter_delay > current_time then
    flicked = false
  end

  if flicked then
    auto_inverter_delay = current_time + 0.1
    auto_side = auto_side * -1
    flicked = false
  end

  return auto_side
end

local get_current_side = function ()
  return auto_inverter:get_value() and get_auto_inverter_side() or get_inverter_side()
end

local create_move_main = function (cmd)
  local local_player = entitylist.get_local_player()

  if not local_player:is_alive() then
    return
  end

  --if API.getMovement() ~= 0 then
  --  return
  --end

  if isReturning(cmd) then
    return
  end

  local delta        = flick_delta:get_value()
  local current_side = get_current_side()
  local tick_count   = cmd.tick_count
  local ticks        = flick_ticks:get_value() 

  if tick_count % ticks == 1 or tick_count % ticks == 2 then
    cmd.viewangles.yaw = cmd.viewangles.yaw + (delta * current_side)
    flicked = true
  end
end

client.register_callback('create_move', create_move_main)

local width1, width2 = 0, 0

local paint_main = function ()
  if not entitylist.get_local_player():is_alive() then
    return
  end

  if auto_inverter:get_value() then
    return
  end

  local current_side = get_current_side()

  local screen_size = engine.get_screen_size()
  local screen_center = vec2_t.new(screen_size.x / 2, screen_size.y / 2)

  width1 = current_side == 1 and 0 or math.min(95, width1 + 3)
  width2 = current_side == 1 and math.min(95, width2 + 3) or 0

  width1 = width1 >= 95 and 0 or width1
  width2 = width2 >= 95 and 0 or width2

  local color1 = current_side == 1 and color_t.new(0, 0, 0, 0) or color_t.new(255, 255, 255, 255)
  local color2 = current_side == 1 and color_t.new(255, 255, 255, 255) or color_t.new(0, 0, 0, 0)

  local gradient1 = color_t.new(100, 100, 100, current_side == 1 and 0 or 255)
  local gradient2 = color_t.new(100, 100, 100, current_side == 1 and 255 or 0)

  local pos1 = { vec2_t.new(screen_center.x - 100, screen_size.y - 55), vec2_t.new(screen_center.x - 5 - width1, screen_size.y - 50) } -- left
  local pos2 = { vec2_t.new(screen_center.x + 5 + width2, screen_size.y - 55), vec2_t.new(screen_center.x + 100, screen_size.y - 50) } -- right

  renderer.rect_filled_fade(pos1[1], pos1[2], color1, gradient1, gradient1, color1)
  renderer.rect_filled_fade(pos2[1], pos2[2], gradient2, color2, color2, gradient2)
end

client.register_callback('paint', paint_main)