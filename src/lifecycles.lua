local commands = require("commands")
local config = require("config")

local lifecycle_handler = {}

-- refresh device status in a period of time
function lifecycle_handler.init(driver, device)
    device.thread:call_on_schedule(
        config.SCHEDULE_PERIOD,
        function()
            return commands.refresh(nil, device)
        end,
        "refresh schedule"
    )
end

-- refresh device status when new device is added
function lifecycle_handler.added(driver, device)
    commands.refresh(nil, device)
end

-- handling device remove
function lifecycle_handler.removed(_, device)
    for timer in pairs(device.thread.timers) do
        device.thread:cancel_timer(timer)
    end
end

return lifecycle_handler