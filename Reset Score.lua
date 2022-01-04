local player_resourse = ffi.cast('void***', client.find_pattern('client.dll', 'A1 ? ? ? ? 57 85 C0 74 08') + 0x1)[0]

local player_kills_offset = se.get_netvar('DT_PlayerResource', 'm_iKills')
local player_deaths_offset = se.get_netvar('DT_PlayerResource', 'm_iDeaths')

local reset_delay = 0

local main = function ()
  if not engine.is_connected() then
    return
  end

  local local_resourse_offset = ffi.cast('uintptr_t*', player_resourse)[0] + (4 * engine.get_local_player())
  
  local kills = ffi.cast('int*', local_resourse_offset + player_kills_offset)[0]
  local deaths = ffi.cast('int*', local_resourse_offset + player_deaths_offset)[0]

  local curr_time = globalvars.get_current_time()

  if curr_time < reset_delay then
    reset_delay = curr_time
  end

  if kills < deaths and curr_time - reset_delay > 3 then
    engine.execute_client_cmd('say !rs')
    reset_delay = curr_time
  end
end

client.register_callback('paint', main)