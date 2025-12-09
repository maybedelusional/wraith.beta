-- resolver.lua | WRAITH.BETA
local resolver = {}

resolver.modes = { "Adaptive", "Aggressive", "Defensive", "Brute" }
resolver.mode = "Adaptive"
resolver.misses = {}
resolver.memory = {}
resolver.max_miss = 2
resolver.anti_brute = {}

function resolver.switch_mode(player)
    local miss = resolver.misses[player] or 0
    if miss > resolver.max_miss then
        resolver.mode = "Brute"
        resolver.anti_brute[player] = true
    else
        resolver.mode = "Adaptive"
        resolver.anti_brute[player] = false
    end
end

function resolver.on_miss(e)
    local victim = client.userid_to_entindex(e.userid)
    resolver.misses[victim] = (resolver.misses[victim] or 0) + 1
    resolver.switch_mode(victim)
end

function resolver.on_hit(e)
    local victim = client.userid_to_entindex(e.userid)
    resolver.misses[victim] = 0
    resolver.memory[victim] = globals.tickcount() -- Example: "learns" this tick was a hit
    resolver.mode = "Adaptive"
end

function resolver.init()
    client.log("[WRAITH.BETA] Resolver loaded.")
    client.register_esp_flag("WRAITH.BETA", 180, 0, 255, function(ent)
        local miss = resolver.misses[ent] or 0
        if resolver.anti_brute[ent] then
            return "Brute("..miss..")"
        else
            return resolver.mode.."("..miss..")"
        end
    end)
    client.set_event_callback("player_hurt", resolver.on_hit)
    client.set_event_callback("aim_miss", resolver.on_miss)
end

return resolver
