Tobacco = Tobacco or {}

Tobacco.busy = false
Tobacco.blips = {}
Tobacco.peds = {}
Tobacco.zones = {}
Tobacco.spawnedVehicle = nil
Tobacco.employee = Config.Job.required == false
Tobacco.boss = false

local function loadModel(model)
    if not model or not IsModelInCdimage(model) or not IsModelValid(model) then
        debug(locale('debug_invalid_model', tostring(model)))
        return false
    end

    if HasModelLoaded(model) then return true end

    RequestModel(model)
    local timeout = GetGameTimer() + 10000

    while not HasModelLoaded(model) do
        if GetGameTimer() >= timeout then
            debug(locale('debug_model_load_failed', tostring(model)))
            return false
        end

        Wait(10)
    end

    return true
end

function Tobacco.RefreshJobState(job)
    job = job or Bridge.Framework.GetJob()

    local hasJob = job and job.name == Config.Job.name or false
    local wasEmployee = Tobacco.employee
    Tobacco.employee = Config.Job.required == false or hasJob
    Tobacco.boss = hasJob and (
        job.isboss == true
        or job.grade_name == 'boss'
        or (type(job.grade) == 'table' and job.grade.name == 'boss')
    ) or false

    return wasEmployee ~= Tobacco.employee
end

function Tobacco.IsEmployee()
    return Tobacco.employee
end

function Tobacco.IsBoss()
    return Tobacco.boss
end

function Tobacco.IsInArea(area)
    return #(GetEntityCoords(PlayerPedId()) - area.coords) <= area.radius
end

function Tobacco.ShowResponse(response)
    if not response then return end

    local message = response.message
    if response.messageKey then
        message = locale(response.messageKey, table.unpack(response.messageArgs or {}))
    end

    if not message then return end
    Bridge.Notify(message, response.type or (response.success and 'success' or 'error'))
end

function Tobacco.RunAction(actionName)
    if Tobacco.busy or not Tobacco.IsEmployee() then return end

    local action = Config.Actions[actionName]
    if not action then return end

    Tobacco.busy = true

    local completed = Standalone.ProgressBar.Start(actionName, action)

    if completed then
        Tobacco.ShowResponse(Bridge.Callback.Await('sc_tobaccojob:server:performAction', actionName))
    end

    Tobacco.busy = false
end

function Tobacco.RemoveBlips()
    for i = 1, #Tobacco.blips do
        if DoesBlipExist(Tobacco.blips[i]) then
            RemoveBlip(Tobacco.blips[i])
        end
    end

    Tobacco.blips = {}
end

