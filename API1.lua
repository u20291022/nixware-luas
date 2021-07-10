ffi.cdef[[

    struct vec3_t { 
        float x, y, z; 
    };

    struct TeslaBeamInfo_t {
        struct vec3_t position; 
		struct vec3_t angle;
		int entityIndex;
		const char* spriteName;
		float beamWidth;
		int beams;
		struct vec3_t color;
		float visibleTime;
		float radius;
    };

    struct CWeaponData
    {
      int8_t pad0[20];
    	int32_t maxClip1;
    	int8_t pad1[12];
    	int32_t maxReservedAmmo;
    	int8_t pad2[96];
    	char* hudName;
    	char* weaponName;
    	int8_t pad3[56];
    	int32_t weaponType;
    	int8_t pad4[4];
    	int32_t weaponPrice;
    	int32_t killAward;
    	int8_t pad5[20];
    	uint8_t fullAuto;
    	int8_t pad6[3];
    	int32_t damage;
    	float armorRatio;
    	int32_t bullets;
    	float penetration;
    	int8_t pad7[8];
    	float range;
    	float rangeModifier;
    	int8_t pad8[16];
    	uint8_t hasSilencer;
    	int8_t pad9[15];
    	float spread;
    	float spreadAlt;
    	int8_t pad10[76];
    	int32_t recoilSeed;
    	int8_t pad11[32];
    };

]]

API = { _version = '1.0' }
weaponDataCall = ffi.cast('int*(__thiscall*)(void*)', client.find_pattern('client.dll', '55 8B EC 81 EC ? ? ? ? 53 8B D9 56 57 8D 8B ? ? ? ? 85 C9 75 04'))
gameRules = ffi.cast('void***', client.find_pattern('client.dll', '8B 0D ?? ?? ?? ?? 85 C0 74 0A 8B 01 FF 50 78 83 C0 54') + 0x2)[0]
API.drawTeslaBeam = ffi.cast('void(__thiscall*)(struct TeslaBeamInfo_t&)', client.find_pattern('client.dll', '55 8B EC 81 EC ? ? ? ? 56 57 8B F9 8B 47 18'))

function API.round( num, idp )
    return math.floor(num * (10^(idp or 0)) + 0.5) / (10^(idp or 0))
end

function API.clampToCloseAndRound( num )
    return API.round(num, 3) < 0.05 
        and 0 or (
        (
            API.round(num, 3) < 0.51 and API.round(num, 3) > 0.49
        ) and 0.5 or 
        (
            API.round(num, 3) > 0.95 and 1 or API.round(num, 3)
        )
    )
end

function API.getWeapon( player )
    local currentPlayer = player ~= nil and player or entitylist.get_local_player()
    local weaponIndex = currentPlayer:get_prop_int( se.get_netvar( 'DT_BaseCombatCharacter', 'm_hActiveWeapon' ) )
    local playerWeapon = entitylist.get_entity_from_handle( weaponIndex )
    return playerWeapon
end

function API.getWeaponData( player )
    local currentPlayerWeapon = API.getWeapon( player )
    local currentPlayerWeaponData = ffi.cast('struct CWeaponData*', weaponDataCall(ffi.cast('void*', currentPlayerWeapon:get_address())))
    return currentPlayerWeaponData
end

function API.getMoveType()
    local localPlayer = entitylist.get_local_player()
    local localPlayerMoveType = localPlayer:get_prop_int( se.get_netvar( 'DT_BaseEntity', 'm_nRenderMode' ) + 1 )
    return localPlayerMoveType
end

function API.isFreezeTime()
    return ffi.cast('bool*', ffi.cast('uintptr_t*', gameRules)[0] + se.get_netvar( 'DT_CSGameRulesProxy', 'm_bFreezePeriod' ))[0]
end

function API.isValveDS() 
    return ffi.cast('bool*', ffi.cast('uintptr_t*', gameRules)[0] + se.get_netvar( 'DT_CSGameRulesProxy', 'm_bIsValveDS' ))[0]
end

function API.getMovement()
    local velocityOffset = se.get_netvar( 'DT_BasePlayer', 'm_vecVelocity[0]' )
    local localPlayer = entitylist.get_local_player()
    local localPlayerFlags = localPlayer:get_prop_int( se.get_netvar( 'DT_BasePlayer', 'm_fFlags' ) )
    local localPlayerVelocity = localPlayer:get_prop_vector( velocityOffset )
    local localPlayerSpeed = math.sqrt(localPlayerVelocity.x^2 + localPlayerVelocity.y^2)
    if not API.band(localPlayerFlags, 1) then
        return 2
    else
        return localPlayerSpeed > 29 and 1 or 0
    end
