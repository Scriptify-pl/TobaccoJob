Bridge = Bridge or {}

local currentResource = GetCurrentResourceName()
local integrationEvent = ('%s:client:setIntegrations'):format(currentResource)
local integrationRequestEvent = ('%s:server:requestIntegrations'):format(currentResource)

Bridge.Ready = false
local frameworkCore

local function runningOnServer()
    return not not IsDuplicityVersion()
end

local function correctSide(expectServer, functionName)
    if runningOnServer() == expectServer then return true end
    debug(locale('debug_wrong_context', functionName))
    return false
end

local function hasIntegration(value, kind)
    if value then return true end
    debug(locale('debug_missing_integration', kind))
    return false
end

function Bridge.ApplyIntegrations(integrations)
    if type(integrations) ~= 'table' then return false end

    frameworkCore = nil
    Bridge.FrameworkName = integrations.framework
    Bridge.TargetName = integrations.target
    Bridge.InventoryName = integrations.inventory
    Bridge.NotifyName = integrations.notify
    Bridge.ClothingName = integrations.clothing
    Bridge.BossMenuName = integrations.bossmenu
    Bridge.Ready = true

    return true
end

function Bridge.Refresh()
    if not runningOnServer() then TriggerServerEvent(integrationRequestEvent) end
    return Bridge.GetIntegrations()
end

function Bridge.AwaitReady(timeout)
    if runningOnServer() or Bridge.Ready then return true end

    local expiresAt = GetGameTimer() + (timeout or 10000)
    local nextRequestAt = 0

    while not Bridge.Ready and GetGameTimer() < expiresAt do
        if GetGameTimer() >= nextRequestAt then
            Bridge.Refresh()
            nextRequestAt = GetGameTimer() + 1000
        end

        Wait(100)
    end

    if not Bridge.Ready then
        debug(locale('debug_bridge_sync_timeout'))
        return false
    end

    return true
end

function Bridge.GetIntegrations()
    return {
        framework = Bridge.FrameworkName,
        target = Bridge.TargetName,
        inventory = Bridge.InventoryName,
        notify = Bridge.NotifyName,
        clothing = Bridge.ClothingName,
        bossmenu = Bridge.BossMenuName
    }
end

Bridge.Callback = {}

function Bridge.Callback.Register(name, callback)
    lib.callback.register(name, callback)
end

function Bridge.Callback.Trigger(name, callback, ...)
    if not runningOnServer() then return lib.callback(name, false, callback, ...) end

    local arguments = { ... }
    local playerId = table.remove(arguments, 1)
    return lib.callback(name, playerId, callback, table.unpack(arguments))
end

function Bridge.Callback.Await(name, ...)
    if not runningOnServer() then return lib.callback.await(name, false, ...) end

    local arguments = { ... }
    local playerId = table.remove(arguments, 1)
    return lib.callback.await(name, playerId, table.unpack(arguments))
end

Bridge.Framework = {}

function Bridge.Framework.GetCore()
    if not hasIntegration(Bridge.FrameworkName, 'framework') then return end

    if Bridge.FrameworkName == 'esx' then
        frameworkCore = frameworkCore or exports.es_extended:getSharedObject()
        return frameworkCore
    end
end

function Bridge.Framework.GetPlayer(playerId)
    if not correctSide(true, 'Bridge.Framework.GetPlayer')
        or not hasIntegration(Bridge.FrameworkName, 'framework') then
        return
    end

    if Bridge.FrameworkName == 'esx' then
        local core = Bridge.Framework.GetCore()
        return core and core.GetPlayerFromId(playerId)
    end
end

function Bridge.Framework.GetPlayerData()
    if not correctSide(false, 'Bridge.Framework.GetPlayerData')
        or not hasIntegration(Bridge.FrameworkName, 'framework') then
        return
    end

    if Bridge.FrameworkName == 'esx' then
        local core = Bridge.Framework.GetCore()
        return core and core.GetPlayerData()
    end
