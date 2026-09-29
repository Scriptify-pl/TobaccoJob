local paymentState = {
    props = {},
    models = {},
    dictionaries = {}
}

local pedMonitorToken = 0
Tobacco.sellerBusy = false

local function configureNetworkPed(ped)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
end

local function resolveNetworkPed(networkId)
    if not networkId or not NetworkDoesEntityExistWithNetworkId(networkId) then return end

    local ped = NetworkGetEntityFromNetworkId(networkId)
    if not ped or ped == 0 or not DoesEntityExist(ped) or not IsEntityAPed(ped) then return end
    return ped
end

local function updateNetworkPed(name, networkId, registerTarget)
    local currentPed = resolveNetworkPed(networkId)

    if currentPed then
        if Tobacco.peds[name] ~= currentPed then
            Tobacco.peds[name] = currentPed
            configureNetworkPed(currentPed)
        end

        registerTarget(currentPed)
        return true
    end

    if Tobacco.peds[name] and not DoesEntityExist(Tobacco.peds[name]) then
        Tobacco.peds[name] = nil
    end

    return false
end

function Tobacco.InitializeNetworkPeds()
    pedMonitorToken = pedMonitorToken + 1
    local monitorToken = pedMonitorToken
    local peds = Bridge.Callback.Await('sc_tobaccojob:server:getPeds')

    if not peds or not peds.sellerNetworkId or not peds.vehicleNetworkId then
        debug(locale('debug_seller_sync_failed'))
        return false
    end

    Tobacco.sellerNetworkId = peds.sellerNetworkId
    Tobacco.vehicleNetworkId = peds.vehicleNetworkId
    Tobacco.sellerBusy = peds.busy == true

    local seller = resolveNetworkPed(Tobacco.sellerNetworkId)
    if seller then
        configureNetworkPed(seller)
        Tobacco.peds.seller = seller
    end

    local vehicleWorker = resolveNetworkPed(Tobacco.vehicleNetworkId)
    if vehicleWorker then
        configureNetworkPed(vehicleWorker)
        Tobacco.peds.vehicle = vehicleWorker
    end

    CreateThread(function()
        Wait(1000)

        while pedMonitorToken == monitorToken
            and Tobacco.sellerNetworkId
            and Tobacco.vehicleNetworkId do
            local delay = 2000

            local sellerFound = updateNetworkPed(
                'seller',
                Tobacco.sellerNetworkId,
                function(ped)
                    if Tobacco.sellerTargetEntity ~= ped
                        and Tobacco.RegisterSellerTarget then
                        Tobacco.RegisterSellerTarget(ped)
                    end
                end
            )

            local vehicleWorkerFound = updateNetworkPed(
                'vehicle',
                Tobacco.vehicleNetworkId,
                function(ped)
                    if Tobacco.vehicleTargetEntity ~= ped
                        and Tobacco.RegisterVehicleTarget then
                        Tobacco.RegisterVehicleTarget(ped)
                    end
                end
            )

            if sellerFound or vehicleWorkerFound then
                delay = 1500
            end

            Wait(delay)
        end
    end)

    return true
end

function Tobacco.ShutdownNetworkPeds()
    pedMonitorToken = pedMonitorToken + 1
    Tobacco.sellerNetworkId = nil
    Tobacco.vehicleNetworkId = nil
    Tobacco.sellerBusy = false
    Tobacco.peds.seller = nil
    Tobacco.peds.vehicle = nil
end

RegisterNetEvent('sc_tobaccojob:client:setSellerBusy', function(busy)
    Tobacco.sellerBusy = busy == true
end)

local function requestEntityControl(entity)
    if NetworkHasControlOfEntity(entity) then return true end

    local timeout = GetGameTimer() + 1500
    repeat
        NetworkRequestControlOfEntity(entity)
        Wait(10)
    until NetworkHasControlOfEntity(entity) or GetGameTimer() >= timeout

    if not NetworkHasControlOfEntity(entity) then
        debug(locale('debug_payment_control_failed'))
        return false
    end

    return true
end

local function loadAnimationDictionary(dictionary)
    if HasAnimDictLoaded(dictionary) then
        paymentState.dictionaries[dictionary] = true
        return true
    end

    RequestAnimDict(dictionary)
    local timeout = GetGameTimer() + 10000

    while not HasAnimDictLoaded(dictionary) do
        if GetGameTimer() >= timeout then
            debug(locale('debug_payment_animation_load_failed', dictionary))
            return false
        end

        Wait(25)
    end

    paymentState.dictionaries[dictionary] = true
    return true
