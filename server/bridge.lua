local resources = {
    framework = { esx = 'es_extended' },
    target = { ox_target = 'ox_target', qtarget = 'qtarget' },
    inventory = {
        ox_inventory = 'ox_inventory',
        esx_inventory = 'es_extended'
    },
    notify = { ox_lib = 'ox_lib', esx_notify = 'esx_notify' },
    clothing = {
        skinchanger = 'skinchanger',
        ['illenium-appearance'] = 'illenium-appearance',
        rcore_clothing = 'rcore_clothing'
    },
    bossmenu = { esx_society = 'esx_society' }
}

local detectionOrder = {
    framework = { 'esx' },
    target = { 'ox_target', 'qtarget' },
    inventory = { 'ox_inventory', 'esx_inventory' },
    notify = { 'ox_lib', 'esx_notify' },
    clothing = { 'illenium-appearance', 'rcore_clothing', 'skinchanger' },
    bossmenu = { 'esx_society' }
}

local watchedResources = {
    es_extended = true,
    ox_target = true,
    qtarget = true,
    ox_inventory = true,
    ox_lib = true,
    esx_notify = true,
    skinchanger = true,
    ['illenium-appearance'] = true,
    rcore_clothing = true,
    esx_society = true
}

local integrationEvent = ('%s:client:setIntegrations'):format(GetCurrentResourceName())
local integrationRequestEvent = ('%s:server:requestIntegrations'):format(GetCurrentResourceName())

local function isStarted(resource)
    local state = resource and GetResourceState(resource)
    return state == 'started' or state == 'starting'
end

local function detect(kind)
    local configured = Config.Integrations[kind] or 'auto'

    if configured ~= 'auto' then
        if configured == 'custom' then return 'custom' end

        local resource = resources[kind][configured]
        if not resource then
            debug(locale('debug_invalid_integration', kind, tostring(configured)))
            return
        end

        if not isStarted(resource) then
            debug(locale('debug_resource_not_started', kind, configured, resource))
            return
        end

        return configured
    end

    for i = 1, #detectionOrder[kind] do
        local name = detectionOrder[kind][i]
        if isStarted(resources[kind][name]) then return name end
    end
end

local function detectNotify(framework)
    if Config.Integrations.notify ~= 'auto' then return detect('notify') end

    if framework == 'esx' and isStarted(resources.notify.esx_notify) then
        return 'esx_notify'
    end

    return detect('notify')
end

local function detectBossMenu(framework)
    if Config.Integrations.bossmenu ~= 'auto' then return detect('bossmenu') end

    if framework == 'esx' and isStarted(resources.bossmenu.esx_society) then
        return 'esx_society'
    end
    if framework == 'esx' then return end

    return detect('bossmenu')
end

function Bridge.Refresh()
    local framework = detect('framework')

    Bridge.ApplyIntegrations({
        framework = framework,
        target = detect('target'),
        inventory = detect('inventory'),
        notify = detectNotify(framework),
        clothing = detect('clothing'),
        bossmenu = detectBossMenu(framework)
    })

    return Bridge.GetIntegrations()
end

Bridge.Inventory = Bridge.Inventory or {}

local function inventoryReady()
    if Bridge.InventoryName then return true end
    debug(locale('debug_missing_integration', 'inventory'))
    return false
end

local function getEsxPlayer(playerId)
    if Bridge.FrameworkName ~= 'esx' then return end

    local esx = Bridge.Framework.GetCore()
    local player = esx and esx.GetPlayerFromId(playerId)
    if not player then debug(locale('debug_player_not_found', playerId)) end
    return player
end

function Bridge.Inventory.GetItemCount(playerId, itemName, metadata)
    if not inventoryReady() then return 0 end

    if Bridge.InventoryName == 'custom' then
        return Standalone.Inventory.GetItemCount(playerId, itemName, metadata) or 0
    end

    if Bridge.InventoryName == 'ox_inventory' then
        return exports.ox_inventory:Search(playerId, 'count', itemName, metadata) or 0
    end

    if Bridge.InventoryName == 'esx_inventory' then
        local player = getEsxPlayer(playerId)
        if not player then return 0 end

        local item = player.getInventoryItem(itemName)
        return item and item.count or 0
    end

    return 0
end

