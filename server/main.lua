local actionCooldowns = {}
local activeBossMenus = {}
local confirmedBossMenus = {}
local bossMenuReservationTokens = {}
local saleSequence = 0
local activeSale
local sellerPed
local vehiclePed
local sellerBusyEvent = 'sc_tobaccojob:client:setSellerBusy'
local sellerAnimationEvent = 'sc_tobaccojob:client:playSellerAnimation'
local bossMenuStateEvent = 'sc_tobaccojob:client:setBossMenuState'
local bossMenuAnimationEvent = 'sc_tobaccojob:client:playBossMenuAnimation'
local stashRegistered = false
local societyRegistered = false

local bossMenuAnimations = {
    enter_chair = true,
    computer_enter_chair = true,
    computer_exit_chair = true,
    exit_chair = true
}

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

local function getBossMenu(bossMenuId)
    bossMenuId = tonumber(bossMenuId)
    if not bossMenuId or not Config.BossMenus[bossMenuId] then return end
    return bossMenuId, Config.BossMenus[bossMenuId]
end

local function setBossMenuOwner(bossMenuId, playerId)
    bossMenuReservationTokens[bossMenuId] =
        (bossMenuReservationTokens[bossMenuId] or 0) + 1
    activeBossMenus[bossMenuId] = playerId
    if not playerId then confirmedBossMenus[bossMenuId] = nil end
    TriggerClientEvent(bossMenuStateEvent, -1, bossMenuId, playerId)
end

local function canUseBossMenu(playerId, bossMenu)
    return Bridge.Framework.HasJob(Config.Job.name, playerId)
        and Bridge.Framework.IsBoss(playerId)
        and isNear(playerId, bossMenu.table.coords.xyz, 5.0)
end

local function broadcastBossMenuAnimation(playerId, bossMenuId, animationName)
    local bossMenu = Config.BossMenus[bossMenuId]
    local coords = bossMenu.table.coords.xyz

    for _, target in ipairs(GetPlayers()) do
        local targetId = tonumber(target)
        if targetId ~= playerId and isNear(targetId, coords, 50.0) then
            TriggerClientEvent(
                bossMenuAnimationEvent,
                targetId,
                bossMenuId,
                animationName,
                playerId
            )
        end
    end
end

local function createNetworkPed(ped, data, heightOffset)
    if ped and DoesEntityExist(ped) then return ped end

    ped = CreatePed(
        4,
        data.model,
        data.coords.x,
        data.coords.y,
        data.coords.z + heightOffset,
        data.coords.w,
        true,
        true
    )

    if not ped or ped == 0 or not DoesEntityExist(ped) then
        debug(locale('debug_ped_create_failed', tostring(data.model)))
        return
    end

    if SetEntityOrphanMode then SetEntityOrphanMode(ped, 2) end
    if FreezeEntityPosition then FreezeEntityPosition(ped, true) end
    if SetEntityInvincible then SetEntityInvincible(ped, true) end
    if SetBlockingOfNonTemporaryEvents then
        SetBlockingOfNonTemporaryEvents(ped, true)
    end
    return ped
end

local function createSellerPed()
    sellerPed = createNetworkPed(sellerPed, Config.Peds.seller, 0.9)
    return sellerPed
end

local function createVehiclePed()
    vehiclePed = createNetworkPed(vehiclePed, Config.Peds.vehicle, 0.8)
    return vehiclePed
end

local function setActiveSale(transaction)
    activeSale = transaction
    TriggerClientEvent(
        sellerBusyEvent,
        -1,
        transaction ~= nil,
        transaction and transaction.playerId or nil
    )
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
    if actionName == 'sell' then
        return response(false, 'error_unsupported_action')
    end

    local valid, action = validateAction(playerId, actionName)
    if not valid then return action end

    if actionName == 'gather' then
        return giveOutput(playerId, action.output)
    end

    if actionName == 'process' or actionName == 'pack' then
        return processItems(playerId, action)
    end

    return response(false, 'error_unsupported_action')
end)