end

local function loadPropModel(model)
    if not model or not IsModelInCdimage(model) or not IsModelValid(model) then
        debug(locale('debug_invalid_model', tostring(model)))
        return false
    end

    if not HasModelLoaded(model) then
        RequestModel(model)
        local timeout = GetGameTimer() + 10000

        while not HasModelLoaded(model) do
            if GetGameTimer() >= timeout then
                debug(locale('debug_model_load_failed', tostring(model)))
                return false
            end

            Wait(10)
        end
    end

    paymentState.models[model] = true
    return true
end

local function loadPaymentAssets(config)
    if not loadAnimationDictionary(config.dictionary) then return false end
    if not loadAnimationDictionary(config.receiver.dictionary) then return false end

    for i = 1, #config.props do
        if not loadPropModel(config.props[i].model) then return false end
    end

    return true
end

RegisterNetEvent('sc_tobaccojob:client:playSellerAnimation', function(networkId)
    if not networkId or not NetworkDoesEntityExistWithNetworkId(networkId) then return end

    local seller = NetworkGetEntityFromNetworkId(networkId)
    if not seller or seller == 0 or not DoesEntityExist(seller) then return end
    if not loadAnimationDictionary(Config.PaymentAnimation.dictionary) then return end

    requestEntityControl(seller)
    configureNetworkPed(seller)
    SetEntityHeading(seller, Config.Peds.seller.coords.w)
    TaskPlayAnim(
        seller,
        Config.PaymentAnimation.dictionary,
        Config.PaymentAnimation.clip,
        8.0,
        -8.0,
        Config.PaymentAnimation.duration,
        Config.PaymentAnimation.flag,
        0.0,
        false,
        false,
        false
    )
end)

local function deletePaymentProp(index)
    local entity = paymentState.props[index]
    if entity and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
    paymentState.props[index] = nil
end

local function createPaymentProp(index, data, seller, player)
    local owner = data.owner == 'player' and player or seller
    if not owner or not DoesEntityExist(owner) then return false end

    local coords = GetEntityCoords(owner)
    local entity = CreateObjectNoOffset(
        data.model,
        coords.x,
        coords.y,
        coords.z,
        true,
        true,
        false
    )

    if not DoesEntityExist(entity) then
        debug(locale('debug_entity_create_failed', tostring(data.model)))
        return false
    end

    SetEntityAsMissionEntity(entity, true, true)
    SetEntityCollision(entity, false, false)

    local networkId = NetworkGetNetworkIdFromEntity(entity)
    if networkId and networkId ~= 0 then
        SetNetworkIdCanMigrate(networkId, true)
    end

    local bone = GetPedBoneIndex(owner, data.bone)
    AttachEntityToEntity(
        entity,
        owner,
        bone,
        data.transform.x,
        data.transform.y,
        data.transform.z,
        data.rotation.x,
        data.rotation.y,
        data.rotation.z,
        false,
        false,
        false,
        false,
        1,
        true
    )

    paymentState.props[index] = entity
    return true
end

local function updatePaymentProps(config, elapsed, seller, player)
    for i = 1, #config.props do
        local data = config.props[i]

        if elapsed >= data.startTime and elapsed < data.endTime then
            if not paymentState.props[i]
                and not createPaymentProp(i, data, seller, player) then
                return false
            end
        elseif elapsed >= data.endTime and paymentState.props[i] then
            deletePaymentProp(i)
        end
    end

    return true
end

local function positionPlayer(player, seller, data)
    local target = GetOffsetFromEntityInWorldCoords(
        seller,
        data.offset.x,
        data.offset.y,
        data.offset.z
    )
    local heading = (GetEntityHeading(seller) + 180.0) % 360.0

    if #(GetEntityCoords(player) - target) > 0.15 then
        TaskGoStraightToCoord(
            player,
            target.x,
            target.y,
            target.z,
            data.speed,
            data.timeout,
            heading,
            0.1
        )

        local timeout = GetGameTimer() + data.timeout
        while #(GetEntityCoords(player) - target) > 0.25 do
            if GetGameTimer() >= timeout
                or IsEntityDead(player)
                or not DoesEntityExist(seller) then
                ClearPedTasks(player)
                return false
            end

            Wait(25)
        end
    end

    ClearPedTasks(player)
    SetEntityCoordsNoOffset(player, target.x, target.y, target.z, false, false, true)
    SetEntityHeading(player, heading)
    return true
