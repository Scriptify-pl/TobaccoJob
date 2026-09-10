local actionCooldowns = {}
local stashRegistered = false
local societyRegistered = false

local function response(success, messageKey, notificationType, extra, messageArgs)
    local result = extra or {}
    result.success = success
    result.messageKey = messageKey
    result.messageArgs = messageArgs
    result.type = notificationType or (success and 'success' or 'error')
    return result
end

local function inventoryFailure(playerId, itemName, reason, fallbackKey)
    reason = reason or 'unknown'
    debug(locale('debug_inventory_failure', reason, itemName, playerId))

    if reason == 'invalid_item' then
        return response(false, 'error_inventory_item_missing', nil, nil, { itemName })
    end

    if reason == 'invalid_inventory' then
        return response(false, 'error_inventory_unavailable')
    end

    if reason == 'inventory_full' then
        return response(false, 'error_inventory_full')
    end

    return response(false, fallbackKey)
end

local translatedStashData

local function translatedStash()
    if translatedStashData then return translatedStashData end

    local stash = {}
    for key, value in pairs(Config.Stash) do stash[key] = value end
    stash.label = Config.Stash.label
    translatedStashData = stash
    return translatedStashData
end

local function isNear(playerId, coords, maximumDistance)
    local ped = GetPlayerPed(playerId)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - coords) <= maximumDistance
end

local function canUseJob(playerId)
    return Config.Job.required == false
        or Bridge.Framework.HasJob(Config.Job.name, playerId)
end

local function validateAction(playerId, actionName)
    local action = Config.Actions[actionName]
    if not action then
        return false, response(false, 'error_invalid_action')
    end

    if not canUseJob(playerId) then
        return false, response(false, 'error_not_employee')
    end

    local validLocation

    if actionName == 'gather' then
        validLocation = isNear(playerId, action.area.coords, action.area.radius)
    elseif actionName == 'sell' then
        validLocation = isNear(playerId, Config.Peds.seller.coords.xyz, action.distance + 2.0)
    else
        validLocation = isNear(playerId, action.target.coords, action.distance + 2.0)
    end

    if not validLocation then
        return false, response(false, 'error_too_far')
    end

    local now = GetGameTimer()
    actionCooldowns[playerId] = actionCooldowns[playerId] or {}
    local availableAt = actionCooldowns[playerId][actionName] or 0

    if now < availableAt then
        return false, response(false, 'error_cooldown', 'warning')
    end

    actionCooldowns[playerId][actionName] = now + math.max(action.duration - 500, 1000)
    return true, action
end

local function giveOutput(playerId, output)
    if output.maximum
        and Bridge.Inventory.GetItemCount(playerId, output.item) + output.count > output.maximum then
        return response(false, 'error_item_limit')
    end

    local canCarry, carryReason = Bridge.Inventory.CanCarryItem(
        playerId,
        output.item,
        output.count
    )
    if not canCarry then
        return inventoryFailure(playerId, output.item, carryReason, 'error_add_item')
    end

    local success, addReason = Bridge.Inventory.AddItem(playerId, output.item, output.count)
    if not success then
        return inventoryFailure(playerId, output.item, addReason, 'error_add_item')
    end

    return response(true, 'success_item_received')
end

local function processItems(playerId, action)
    if Bridge.Inventory.GetItemCount(playerId, action.input.item) < action.input.count then
        return response(false, 'error_missing_items')
    end

    if action.output.maximum
        and Bridge.Inventory.GetItemCount(playerId, action.output.item) + action.output.count
            > action.output.maximum then
        return response(false, 'error_product_limit')
    end

    local canCarry, carryReason = Bridge.Inventory.CanCarryItem(
        playerId,
        action.output.item,
        action.output.count
    )
    if not canCarry then
        return inventoryFailure(playerId, action.output.item, carryReason, 'error_add_product')
    end

    if not Bridge.Inventory.RemoveItem(playerId, action.input.item, action.input.count) then
        return response(false, 'error_remove_ingredients')
    end

    local added, addReason = Bridge.Inventory.AddItem(
        playerId,
        action.output.item,
        action.output.count
    )
    if not added then
        Bridge.Inventory.AddItem(playerId, action.input.item, action.input.count)
        return inventoryFailure(playerId, action.output.item, addReason, 'error_add_product')
    end

    return response(true, 'success_production')