function Bridge.Inventory.CanCarryItem(playerId, itemName, amount, metadata)
    if not inventoryReady() then return false, 'invalid_inventory' end

    if Bridge.InventoryName == 'custom' then
        local success, reason = Standalone.Inventory.CanCarryItem(
            playerId,
            itemName,
            amount,
            metadata
        )
        return success == true, reason
    end

    if Bridge.InventoryName == 'ox_inventory' then
        if not exports.ox_inventory:Items(itemName) then return false, 'invalid_item' end
        if not exports.ox_inventory:GetInventory(playerId) then return false, 'invalid_inventory' end

        local canCarry = exports.ox_inventory:CanCarryItem(playerId, itemName, amount, metadata)
        return canCarry == true, canCarry and nil or 'inventory_full'
    end

    if Bridge.InventoryName == 'esx_inventory' then
        local player = getEsxPlayer(playerId)
        if not player then return false, 'invalid_inventory' end
        if not player.getInventoryItem(itemName) then return false, 'invalid_item' end

        local canCarry = player.canCarryItem(itemName, amount)
        return canCarry == true, canCarry and nil or 'inventory_full'
    end

    return false, 'invalid_inventory'
end

function Bridge.Inventory.AddItem(playerId, itemName, amount, metadata)
    if not inventoryReady() then return false, 'invalid_inventory' end

    if Bridge.InventoryName == 'custom' then
        local success, reason = Standalone.Inventory.AddItem(playerId, itemName, amount, metadata)
        return success == true, reason
    end

    if Bridge.InventoryName == 'ox_inventory' then
        local success, reason = exports.ox_inventory:AddItem(playerId, itemName, amount, metadata)
        return success == true, reason
    end

    if Bridge.InventoryName == 'esx_inventory' then
        local player = getEsxPlayer(playerId)
        if not player then return false, 'invalid_inventory' end
        if not player.getInventoryItem(itemName) then return false, 'invalid_item' end

        local canCarry = player.canCarryItem(itemName, amount)
        if not canCarry then return false, 'inventory_full' end

        player.addInventoryItem(itemName, amount)
        return true
    end

    return false, 'invalid_inventory'
end

function Bridge.Inventory.RemoveItem(playerId, itemName, amount, metadata)
    if not inventoryReady() then return false, 'invalid_inventory' end

    if Bridge.InventoryName == 'custom' then
        local success, reason = Standalone.Inventory.RemoveItem(playerId, itemName, amount, metadata)
        return success == true, reason
    end

    if Bridge.InventoryName == 'ox_inventory' then
        local success, reason = exports.ox_inventory:RemoveItem(
            playerId,
            itemName,
            amount,
            metadata
        )
        return success == true, reason
    end

    if Bridge.InventoryName == 'esx_inventory' then
        local player = getEsxPlayer(playerId)
        if not player then return false, 'invalid_inventory' end

        local item = player.getInventoryItem(itemName)
        if not item then return false, 'invalid_item' end
        if (item.count or 0) < amount then return false, 'not_enough_items' end

        player.removeInventoryItem(itemName, amount)
        return true
    end

    return false, 'invalid_inventory'
end

local lastIntegrationState

local function refreshIntegrations(broadcast)
    local detected = Bridge.Refresh()
    local state = table.concat({
        detected.framework or 'none',
        detected.target or 'none',
        detected.inventory or 'none',
        detected.notify or 'none',
        detected.clothing or 'none',
        detected.bossmenu or 'none'
    }, ':')

    if Config.Debug and state ~= lastIntegrationState then
        lastIntegrationState = state

        print('^6═══════════════════[ Integration Detect ]════════════════════^7')
        print('^2[sc_tobaccojob] - Integrations detected!')
        print('^7Framework: ^4' .. (detected.framework or 'none') .. '^7.')
        print('^7Target: ^4' .. (detected.target or 'none') .. '^7.')
        print('^7Inventory: ^4' .. (detected.inventory or 'none') .. '^7.')
        print('^7Notify: ^4' .. (detected.notify or 'none') .. '^7.')
        print('^7Clothing: ^4' .. (detected.clothing or 'none') .. '^7.')
        print('^7Boss Menu: ^4' .. (detected.bossmenu or 'none') .. '^7.')
        print('^6═════════════════════════════════════════════════════════════^7')
    end

    if broadcast then TriggerClientEvent(integrationEvent, -1, detected) end
end

local refreshQueued = false

local function queueRefresh(resourceName)
    if not watchedResources[resourceName] then return end
    if refreshQueued then return end

    refreshQueued = true
    CreateThread(function()
        Wait(250)
        refreshQueued = false
        refreshIntegrations(true)
    end)
end

refreshIntegrations(false)

RegisterNetEvent(integrationRequestEvent, function()
    TriggerClientEvent(integrationEvent, source, Bridge.GetIntegrations())
end)

AddEventHandler('onResourceStart', queueRefresh)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then queueRefresh(resourceName) end
end)
