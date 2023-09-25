local socket = require("socket")
local config = require("config")
local log = require("log")

-- handling string response from DAIKIN thermostat
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

-- discover DAIKIN thermostat in the network with UDP broadcast
local function find_device()
	local udp = socket.udp()
	udp:setsockname("*", 0)
	udp:setoption("broadcast", true)
	udp:settimeout(config.udp_timeout)
	
	log.info("===== SCANNING NETWORK...")
	udp:sendto(config.udp_msg, config.udp_address, config.udp_port)
	
	local devices = {}
	local beginTime = os.time()
	while os.time() - beginTime < 5 do
		local raw, ip = udp:receivefrom()
		if raw then
			local device = response_handler(raw)
			device.IP = ip
			table.insert(devices, device)
		end
	end
	return devices
end

-- create device
local function create_device(driver, device)
	log.info("===== CREATING DEVICE...")
	
	local metadata = {
		type = config.DEVICE_TYPE,
		device_network_id = device.ssid,
		label = device.ssid,
		profile = config.DEVICE_PROFILE,
		manufacturer = config.DEVICE_MANUFACTURER,
		model = config.DEVICE_MODEL,
		vendor_provided_label = device.IP
	}

	return driver:try_create_device(metadata)
end

local disco = {}
function disco.start(driver, opts, cons)
    while true do
        local device_res = find_device()

        if device_res ~= nil then
            log.info("===== DEVICE FOUND IN NETWORK...")
            for _, device in ipairs(device_res) do
                log.info("DEVICE FOUND ON "..device.IP)
                create_device(driver, device)
            end
			return driver
        else
            log.error("===== DEVICE NOT FOUND IN NETWORK")
        end
    end
end
return disco