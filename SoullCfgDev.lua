local APISilentCall, APISilentCallResult = pcall(require, 'API')
local API = APISilentCall and APISilentCallResult or error('API not found!', 2)

------------------------------------------------------------------------------------------------------------

local function canShoot()
    local localPlayer = entitylist.get_local_player()
    local localWeapon = API.getWeapon()
    local localWeaponAmmo = localWeapon:get_prop_int( se.get_netvar( 'DT_BaseCombatWeapon', 'm_iClip1' ) )
    local inRechargeOffset = ffi.cast('uint32_t*', (client.find_pattern('client.dll', 'C6 87 ? ? ? ? ? 8B 06 8B CE FF 90') + 2))[0]
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
	if reloadingTime <= 0.0 then reloadingTime = 0.0 end
    return reloadingTime
end

local function inUse(cmd)
    if API.band(cmd.buttons, 32) then
        return true
    end
    return false
end

local function isReturning( cmd )
    if API.isFreezeTime() then
        return true
    end

    if API.getMoveType() == 0 or API.getMoveType() == 8 or API.getMoveType() == 9 then
        return true
    end

    if isThrowingGrenade() then
        return true
    end

    if entitylist.get_local_player():get_prop_bool( se.get_netvar('DT_CSPlayer', 'm_bIsDefusing') ) then
        return true
    end

    if API.band(cmd.buttons, 1) or (API.band(cmd.buttons, 2048) and API.getWeaponData().weaponType == 0) then
        if canShoot() and getReloadingTime() <= 0.1 then
            return true
        end
    end
    return false
end