end

function API.band( bit1, bit2 )
    return bit32.band( bit1, bit2 ) ~= 0
end

function API.setBit( bit1, bit2 )
    return API.band( bit1, bit2 ) and bit1 or bit1 + bit2
end

function API.clearBit( bit1, bit2 )
    return API.band( bit1, bit2 ) and bit1 - bit2 or bit1
end

function API.isLocalPlayerInScope() 
    local localPlayer = entitylist.get_local_player()
    local localWeapon = API.getWeapon()
    local localWeaponNextPrimaryAttack = localWeapon:get_prop_float( se.get_netvar( 'DT_BaseCombatWeapon', 'm_flNextPrimaryAttack' ) )
    local serverTime = localPlayer:get_prop_int( se.get_netvar( 'DT_BasePlayer', 'm_nTickBase' ) ) * globalvars.get_interval_per_tick()
    local zoomLevel = localWeapon:get_prop_int( se.get_netvar('DT_WeaponCSBaseGun', 'm_zoomLevel') )
    return zoomLevel > 0 and (localWeaponNextPrimaryAttack - serverTime) <= 0.235
end

function API.isSendingPacket()
    return clientstate.get_choked_commands() == 0
end

local function AngleVectors(vAngles) if (vAngles.x == nil or vAngles.y == nil or vAngles.z == nil) then vAngles = vec3_t.new(vAngles.pitch, vAngles.yaw, vAngles.roll); end local sy = math.sin((math.pi/180)*(vAngles.y));	local cy = math.cos((math.pi/180)*(vAngles.y));	local sp = math.sin((math.pi/180)*(vAngles.x));	local cp = math.cos((math.pi/180)*(vAngles.x)); return vec3_t.new(cp * cy, cp * sy, -sp) end
local function VectorNumberMultiplication(Vector, Number) return vec3_t.new(Vector.x * Number, Vector.y * Number, Vector.z * Number); end
local function VectorAngles(vAngles) if (vAngles.x == nil or vAngles.y == nil or vAngles.z == nil) then vAngles = vec3_t.new(vAngles.pitch, vAngles.yaw, vAngles.roll); end local tmp, yaw, pitch; if (vAngles.y == 0 and vAngles.x == 0) then yaw = 0; if (vAngles.z > 0) then pitch = 270; else pitch = 90; end else	yaw = math.atan2(vAngles.y, vAngles.x) * 180.0 / math.pi; if (yaw < 0) then	yaw = yaw + 360; end tmp = math.sqrt(vAngles.x * vAngles.x + vAngles.y * vAngles.y); pitch = math.atan2(-vAngles.z, tmp) * 180.0 / math.pi; if (pitch < 0) then pitch = pitch + 360; end end return vec3_t.new(pitch, yaw, 0) end
function API.automaticStop( cmd )
    local velocityOffset = se.get_netvar( 'DT_BasePlayer', 'm_vecVelocity[0]' )
    local localPlayer = entitylist.get_local_player()
    local localPlayerVelocity = localPlayer:get_prop_vector( velocityOffset )
    local localPlayerSpeed = math.sqrt(localPlayerVelocity.x^2 + localPlayerVelocity.y^2)
	if localPlayerSpeed < 1 then
		cmd.sidemove = 0
        cmd.forwardmove = 0
	else
		direction = VectorAngles(localPlayerVelocity); viewangles = engine.get_view_angles()
        direction.y = viewangles.yaw - direction.y
		forward = AngleVectors(direction)
        negative = vec3_t.new( forward.x * -250, forward.y * -250, forward.z * -250 )
		cmd.sidemove = negative.y
        cmd.forwardmove = negative.x
	end
end

function API.getEyePosition( player )
    local originOffset = se.get_netvar('DT_BaseEntity', 'm_vecOrigin')
    local viewOffset = se.get_netvar('DT_BasePlayer', 'm_vecViewOffset')
    local currentPlayer = player ~= nil and player or entitylist.get_local_player()
    local playerOrigin = currentPlayer:get_prop_vector( originOffset )
    local playerView   = currentPlayer:get_prop_vector( viewOffset )
    local playerEyePos = vec3_t.new( playerOrigin.x + playerView.x, playerOrigin.y + playerView.y, playerOrigin.z + playerView.z )
    return playerEyePos
end

return API
