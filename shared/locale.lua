lib.locale()

function debug(message, ...)
    if not Config or Config.Debug ~= true then return end

    local side = IsDuplicityVersion() and 'server' or 'client'
    local formatted = tostring(message)

    if select('#', ...) > 0 then
        local success, result = pcall(string.format, formatted, ...)
        if success then
            formatted = result
        end
    end

    print(('[%s][%s] %s'):format(GetCurrentResourceName(), side, formatted))
end
