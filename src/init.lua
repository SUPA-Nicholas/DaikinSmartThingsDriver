local Driver = require("st.driver")
local caps = require("st.capabilities")

local discovery = require("discovery")
local lifecycles = require("lifecycles")
local commands = require("commands")
local server = require("server")

-- declare driver object
local driver = Driver(
    "DAIKIN-Thermostat",
    {
        discovery = discovery.start,
        lifecycle_handlers = lifecycles,
        supported_capabilities = {
            caps.thermostatMode(),
            caps.thermostatHeatingSetpoint(),
            caps.thermostatCoolingSetpoint(),
            caps.refresh()
        },
        capability_handlers = {
            [caps.thermostatMode.ID] = {
                [caps.thermostatMode.commands.setThermostatMode.NAME] = commands.mode
            },
            [caps.thermostatHeatingSetpoint.ID] = {
                [caps.thermostatHeatingSetpoint.commands.setHeatingSetpoint.NAME] = commands.heatingSetpoint
            },
            [caps.thermostatCoolingSetpoint.ID] = {
                [caps.thermostatCoolingSetpoint.commands.setCoolingSetpoint.NAME] = commands.coolingSetpoint
            },
            [caps.refresh.ID] = {
                [caps.refresh.commands.refresh.NAME] = commands.refresh
            }
        }
    }
)

function driver:mode(device, mode)
    return device:emit_event(caps.thermostatMode.thermostatMode(mode))
end

function driver:heatingSetpoint(device, heating_setpoint)
    return device:emit_event(caps.thermostatHeatingSetpoint.heatingSetpoint(heating_setpoint))
end

function driver:coolingSetpoint(device, cooling_setpoint)
    return device:emit_event(caps.thermostatCoolingSetpoint.coolingSetpoint(cooling_setpoint))
end

server.start(driver)

driver:run()