function Tobacco.RefreshBlips()
    Tobacco.RemoveBlips()

    for i = 1, #Config.Blips do
        local data = Config.Blips[i]

        if not data.jobOnly or Tobacco.IsEmployee() then
            local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
            SetBlipSprite(blip, data.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, data.scale)
            SetBlipColour(blip, data.colour)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(data.label)
            EndTextCommandSetBlipName(blip)
            Tobacco.blips[#Tobacco.blips + 1] = blip
        end
    end
end

local function createPed(data)
    if not data or not loadModel(data.model) then return end

    local ped = CreatePed(
        4,
        data.model,
        data.coords.x,
        data.coords.y,
        data.coords.z,
        data.coords.w,
        false,
        false
    )

    if not DoesEntityExist(ped) then
        debug(locale('debug_ped_create_failed', tostring(data.model)))
        return
    end

    SetEntityHeading(ped, data.coords.w)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetModelAsNoLongerNeeded(data.model)

    return ped
end

function Tobacco.SpawnPeds()
    Tobacco.peds.vehicle = createPed(Config.Peds.vehicle)
    Tobacco.peds.seller = createPed(Config.Peds.seller)
end

function Tobacco.SpawnJobVehicle()
    if not Tobacco.IsEmployee() then return end

    if Tobacco.spawnedVehicle and DoesEntityExist(Tobacco.spawnedVehicle) then
        return Bridge.Notify(locale('error_vehicle_exists'), 'error')
    end

    if IsAnyVehicleNearPoint(
        Config.Vehicle.spawn.x,
        Config.Vehicle.spawn.y,
        Config.Vehicle.spawn.z,
        2.5
    ) then
        return Bridge.Notify(locale('error_vehicle_spawn_blocked'), 'error')
    end

    if not loadModel(Config.Vehicle.model) then return end

    local vehicle = CreateVehicle(
        Config.Vehicle.model,
        Config.Vehicle.spawn.x,
        Config.Vehicle.spawn.y,
        Config.Vehicle.spawn.z,
        Config.Vehicle.spawn.w,
        true,
        false
    )

    if not DoesEntityExist(vehicle) then
        debug(locale('debug_vehicle_create_failed', tostring(Config.Vehicle.model)))
        return
    end

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetModelAsNoLongerNeeded(Config.Vehicle.model)
    Tobacco.spawnedVehicle = vehicle

    local plate = GetVehicleNumberPlateText(vehicle)
    Standalone.Vehicle.GiveKeys(vehicle, plate)
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
end

function Tobacco.StoreJobVehicle()
    if not Tobacco.IsEmployee() then return end

    local vehicle = Tobacco.spawnedVehicle

    if not vehicle
        or not DoesEntityExist(vehicle)
        or #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(vehicle)) > Config.Vehicle.returnRadius then
        return Bridge.Notify(locale('error_vehicle_not_found'), 'error')
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    Standalone.Vehicle.RemoveKeys(vehicle, plate)
    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteEntity(vehicle)
    Tobacco.spawnedVehicle = nil
end

function Tobacco.OpenStash()
    if not Tobacco.IsEmployee() then return end

    local response = Bridge.Callback.Await('sc_tobaccojob:server:openStash')
    if not response then return end

    if response.openClient and Bridge.InventoryName == 'ox_inventory' then
        exports.ox_inventory:openInventory('stash', Config.Stash.id)
    elseif response.message or response.messageKey then
        Tobacco.ShowResponse(response)
    end
end

function Tobacco.OpenCloakroom()
    if Tobacco.IsEmployee() then
        OpenCloakroom(Config.Cloakroom)
    end
end

local function createFurnitureObject(data, parentEntity)
    if not data or not loadModel(data.model) then return end

    local coords
    local heading

    if parentEntity then
        if not DoesEntityExist(parentEntity) or not data.offset then return end
        coords = GetOffsetFromEntityInWorldCoords(
            parentEntity,
            data.offset.x,
            data.offset.y,
            data.offset.z
        )
        heading = GetEntityHeading(parentEntity) + data.offset.w
    else
        if not data.coords then return end
        coords = data.coords.xyz
        heading = data.coords.w
    end

    local entity = CreateObjectNoOffset(
        data.model,
        coords.x,
        coords.y,
        coords.z,
        false,
        false,
        false
    )

    if not DoesEntityExist(entity) then
        debug(locale('debug_entity_create_failed', tostring(data.model)))
        return
    end

    SetEntityHeading(entity, heading)
    SetEntityAsMissionEntity(entity, true, true)
    SetEntityCollision(entity, true, true)
    FreezeEntityPosition(entity, true)
    SetModelAsNoLongerNeeded(data.model)
    return entity
end

function Tobacco.DeleteBossMenus()
    if BossMenu.playerSitting or BossMenu.computerActive then
        ClearPedTasksImmediately(PlayerPedId())
    end

    BossMenu.sceneBusy = false
    BossMenu.playerSitting = false
    BossMenu.computerActive = false
    BossMenu.activeChairEntity = nil
    BossMenu.activeBossMenuId = nil

    for i = 1, #BossMenu.entries do
        local bossMenu = BossMenu.entries[i]
        Tobacco.RemoveBossMenuTargets(bossMenu)

        for _, entity in pairs(bossMenu.entities) do
            if entity and DoesEntityExist(entity) then
                DeleteEntity(entity)
            end
        end
    end

    BossMenu.entries = {}
end

function Tobacco.SpawnBossMenus()
    Tobacco.DeleteBossMenus()

    for bossMenuId, bossMenuConfig in ipairs(Config.BossMenus) do
        local bossMenu = {
            config = bossMenuConfig,
            entities = {
                table = createFurnitureObject(bossMenuConfig.table)
            }
        }

        bossMenu.entities.chair = createFurnitureObject(
            bossMenuConfig.chair,
            bossMenuConfig.chair.offset and bossMenu.entities.table or nil
        )
        bossMenu.entities.computer = createFurnitureObject(
            bossMenuConfig.computer,
            bossMenuConfig.computer.offset and bossMenu.entities.table or nil
        )
        BossMenu.entries[bossMenuId] = bossMenu

        local complete = bossMenu.entities.table
            and DoesEntityExist(bossMenu.entities.table)
            and bossMenu.entities.chair
            and DoesEntityExist(bossMenu.entities.chair)
            and bossMenu.entities.computer
            and DoesEntityExist(bossMenu.entities.computer)

        if complete then
            Tobacco.RegisterBossMenuTargets(bossMenu, bossMenuId)
            debug(locale(
                'debug_bossmenu_spawned',
                bossMenuId,
                bossMenu.entities.table,
                bossMenu.entities.chair,
                bossMenu.entities.computer
            ))
        else
            debug(locale('debug_bossmenu_incomplete', bossMenuId))

            for _, entity in pairs(bossMenu.entities) do
                if entity and DoesEntityExist(entity) then
                    DeleteEntity(entity)
                end
            end
        end
    end
end

function Tobacco.Cleanup()
    Tobacco.RemoveTargets()
    Tobacco.RemoveBlips()
    Tobacco.DeleteBossMenus()

    if Tobacco.spawnedVehicle and DoesEntityExist(Tobacco.spawnedVehicle) then
        local plate = GetVehicleNumberPlateText(Tobacco.spawnedVehicle)
        Standalone.Vehicle.RemoveKeys(Tobacco.spawnedVehicle, plate)
        SetEntityAsMissionEntity(Tobacco.spawnedVehicle, true, true)
        DeleteEntity(Tobacco.spawnedVehicle)
        Tobacco.spawnedVehicle = nil
    end

    for _, ped in pairs(Tobacco.peds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end

    Tobacco.peds = {}
    Tobacco.spawnedVehicle = nil
end
