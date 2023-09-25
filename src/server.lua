local lux = require("luxure")
local cosock = require("cosock").socket
local json = require("dkjson")

local hub_server = {}

function hub_server.start(driver)
    local server = lux.Server.new_with(cosock.tcp(), {env='debug'})

    driver:register_channel_handler(server.sock, function ()
        server:tick()
    end)
    
    server:post('/push-state', function (req, res)
        local body = json.decode(req:get_body())
        
        local device = driver:get_device_info(body.uuid)
        if body.mode then
            driver:mode(device, body.mode)
        elseif body.heatingSetpoint then
            driver:heatingSetpoint(device, tonumber(body.heatingSetpoint))
        elseif body.coolingSetpoint then
            driver:coolingSetpoint(device, tonumber(body.coolingSetpoint))
        end
        res:send('HTTP/1.1 200 OK')
    end)
    server:listen()
    driver.server = server
end

return hub_server