local function getNetworkId(ped)
    if not ped then return end

    local networkId = NetworkGetNetworkIdFromEntity(ped)
    local timeout = GetGameTimer() + 2000

    while (not networkId or networkId == 0) and GetGameTimer() < timeout do
        Wait(25)
        networkId = NetworkGetNetworkIdFromEntity(ped)
    end

    if networkId and networkId ~= 0 then return networkId end
end

Bridge.Callback.Register('sc_tobaccojob:server:getPeds', function()
    local seller = createSellerPed()
    local vehicleWorker = createVehiclePed()
    if not seller or not vehicleWorker then return end

    local sellerNetworkId = getNetworkId(seller)
    local vehicleNetworkId = getNetworkId(vehicleWorker)
    if not sellerNetworkId or not vehicleNetworkId then return end

    return {
        sellerNetworkId = sellerNetworkId,
        vehicleNetworkId = vehicleNetworkId,
        busy = activeSale ~= nil
    }
end)

Bridge.Callback.Register('sc_tobaccojob:server:getBossMenuStates', function()
    local states = {}

    for bossMenuId, playerId in pairs(activeBossMenus) do
        if GetPlayerName(playerId) then
            states[bossMenuId] = playerId
        else
            setBossMenuOwner(bossMenuId, nil)
        end
    end

    return states
end)

Bridge.Callback.Register('sc_tobaccojob:server:reserveBossMenu', function(playerId, requestedId)
    local bossMenuId, bossMenu = getBossMenu(requestedId)
    if not bossMenuId then return response(false, 'error_bossmenu_access') end

    if not Bridge.Framework.HasJob(Config.Job.name, playerId)
        or not Bridge.Framework.IsBoss(playerId) then
        return response(false, 'error_not_boss')
    end

    if not isNear(playerId, bossMenu.table.coords.xyz, 5.0) then
        return response(false, 'error_too_far')
    end

    local currentOwner = activeBossMenus[bossMenuId]
    if currentOwner and not GetPlayerName(currentOwner) then
        setBossMenuOwner(bossMenuId, nil)
        currentOwner = nil
    end

    if currentOwner and currentOwner ~= playerId then
        return response(false, 'error_bossmenu_busy', 'warning')
    end

    if currentOwner == playerId then return response(true) end

    setBossMenuOwner(bossMenuId, playerId)
    confirmedBossMenus[bossMenuId] = false
    local reservationToken = bossMenuReservationTokens[bossMenuId]

    SetTimeout(30000, function()
        if activeBossMenus[bossMenuId] == playerId
            and bossMenuReservationTokens[bossMenuId] == reservationToken
            and confirmedBossMenus[bossMenuId] == false then
            setBossMenuOwner(bossMenuId, nil)
        end
    end)

    return response(true)
end)

Bridge.Callback.Register('sc_tobaccojob:server:confirmBossMenu', function(playerId, requestedId)
    local bossMenuId, bossMenu = getBossMenu(requestedId)
    if not bossMenuId
        or activeBossMenus[bossMenuId] ~= playerId
        or not canUseBossMenu(playerId, bossMenu) then
        return false
    end

    confirmedBossMenus[bossMenuId] = true
    return true
end)

Bridge.Callback.Register('sc_tobaccojob:server:releaseBossMenu', function(playerId, requestedId)
    local bossMenuId = getBossMenu(requestedId)
    if not bossMenuId or activeBossMenus[bossMenuId] ~= playerId then return false end

    setBossMenuOwner(bossMenuId, nil)
    return true
end)

RegisterNetEvent('sc_tobaccojob:server:syncBossMenuAnimation', function(requestedId, animationName)
    local playerId = source
    local bossMenuId, bossMenu = getBossMenu(requestedId)

    if not bossMenuId
        or not bossMenuAnimations[animationName]
        or activeBossMenus[bossMenuId] ~= playerId
        or not canUseBossMenu(playerId, bossMenu) then
        return
    end

    broadcastBossMenuAnimation(playerId, bossMenuId, animationName)
end)

