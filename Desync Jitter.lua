

client.register_callback('create_move', function(cmd)
    local previousDesyncSide = ui.get_key_bind('antihit_antiaim_flip_bind'):is_active() and 1 or 0
    if clientstate.get_choked_commands() == 0 then
        ui.get_key_bind('antihit_antiaim_flip_bind'):set_type(previousDesyncSide)
    end
end)