end

function Tobacco.CleanupPaymentAnimation()
    for index in pairs(paymentState.props) do
        deletePaymentProp(index)
    end

    if paymentState.player and DoesEntityExist(paymentState.player) then
        ClearPedTasks(paymentState.player)
        FreezeEntityPosition(paymentState.player, false)
    end

    if paymentState.seller and DoesEntityExist(paymentState.seller) then
        ClearPedTasks(paymentState.seller)
        if paymentState.sellerHeading then
            SetEntityHeading(paymentState.seller, paymentState.sellerHeading)
        end
        FreezeEntityPosition(paymentState.seller, true)
    end

    for model in pairs(paymentState.models) do
        SetModelAsNoLongerNeeded(model)
    end

    for dictionary in pairs(paymentState.dictionaries) do
        RemoveAnimDict(dictionary)
    end

    paymentState.props = {}
    paymentState.models = {}
    paymentState.dictionaries = {}
    paymentState.player = nil
    paymentState.seller = nil
    paymentState.sellerHeading = nil
end

function Tobacco.PlayPaymentAnimation(seller, transactionId)
    local config = Config.PaymentAnimation
    local player = PlayerPedId()

    if not config
        or not seller
        or not DoesEntityExist(seller)
        or IsEntityDead(player)
        or IsPedInAnyVehicle(player, false) then
        return false
    end

    Tobacco.CleanupPaymentAnimation()
    paymentState.player = player
    paymentState.seller = seller
    paymentState.sellerHeading = GetEntityHeading(seller)

    if not loadPaymentAssets(config)
        or not positionPlayer(player, seller, config.playerPosition) then
        Tobacco.CleanupPaymentAnimation()
        return false
    end

    FreezeEntityPosition(player, true)
    TriggerServerEvent('sc_tobaccojob:server:playSellerAnimation', transactionId)

    local animationStartTimeout = GetGameTimer() + 3000
    while not IsEntityPlayingAnim(seller, config.dictionary, config.clip, 3) do
        if GetGameTimer() >= animationStartTimeout then
            debug(locale('debug_payment_animation_load_failed', config.dictionary))
            Tobacco.CleanupPaymentAnimation()
            return false
        end

        Wait(10)
    end

    local startedAt = GetGameTimer()
    local receiverStarted = false
    local completed = true

    while GetGameTimer() - startedAt < config.duration do
        if not DoesEntityExist(seller) or IsEntityDead(player) then
            completed = false
            break
        end

        local elapsed = (GetGameTimer() - startedAt) / 1000

        if not receiverStarted and elapsed >= config.receiver.startTime then
            receiverStarted = true
            TaskPlayAnim(
                player,
                config.receiver.dictionary,
                config.receiver.clip,
                8.0,
                -8.0,
                config.receiver.duration,
                config.receiver.flag,
                0.0,
                false,
                false,
                false
            )
        end

        if not updatePaymentProps(config, elapsed, seller, player) then
            completed = false
            break
        end

        Wait(25)
    end

    Tobacco.CleanupPaymentAnimation()
    return completed
end

function Tobacco.RunSale()
    if Tobacco.busy or not Tobacco.IsEmployee() then return end

    local seller = Tobacco.peds.seller
    if not seller or not DoesEntityExist(seller) then
        return Bridge.Notify(locale('error_payment_animation'), 'error')
    end

    Tobacco.busy = true

    local started = Bridge.Callback.Await('sc_tobaccojob:server:beginSale')
    if not started then
        Bridge.Notify(locale('error_payment'), 'error')
        Tobacco.busy = false
        return
    end

    if not started.success then
        Tobacco.ShowResponse(started)
        Tobacco.busy = false
        return
    end

    local animationOk, completed = pcall(
        Tobacco.PlayPaymentAnimation,
        seller,
        started.transactionId
    )
    if not animationOk then
        debug(locale('debug_payment_animation_failed', tostring(completed)))
        completed = false
        Tobacco.CleanupPaymentAnimation()
    end

    local result = Bridge.Callback.Await(
        'sc_tobaccojob:server:finishSale',
        started.transactionId,
        completed == true
    )

    if not result then
        Bridge.Notify(locale('error_payment'), 'error')
    elseif completed then
        Tobacco.ShowResponse(result)
    elseif result and (result.message or result.messageKey) then
        Tobacco.ShowResponse(result)
    else
        Bridge.Notify(locale('error_payment_animation'), 'error')
    end

    Tobacco.busy = false
end