Bridge.Callback.Register('sc_tobaccojob:server:beginSale', function(playerId)
    local now = GetGameTimer()

    if activeSale and now < activeSale.expiresAt then
        return response(false, 'error_seller_busy', 'warning')
    end

    if activeSale then setActiveSale(nil) end

    local valid, action = validateAction(playerId, 'sell')
    if not valid then return action end

    if Bridge.Inventory.GetItemCount(playerId, action.input.item) < action.input.count then
        return response(false, 'error_missing_pack')
    end

    saleSequence = saleSequence + 1
    local transactionId = ('%s:%s:%s'):format(playerId, now, saleSequence)
    local transactionTimeout = Config.PaymentAnimation.transactionTimeout

    local transaction = {
        id = transactionId,
        playerId = playerId,
        payment = math.random(action.payment.minimum, action.payment.maximum),
        completeAt = now + Config.PaymentAnimation.serverMinimumDuration,
        expiresAt = now + transactionTimeout
    }
    setActiveSale(transaction)

    SetTimeout(transactionTimeout, function()
        if activeSale and activeSale.id == transactionId then
            setActiveSale(nil)
        end
    end)

    return {
        success = true,
        transactionId = transactionId
    }
end)

RegisterNetEvent('sc_tobaccojob:server:playSellerAnimation', function(transactionId)
    local playerId = source

    if not activeSale
        or activeSale.id ~= transactionId
        or activeSale.playerId ~= playerId
        or not sellerPed
        or not DoesEntityExist(sellerPed) then
        return
    end

    local owner = NetworkGetEntityOwner(sellerPed)
    local recipient = owner and owner > 0 and owner or playerId
    local networkId = NetworkGetNetworkIdFromEntity(sellerPed)

    if networkId and networkId ~= 0 then
        TriggerClientEvent(sellerAnimationEvent, recipient, networkId)
    end
end)

Bridge.Callback.Register(
    'sc_tobaccojob:server:finishSale',
    function(playerId, transactionId, completed)
        local transaction = activeSale

        if not transaction
            or transaction.id ~= transactionId
            or transaction.playerId ~= playerId then
            return response(false, 'error_sale_expired')
        end

        setActiveSale(nil)

        if completed ~= true then
            return { success = false }
        end

        local now = GetGameTimer()
        if now < transaction.completeAt or now > transaction.expiresAt then
            return response(false, 'error_sale_expired')
        end

        local action = Config.Actions.sell

        if not canUseJob(playerId) then
            return response(false, 'error_not_employee')
        end

        if not isNear(
            playerId,
            Config.Peds.seller.coords.xyz,
            action.distance + 2.0
        ) then
            return response(false, 'error_too_far')
        end

        if Bridge.Inventory.GetItemCount(playerId, action.input.item) < action.input.count then
            return response(false, 'error_missing_pack')
        end

        local removed, removeReason = Bridge.Inventory.RemoveItem(
            playerId,
            action.input.item,
            action.input.count
        )

        if not removed then
            return inventoryFailure(
                playerId,
                action.input.item,
                removeReason,
                'error_remove_pack'
            )
        end

        if not Bridge.Framework.AddMoney(
            playerId,
            action.payment.account,
            transaction.payment,
            'tobacco-job-sale'
        ) then
            Bridge.Inventory.AddItem(playerId, action.input.item, action.input.count)
            return response(false, 'error_payment')
        end

        return response(true, 'success_sale', nil, nil, { transaction.payment })
    end
)

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
    createSellerPed()
    createVehiclePed()
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
    local playerId = source
    actionCooldowns[playerId] = nil

    if activeSale and activeSale.playerId == playerId then
        setActiveSale(nil)
    end

    for bossMenuId, owner in pairs(activeBossMenus) do
        if owner == playerId then setBossMenuOwner(bossMenuId, nil) end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if sellerPed and DoesEntityExist(sellerPed) then DeleteEntity(sellerPed) end
        sellerPed = nil

        if vehiclePed and DoesEntityExist(vehiclePed) then DeleteEntity(vehiclePed) end
        vehiclePed = nil
    end

    if resourceName == 'ox_inventory' then
        stashRegistered = false
    elseif resourceName == 'esx_society' then
        societyRegistered = false
    end
end)
