local jsonSilentCall, jsonSilentCallResult = pcall(require, 'json')
local json = jsonSilentCall and jsonSilentCallResult or error('JSON not found!', 2)

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

    bool VirtualProtect(void* lpAddress, size_t dwSize, int flNewProtect, int* lpflOldProtect);

]]

API = { _version = '1.0' }
weaponDataCall = ffi.cast('int*(__thiscall*)(void*)', client.find_pattern('client.dll', '55 8B EC 81 EC ? ? ? ? 53 8B D9 56 57 8D 8B ? ? ? ? 85 C9 75 04'))
gameRules = ffi.cast('void***', client.find_pattern('client.dll', '8B 0D ?? ?? ?? ?? 85 C0 74 0A 8B 01 FF 50 78 83 C0 54') + 0x2)[0]
API.drawTeslaBeam = ffi.cast('void(__thiscall*)(struct TeslaBeamInfo_t&)', client.find_pattern('client.dll', '55 8B EC 81 EC ? ? ? ? 56 57 8B F9 8B 47 18'))
API.MD5 = (function() local a={}local b,c,d,e,f=string.char,string.byte,string.format,string.rep,string.sub;local g,h,i,j,k,l;local m,n=pcall(require,'bit')if m then g,h,i,j,k,l=n.bor,n.band,n.bnot,n.bxor,n.rshift,n.lshift else m,n=pcall(require,'bit32')if m then i=n.bnot;local o=function(p)return p<=0x7fffffff and p or-(i(p)+1)end;local q=function(r)return function(s,t)return o(r(o(s),o(t)))end end;g,h,j=q(n.bor),q(n.band),q(n.bxor)k,l=q(n.rshift),q(n.lshift)else local function u(v)local w=0;local x=1;for y=1,#v do w=w+v[y]*x;x=x*2 end;return w end;local function z(A,B)local C,D=A,B;if#C<#D then C,D=D,C end;for y=#D+1,#C do D[y]=0 end end;local E;i=function(p)local v=E(p)local F=math.max(#v,32)for y=1,F do if v[y]==1 then v[y]=0 else v[y]=1 end end;return u(v)end;E=function(p)if p<0 then return E(i(math.abs(p))+1)end;local v={}local G=1;local H;while p>0 do H=p%2;v[G]=H;p=(p-H)/2;G=G+1 end;return v end;g=function(I,p)local J=E(I)local K=E(p)z(J,K)local v={}for y=1,#J do if J[y]==0 and K[y]==0 then v[y]=0 else v[y]=1 end end;return u(v)end;h=function(I,p)local J=E(I)local K=E(p)z(J,K)local v={}for y=1,#J do if J[y]==0 or K[y]==0 then v[y]=0 else v[y]=1 end end;return u(v)end;j=function(I,p)local J=E(I)local K=E(p)z(J,K)local v={}for y=1,#J do if J[y]~=K[y]then v[y]=1 else v[y]=0 end end;return u(v)end;k=function(p,L)local M=0;if p<0 then p=i(math.abs(p))+1;M=0x80000000 end;local N=math.floor;for y=1,L do p=p/2;p=g(N(p),M)end;return N(p)end;l=function(p,L)if p<0 then p=i(math.abs(p))+1 end;for y=1,L do p=p*2 end;return h(p,0xFFFFFFFF)end end end;local function O(y)local r=function(P)return b(h(k(y,P),255))end;return r(0)..r(8)..r(16)..r(24)end;local function Q(P)local R=0;for y=1,#P do R=R*256+c(P,y)end;return R end;local function S(P)local R=0;for y=#P,1,-1 do R=R*256+c(P,y)end;return R end;local function T(P,...)local U,V=1,{}local W={...}for y=1,#W do table.insert(V,S(f(P,U,U+W[y]-1)))U=U+W[y]end;return V end;local X=function(Y)return Q(O(Y))end;local Z={0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,0x6b901122,0xfd987193,0xa679438e,0x49b40821,0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,0x289b7ec6,0xeaa127fa,0xd4ef3085,0x04881d05,0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391,0x67452301,0xefcdab89,0x98badcfe,0x10325476}local r=function(_,a0,a1)return g(h(_,a0),h(-_-1,a1))end;local a2=function(_,a0,a1)return g(h(_,a1),h(a0,-a1-1))end;local a3=function(_,a0,a1)return j(_,j(a0,a1))end;local y=function(_,a0,a1)return j(a0,g(_,-a1-1))end;local a1=function(a4,s,t,a5,a6,_,P,a7)s=h(s+a4(t,a5,a6)+_+a7,0xFFFFFFFF)return g(l(h(s,k(0xFFFFFFFF,P)),P),k(s,32-P))+t end;local function a8(a9,aa,ab,ac,ad)local s,t,a5,a6=a9,aa,ab,ac;local ae=Z;s=a1(r,s,t,a5,a6,ad[0],7,ae[1])a6=a1(r,a6,s,t,a5,ad[1],12,ae[2])a5=a1(r,a5,a6,s,t,ad[2],17,ae[3])t=a1(r,t,a5,a6,s,ad[3],22,ae[4])s=a1(r,s,t,a5,a6,ad[4],7,ae[5])a6=a1(r,a6,s,t,a5,ad[5],12,ae[6])a5=a1(r,a5,a6,s,t,ad[6],17,ae[7])t=a1(r,t,a5,a6,s,ad[7],22,ae[8])s=a1(r,s,t,a5,a6,ad[8],7,ae[9])a6=a1(r,a6,s,t,a5,ad[9],12,ae[10])a5=a1(r,a5,a6,s,t,ad[10],17,ae[11])t=a1(r,t,a5,a6,s,ad[11],22,ae[12])s=a1(r,s,t,a5,a6,ad[12],7,ae[13])a6=a1(r,a6,s,t,a5,ad[13],12,ae[14])a5=a1(r,a5,a6,s,t,ad[14],17,ae[15])t=a1(r,t,a5,a6,s,ad[15],22,ae[16])s=a1(a2,s,t,a5,a6,ad[1],5,ae[17])a6=a1(a2,a6,s,t,a5,ad[6],9,ae[18])a5=a1(a2,a5,a6,s,t,ad[11],14,ae[19])t=a1(a2,t,a5,a6,s,ad[0],20,ae[20])s=a1(a2,s,t,a5,a6,ad[5],5,ae[21])a6=a1(a2,a6,s,t,a5,ad[10],9,ae[22])a5=a1(a2,a5,a6,s,t,ad[15],14,ae[23])t=a1(a2,t,a5,a6,s,ad[4],20,ae[24])s=a1(a2,s,t,a5,a6,ad[9],5,ae[25])a6=a1(a2,a6,s,t,a5,ad[14],9,ae[26])a5=a1(a2,a5,a6,s,t,ad[3],14,ae[27])t=a1(a2,t,a5,a6,s,ad[8],20,ae[28])s=a1(a2,s,t,a5,a6,ad[13],5,ae[29])a6=a1(a2,a6,s,t,a5,ad[2],9,ae[30])a5=a1(a2,a5,a6,s,t,ad[7],14,ae[31])t=a1(a2,t,a5,a6,s,ad[12],20,ae[32])s=a1(a3,s,t,a5,a6,ad[5],4,ae[33])a6=a1(a3,a6,s,t,a5,ad[8],11,ae[34])a5=a1(a3,a5,a6,s,t,ad[11],16,ae[35])t=a1(a3,t,a5,a6,s,ad[14],23,ae[36])s=a1(a3,s,t,a5,a6,ad[1],4,ae[37])a6=a1(a3,a6,s,t,a5,ad[4],11,ae[38])a5=a1(a3,a5,a6,s,t,ad[7],16,ae[39])t=a1(a3,t,a5,a6,s,ad[10],23,ae[40])s=a1(a3,s,t,a5,a6,ad[13],4,ae[41])a6=a1(a3,a6,s,t,a5,ad[0],11,ae[42])a5=a1(a3,a5,a6,s,t,ad[3],16,ae[43])t=a1(a3,t,a5,a6,s,ad[6],23,ae[44])s=a1(a3,s,t,a5,a6,ad[9],4,ae[45])a6=a1(a3,a6,s,t,a5,ad[12],11,ae[46])a5=a1(a3,a5,a6,s,t,ad[15],16,ae[47])t=a1(a3,t,a5,a6,s,ad[2],23,ae[48])s=a1(y,s,t,a5,a6,ad[0],6,ae[49])a6=a1(y,a6,s,t,a5,ad[7],10,ae[50])a5=a1(y,a5,a6,s,t,ad[14],15,ae[51])t=a1(y,t,a5,a6,s,ad[5],21,ae[52])s=a1(y,s,t,a5,a6,ad[12],6,ae[53])a6=a1(y,a6,s,t,a5,ad[3],10,ae[54])a5=a1(y,a5,a6,s,t,ad[10],15,ae[55])t=a1(y,t,a5,a6,s,ad[1],21,ae[56])s=a1(y,s,t,a5,a6,ad[8],6,ae[57])a6=a1(y,a6,s,t,a5,ad[15],10,ae[58])a5=a1(y,a5,a6,s,t,ad[6],15,ae[59])t=a1(y,t,a5,a6,s,ad[13],21,ae[60])s=a1(y,s,t,a5,a6,ad[4],6,ae[61])a6=a1(y,a6,s,t,a5,ad[11],10,ae[62])a5=a1(y,a5,a6,s,t,ad[2],15,ae[63])t=a1(y,t,a5,a6,s,ad[9],21,ae[64])return h(a9+s,0xFFFFFFFF),h(aa+t,0xFFFFFFFF),h(ab+a5,0xFFFFFFFF),h(ac+a6,0xFFFFFFFF)end;local function af(self,P)self.pos=self.pos+#P;P=self.buf..P;for ag=1,#P-63,64 do local ad=T(f(P,ag,ag+63),4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4)assert(#ad==16)ad[0]=table.remove(ad,1)self.a,self.b,self.c,self.d=a8(self.a,self.b,self.c,self.d,ad)end;self.buf=f(P,math.floor(#P/64)*64+1,#P)return self end;local function ah(self)local ai=self.pos;local aj=56-ai%64;if ai%64>56 then aj=aj+64 end;if aj==0 then aj=64 end;local P=b(128)..e(b(0),aj-1)..O(h(8*ai,0xFFFFFFFF))..O(math.floor(ai/0x20000000))af(self,P)assert(self.pos%64==0)return O(self.a)..O(self.b)..O(self.c)..O(self.d)end;function a.new()return{a=Z[65],b=Z[66],c=Z[67],d=Z[68],pos=0,buf='',update=af,finish=ah}end;function a.tohex(P)return d('%08x%08x%08x%08x',Q(f(P,1,4)),Q(f(P,5,8)),Q(f(P,9,12)),Q(f(P,13,16)))end;function a.sum(P)return a.new():update(P):finish()end;function a.sumhexa(P)return a.tohex(a.sum(P))end;return a end)()


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

function API.getRandomCharacters( length )
    local randomSymbols = ''
    for count = 1, length do
        randomSymbols = randomSymbols .. ( string.char( string.byte('a') + client.random_int(0, 25) ) )
    end
    return randomSymbols
end

function API.getStringByteSum( str )
    if not str then str = 'none' end
    local sum = 0
    for charIndex = 1, #str do
        sum = sum + string.byte(str:sub(charIndex, charIndex))
    end
    return sum
end

function API.createJsonFromString( string )
    return json.decode('['..string:gsub( '%-?%a+', ',' )..']')
end

function API.createJsonFromObject( name, hwid, pcname, hash )
    local jsonData = {
        name = name,
        pcname = pcname,
        hwid = hwid,
        hash = hash,
    }
    return json.encode(jsonData)
end

function API.parseJson( jsonData )
    return json.decode( jsonData )
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