end

Bridge.Callback.Register('sc_tobaccojob:server:performAction', function(playerId, actionName)
    local valid, action = validateAction(playerId, actionName)
    if not valid then return action end

    if actionName == 'gather' then
        return giveOutput(playerId, action.output)
    end

    if actionName == 'process' or actionName == 'pack' then
        return processItems(playerId, action)
    end

    if actionName == 'sell' then
        if Bridge.Inventory.GetItemCount(playerId, action.input.item) < action.input.count then
            return response(false, 'error_missing_pack')
        end

        if not Bridge.Inventory.RemoveItem(playerId, action.input.item, action.input.count) then
            return response(false, 'error_remove_pack')
        end

        local payment = math.random(action.payment.minimum, action.payment.maximum)

        if not Bridge.Framework.AddMoney(
            playerId,
            action.payment.account,
            payment,
            'tobacco-job-sale'
        ) then
            Bridge.Inventory.AddItem(playerId, action.input.item, action.input.count)
            return response(false, 'error_payment')
        end

        return response(true, 'success_sale', nil, nil, { payment })
    end

    return response(false, 'error_unsupported_action')
end)

Bridge.Callback.Register('sc_tobaccojob:server:openStash', function(playerId)
    if not canUseJob(playerId)
        or not isNear(playerId, Config.Stash.target.coords, 5.0) then
        return response(false, 'error_stash_access')
    end

    if Bridge.InventoryName == 'ox_inventory' then
        return response(true, nil, nil, { openClient = true })
    end

    if Bridge.InventoryName == 'custom' then
        local success = Standalone.Inventory.OpenStash(playerId, translatedStash())
        return response(success == true, success and nil or 'error_stash_open')
    end

    return response(false, 'error_stash_unsupported')
end)

local function registerStash()
    if stashRegistered then return end

    if Bridge.InventoryName == 'ox_inventory' then
        local groups
        if Config.Job.required ~= false then
            groups = { [Config.Job.name] = 0 }
        end

        exports.ox_inventory:RegisterStash(
            Config.Stash.id,
            Config.Stash.label,
            Config.Stash.slots,
            Config.Stash.weight,
            false,
            groups
        )
        stashRegistered = true
    elseif Bridge.InventoryName == 'custom' then
        stashRegistered = Standalone.Inventory.RegisterStash(translatedStash()) == true
    end
end

local function registerSociety()
    if societyRegistered
        or Bridge.BossMenuName ~= 'esx_society'
        or GetResourceState('esx_society') ~= 'started' then
        return
    end

    TriggerEvent(
        'esx_society:registerSociety',
        Config.Job.name,
        Config.Job.label,
        ('society_%s'):format(Config.Job.name),
        ('society_%s'):format(Config.Job.name),
        ('society_%s'):format(Config.Job.name),
        { type = 'private' }
    )
    societyRegistered = true
end

CreateThread(function()
    Wait(1000)
    registerStash()
    registerSociety()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'ox_inventory' then
        stashRegistered = false
    elseif resourceName == 'esx_society' then
        societyRegistered = false
    else
        return
    end

    Wait(500)

    if resourceName == 'ox_inventory' then
        registerStash()
    else
        registerSociety()
    end
end)

AddEventHandler('playerDropped', function()
    actionCooldowns[source] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == 'ox_inventory' then
        stashRegistered = false
    elseif resourceName == 'esx_society' then
        societyRegistered = false
    end
end)
