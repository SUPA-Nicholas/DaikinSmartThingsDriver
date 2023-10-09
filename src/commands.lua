local caps = require("st.capabilities")
local log = require("log")
local cosock = require "cosock"
local http = cosock.asyncify "socket.http"
local socket = cosock.asyncify "socket"
local config = require("config")

-- handling response from DAIKIN thermostat
local function response_handler(raw_res)
	local res = {}
	for var in string.gmatch(raw_res, "([^,]+)") do
		if var:match("([^=]+)=([^=]+)") ~= nil then
			local var_name, var_value = var:match("([^=]+)=([^=]+)")
			res[var_name] = var_value
		else
			res[var:match("([^=]+)")] = 'n/a'
		end
	end
	return res
end

-- trying to find device when device is not reachable
local function looking_for_device(device)
    local udp = socket:udp()
    udp:setsockname("*", 0)
	udp:setoption("broadcast", true)
	udp:settimeout(config.udp_timeout)

    log.error("device not reached")
    log.info("===== LOOKING FOR "..device.device_network_id.." IN NETWORK...")
	udp:sendto(config.udp_msg, config.udp_address, config.udp_port)

    local beginTime = os.time()
    local device_found = false
    while os.time() - beginTime < 5 do
        local raw, ip = udp:receivefrom()
        if raw then
            local res = response_handler(raw)
            if res.ssid == device.device_network_id then
                log.info("===== "..res.ssid.." FOUND, TRYING TO UPDATE IP ADDRESS")
                device_found = true
                log.info("===== PREVIOUS IP "..device.vendor_provided_label)
                log.info("===== CHANGING TO IP "..ip)
                device:try_update_metadata({vendor_provided_label = ip})
            end
        end
    end
    udp:close()
    if device_found == false then
        log.error("===== DEVICE MISSING IN NETWORK")
        device:offline()
    end
end

local command_handler = {}

-- status refresh function
function command_handler.refresh(_, device)
    local success, raw_data = command_handler.send_lan_command(
        device, nil)

    if success then
        local status = response_handler(raw_data)

        device:online()

        log.trace("Refreshing Power")
        if status.pow == "1" then
            device:emit_event(caps.switch.switch("on"))
            log.trace("Refreshing Mode")
            if status.mode == "0" then
                device:emit_event(caps.thermostatMode.thermostatMode("fanonly"))
            elseif status.mode == "1" then
                device:emit_event(caps.thermostatMode.thermostatMode("heat"))
            elseif status.mode == "2" then
                device:emit_event(caps.thermostatMode.thermostatMode("cool"))
            elseif status.mode == "7" then
                device:emit_event(caps.thermostatMode.thermostatMode("dryair"))
            end
        else
            device:emit_event(caps.switch.switch("off"))
            device:emit_event(caps.thermostatMode.thermostatMode("off"))
        end

        log.trace("Refreshing Heating Setpoint")
        device:emit_event(caps.thermostatHeatingSetpoint.heatingSetpoint({
            value = tonumber(status.dt1), unit = "C"}))

        log.trace("Refreshing Cooling Setpoint")
        device:emit_event(caps.thermostatCoolingSetpoint.coolingSetpoint({
            value = tonumber(status.dt2), unit = "C"}))
    else
        log.error("failed to poll device state")
    end
end

-- power control function
function command_handler.power(_, device, command)
    local pow
    
    if command.command == "on" then
        pow = "1"
    else
        pow = "0"
    end

    local get_success, raw = command_handler.send_lan_command(device, nil)
    if get_success then
        local status = response_handler(raw)
        status.pow = pow
        if status.pow == "1" then
            if status.stemp == status.dt1 then
                status.mode = "1"
            else
                status.mode = "2"
            end
        end
        local send_success = command_handler.send_lan_command(
            device,
            status)
        if send_success then
            if status.pow == "0" then
                device:emit_event(caps.thermostatMode.thermostatMode("off"))
            end
            return device:emit_event(caps.switch.switch(command.command))
        else
            log.error("pow setting fail")
        end
    else
        log.error("get current status fail, pow setting fail")
    end
end

