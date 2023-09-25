local config = {}

--constant for device metadata
config.DEVICE_PROFILE = "Thermostat.v1"
config.DEVICE_TYPE = "LAN"
config.DEVICE_MANUFACTURER = "DAIKIN"
config.DEVICE_MODEL = "BRP15B61"

--constant for discover use
config.udp_address = "255.255.255.255"
config.udp_port = 30050
config.udp_timeout = 2
config.udp_msg = "DAIKIN_UDP/common/basic_info"

--refresh period
config.SCHEDULE_PERIOD=30

return config