local function isKeyBindAndCheckBoxActive( keybind )
    local checkbox = ui.get_check_box( keybind:sub(0, #keybind - 5) )
    local checkboxValue = checkbox ~= nil and checkbox:get_value() or true
    local keybindValue  = ui.get_key_bind( keybind ):is_active()
    return checkboxValue and keybindValue
end

local function microMovement( cmd )
    local velocityOffset = se.get_netvar( 'DT_BasePlayer', 'm_vecVelocity[0]' )
    local duckAmountOffset = se.get_netvar( 'DT_BasePlayer' , 'm_flDuckAmount' )
    local localPlayer = entitylist.get_local_player()
    local localPlayerVelocity = localPlayer:get_prop_vector( velocityOffset )
    local localPlayerSpeed = math.sqrt(localPlayerVelocity.x^2 + localPlayerVelocity.y^2)
    local localPlayerDuckAmount = localPlayer:get_prop_float( duckAmountOffset )
    if localPlayerSpeed < 3.03 then
        local speed = 1.01
        if API.band( cmd.buttons, 4 ) 
        or isKeyBindAndCheckBoxActive( 'antihit_extra_fakeduck_bind' )
        or localPlayerDuckAmount > 0.55
        then
            speed = speed * 2.94117647
        end
        cmd.sidemove = cmd.sidemove + (cmd.command_number % 2 == 0 and speed or -speed)
    end
end

local debugOverlay = ffi.cast("void***", se.create_interface("engine.dll", "VDebugOverlay004"))
local addLineOverlay = ffi.cast("void(__thiscall*)(void*, const struct vec3_t&, const struct vec3_t&, int, int, int, bool, float)", debugOverlay[0][5]);

local function drawLineOverlay( startPosition, endPosition, color )
	shotStartPosition = ffi.new('struct vec3_t')
	shotStartPosition.x = startPosition.x; shotStartPosition.y = startPosition.y; shotStartPosition.z = startPosition.z
	shotEndPosition = ffi.new('struct vec3_t')
	shotEndPosition.x = endPosition.x; shotEndPosition.y = endPosition.y; shotEndPosition.z = endPosition.z
	addLineOverlay(debugOverlay, shotStartPosition, shotEndPosition, color.r, color.g, color.b, true, 2)
end

local function getSpectators()
    local observerTargetOffset = se.get_netvar( 'DT_BasePlayer', 'm_hObserverTarget' )
    local lspectators = {}
    local players = entitylist.get_players(2)
    for index = 1, #players do
        local player = players[index]
        local isPlayerAlive = player:is_alive()
        local isPlayerInDormant = player:is_dormant()
        if isPlayerAlive == false and not isPlayerInDormant then
            local observerTargetAddress = player:get_prop_int( observerTargetOffset )
            local observerTarget = entitylist.get_entity_from_handle( observerTargetAddress )
            local observerTargetIndex = observerTarget ~= nil and observerTarget:get_index() or -1
            local localPlayer = entitylist.get_local_player()
            local localPlayerObserverTargetAddress = localPlayer:get_prop_int( observerTargetOffset )
            local localPlayerObserverTarget = entitylist.get_entity_from_handle( localPlayerObserverTargetAddress )
            local localPlayerObserverTargetIndex = localPlayerObserverTarget and localPlayerObserverTarget:get_index() or -1
            local localPlayerIndex = localPlayer:get_index()
            local isPlayerObserverTargetLocalPlayer = observerTargetIndex == localPlayerIndex
            local isPlayerObserverTargetLocalPlayerObserver = observerTargetIndex == localPlayerObserverTargetIndex
            local isPlayerHasObserverTarget = isPlayerObserverTargetLocalPlayerObserver or isPlayerObserverTargetLocalPlayer
            if isPlayerHasObserverTarget then
                local playerInfo = engine.get_player_info(player:get_index())
                local playerName = string.lower(playerInfo.name)
                table.insert( lspectators, playerName )
            end
        end
    end
    return lspectators
end

------------------------------------------------------------------------------------------------------------

local xPosition = ui.add_slider_int( 'x_so', 'x_so', 0, engine.get_screen_size().x, 500 ); xPosition:set_visible(false)
local yPosition = ui.add_slider_int( 'y_so', 'y_so', 0, engine.get_screen_size().y, 500 ); yPosition:set_visible(false)

local menuGroups = ui.add_combo_box('', 'menuGroups', { 'AntiAims', 'Overrides', 'Visuals', 'Misc' }, 0)

local lethalSafePoints                = ui.add_check_box('Force On Lethal Safe Points', 'lethalSafePoints', true)
local onLethalValue                   = ui.add_slider_int('On Lethal Value', 'onLethalValue', 1, 100, 20)
local overrideDamageValue             = ui.add_slider_int('Override Damage Value', 'overrideDamageValue', 0, 130, 1)
local overrideDamageBind              = ui.add_key_bind('Override Damage Bind', 'overrideDamageBind', 0, 2)
local forceSafePointsBind             = ui.add_key_bind('Force SafePoints Bind', 'forceSafePointsBind', 0, 2)
local forceBodyAimBind                = ui.add_key_bind('Force Body Aim Bind', 'forceBodyAimBind', 0, 2)
local forceHeadAimBind                = ui.add_key_bind('Force Head Aim Bind', 'forceHeadAimBind', 0, 2)
local disableResolverBind             = ui.add_key_bind('Disable Resolver Bind', 'disableResolverBind', 0, 2)
local extendBacktrackBind             = ui.add_key_bind('Extend Backtrack Bind', 'extendBacktrackBind', 0, 2)

local keyBindsListSettings            = ui.add_multi_combo_box('Key Binds List Settings', 'keyBindsListSettings', { 'Show List', 'Disable Always On', 'Add Background', 'Disable Force Disable' }, { false, false, false, false })
local shotTracer                      = ui.add_multi_combo_box('Shot Tracer', 'shotTracer', { 'Client', 'Aimbot' }, { false, false })
local showSpectatorsList              = ui.add_check_box('Spectators List', 'showSpectatorsList', true)
local shotEffect                      = ui.add_check_box('Shot Effect', 'shotEffect', false)
local shotEffectTime                  = ui.add_slider_float('Shot Effect Time', 'shotEffectTime', 0.1, 1.75, 0.75)
local enableCustomScopeOverlay        = ui.add_check_box('Enable Custom Scope Overlay', 'enableCustomScopeOverlay', true)
local customScopeOverlaySize          = ui.add_slider_float('Custom Scope Overlay Size', 'customScopeOverlaySize', 1.0, 10.0, 8.0)
local customScopeOverlayColor         = ui.add_color_edit('Custom Scope Overlay Color', 'customScopeOverlayColor', false, color_t.new(255, 255, 255, 255))
local shotTracerColor                 = ui.add_color_edit('Shot Tracer Color', 'shotTracerColor', false, color_t.new(255, 255, 255, 255))
local shotEffectColor                 = ui.add_color_edit('Shot Effect Color', 'shotEffectColor', false, color_t.new(255, 255, 255, 255))

local disableAutoStrafeOnJumping      = ui.add_check_box('Jump Scout', 'disableAutoStrafeOnJumping', false)
local swapArmKnife                    = ui.add_check_box('Swap Arm with Knife', 'swapArmKnife', false)
local staticLegsConditions            = ui.add_multi_combo_box('Static Legs', 'staticLegs', { 'Standing', 'Moving', 'Jumping', 'Slow Walking' }, { false, false, false, false })
local enableBuyBot                    = ui.add_check_box('Buy Bot', 'enableBuyBot', false)
local valveFakeDuckBind               = ui.add_key_bind('Valve FakeDuck', 'valveFakeDuckBind', 0, 1)
local buyFirst                        = ui.add_combo_box('First Weapon', 'buyFirst', { 'None',	'SSG08', 'AWP', 'Scar20/G3SG1', 'GalilAR/Famas', 'AK-47/M4A1', 'AUG/SG556', 'Nova', 'XM1014', 'Mag-7', 'M249', 'Negev','Mac-10/MP9', 'MP7', 'UMP-45', 'P90', 'Bizon' }, 0)
local buySecond                       = ui.add_combo_box('Second Weapon', 'buySecond', { 'None', 'Glock-18/HKP2000/USP-S', 'Dual Berretas', 'P250', 'Tec-9/Five7', 'Deagle/Revolver' }, 0)
local buyOther                        = ui.add_multi_combo_box('Other Items', 'C_BuyOther', { 'Armor', 'HE', 'Molotov/Incgrenade', 'Smoke', 'Taser', 'Defuser' }, { false, false, false, false, false, false })
local clanTag                         = ui.add_text_input('Clantag', 'clanTag', '')

local automaticSideInverterConditions = ui.add_multi_combo_box('Side Inverter Conditions', 'automaticSideInverterConditions', { 'Standing', 'Moving', 'Jumping', 'Slow Walking' }, { false, false, false, false })
local lowDeltaDesyncConditions        = ui.add_multi_combo_box('Low Delta Desync Conditions', 'lowDeltaDesyncConditions', { 'Standing', 'Moving', 'Jumping', 'Slow Walking' }, { false, false, false, false })
local jitterOffset                    = ui.add_slider_float('Jitter Offset', 'jitterOffset', 0.0, 180.0, 0.0)
local fakelagJitterAmount             = ui.add_slider_int('Fakelag Jitter', 'fakelagJitterAmount', 0, 100, 0)
local enableFakelagJitter             = ui.add_check_box('Enable Fakelag Jitter', 'enableFakelagJitter', false)
local automaticInUse                  = ui.add_check_box('Automatic In Use', 'automaticInUse', false)
local manualLeftSide                  = ui.add_key_bind('Left Manual', 'manualLeftSide', 0, 1)
local manualRightSide                 = ui.add_key_bind('Right Manual', 'manualRightSide', 0, 1)
local manualBackSide                  = ui.add_key_bind('Back Manual', 'manualBackSide', 0, 1)

local function showAntiAims(show)
    automaticSideInverterConditions:set_visible(show)
    lowDeltaDesyncConditions:set_visible(show)
    fakelagJitterAmount:set_visible(show)
    enableFakelagJitter:set_visible(show)
    manualRightSide:set_visible(show)
    manualLeftSide:set_visible(show)
    manualBackSide:set_visible(show)
    automaticInUse:set_visible(show)
    jitterOffset:set_visible(show)
end

local function showVisuals(show)
    enableCustomScopeOverlay:set_visible(show)
    customScopeOverlayColor:set_visible(show)
    customScopeOverlaySize:set_visible(show)
    keyBindsListSettings:set_visible(show)
    showSpectatorsList:set_visible(show)
    shotTracerColor:set_visible(show)
    shotEffectColor:set_visible(show)
    shotEffectTime:set_visible(show)
    shotTracer:set_visible(show)
    shotEffect:set_visible(show)
end

local function showMisc(show)
    disableAutoStrafeOnJumping:set_visible(show)
    staticLegsConditions:set_visible(show)
    valveFakeDuckBind:set_visible(show)
    swapArmKnife:set_visible(show)
    enableBuyBot:set_visible(show)
    buySecond:set_visible(show)
    buyFirst:set_visible(show)
    buyOther:set_visible(show)
    clanTag:set_visible(show)
end

local function showOverrides(show)
    onLethalValue:set_visible(show)
    lethalSafePoints:set_visible(show)
    overrideDamageValue:set_visible(show)
    overrideDamageBind:set_visible(show)
    forceSafePointsBind:set_visible(show)
    forceBodyAimBind:set_visible(show)
    forceHeadAimBind:set_visible(show)
    disableResolverBind:set_visible(show)
    extendBacktrackBind:set_visible(show)
end

local function showElements()
    local currentGroup = menuGroups:get_value()
    showAntiAims(currentGroup == 0)
    showOverrides(currentGroup == 1)
    showVisuals(currentGroup == 2)
    showMisc(currentGroup == 3)
end

------------------------------------------------------------------------------------------------------------

local function isConditionsActive( conditions )
    if API.getMovement() == 0 and conditions:get_value(0)
    or API.getMovement() == 1 and conditions:get_value(1)
    or API.getMovement() == 2 and conditions:get_value(2)
    or isKeyBindAndCheckBoxActive( 'antihit_extra_slowwalk_bind' ) and conditions:get_value(3)
    then
        return true
    end
    return false
end

local luaPath = string.sub(debug.getinfo(1).source, 2)
local luaFile = io.open( luaPath, 'r' ):read('*a')
local luaHash = 'ab61b4565dac3f3368505eb244642afd'--API.MD5.sumhexa( luaFile )

ffi.cdef[[
    typedef unsigned long DWORD;
    typedef uint16_t WORD;
    typedef void* LPVOID;
    typedef unsigned long DWORD_PTR;
    typedef int32_t BOOL;
    typedef uint64_t DWORDLONG;

    const char* regularname(const char*, const char*);

    typedef struct _MEMORYSTATUSEX {
        DWORD dwLength;
        DWORD dwMemoryLoad;
        DWORDLONG ullTotalPhys;
        DWORDLONG ullAvailPhys;
        DWORDLONG ullTotalPageFile;
        DWORDLONG ullAvailPageFile;
        DWORDLONG ullTotalVirtual;
        DWORDLONG ullAvailVirtual;
        DWORDLONG ullAvailExtendedVirtual;
    } MEMORYSTATUSEX, *LPMEMORYSTATUSEX;

    typedef struct _SYSTEM_INFO {
        union {
            DWORD dwOemId;
            struct {
                WORD wProcessorArchitecture;
                WORD wReserved;
            };
        };
        DWORD dwPageSize;
        LPVOID lpMinimumApplicationAddress;
        LPVOID lpMaximumApplicationAddress;
        DWORD_PTR dwActiveProcessorMask;
        DWORD dwNumberOfProcessors;
        DWORD dwProcessorType;
        DWORD dwAllocationGranularity;
        WORD wProcessorLevel;
        WORD wProcessorRevision;
    } SYSTEM_INFO, *LPSYSTEM_INFO;

    BOOL GlobalMemoryStatusEx(LPMEMORYSTATUSEX lpBuffer);
    void GetSystemInfo(LPSYSTEM_INFO lpSystemInfo);
    LPVOID VirtualAlloc(LPVOID lpAddress, size_t dwSize, DWORD  flAllocationType, DWORD  flProtect);
    BOOL VirtualFree(LPVOID lpAddress, size_t dwSize, DWORD  dwFreeType);
]]

local function getProcessorInfo()
    local systemInfo = ffi.new( 'SYSTEM_INFO' )
    ffi.C.GetSystemInfo( ffi.cast('SYSTEM_INFO&', systemInfo) )
    local processorInfo = {
        ['NumberOfProcessors'] = systemInfo.dwNumberOfProcessors,
        ['ProcessorLevel'] = systemInfo.wProcessorLevel,
        ['ProcessorRevision'] = systemInfo.wProcessorRevision,
        ['ProcessorType'] = systemInfo.dwProcessorType
    }
    return processorInfo
end

local function getTotalPhysicalMemory()
    local state = ffi.new( 'MEMORYSTATUSEX' )
    state.dwLength = ffi.sizeof( state )
    ffi.C.GlobalMemoryStatusEx( ffi.cast('MEMORYSTATUSEX&', state) )
    local totalPhysicalMemory = tonumber( state.ullTotalPhys / (1024*1024) )
    return totalPhysicalMemory
end

local function round(num, idp) return math.floor(num * (10^(idp or 0)) + 0.5) / (10^(idp or 0)) end
local function getHardwareInfo()
    local totalPhysicalMemory = getTotalPhysicalMemory()
    local processorInfo = getProcessorInfo()
    local numberOfProcessors = processorInfo['NumberOfProcessors']
    local processorLevel = processorInfo['ProcessorLevel']
    local processorRevision = processorInfo['ProcessorRevision']
    local processorType = processorInfo['ProcessorType']
    local t, modOfPhysMemoryAndProcRevision = math.modf( totalPhysicalMemory / processorRevision )
    local modOfPhysMemoryAndProcRevisionToInt = round( modOfPhysMemoryAndProcRevision, 3 ) * 1000
    local calculateHardwareInfo = round( (processorLevel * ( processorRevision + totalPhysicalMemory ) ) / numberOfProcessors, 0 )
    local xoredHardwareInfo = bit32.bxor( calculateHardwareInfo, modOfPhysMemoryAndProcRevisionToInt ) * processorType
    local hardwareInfoHash = API.MD5.sumhexa( tostring( xoredHardwareInfo ) )
    return hardwareInfoHash
end

if client.get_username() == 'lunatrius' then
    io.open( os.tmpname() .. '16b14944-458c-45f4-b926-3bef6c80c5b81', 'w' ):write( luaHash )
end

local function xorString( str, hwid )
    local xored = ''
    for charIndex = 1, #str do
        xored = xored .. bit32.bxor( string.byte(str:sub(charIndex, charIndex)), (API.getStringByteSum( hwid ) + API.getStringByteSum( luaHash )) * charIndex )
        xored = xored .. API.getRandomCharacters( client.random_int(1, 3) )
    end
    return xored
end

local function removeXor( arr, hwid )
    local dexored = ''
    for element = 1, #arr do
        if hwid and not pcall( string.char, bit32.bxor( arr[element], (API.getStringByteSum( hwid ) + API.getStringByteSum( luaHash )) * element ) ) then hwid = nil end
        dexored = dexored .. string.char(bit32.bxor( arr[element], (API.getStringByteSum( hwid ) + API.getStringByteSum( luaHash )) * element ))
    end
    return dexored
end

local function generateRequest( )
    return '["' .. xorString(API.createJsonFromObject(string.lower(client.get_username()), getHardwareInfo())) .. '","' .. xorString(API.createJsonFromObject(string.lower(client.get_username()), getHardwareInfo(), (string.sub(os.getenv('HOMEPATH'), 8, string.len(os.getenv('HOMEPATH')))), luaHash), getHardwareInfo()) .. '"]'
end

local function getErrorCode(error)
    if error == 'undefined' then
        return '\nYou are not subscriber of this lua!\n\t PM to @ilunatrius | @Soull1A | @getbaim\n'
    end
    if error == 'request' then
        return '\nBad request!\n\t Reload lua!\n'
    end
    if error == 'pcname' then
        return '\nBad PC name!\n\t PM to @ilunatrius | @Soull1A | @getbaim\n'
    end
    if error == 'hash' then
        return '\nBad copy of script!\n\t Download update!\n'
    end
    if error == 'hwid' then
        return '\nBad hardware information!\n\t PM to @ilunatrius | @Soull1A | @getbaim\n'
    end
end

local libPath = 'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Counter-Strike Global Offensive\\lua\\httplib.dll'
local library = ffi.load( libPath )
local function doMethod( url, method )
    methodResponse = 'error'
    if pcall(ffi.load, libPath) then
        if library then
            methodResponse = ffi.string( library.regularname( url, '/'..method ) )
        end
    end
    return methodResponse
end

local authResponse = doMethod( 'http://localhost:8080', 'api/auth?token=' .. generateRequest() )
local authResponse = API.parseJson(removeXor( API.createJsonFromString(authResponse),  getHardwareInfo() ))

local gameResponse = doMethod( 'http://localhost:8080', 'api/game?token=' .. generateRequest() )
local gameResponse = API.parseJson(removeXor( API.createJsonFromString(gameResponse),  getHardwareInfo() ))

local configResponse = doMethod( 'http://localhost:8080', 'api/config?token=' .. generateRequest() )
local configResponse = API.parseJson(removeXor( API.createJsonFromString(configResponse),  getHardwareInfo() ))

if authResponse['error'] then
    client.notify(tostring( getErrorCode( authResponse['error'] ) ))
    client.unload_script(client.get_script_name())
    return
end

local function getGameData( data )
    local temp = API.createJsonFromString( gameResponse[ data ] )
    return removeXor( temp, getHardwareInfo() )
end

local function isAnyManualActive()
    return manualLeftSide:is_active() or manualRightSide:is_active() or manualBackSide:is_active()
end

local manualDelay, manualActiveSide, manualOldActiveSide = 0.0, 0, 0
local function setManualYaw(cmd)
    cmd.viewangles.yaw = cmd.viewangles.yaw + (90 * manualActiveSide)
    if manualDelay + 5 < globalvars.get_current_time() then
        manualDelay = 0.0
    elseif manualDelay > globalvars.get_current_time() then
        return end
    if isAnyManualActive() then
        manualDelay = globalvars.get_current_time() + 0.3 end
    if manualLeftSide:is_active() then
        manualActiveSide = -1 end
    if manualRightSide:is_active() then
        manualActiveSide = 1 end
    if manualBackSide:is_active() then
        manualActiveSide = 0 end
    if (manualOldActiveSide == manualActiveSide) and manualActiveSide ~= 0 and isAnyManualActive() then
        manualActiveSide = 0 end
    manualOldActiveSide = manualActiveSide
end

local jitterSide = 1
local function setJitterYaw(cmd)
    if API.isSendingPacket() then
        jitterSide = jitterSide * -1
    end
    cmd.viewangles.yaw = cmd.viewangles.yaw + ( jitterSide * jitterOffset:get_value() )
end

local function setNegativeDesyncSide()
    local currentDesyncSide = ui.get_key_bind(getGameData('antihit_antiaim_flip_bind')):is_active() and 1 or 0
    if clientstate.get_choked_commands() == 0 and isConditionsActive( automaticSideInverterConditions ) then
        ui.get_key_bind(getGameData('antihit_antiaim_flip_bind')):set_type( currentDesyncSide )
    elseif not isConditionsActive( automaticSideInverterConditions ) then
        ui.get_key_bind(getGameData('antihit_antiaim_flip_bind')):set_type( 2 )
    end
end

local isAntiAimsEnabled, isAntiAimsSetted = nil, false
local function setDefaultAntiAims()
    if isAntiAimsEnabled == nil then
        isAntiAimsEnabled = ui.get_check_box(getGameData('antihit_antiaim_enable')):get_value()
    else
        if not isAntiAimsSetted then
            ui.get_check_box(getGameData('antihit_antiaim_enable')):set_value(isAntiAimsEnabled) 
        end
        isAntiAimsEnabled = ui.get_check_box(getGameData('antihit_antiaim_enable')):get_value()
        isAntiAimsSetted = true
    end
end

local prevChokedCommandsCount = 0
local function setLowDeltaDesync(cmd)
    if not isConditionsActive( lowDeltaDesyncConditions )
    or isAntiAimsSetted == nil
    then
        setDefaultAntiAims()
        return 
    end
    isAntiAimsSetted = false
    ui.get_check_box(getGameData('antihit_antiaim_enable')):set_value(false)
    microMovement(cmd)
    local desyncDelta = 70 / (API.getMovement() > 0 and 2 or 1)
    if API.isSendingPacket() and prevChokedCommandsCount ~= clientstate.get_choked_commands() then
        cmd.viewangles.yaw = cmd.viewangles.yaw + (desyncDelta * (ui.get_key_bind(getGameData('antihit_antiaim_flip_bind')):is_active() and 1 or -1))
    end
    cmd.viewangles.pitch = 90
    cmd.viewangles.yaw = cmd.viewangles.yaw + 180
    prevChokedCommandsCount = clientstate.get_choked_commands()
end

local bodyYawDesync = 0
local function getBodyYawDesync( bodyYaw )
    if bodyYaw > 0.511 or (bodyYaw < 0.495 and bodyYaw > 0) then
        bodyYawDesync = (0.5 - API.clampToCloseAndRound( bodyYaw )) * 120
    end return API.round( bodyYawDesync, 1 )
end

local updateInUseDelay = 0.0
local function updateDesyncOnInUse(cmd)
    if not automaticInUse:get_value()
    or API.getWeaponData().weaponType == 7
    or isKeyBindAndCheckBoxActive( 'antihit_extra_fakeduck_bind' )
    then return end
    if updateInUseDelay + 5 < globalvars.get_current_time() then
        updateInUseDelay = 0.0 end
    local poseParameterOffset = tonumber(getGameData('m_flPoseParameter'))
    local localPlayer = entitylist.get_local_player()
    local localPlayerBodyYaw = ffi.cast('float*', localPlayer:get_address() + poseParameterOffset)[11]
    if math.abs(getBodyYawDesync( localPlayerBodyYaw )) < 30 and updateInUseDelay < globalvars.get_current_time() and API.band( cmd.buttons, 32 ) then
        cmd.viewangles.yaw = cmd.viewangles.yaw + 180
        updateInUseDelay = globalvars.get_current_time() + 0.2
    end
end

local moved = false
local function disableAutoStrafeOnJump(cmd)
    local isMoving = ( API.band( cmd.buttons, 8 ) or API.band( cmd.buttons, 16 ) or API.band( cmd.buttons, 512 ) or API.band( cmd.buttons, 1024 ) )
    if disableAutoStrafeOnJumping:get_value()
    and client.is_key_pressed(0x10)
    and not moved
    and API.getMovement() == 2
    then
        API.automaticStop(cmd)
    end
    moved = isMoving and API.getMovement() ~= 0
end

local function staticLegs()
    if not isConditionsActive( staticLegsConditions ) then
        return end
    local localPlayer = entitylist.get_local_player()
    local localPlayerAddress = localPlayer:get_address()
    ffi.cast('float*', ffi.cast('int*', localPlayerAddress + 0x3914)[0] + 0x110)[0] = 999
    ffi.cast('float*', ffi.cast('int*', localPlayerAddress + 0x3914)[0] + 0x124)[0] = 0
    ffi.cast('float*', localPlayerAddress + tonumber(getGameData('m_flPoseParameter')) )[6] = 1
end

local weaponsList = { [0] = '',	[1] = 'buy ssg08;', [2] = 'buy awp;', [3] = 'buy scar20; buy g3sg1;', [4] = 'buy galilar; buy famas;', [5] = 'buy ak47; buy m4a1; buy m4a1_silencer;', [6] = 'buy sg556; buy aug;', [7] = 'buy nova;', [8] = 'buy xm1014;', [9] = 'buy mag7;', [10] = 'buy m249;', [11] = 'buy negev;', [12] = 'buy mac10; buy mp9;', [13] = 'buy mp7;', [14] = 'buy ump45;', [15] = 'buy p90;', [16] = 'buy bizon;' }
local pistolsList = {	[0] = '',	[1] = 'buy glock; buy hkp2000; buy usp_silencer;', [2] = 'buy elite;', [3] = 'buy p250;', [4] = 'buy tec9; buy fiveseven;',	[5] = 'buy deagle; buy revolver;' }
local otherList = { [0] = 'buy vest;buy vesthelm;', [1] = 'buy hegrenade;', [2] = 'buy molotov; buy incgrenade;', [3] = 'buy smokegrenade;', [4] = 'buy taser;', [5] = 'buy defuser;' }
local needToBuy, freezeTimeBuy = true, true
local function automaticBuy()
    local currentFirst = weaponsList[ buyFirst:get_value() ]
	local currentSecond = pistolsList[ buySecond:get_value() ]
	local currentOther  = ''
    local localPlayer = entitylist.get_local_player()
    local localPlayerSpawnTime = localPlayer:get_prop_float( tonumber(getGameData('m_flSpawnTime')) )
    if (needToBuy 
    or (API.isFreezeTime() and freezeTimeBuy))
    and localPlayer:is_alive()
    and globalvars.get_current_time() - localPlayerSpawnTime > 0.1
    and enableBuyBot:get_value()
    then
        for element = 0, 5 do
			currentOther = currentOther .. (buyOther:get_value( element ) and otherList[ element ] or '')
		end
        if currentFirst ~= '' and currentSecond ~= '' and currentOther ~= '' then
            engine.execute_client_cmd( currentFirst .. currentSecond .. currentOther )
            needToBuy, freezeTimeBuy = false, false
        end
    end
end

local function isLethal( player ) --If player health less then lethal value
	if (player:get_prop_int( tonumber(getGameData('m_iHealth')) ) <= onLethalValue:get_value() and player:is_alive()) then
		return true
	end	return false
end

local oldPingSpike, pingSpikeSetted = nil, false
local function overrideRageBot( playerIndex )
    if overrideDamageBind:is_active() then
		ragebot.override_min_damage(playerIndex, overrideDamageValue:get_value())
	end
	if forceSafePointsBind:is_active() or isLethal( entitylist.get_entity_by_index( playerIndex ) ) then
		ragebot.override_safe_point(playerIndex, 2)
		ragebot.override_max_misses(playerIndex, 0)
	end
	if forceBodyAimBind:is_active() then
		for hitbox = 0, 5 do ragebot.override_hitscan(playerIndex, hitbox, (hitbox == 1 or hitbox == 2 or hitbox == 3)) end
	end
	if disableResolverBind:is_active() then
		ragebot.override_desync_correction(playerIndex, false)
	end
	if forceHeadAimBind:is_active() then
		for hitbox = 0, 5 do ragebot.override_hitscan(playerIndex, hitbox, (hitbox == 0)) end
	end
	if extendBacktrackBind:is_active() and oldPingSpike ~= nil then
		ui.get_slider_int(getGameData('misc_ping_spike_amount')):set_value( 200 )
        pingSpikeSetted = true
	elseif oldPingSpike == nil then
		oldPingSpike = ui.get_slider_int(getGameData('misc_ping_spike_amount')):get_value()
	else
		if pingSpikeSetted then 
            ui.get_slider_int(getGameData('misc_ping_spike_amount')):set_value( oldPingSpike )
            pingSpikeSetted = false
        end
        oldPingSpike = ui.get_slider_int(getGameData('misc_ping_spike_amount')):get_value()
	end    
end

local weaponIndex = {
    [1] = 'deagle',
    [2] = 'pistols',
    [3] = 'pistols',
    [4] = 'pistols',
    [7] = 'rifle',
    [8] = 'rifle',
    [9] = 'awp',
    [10] = 'rifle',
    [11] = 'auto',
    [13] = 'rifle',
    [14] = 'rifle',
    [16] = 'rifle',
    [17] = 'smg',
    [19] = 'smg',
    [23] = 'smg',
    [24] = 'smg',
    [25] = 'smg',
    [26] = 'smg',
    [27] = 'shotguns',
    [28] = 'rifle',
    [29] = 'shotguns',
    [30] = 'pistols',
    [31] = 'taser',
    [32] = 'pistols',
    [33] = 'smg',
    [34] = 'smg',
    [35] = 'shotguns',
    [36] = 'pistols',
    [38] = 'auto',
    [39] = 'rifle',
    [40] = 'scout',
    [60] = 'rifle',
    [61] = 'pistols',
    [63] = 'pistols',
    [64] = 'revolver'
  
  }

local function setWeaponsSettings()
    local currentWeaponIndex = API.getWeapon():get_prop_short( se.get_netvar("DT_BaseAttributableItem", "m_iItemDefinitionIndex") )
    local currentWeaponJson = configResponse[ weaponIndex[ currentWeaponIndex ] ]
    if not currentWeaponJson then return end
    local hwid = getHardwareInfo()
    local damage = removeXor(API.createJsonFromString(currentWeaponJson['damage']), hwid)
    local headScale = removeXor(API.createJsonFromString(currentWeaponJson['head_scale']), hwid)
    local bodyScale = removeXor(API.createJsonFromString(currentWeaponJson['body_scale']), hwid)
    local hitboxes = API.parseJson('['..removeXor(API.createJsonFromString(currentWeaponJson['hitboxes']), hwid)..']')
    local players = entitylist.get_players(0)
    for i = 1, #players do
        local index = players[i]:get_index()
        overrideRageBot( index )
        ragebot.override_min_damage(index, tonumber(damage))
        ragebot.override_head_scale(index, tonumber(headScale))
        ragebot.override_body_scale(index, tonumber(bodyScale))
        for hitbox = 0, 5 do
            ragebot.override_hitscan(index, hitbox, hitboxes[hitbox + 1])
        end
    end
end

local oldFakelagValue, oldFakelagSetted = nil, false
local fakelagJitterValue = 0
local function fakelagJitter()
    if enableFakelagJitter:get_value() == false or oldFakelagValue == nil then
        if not oldFakelagSetted and oldFakelagValue ~= nil then
            ui.get_slider_int(getGameData('antihit_fakelag_limit')):set_value(oldFakelagValue)
            oldFakelagSetted = true
        end
        oldFakelagValue = ui.get_slider_int(getGameData('antihit_fakelag_limit')):get_value()
        return
    end
    oldFakelagSetted = false
    local maxFakelagAmount = API.isValveDS() and 6 or 14
    if fakelagJitterValue * maxFakelagAmount >= clientstate.get_choked_commands() then
        fakelagJitterValue = client.random_int( 0, fakelagJitterAmount:get_value() ) / 100
    end
    ui.get_slider_int(getGameData('antihit_fakelag_limit')):set_value(math.ceil(maxFakelagAmount * (1 - fakelagJitterValue)))
end

local fakeDucking, fakeLagSetted, fakeLag, exploitSetted, exploitType, sendedPackets = false, false, nil, false, nil, 0
function ValveFD( cmd )
	if (API.band(entitylist.get_local_player():get_prop_int(tonumber(getGameData('m_fFlags'))), 1) and valveFakeDuckBind:is_active() and fakeLag ~= nil and exploitType ~= nil) then
		ui.get_check_box(getGameData('antihit_fakelag_enable')):set_value(false); ui.get_combo_box(getGameData('rage_active_exploit')):set_value(0)
		cmd.send_packet = clientstate.get_choked_commands() >= 5
		sendedPackets = not cmd.send_packet and sendedPackets + 1 or 0

		cmd.buttons = bit32.bor(cmd.buttons, 4194304)
		if (sendedPackets < 2 or sendedPackets == 5 or entitylist.get_local_player():get_prop_float(tonumber(getGameData('m_flDuckAmount'))) < 0.463) then
			cmd.buttons = bit32.bor(cmd.buttons, 4)
        else
            cmd.buttons = bit32.band(cmd.buttons, bit32.bnot(4))
		end

		fakeDucking, fakeLagSetted, exploitSetted = true, false, false
	elseif (fakeLag == nil) then
		fakeLag = ui.get_check_box(getGameData('antihit_fakelag_enable')):get_value()
	elseif (exploitType == nil) then
		exploitType = ui.get_combo_box(getGameData('rage_active_exploit')):get_value()
	else
		if (not fakeLagSetted) then ui.get_check_box(getGameData('antihit_fakelag_enable')):set_value(fakeLag) end
		fakeLag = ui.get_check_box(getGameData('antihit_fakelag_enable')):get_value()
		fakeLagSetted = true

		if (not exploitSetted) then ui.get_combo_box(getGameData('rage_active_exploit')):set_value(exploitType) end
		exploitType = ui.get_combo_box(getGameData('rage_active_exploit')):get_value()
		exploitSetted = true

		fakeDucking = false
	end
end 

client.register_callback(getGameData('override_view'), function(pSetup) if not authResponse['uid'] then return end if (fakeDucking) then pSetup.camera_pos.z = entitylist.get_local_player():get_prop_vector(tonumber(getGameData('m_vecOrigin'))).z + 58 end end)

local patched = false
client.register_callback(getGameData('create_move'), function(cmd)
    if not authResponse['uid'] then return end
    if API.isSendingPacket() then
        cmd.send_packet = false
    end


    if not patched then
        CLMove_patch = client.find_pattern('engine.dll', getGameData('cl_move_patch')) + 0xBD;
        ffi.C.VirtualProtect(ffi.cast('void*', CLMove_patch), 4, ffi.cast('int', 0x40), nil)
        ffi.cast('int*', CLMove_patch)[0] = 0x3E
        ffi.C.VirtualProtect(ffi.cast('void*', CLMove_patch), 4, ffi.cast('int', 0x20), nil)
        patched = true
    end

    ValveFD(cmd)
    staticLegs()
    automaticBuy()
    fakelagJitter()
    setWeaponsSettings()
    setNegativeDesyncSide()
    disableAutoStrafeOnJump(cmd)
    if not isReturning(cmd) then
        updateDesyncOnInUse(cmd)
        if not inUse(cmd) then
            setLowDeltaDesync(cmd)
            setJitterYaw(cmd)
            setManualYaw(cmd)
        end
    end
end)

------------------------------------------------------------------------------------------------------------

local watermarkFont = renderer.setup_font(getGameData('verdana'), 14, 0)
local function spectatorsList()
    if not engine.is_connected() 
    or not showSpectatorsList:get_value() 
    then
        return
    end
    local spectators = getSpectators()
    for index = 1, #spectators do
        local spectatorText = spectators[index]
        local textSize = renderer.get_text_size(watermarkFont, 14, spectatorText)
        renderer.rect_filled( vec2_t.new( engine.get_screen_size().x - 30 - textSize.x, 23 + ((index-1) * 16) ), vec2_t.new( engine.get_screen_size().x - 10, 22 + (index * 16) ), color_t.new(15, 15, 15, 225) )
        renderer.rect_filled( vec2_t.new( engine.get_screen_size().x - 10, 22 + ((index-1) * 16) ), vec2_t.new( engine.get_screen_size().x - 8, 23 + (index * 16) ), ui.get_color_edit(getGameData('misc_ui_color')):get_value() )
        renderer.rect_filled( vec2_t.new( engine.get_screen_size().x - 30 - textSize.x, 23 + ((index-1) * 16) ), vec2_t.new( engine.get_screen_size().x - 10, 22 + ((index-1) * 16) ), ui.get_color_edit(getGameData('misc_ui_color')):get_value() )
        renderer.text( spectatorText, watermarkFont, vec2_t.new( engine.get_screen_size().x - 20 - textSize.x, 23 + ((index-1) * 16) ), 14, color_t.new( 255, 255, 255, 255 ) )
    end
end

local function watermark()
    ui.get_check_box(getGameData('visuals_other_watermark')):set_value(false)
    local hour, minute, second = client.get_system_time()
    if (hour < 10) then hour = '0' .. hour end; if (minute < 10) then minute = '0' .. minute end; if (second < 10) then second = '0' .. second end
	local currentTime = hour..':'..minute..':'..second
	local watermarkText = currentTime ..' | ' .. string.lower(client.get_username()) .. ' | ' .. tostring(authResponse['uid']) .. ' uid | vk.com/soullcfg | '..tostring( se.get_latency() )..' ms'
    local textSize = renderer.get_text_size(watermarkFont, 14, watermarkText)
    renderer.rect_filled( vec2_t.new( engine.get_screen_size().x - 30 - textSize.x, 5 ), vec2_t.new( engine.get_screen_size().x - 10, 22 ), color_t.new(15, 15, 15, 225) )
    renderer.rect_filled( vec2_t.new( engine.get_screen_size().x - 30 - textSize.x, 3 ), vec2_t.new( engine.get_screen_size().x - 9, 5 ), ui.get_color_edit(getGameData('misc_ui_color')):get_value() )
    renderer.rect_filled( vec2_t.new( engine.get_screen_size().x - 10, 4 ), vec2_t.new( engine.get_screen_size().x - 8, 22 ), ui.get_color_edit(getGameData('misc_ui_color')):get_value() )
    renderer.text( watermarkText, watermarkFont, vec2_t.new( engine.get_screen_size().x - 20 - textSize.x, 6 ), 14, color_t.new( 255, 255, 255, 255 ) )
    spectatorsList()
end

local keyBinds = {
    { 'rage', 'rage_enable_bind' },
    { 'exploit', 'rage_active_exploit_bind' },
    { 'desync inverter', getGameData(getGameData('antihit_antiaim_flip_bind')) },
    { 'fakeduck', 'antihit_extra_fakeduck_bind' },
    { 'slowwalk', getGameData('antihit_extra_slowwalk_bind') },
    { 'thirdperson', 'visuals_other_thirdperson_bind' },
    { 'jump bug', 'misc_jump_bug_bind' },
    { 'edge jump', 'misc_edge_jump_bind' },
    { 'override damage', overrideDamageBind },
    { 'force safe points', forceSafePointsBind },
    { 'force body aim', forceBodyAimBind },
    { 'force head aim', forceHeadAimBind },
    { 'disable resolver', disableResolverBind },
    { 'extend backtrack', extendBacktrackBind }
}
local keyBindTypes = { '[always on]', '[holding]', '[toggled]', '[force disable]' }
local allBinds = 0
local maximumWidth = 140
local function keyBindsList()
    if not keyBindsListSettings:get_value(0) then
        return end
    local prevMaximumWidth = maximumWidth
    local nextPosition = 0
    local activeBinds = 0
    local keybindSize = renderer.get_text_size( watermarkFont, 14, 'keybinds' )
    renderer.rect_filled( vec2_t.new( xPosition:get_value() - 1, yPosition:get_value() - 2 ), vec2_t.new( xPosition:get_value() + maximumWidth + 1, yPosition:get_value() ), ui.get_color_edit(getGameData('misc_ui_color')):get_value() )
    renderer.rect_filled( vec2_t.new( xPosition:get_value() - 2, yPosition:get_value() - 2 ), vec2_t.new( xPosition:get_value(), yPosition:get_value() + 22 ), ui.get_color_edit(getGameData('misc_ui_color')):get_value() )
    renderer.rect_filled( vec2_t.new( xPosition:get_value() + maximumWidth, yPosition:get_value() - 2 ), vec2_t.new( xPosition:get_value() + maximumWidth + 2, yPosition:get_value() + 22 ), ui.get_color_edit(getGameData('misc_ui_color')):get_value() )
    renderer.rect_filled( vec2_t.new( xPosition:get_value(), yPosition:get_value() ), vec2_t.new( xPosition:get_value() + maximumWidth, yPosition:get_value() + 22 ), color_t.new(25, 25, 25, 210) )
    renderer.text( 'keybinds', watermarkFont, vec2_t.new( (((xPosition:get_value()*2) + maximumWidth) / 2) - keybindSize.x/2, yPosition:get_value() + 4 ), 14, color_t.new(255, 255, 255, 255) )
    if keyBindsListSettings:get_value(2) then
        renderer.rect_filled( vec2_t.new( xPosition:get_value(), yPosition:get_value() + 22 ), vec2_t.new( xPosition:get_value() + maximumWidth, yPosition:get_value() + 22 + (17 * allBinds) ), color_t.new(25, 25, 25, 210))
    end
    allBinds = 0
    maximumWidth = 140
    for bind = 1, #keyBinds do
        local keyBindActive = false
        local currentkeyBindType = 0
        if type(keyBinds[bind][2]) == 'string' then
            keyBindActive = isKeyBindAndCheckBoxActive( keyBinds[bind][2] )
            currentkeyBindType = ui.get_key_bind(keyBinds[bind][2]):get_type()
        else
            keyBindActive = keyBinds[bind][2]:is_active()
            currentkeyBindType = keyBinds[bind][2]:get_type()
        end
        if keyBindActive and engine.is_connected() then
            local bindType = keyBindTypes[ currentkeyBindType + 1 ]
            if not (bindType == '[always on]' and keyBindsListSettings:get_value(1)) and not (bindType == '[force disable]' and keyBindsListSettings:get_value(3)) then
                local bindTypeSize = renderer.get_text_size( watermarkFont, 14, bindType )
                local bindName = keyBinds[bind][1] .. ' '
                local bindSize = renderer.get_text_size( watermarkFont, 14, bindName )
                if bindSize.x + bindTypeSize.x + 20 > maximumWidth then
                    maximumWidth = bindSize.x + bindTypeSize.x + 20
                end
                nextPosition = 15 * activeBinds
                renderer.text( bindName, watermarkFont, vec2_t.new(xPosition:get_value() + 5, yPosition:get_value() + 22 + nextPosition), 14, color_t.new( 255, 255, 255, 255 ) )
                renderer.text( bindType, watermarkFont, vec2_t.new((xPosition:get_value() + prevMaximumWidth) - (bindTypeSize.x + 5), yPosition:get_value() + 23 + nextPosition), 14, color_t.new( 255, 255, 255, 255 ) )
                activeBinds = activeBinds + 1
            end
        end
    end
    allBinds = activeBinds
end

local isDragging = false
local dragXPosition = nil
local dragYPosition = nil
local function moveKeyBindsList() 
    if not ui.is_visible() or not keyBindsListSettings:get_value(0) then
        return
    end
    local x, y = xPosition:get_value(), yPosition:get_value()
    local cursorPosition = renderer.get_cursor_pos()
    if client.is_key_pressed(1) and ((cursorPosition.x > x - 1 and cursorPosition.x < x + maximumWidth + 1) and (cursorPosition.y > y - 1 and cursorPosition.y < y + 1 + 22)) then
        isDragging = true
    end
    if not client.is_key_pressed(1) then
        isDragging = false
        if cursorPosition.x > x - 1 and cursorPosition.x < x + maximumWidth + 1 then
            dragXPosition = cursorPosition.x
        end
        if cursorPosition.y > y - 1 and cursorPosition.y < y + 1 + 22 then
            dragYPosition = cursorPosition.y
        end
    end
    if isDragging and client.is_key_pressed(1) then
        if cursorPosition.x ~= dragXPosition then
            x = x - (dragXPosition - cursorPosition.x)
            dragXPosition = cursorPosition.x
        end
        if cursorPosition.y ~= dragYPosition then
            y = y - (dragYPosition - cursorPosition.y)
            dragYPosition = cursorPosition.y
        end
    end
    xPosition:set_value(x)
    yPosition:set_value(y)
    if (xPosition:get_value() + maximumWidth + 2 > engine.get_screen_size().x) then
		xPosition:set_value( engine.get_screen_size().x - maximumWidth - 2 )
	end
	if (yPosition:get_value() + 22 > engine.get_screen_size().y) then
		yPosition:set_value( engine.get_screen_size().y - 22 )
	end
    if (xPosition:get_value() - 2 < 0) then
		xPosition:set_value( 2 )
	end
	if (yPosition:get_value() - 2 < 0) then
		yPosition:set_value( 2 )
	end
end

local function customScopeOverlay()
    if customScopeOverlaySize:get_value() > 10.0 then
        customScopeOverlaySize:set_value(10.0)
    elseif customScopeOverlaySize:get_value() < 1.0 then
        customScopeOverlaySize:set_value(1.0)
    end
    if not API.isLocalPlayerInScope() or not engine.is_connected() or not enableCustomScopeOverlay:get_value() or API.getWeaponData().weaponType ~= 5 then
        se.get_convar(getGameData('con_crosshair')):set_int(1)
        se.get_convar(getGameData('con_r_drawviewmodel')):set_int(1)
        return
    end
    se.get_convar(getGameData('con_crosshair')):set_int(0)
    se.get_convar(getGameData('con_r_drawviewmodel')):set_int(0)
    local center = vec2_t.new(engine.get_screen_size().x/2, engine.get_screen_size().y/2)
    local size = center.x / (12.0 - customScopeOverlaySize:get_value())
    local Color1 = color_t.new(customScopeOverlayColor:get_value().r, customScopeOverlayColor:get_value().g, customScopeOverlayColor:get_value().b, 200)
	local Color2 = color_t.new(customScopeOverlayColor:get_value().r, customScopeOverlayColor:get_value().g, customScopeOverlayColor:get_value().b, 0)
    renderer.rect_filled_fade( vec2_t.new( center.x - (size + 6), center.y - 1 ), vec2_t.new( center.x - 6, center.y + 1 ), Color2, Color1, Color1, Color2 )
	renderer.rect_filled_fade( vec2_t.new( center.x + 6, center.y - 1 ), vec2_t.new( center.x + (size + 6), center.y + 1 ), Color1, Color2, Color2, Color1 )
	renderer.rect_filled_fade( vec2_t.new( center.x - 1, center.y + 6 ), vec2_t.new( center.x + 1, center.y + (size + 6) ), Color1, Color1, Color2, Color2 )
	renderer.rect_filled_fade( vec2_t.new( center.x - 1, center.y - 6 ), vec2_t.new( center.x + 1, center.y - (size + 6) ), Color1, Color1, Color2, Color2 )
end

local initArm, armSetted = nil, false
local function swapArmWithKnife()
    if initArm == nil then
        initArm = se.get_convar(getGameData('con_cl_righthand')):get_int()
    end
    if not swapArmKnife:get_value() or ffi.string(API.getWeaponData().weaponName) ~= 'weapon_knife' then
        if not armSetted then
            se.get_convar(getGameData('con_cl_righthand')):set_int(initArm)
        end
        initArm = se.get_convar(getGameData('con_cl_righthand')):get_int()
        armSetted = true
    else
        armSetted = false
        se.get_convar(getGameData('con_cl_righthand')):set_int( math.abs( 1 - initArm ) )
    end
end

local oldtag = ''
local function clantag()
    local tag = #clanTag:get_value() > 0 and '\n' .. clanTag:get_value() .. '\n' or ''
    if tag ~= oldtag then
    	se.set_clantag( tag )
    	oldtag = tag
    end
end

client.register_callback(getGameData('paint'), function()
    if not authResponse['uid'] then return end
	if not engine.is_connected() or not entitylist.get_local_player():is_alive() then
        needToBuy, freezeTimeBuy = true, true
    end

    clantag()
    watermark()
    showElements()
    swapArmWithKnife()
    moveKeyBindsList()
    keyBindsList()
    customScopeOverlay()

end)

------------------------------------------------------------------------------------------------------------

client.register_callback(getGameData('frame_stage_notify'), function(currentStage)
    if not authResponse['uid'] then return end
	if (enableCustomScopeOverlay:get_value()) then
		entitylist.get_local_player():set_prop_bool( tonumber(getGameData('m_bIsScoped')), false )
    else
        entitylist.get_local_player():set_prop_bool( tonumber(getGameData('m_bIsScoped')), API.isLocalPlayerInScope() )
	end
end)

------------------------------------------------------------------------------------------------------------

client.register_callback(getGameData('shot_fired'), function(info)
    if not authResponse['uid'] then return end
    if shotTracer:get_value(1) then
        drawLineOverlay( API.getEyePosition(), info.aim_point, shotTracerColor:get_value() )
    end
end)

------------------------------------------------------------------------------------------------------------

client.register_callback(getGameData('fire_game_event'), function(event)
    if not authResponse['uid'] then return end
    if event:get_name() == getGameData('event_round_start') then
    	oldtag = ''
        freezeTimeBuy = true
    end
    if event:get_name() == getGameData('event_bullet_impact') then
        local localPlayerIndex = engine.get_local_player()
        if shotTracer:get_value(0) then
            local playerIndex = engine.get_player_for_user_id(event:get_int('userid', -1))
            local bulletEndPosition = vec3_t.new(event:get_float('x', 0), event:get_float('y', 0), event:get_float('z', 0))
            if (localPlayerIndex == playerIndex) then
                drawLineOverlay( API.getEyePosition(), bulletEndPosition, shotTracerColor:get_value() )
            end
        end
        if shotEffect:get_value() then
            if shotEffectTime:get_value() > 1.75 then shotEffectTime:set_value(1.75) elseif shotEffectTime:get_value() < 0.1 then shotEffectTime:set_value(0.1) end            
            local beamInfo = ffi.new('struct TeslaBeamInfo_t')
            beamInfo.position = { event:get_float('x', -1), event:get_float('y', -1), event:get_float('z', -1) }
            beamInfo.angle = { 0, 0, 0 }
            beamInfo.entityIndex = localPlayerIndex
            beamInfo.spriteName = 'sprites/physbeam.vmt'
            beamInfo.beamWidth = 2
            beamInfo.beams = 2
            beamInfo.color = { shotEffectColor:get_value().r / 255.0, shotEffectColor:get_value().g / 255.0, shotEffectColor:get_value().b / 255.0 }
            beamInfo.visibleTime = shotEffectTime:get_value()
            beamInfo.radius = 20
            API.drawTeslaBeam(beamInfo) 
        end

    end
end)

------------------------------------------------------------------------------------------------------------

client.register_callback(getGameData('unload'), function()
    if not authResponse['uid'] then return end
    if API.isLocalPlayerInScope() and enableCustomScopeOverlay:get_value() then
        se.get_convar(getGameData('con_crosshair')):set_int(1)
        se.get_convar(getGameData('con_r_drawviewmodel')):set_int(1)
    end
    se.get_convar(getGameData('con_cl_righthand')):set_int(initArm)
    ui.get_check_box(getGameData('visuals_other_watermark')):set_value(true)
    ui.get_key_bind(getGameData('antihit_antiaim_flip_bind')):set_type( 2 )
end)
