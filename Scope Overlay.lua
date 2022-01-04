API = require('API')

local oldCrosshair = nil

local customScopeOverlaySize  = ui.add_slider_float('Scope Overlay Size', 'customScopeOverlaySize', 0.1, 10.0, 8)
local customScopeOverlayColor = ui.add_color_edit('Scope Overlay Color', 'customScopeOverlayColor', false, color_t.new(255,255,255,255)) 

local once = false

client.register_callback('paint', function ()
    if customScopeOverlaySize:get_value() > 10.0 then
        customScopeOverlaySize:set_value(10.0)
    elseif customScopeOverlaySize:get_value() < 1.0 then
        customScopeOverlaySize:set_value(1.0)
    end

    if oldCrosshair == nil or not engine.is_connected() then
        oldCrosshair =  se.get_convar('crosshair'):get_int()
    end

    if not API.isLocalPlayerInScope() or not engine.is_connected() or API.getWeaponData().weaponType ~= 5 and oldCrosshair ~= nil then
        if not once then
            se.get_convar('crosshair'):set_int(oldCrosshair)
        end
        oldCrosshair = se.get_convar('crosshair'):get_int()
        once = true
        se.get_convar('r_drawviewmodel'):set_int(1)
        return
    end

    once = false
    se.get_convar('crosshair'):set_int(0)
    se.get_convar('r_drawviewmodel'):set_int(0)

    local center = vec2_t.new(engine.get_screen_size().x/2, engine.get_screen_size().y/2)
    local size = center.x / (12.0 - customScopeOverlaySize:get_value())

    local Color1 = color_t.new(customScopeOverlayColor:get_value().r, customScopeOverlayColor:get_value().g, customScopeOverlayColor:get_value().b, 200)
	local Color2 = color_t.new(customScopeOverlayColor:get_value().r, customScopeOverlayColor:get_value().g, customScopeOverlayColor:get_value().b, 0)

    renderer.rect_filled_fade( vec2_t.new( center.x - (size + 6), center.y - 1 ), vec2_t.new( center.x - 6, center.y + 1 ), Color2, Color1, Color1, Color2 )
	renderer.rect_filled_fade( vec2_t.new( center.x + 6, center.y - 1 ), vec2_t.new( center.x + (size + 6), center.y + 1 ), Color1, Color2, Color2, Color1 )
	renderer.rect_filled_fade( vec2_t.new( center.x - 1, center.y + 6 ), vec2_t.new( center.x + 1, center.y + (size + 6) ), Color1, Color1, Color2, Color2 )
	renderer.rect_filled_fade( vec2_t.new( center.x - 1, center.y - 6 ), vec2_t.new( center.x + 1, center.y - (size + 6) ), Color1, Color1, Color2, Color2 )
end)

client.register_callback('frame_stage_notify', function(currentStage)
	entitylist.get_local_player():set_prop_bool( se.get_netvar( 'DT_CSPlayer', 'm_bIsScoped' ), false )
end)

client.register_callback('unload', function()
    if API.isLocalPlayerInScope() then
        se.get_convar('crosshair'):set_int(1)
        se.get_convar('r_drawviewmodel'):set_int(1)
    end
end)