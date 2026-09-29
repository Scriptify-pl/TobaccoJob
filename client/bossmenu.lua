BossMenu = {
    animationDictionary = 'anim@amb@clubhouse@boss@male@',
    sceneBusy = false,
    playerSitting = false,
    computerActive = false,
    activeChairEntity = nil,
    activeBossMenuId = nil,
    occupants = {},
    remoteAnimationTokens = {},
    entries = {}
}

local bossMenuAnimationPhases = {
    enter_chair = 0.9,
    computer_enter_chair = 0.5,
    computer_exit_chair = 0.5,
    exit_chair = 0.9
}

local function requestAnimationDictionary()
    if HasAnimDictLoaded(BossMenu.animationDictionary) then
        return true
    end

    RequestAnimDict(BossMenu.animationDictionary)
    local timeout = GetGameTimer() + 5000

    while not HasAnimDictLoaded(BossMenu.animationDictionary) do
        if GetGameTimer() >= timeout then
            debug(locale('debug_animation_load_failed'))
            return false
        end

        Wait(10)
    end

    return true
end

local function getTransform(entity, objectAnimation)
    local entityCoords = GetEntityCoords(entity)
    local entityHeading = GetEntityHeading(entity)
    local initialRotation = GetAnimInitialOffsetRotation(
        BossMenu.animationDictionary,
        objectAnimation,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.01,
        2
    )
    local sceneHeading = entityHeading - initialRotation.z
    local initialPosition = GetAnimInitialOffsetPosition(
        BossMenu.animationDictionary,
        objectAnimation,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        sceneHeading,
        0.01,
        2
    )

    return vector3(
        entityCoords.x - initialPosition.x,
        entityCoords.y - initialPosition.y,
        entityCoords.z - initialPosition.z
    ), sceneHeading
end

local function getPedSceneZOffset(entity, objectAnimation)
    local model = GetEntityModel(entity)
    local computerAnimation = objectAnimation == 'computer_enter_chair'
        or objectAnimation == 'computer_exit_chair'

    if model == 1339364336 then
        return computerAnimation and 0.0101 or 0.1101
    end

    if model == 538002882 then
        return 0.2
    end

    return 0.6101
end

local function getPedScenePosition(entity, objectAnimation, objectScenePosition)
    return vector3(
        objectScenePosition.x,
        objectScenePosition.y,
        objectScenePosition.z + getPedSceneZOffset(entity, objectAnimation)
    )
end

local function playObjectScene(entity, objectAnimation)
    local scenePosition, sceneHeading = getTransform(entity, objectAnimation)
    FreezeEntityPosition(entity, false)

    local scene = CreateSynchronizedScene(
        scenePosition.x,
        scenePosition.y,
        scenePosition.z,
        0.0,
        0.0,
        sceneHeading,
        0
    )

    PlaySynchronizedEntityAnim(
        entity,
        scene,
        objectAnimation,
        BossMenu.animationDictionary,
        1000.0,
        1.0,
        0,
        1.0
    )

    return scene, scenePosition, sceneHeading
end

local function waitForPhase(scene, targetPhase, timeoutMs)
    local timeout = GetGameTimer() + timeoutMs

    while GetSynchronizedScenePhase(scene) < targetPhase do
        if GetGameTimer() >= timeout then
            debug(locale('debug_animation_timeout'))
            return false
        end

        Wait(10)
    end

    return true
end

local function playScene(
    bossMenuId,
    entity,
    objectAnimation,
    pedAnimation,
    targetPhase,
    onStarted
)
    if not entity or not DoesEntityExist(entity) or not requestAnimationDictionary() then
        return false
    end

    local ped = PlayerPedId()
    local _, scenePosition, sceneHeading = playObjectScene(entity, objectAnimation)
    TriggerServerEvent(
        'sc_tobaccojob:server:syncBossMenuAnimation',
        bossMenuId,
        objectAnimation
    )

    local pedScenePosition = getPedScenePosition(entity, objectAnimation, scenePosition)
    local pedScene = CreateSynchronizedScene(
        pedScenePosition.x,
        pedScenePosition.y,
        pedScenePosition.z,
        0.0,
        0.0,
        sceneHeading,
        0
    )

    TaskSynchronizedScene(
        ped,
        pedScene,
        BossMenu.animationDictionary,
        pedAnimation,
        2.0,
        -1.5,
        13,
        16,
        2.0,
        0
    )

    if onStarted then onStarted() end

    local completed = waitForPhase(pedScene, targetPhase, 12000)
    FreezeEntityPosition(entity, true)
    return completed
end

local function releaseBossMenu(bossMenuId)
    if not bossMenuId then return false end
    return Bridge.Callback.Await('sc_tobaccojob:server:releaseBossMenu', bossMenuId) == true
end

function BossMenu.RefreshReservations()
    local states = Bridge.Callback.Await('sc_tobaccojob:server:getBossMenuStates')
    if type(states) == 'table' then BossMenu.occupants = states end
end

RegisterNetEvent('sc_tobaccojob:client:setBossMenuState', function(bossMenuId, playerId)
    bossMenuId = tonumber(bossMenuId)
    if not bossMenuId then return end
    BossMenu.occupants[bossMenuId] = playerId
end)

