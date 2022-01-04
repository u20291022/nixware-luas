local fakelag_jitter_amount = ui.add_slider_int('Jitter amount', 'fakelag_jitter_amount', 0, 100, 0)
local antihit_fakelag_limit = ui.get_slider_int('antihit_fakelag_limit')

local fakelag_amount = 0

local game_rules = ffi.cast('void***', client.find_pattern('client.dll', '8B 0D ?? ?? ?? ?? 85 C0 74 0A 8B 01 FF 50 78 83 C0 54') + 0x2)[0]
local net_valve_ds = se.get_netvar('DT_CSGameRulesProxy', 'm_bIsValveDS')

local main = function ()
  local local_player = entitylist.get_local_player()

  if not local_player:is_alive() then
    return
  end

  local is_valve_ds = ffi.cast('bool*', ffi.cast('uintptr_t*', game_rules)[0] + net_valve_ds)[0]

  local max_fakelag_amount = is_valve_ds and 6 or 14
  
  local jitter_amount = fakelag_jitter_amount:get_value()

  if fakelag_amount * max_fakelag_amount >= clientstate.get_choked_commands() then
    fakelag_amount = math.random(jitter_amount) / 100
  end

  local fakelag_limit = math.ceil(max_fakelag_amount * fakelag_amount)

  antihit_fakelag_limit:set_value(fakelag_limit)
end

client.register_callback('create_move', main)