-- mode changing function
function command_handler.mode(_, device, command)
    local pow, mode

    if command.args.mode == "off" then
        pow = "0"
    elseif command.args.mode == "fanonly" then
        pow = "1"
        mode = "0"
    elseif command.args.mode == "heat" then
        pow = "1"
        mode = "1"
    elseif command.args.mode == "cool" then
        pow = "1"
        mode = "2"
    elseif command.args.mode == "dryair" then
        pow = "1"
        mode = "7"
    end

    local get_success, raw = command_handler.send_lan_command(device, nil)
    if get_success then
        local status = response_handler(raw)
        status.pow = pow
        status.mode = mode
        if mode == "1" then
            status.stemp = status.dt1
        elseif mode == "2" then
            status.stemp = status.dt2
        end
        local send_success = command_handler.send_lan_command(
            device,
            status)
        if send_success then
            if status.pow == "0" then
                device:emit_event(caps.switch.switch("off"))
                return device:emit_event(caps.thermostatMode.thermostatMode("off"))
            elseif status.mode == "0" then
                device:emit_event(caps.switch.switch("on"))
                return device:emit_event(caps.thermostatMode.thermostatMode("fanonly"))
            elseif status.mode == "1" then
                device:emit_event(caps.switch.switch("on"))
                return device:emit_event(caps.thermostatMode.thermostatMode("heat"))
            elseif status.mode == "2" then
                device:emit_event(caps.switch.switch("on"))
                return device:emit_event(caps.thermostatMode.thermostatMode("cool"))
            elseif status.mode == "7" then
                device:emit_event(caps.switch.switch("on"))
                return device:emit_event(caps.thermostatMode.thermostatMode("dryair"))
            end
        else
            log.error("mode setting fail")
        end
    else
        log.error("get current status fail, mode setting fail")
    end
end

-- heating temperature changing function
function command_handler.heatingSetpoint(_, device, command)
    if command.args.setpoint >= 16 and command.args.setpoint <= 31 then
        local heating_setpoint = tostring(command.args.setpoint)

        local get_success, raw = command_handler.send_lan_command(device, nil)
        if get_success then
            local status = response_handler(raw)
            if status.mode == "1" then
                status.stemp = heating_setpoint
            else
                status.dt1 = heating_setpoint
            end
            local send_success = command_handler.send_lan_command(
                device,
                status)
            if send_success then
                return device:emit_event(caps.thermostatHeatingSetpoint.heatingSetpoint({
                    value = command.args.setpoint, unit = "C"}))
            else
                log.error("heating setpoint setting fail")
            end
        end
        log.error("get current status fail, heating setpoint setting fail")
    else
        log.error("unacceptable value")
    end
end

-- cooling temperature changing function
function command_handler.coolingSetpoint(_, device, command)
    if command.args.setpoint >= 17 and command.args.setpoint <= 32 then
        local cooling_setpoint = tostring(command.args.setpoint)

        local get_success, raw = command_handler.send_lan_command(device, nil)
        if get_success then
            local status = response_handler(raw)
            if status.mode == "2" then
                status.stemp = cooling_setpoint
            else
                status.dt2 = cooling_setpoint
            end
            local send_success = command_handler.send_lan_command(
                device,
                status)
            if send_success then
                return device:emit_event(caps.thermostatCoolingSetpoint.coolingSetpoint({
                    value = command.args.setpoint, unit = "C"}))
            else
                log.error("cooling setpoint setting fail")
            end
        end
        log.error("get current status fail, cooling setpoint setting fail")
    else
        log.error("unacceptable value")
    end
end

-- function for sending TCP command to DAIKIN thermostat
function command_handler.send_lan_command(device, status)
    log.info("===== SENDING COMMAND...")
    local command
    if status ~= nil then
        command = string.format(
            "GET /skyfi/aircon/set_control_info?pow=%d&mode=%d&stemp=%d&dt1=%d&dt2=%d&f_rate=%d&f_dir=%d \r\nHost: %s\r\n\r\n",
            status.pow, status.mode, status.stemp, status.dt1, status.dt2, status.f_rate, status.f_dir, device.vendor_provided_label)
    else
        command = string.format(
            "GET /skyfi/aircon/get_control_info \r\nHost: %s\r\n\r\n",
            device.vendor_provided_label)
    end

    local http_send = socket.connect(device.vendor_provided_label, 80)
    -- testing if TCP connection is created successful
    if http_send ~= nil then
        http_send:send(command)
        local raw_res = http_send:receive("*a")
        local code, res_body
        for line in string.gmatch(raw_res, "([^\r\n]+)") do
            if line:sub(1, 4) == "HTTP" then
                code = tonumber(line:sub(10, 12))
                if code ~= 200 then
                    break
                end
            elseif line:sub(1, 3) == "ret" then
                res_body = line
            end
        end
        http_send:close()

        if code == 200 then
            -- testing if the received response is valid
            if res_body ~= nil then
                return true, res_body
            else
                looking_for_device(device)
                return false, nil
            end
        end
        return false, nil
    else
        looking_for_device(device)
        return false, nil
    end
end

return command_handler