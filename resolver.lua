-- resolver.lua | WRAITH.BETA Premium Resolver

local resolver = {}

-- === SETTINGS ===
resolver.angles = {0, 58, -58, 90, -90, 180, 123, -123}
resolver.jitter_angles = {58, -58, 87, -87}
resolver.spin_angles = {0, 90, 180, -90}
resolver.max_miss = 2
resolver.memory_time = 120 -- seconds to remember best angle per enemy

-- === DATA TABLES ===
resolver.learning = {}        -- Per-SteamID: {angle, last_hit_time}
resolver.cycle = {}           -- Per-SteamID: current angle index
resolver.misses = {}          -- Per-entity: miss count
resolver.stats = {}           -- Per-SteamID: {hits, misses}
resolver.anti_brute = {}      -- Per-SteamID: true/false if in anti-brute mode

-- === UTILS ===
local function now() return globals.realtime() end

local function get_steamid(ent)
    return entity.get_steam64 and entity.get_steam64(ent) or tostring(ent)
end

-- === ANTI-AIM DETECTION ===
function resolver.detect_aa(ent)
    -- Super simple: if player yaw or velocity changes rapidly, assume jitter/spin
    -- Replace with more advanced logic if your Lua API supports reading player angles!
    local vel = {entity.get_prop(ent, "m_vecVelocity[0]") or 0, entity.get_prop(ent, "m_vecVelocity[1]") or 0}
    local speed = math.sqrt(vel[1]^2 + vel[2]^2)
    if speed > 350 then
        return "spin"
    elseif speed > 60 then
        return "jitter"
    else
        return "normal"
    end
end

-- === RESOLVER LOGIC ===
function resolver.get_angle(steamid, aa_type)
    -- Use learned angle if recent & working
    local mem = resolver.learning[steamid]
    if mem and now() - mem.last_hit_time < resolver.memory_time then
        return mem.angle, "learn"
    end
    -- If anti-brute active, pick random wild angle
    if resolver.anti_brute[steamid] then
        local idx = math.random(1, #resolver.angles)
        return resolver.angles[idx], "anti-brute"
    end
    -- Otherwise, cycle through angle table by AA type
    if aa_type == "jitter" then
        local idx = resolver.cycle[steamid] or 1
        return resolver.jitter_angles[((idx-1) % #resolver.jitter_angles)+1], "jitter"
    elseif aa_type == "spin" then
        local idx = resolver.cycle[steamid] or 1
        return resolver.spin_angles[((idx-1) % #resolver.spin_angles)+1], "spin"
    else
        local idx = resolver.cycle[steamid] or 1
        return resolver.angles[((idx-1) % #resolver.angles)+1], "brute"
    end
end

-- === HOOKS ===

-- Call this in your "aim_resolve" or equivalent event:
function resolver.on_resolve(ent)
    local steamid = get_steamid(ent)
    local aa_type = resolver.detect_aa(ent)
    local angle, mode = resolver.get_angle(steamid, aa_type)
    -- Actually set the resolver angle here (pseudo-code, depends on cheat API):
    -- entity.set_yaw(ent, angle) or whatever your base allows
    return angle, mode
end

-- On miss
function resolver.on_miss(e)
    local ent = client.userid_to_entindex(e.userid)
    if not entity.is_enemy(ent) then return end
    local steamid = get_steamid(ent)
    resolver.misses[ent] = (resolver.misses[ent] or 0) + 1
    resolver.stats[steamid] = resolver.stats[steamid] or {hits=0, misses=0}
    resolver.stats[steamid].misses = resolver.stats[steamid].misses + 1
    -- Only brute if miss reason is resolver
    if e.reason == "resolver" then
        resolver.cycle[steamid] = (resolver.cycle[steamid] or 1) + 1
        if resolver.misses[ent] >= resolver.max_miss then
            resolver.anti_brute[steamid] = true
        end
    end
end

-- On hit
function resolver.on_hit(e)
    local ent = client.userid_to_entindex(e.userid)
    if not entity.is_enemy(ent) then return end
    local steamid = get_steamid(ent)
    local idx = resolver.cycle[steamid] or 1
    local aa_type = resolver.detect_aa(ent)
    local angle, _ = resolver.get_angle(steamid, aa_type)
    -- Save as learned if legit
    resolver.learning[steamid] = {angle = angle, last_hit_time = now()}
    resolver.anti_brute[steamid] = false
    resolver.cycle[steamid] = 1
    resolver.misses[ent] = 0
    resolver.stats[steamid] = resolver.stats[steamid] or {hits=0, misses=0}
    resolver.stats[steamid].hits = resolver.stats[steamid].hits + 1
end

-- === VISUAL FEEDBACK ===

client.register_esp_flag("WRAITH.BETA", 180, 0, 255, function(ent)
    local steamid = get_steamid(ent)
    local mode = "adaptive"
    local miss = resolver.misses[ent] or 0
    if resolver.anti_brute[steamid] then
        mode = "anti-brute"
    elseif resolver.learning[steamid] and now() - resolver.learning[steamid].last_hit_time < resolver.memory_time then
        mode = "learn"
    else
        local aa_type = resolver.detect_aa(ent)
        mode = aa_type
    end
    return string.format("%s(%d)", mode, miss)
end)

-- === MODULE INIT ===
function resolver.init()
    client.log("[WRAITH.BETA] Advanced resolver loaded!")
    client.set_event_callback("player_hurt", resolver.on_hit)
    client.set_event_callback("aim_miss", resolver.on_miss)
    -- To actually resolve, call resolver.on_resolve(ent) in your shot logic
end

return resolver
