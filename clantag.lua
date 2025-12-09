-- clantag.lua or visuals.lua
local visuals = {}

function visuals.init(config)
    client.set_event_callback("paint", function()
        local sw, _ = client.screen_size()
        local local_player = entity.get_local_player()
        local steamname = entity.get_player_name(local_player)
        local hour, min = client.system_time()
        local timestr = string.format("%02d:%02d", hour, min)
        local msg = "[WRAITH.BETA | " .. timestr .. " | " .. steamname .. "]"
        if config.flex_mode then msg = msg .. " | FLEX MODE" end
        if config.needs_update then msg = msg .. " | Update!" end
        -- Watermark box
        renderer.rectangle(sw-#msg*7-28, 24, #msg*7+16, 30, 30,30,40,180)
        renderer.rectangle(sw-#msg*7-28, 24, #msg*7+16, 3, 180,0,255,255)
        renderer.text(sw-#msg*7-18, 28, 220,220,255,255, "", 0, msg)
    end)
end

return visuals