end

function Bridge.Framework.GetJob(playerId)
    if runningOnServer() then
        local player = Bridge.Framework.GetPlayer(playerId)
        if not player then return end
        return player.job
    end

    local playerData = Bridge.Framework.GetPlayerData()
    return playerData and playerData.job
end

function Bridge.Framework.HasJob(jobName, playerId, minimumGrade)
    local job = Bridge.Framework.GetJob(playerId)
    if not job or job.name ~= jobName then return false end

    local grade = job.grade
    if type(grade) == 'table' then grade = grade.level end
    return (tonumber(grade) or 0) >= (minimumGrade or 0)
end

function Bridge.Framework.IsBoss(playerId)
    local job = Bridge.Framework.GetJob(playerId)
    if not job then return false end

    return job.isboss == true
        or job.grade_name == 'boss'
        or (type(job.grade) == 'table' and job.grade.name == 'boss')
end

function Bridge.Framework.AddMoney(playerId, account, amount, reason)
    if not correctSide(true, 'Bridge.Framework.AddMoney')
        or not hasIntegration(Bridge.FrameworkName, 'framework') then
        return false
    end

    local player = Bridge.Framework.GetPlayer(playerId)
    if not player then
        debug(locale('debug_player_not_found', playerId))
        return false
    end

    if Bridge.FrameworkName == 'esx' then
        if account == 'cash' or account == 'money' then
            player.addMoney(amount, reason)
        else
            player.addAccountMoney(account, amount, reason)
        end
        return true
    end

    return false
end

local esxNotifyTypes = { inform = 'info', warning = 'warning', success = 'success', error = 'error' }

function Bridge.Notify(message, notificationType, duration)
    if not correctSide(false, 'Bridge.Notify')
        or not hasIntegration(Bridge.NotifyName, 'notify') then
        return false
    end

    notificationType = notificationType or 'inform'
    duration = duration or 3000

    if Bridge.NotifyName == 'custom' then
        return Standalone.Notify(message, notificationType, duration)
    end
    if Bridge.NotifyName == 'ox_lib' then
        lib.notify({ description = message, type = notificationType, duration = duration })
        return true
    end
    if Bridge.NotifyName == 'esx_notify' then
        exports.esx_notify:Notify(esxNotifyTypes[notificationType] or 'info', duration, message)
        return true
    end
    return false
end

function Bridge.NotifyPlayer(playerId, message, notificationType, duration)
    if not correctSide(true, 'Bridge.NotifyPlayer') then return false end

    TriggerClientEvent(('%s:client:notify'):format(currentResource), playerId, {
        message = message,
        type = notificationType,
        duration = duration
    })
    return true
end

function Bridge.Framework.Notify(message, notificationType, duration)
    return Bridge.Notify(message, notificationType, duration)
end

if not runningOnServer() then
    RegisterNetEvent(integrationEvent, function(integrations)
        Bridge.ApplyIntegrations(integrations)
    end)

    RegisterNetEvent(('%s:client:notify'):format(currentResource), function(data)
        if data then Bridge.Notify(data.message, data.type, data.duration) end
    end)
end

Bridge.Inventory = Bridge.Inventory or {}

Bridge.Target = {}
local targetLabels = {}

local function convertTargetOptions(options)
    local converted = {}
    local maximumDistance = 0.0

    for i = 1, #options do
        local option = options[i]
        if option.name then targetLabels[option.name] = option.label end
        maximumDistance = math.max(maximumDistance, option.distance or 2.5)
        converted[i] = {
            icon = option.icon,
            label = option.label,
            job = option.groups,
            item = option.items,
            canInteract = option.canInteract,
            action = function(entity)
                if option.onSelect then option.onSelect({ entity = entity }) end
            end
        }
    end

    return { options = converted, distance = maximumDistance }
end