RegisterNetEvent(
    'sc_tobaccojob:client:playBossMenuAnimation',
    function(bossMenuId, objectAnimation, playerId)
        if playerId == GetPlayerServerId(PlayerId()) then return end

        local targetPhase = bossMenuAnimationPhases[objectAnimation]
        local bossMenu = BossMenu.entries[tonumber(bossMenuId)]
        local chair = bossMenu and bossMenu.entities.chair

        if not targetPhase or not chair or not DoesEntityExist(chair) then return end

        local menuId = tonumber(bossMenuId)
        BossMenu.remoteAnimationTokens[menuId] =
            (BossMenu.remoteAnimationTokens[menuId] or 0) + 1
        local animationToken = BossMenu.remoteAnimationTokens[menuId]

        CreateThread(function()
            if not requestAnimationDictionary() then return end

            local scene = playObjectScene(chair, objectAnimation)
            waitForPhase(scene, targetPhase, 12000)
            if BossMenu.remoteAnimationTokens[menuId] == animationToken then
                FreezeEntityPosition(chair, true)
            end
        end)
    end
)

function sc_bossmenu_start(bossMenuId)
    if BossMenu.sceneBusy or BossMenu.computerActive or BossMenu.playerSitting then return end

    local bossMenu = BossMenu.entries[bossMenuId]
    if not bossMenu
        or not bossMenu.entities.table
        or not DoesEntityExist(bossMenu.entities.table)
        or not bossMenu.entities.chair
        or not DoesEntityExist(bossMenu.entities.chair) then
        debug(locale('debug_bossmenu_incomplete', bossMenuId))
        return
    end

    BossMenu.sceneBusy = true
    local reservation = Bridge.Callback.Await(
        'sc_tobaccojob:server:reserveBossMenu',
        bossMenuId
    )

    if not reservation then
        BossMenu.sceneBusy = false
        return Bridge.Notify(locale('error_bossmenu_access'), 'error')
    end

    if not reservation.success then
        BossMenu.sceneBusy = false
        return Tobacco.ShowResponse(reservation)
    end

    CreateThread(function()
        local chair = bossMenu.entities.chair
        local enteredChair = playScene(
            bossMenuId,
            chair,
            'enter_chair',
            'enter',
            0.9
        )

        if not enteredChair then
            releaseBossMenu(bossMenuId)
            BossMenu.sceneBusy = false
            return
        end

        BossMenu.playerSitting = true
        BossMenu.activeChairEntity = chair
        BossMenu.activeBossMenuId = bossMenuId
        Wait(100)

        local enteredComputer = playScene(
            bossMenuId,
            chair,
            'computer_enter_chair',
            'computer_enter',
            0.5,
            OpenBossMenu
        )

        if not enteredComputer then
            ClearPedTasksImmediately(PlayerPedId())
            BossMenu.playerSitting = false
            BossMenu.activeChairEntity = nil
            BossMenu.activeBossMenuId = nil
            releaseBossMenu(bossMenuId)
            BossMenu.sceneBusy = false
            return
        end

        local confirmed = Bridge.Callback.Await(
            'sc_tobaccojob:server:confirmBossMenu',
            bossMenuId
        )

        if not confirmed then
            ClearPedTasksImmediately(PlayerPedId())
            releaseBossMenu(bossMenuId)
            BossMenu.playerSitting = false
            BossMenu.activeChairEntity = nil
            BossMenu.activeBossMenuId = nil
            BossMenu.sceneBusy = false
            return Bridge.Notify(locale('error_bossmenu_access'), 'error')
        end

        BossMenu.computerActive = true
        BossMenu.sceneBusy = false
    end)
end

function sc_bossmenu_stop()
    if BossMenu.sceneBusy or not BossMenu.computerActive then return end

    if not BossMenu.activeChairEntity or not DoesEntityExist(BossMenu.activeChairEntity) then
        releaseBossMenu(BossMenu.activeBossMenuId)
        BossMenu.computerActive = false
        BossMenu.playerSitting = false
        BossMenu.activeChairEntity = nil
        BossMenu.activeBossMenuId = nil
        return
    end

    BossMenu.sceneBusy = true

    CreateThread(function()
        local ped = PlayerPedId()
        local chair = BossMenu.activeChairEntity
        local exitedComputer = playScene(
            BossMenu.activeBossMenuId,
            chair,
            'computer_exit_chair',
            'computer_exit',
            0.5
        )

        if not exitedComputer then
            BossMenu.sceneBusy = false
            return
        end

        BossMenu.computerActive = false
        Wait(100)
        playScene(
            BossMenu.activeBossMenuId,
            chair,
            'exit_chair',
            'exit',
            0.9
        )

        releaseBossMenu(BossMenu.activeBossMenuId)
        BossMenu.playerSitting = false
        BossMenu.activeChairEntity = nil
        BossMenu.activeBossMenuId = nil
        ClearPedTasks(ped)
        ClearPedSecondaryTask(ped)
        BossMenu.sceneBusy = false
    end)
end
