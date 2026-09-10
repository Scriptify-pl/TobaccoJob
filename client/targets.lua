local function jobOption(data)
    return {
        name = data.name,
        icon = data.icon,
        label = data.label,
        distance = data.distance,
        canInteract = function(entity, distance, coords, name, bone)
            return Tobacco.IsEmployee()
                and not Tobacco.busy
                and (not data.canInteract or data.canInteract(entity, distance, coords, name, bone))
        end,
        onSelect = data.onSelect
    }
end

function Tobacco.RegisterTargets()
    local gather = Config.Actions.gather

    Bridge.Target.AddModel(gather.model, {
        jobOption({
            name = 'tobacco_gather',
            icon = gather.icon,
            label = gather.targetLabel,
            distance = gather.distance,
            canInteract = function()
                return Tobacco.IsInArea(gather.area)
            end,
            onSelect = function()
                if Tobacco.IsInArea(gather.area) then
                    Tobacco.RunAction('gather')
                end
            end
        })
    })

    for _, actionName in ipairs({ 'process', 'pack' }) do
        local currentActionName = actionName
        local action = Config.Actions[currentActionName]
        Tobacco.zones[#Tobacco.zones + 1] = Bridge.Target.AddBoxZone(action.target, {
            jobOption({
                name = ('tobacco_%s'):format(currentActionName),
                icon = action.icon,
                label = action.targetLabel,
                distance = action.distance,
                onSelect = function()
                    Tobacco.RunAction(currentActionName)
                end
            })
        })
    end

    Tobacco.zones[#Tobacco.zones + 1] = Bridge.Target.AddBoxZone(Config.Stash.target, {
        jobOption({
            name = 'tobacco_open_stash',
            icon = 'fa-solid fa-box-open',
            label = locale('target_open_stash'),
            distance = 2.0,
            onSelect = Tobacco.OpenStash
        })
    })

    Tobacco.zones[#Tobacco.zones + 1] = Bridge.Target.AddBoxZone(Config.Cloakroom.target, {
        jobOption({
            name = 'tobacco_open_cloakroom',
            icon = 'fa-solid fa-shirt',
            label = locale('target_open_cloakroom'),
            distance = 3.0,
            onSelect = Tobacco.OpenCloakroom
        })
    })

    if Tobacco.peds.seller and DoesEntityExist(Tobacco.peds.seller) then
        Bridge.Target.AddLocalEntity(Tobacco.peds.seller, {
        jobOption({
            name = 'tobacco_sell',
            icon = Config.Actions.sell.icon,
            label = Config.Actions.sell.targetLabel,
            distance = Config.Actions.sell.distance,
            onSelect = function()
                Tobacco.RunAction('sell')
            end
        })
        })
    end

    if Tobacco.peds.vehicle and DoesEntityExist(Tobacco.peds.vehicle) then
        Bridge.Target.AddLocalEntity(Tobacco.peds.vehicle, {
        jobOption({
            name = 'tobacco_spawn_vehicle',
            icon = 'fa-solid fa-truck',
            label = locale('target_spawn_vehicle'),
            distance = 3.0,
            onSelect = Tobacco.SpawnJobVehicle
        }),
        jobOption({
            name = 'tobacco_store_vehicle',
            icon = 'fa-solid fa-warehouse',
            label = locale('target_store_vehicle'),
            distance = 3.0,
            onSelect = Tobacco.StoreJobVehicle
        })
        })
    end
end

function Tobacco.RegisterBossMenuTargets(bossMenu, bossMenuId)
    if not bossMenu or not bossMenu.entities.table or not DoesEntityExist(bossMenu.entities.table) then
        return
    end

    local target = bossMenu.config.target
    if not target or not target.open or not target.close then
        debug(locale('debug_bossmenu_incomplete', bossMenuId))
        return
    end

    bossMenu.targetNames = {
        open = ('sc_tobaccojob_bossmenu_open_%s'):format(bossMenuId),
        close = ('sc_tobaccojob_bossmenu_close_%s'):format(bossMenuId)
    }

    Bridge.Target.AddLocalEntity(bossMenu.entities.table, {
        {
            name = bossMenu.targetNames.open,
            icon = target.open.icon,
            label = target.open.label,
            distance = target.open.distance,
            canInteract = function()
                return not BossMenu.sceneBusy
                    and not BossMenu.playerSitting
                    and not BossMenu.computerActive
                    and Tobacco.IsBoss()
                    and bossMenu.entities.chair
                    and DoesEntityExist(bossMenu.entities.chair)
            end,
            onSelect = function()
                sc_bossmenu_start(bossMenuId)
            end
        },
        {
            name = bossMenu.targetNames.close,
            icon = target.close.icon,
            label = target.close.label,
            distance = target.close.distance,
            canInteract = function()
                return not BossMenu.sceneBusy
                    and BossMenu.computerActive
                    and BossMenu.playerSitting
                    and BossMenu.activeBossMenuId == bossMenuId
                    and BossMenu.activeChairEntity == bossMenu.entities.chair
            end,
            onSelect = sc_bossmenu_stop
        }
    })
end

function Tobacco.RemoveBossMenuTargets(bossMenu)
    if not bossMenu
        or not bossMenu.targetNames
        or not bossMenu.entities.table
        or not DoesEntityExist(bossMenu.entities.table) then
        return
    end

    Bridge.Target.RemoveLocalEntity(bossMenu.entities.table, {
        bossMenu.targetNames.open,
        bossMenu.targetNames.close
    })
    bossMenu.targetNames = nil
end

function Tobacco.RemoveTargets()
    Bridge.Target.RemoveModel(Config.Actions.gather.model, 'tobacco_gather')

    for i = 1, #Tobacco.zones do
        if Tobacco.zones[i] then
            Bridge.Target.RemoveZone(Tobacco.zones[i])
        end
    end

    Tobacco.zones = {}

    if Tobacco.peds.seller and DoesEntityExist(Tobacco.peds.seller) then
        Bridge.Target.RemoveLocalEntity(Tobacco.peds.seller, 'tobacco_sell')
    end

    if Tobacco.peds.vehicle and DoesEntityExist(Tobacco.peds.vehicle) then
        Bridge.Target.RemoveLocalEntity(Tobacco.peds.vehicle, {
            'tobacco_spawn_vehicle',
            'tobacco_store_vehicle'
        })
    end
end