local function targetOptionLabels(optionNames)
    if type(optionNames) == 'table' then
        local labels = {}
        for i = 1, #optionNames do
            labels[i] = targetLabels[optionNames[i]] or optionNames[i]
        end
        return labels
    end

    return targetLabels[optionNames] or optionNames
end


local function targetReady(functionName)
    return correctSide(false, functionName) and hasIntegration(Bridge.TargetName, 'target')
end

function Bridge.Target.AddLocalEntity(entity, options)
    if not targetReady('Bridge.Target.AddLocalEntity') or not entity then return false end
    if Bridge.TargetName == 'custom' then return Standalone.Target.AddLocalEntity(entity, options) end
    if Bridge.TargetName == 'ox_target' then return exports.ox_target:addLocalEntity(entity, options) end

    local converted = convertTargetOptions(options)
    if Bridge.TargetName == 'qtarget' then return exports.qtarget:AddTargetEntity(entity, converted) end
    return false
end

function Bridge.Target.RemoveLocalEntity(entity, optionNames)
    if not targetReady('Bridge.Target.RemoveLocalEntity') or not entity then return false end
    if Bridge.TargetName == 'custom' then return Standalone.Target.RemoveLocalEntity(entity, optionNames) end
    if Bridge.TargetName == 'ox_target' then return exports.ox_target:removeLocalEntity(entity, optionNames) end
    local labels = targetOptionLabels(optionNames)
    if Bridge.TargetName == 'qtarget' then
        return exports.qtarget:RemoveTargetEntity(entity, labels)
    end
    return false
end

function Bridge.Target.AddModel(models, options)
    if not targetReady('Bridge.Target.AddModel') then return false end
    if Bridge.TargetName == 'custom' then return Standalone.Target.AddModel(models, options) end
    if Bridge.TargetName == 'ox_target' then return exports.ox_target:addModel(models, options) end

    local converted = convertTargetOptions(options)
    if Bridge.TargetName == 'qtarget' then return exports.qtarget:AddTargetModel(models, converted) end
    return false
end

function Bridge.Target.RemoveModel(models, optionNames)
    if not targetReady('Bridge.Target.RemoveModel') then return false end
    if Bridge.TargetName == 'custom' then return Standalone.Target.RemoveModel(models, optionNames) end
    if Bridge.TargetName == 'ox_target' then return exports.ox_target:removeModel(models, optionNames) end
    local labels = targetOptionLabels(optionNames)
    if Bridge.TargetName == 'qtarget' then
        return exports.qtarget:RemoveTargetModel(models, labels)
    end
    return false
end

function Bridge.Target.AddBoxZone(data, options)
    if not targetReady('Bridge.Target.AddBoxZone') then return false end
    if Bridge.TargetName == 'custom' then return Standalone.Target.AddBoxZone(data, options) end
    if Bridge.TargetName == 'ox_target' then
        return exports.ox_target:addBoxZone({
            name = data.name,
            coords = data.coords,
            size = data.size,
            rotation = data.rotation or 0.0,
            debug = Config.Debug,
            options = options
        })
    end

    local converted = convertTargetOptions(options)
    local zoneData = {
        name = data.name,
        heading = data.rotation or 0.0,
        debugPoly = Config.Debug,
        minZ = data.coords.z - (data.size.z / 2),
        maxZ = data.coords.z + (data.size.z / 2)
    }

    if Bridge.TargetName ~= 'qtarget' then return false end
    exports.qtarget:AddBoxZone(data.name, data.coords, data.size.x, data.size.y, zoneData, converted)
    return data.name
end

function Bridge.Target.RemoveZone(zone)
    if not targetReady('Bridge.Target.RemoveZone') or not zone then return false end
    if Bridge.TargetName == 'custom' then return Standalone.Target.RemoveZone(zone) end
    if Bridge.TargetName == 'ox_target' then return exports.ox_target:removeZone(zone) end
    if Bridge.TargetName == 'qtarget' then return exports.qtarget:RemoveZone(zone) end
    return false
end
