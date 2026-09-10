Standalone = {
    Inventory = {},
    Target = {},
    Vehicle = {},
    Clothing = {},
    BossMenu = {},
    ProgressBar = {}
}

local function customNotConfigured(name)
    debug(locale('debug_standalone_missing', name))
    return false
end

-- CLIENT
function OpenBossMenu()
    if Bridge.BossMenuName == 'esx_society' then
        TriggerEvent('esx_society:openBossMenu', Config.Job.name, function(_, menu)
            if menu then menu.close() end
        end)
        return true
    end

    if Bridge.BossMenuName == 'custom' then
        return Standalone.BossMenu.Open(Config.Job)
    end

    debug(locale('debug_bossmenu_missing'))
    return false
end

local skinchangerCivilianSkin
local illeniumCivilianAppearance

local componentFields = {
    mask_1 = { id = 1, texture = 'mask_2' },
    arms = { id = 3, texture = 'arms_2' },
    pants_1 = { id = 4, texture = 'pants_2' },
    bags_1 = { id = 5, texture = 'bags_2' },
    shoes_1 = { id = 6, texture = 'shoes_2' },
    chain_1 = { id = 7, texture = 'chain_2' },
    tshirt_1 = { id = 8, texture = 'tshirt_2' },
    bproof_1 = { id = 9, texture = 'bproof_2' },
    decals_1 = { id = 10, texture = 'decals_2' },
    torso_1 = { id = 11, texture = 'torso_2' }
}

local propFields = {
    helmet_1 = { id = 0, texture = 'helmet_2' },
    glasses_1 = { id = 1, texture = 'glasses_2' },
    ears_1 = { id = 2, texture = 'ears_2' },
    watches_1 = { id = 6, texture = 'watches_2' },
    bracelets_1 = { id = 7, texture = 'bracelets_2' }
}

local function currentOutfit(cloakroom)
    return IsPedMale(PlayerPedId()) and cloakroom.outfits.male or cloakroom.outfits.female
end

local function openCloakroomContext(onCivilian, onWork)
    lib.registerContext({
        id = 'sc_tobaccojob_cloakroom',
        title = locale('cloakroom_title'),
        options = {
            {
                title = locale('cloakroom_civilian'),
                icon = 'shirt',
                onSelect = onCivilian
            },
            {
                title = locale('cloakroom_work'),
                icon = 'user-tie',
                onSelect = onWork
            }
        }
    })

    lib.showContext('sc_tobaccojob_cloakroom')
end

local function openSkinchangerCloakroom(cloakroom)
    openCloakroomContext(
        function()
            if skinchangerCivilianSkin then
                TriggerEvent('skinchanger:loadSkin', skinchangerCivilianSkin)
                skinchangerCivilianSkin = nil
                return
            end

            if Bridge.FrameworkName == 'esx' and GetResourceState('esx_skin') == 'started' then
                local esx = Bridge.Framework.GetCore()
                esx.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
                    if skin then TriggerEvent('skinchanger:loadSkin', skin) end
                end)
                return
            end

            debug(locale('debug_clothing_restore_failed', 'skinchanger'))
        end,
        function()
            TriggerEvent('skinchanger:getSkin', function(skin)
                if not skinchangerCivilianSkin then
                    skinchangerCivilianSkin = json.decode(json.encode(skin))
                end
                TriggerEvent('skinchanger:loadClothes', skin, currentOutfit(cloakroom))
            end)
        end
    )
end

local function setAppearanceEntry(entries, idField, id, drawable, texture)
    for i = 1, #entries do
        if entries[i][idField] == id then
            entries[i].drawable = drawable
            entries[i].texture = texture
            return
        end
    end

    entries[#entries + 1] = {
        [idField] = id,
        drawable = drawable,
        texture = texture
    }
end

local function applyIlleniumOutfit(cloakroom)
    local ped = PlayerPedId()
    local appearance = exports['illenium-appearance']:getPedAppearance(ped)
    if not appearance then
        debug(locale('debug_clothing_restore_failed', 'illenium-appearance'))
        return false
    end

    if not illeniumCivilianAppearance then
        illeniumCivilianAppearance = json.decode(json.encode(appearance))
    end

    local outfit = currentOutfit(cloakroom)
    appearance.components = appearance.components or {}
    appearance.props = appearance.props or {}

    for field, mapping in pairs(componentFields) do
        if outfit[field] ~= nil then
            setAppearanceEntry(
                appearance.components,
                'component_id',
                mapping.id,
                outfit[field],
                outfit[mapping.texture] or 0
            )
        end
    end

    for field, mapping in pairs(propFields) do
        if outfit[field] ~= nil then
            setAppearanceEntry(
                appearance.props,
                'prop_id',
                mapping.id,
                outfit[field],
                outfit[mapping.texture] or 0
            )
        end
    end

    exports['illenium-appearance']:setPedAppearance(ped, appearance)
    return true
end

local function openIlleniumCloakroom(cloakroom)
    openCloakroomContext(
        function()
            if illeniumCivilianAppearance then
                exports['illenium-appearance']:setPedAppearance(
                    PlayerPedId(),
                    illeniumCivilianAppearance
                )
                illeniumCivilianAppearance = nil
            else
                TriggerEvent('illenium-appearance:client:reloadSkin', true)
            end
        end,
        function()
            applyIlleniumOutfit(cloakroom)
        end
    )
end

-- CLIENT
function OpenCloakroom(cloakroom)
    if Bridge.ClothingName == 'skinchanger' then
        return openSkinchangerCloakroom(cloakroom)
    end

    if Bridge.ClothingName == 'illenium-appearance' then
        return openIlleniumCloakroom(cloakroom)
    end

    if Bridge.ClothingName == 'rcore_clothing' then
        TriggerEvent('rcore_clothing:openJobChangingRoom', Config.Job.name)
        return true
    end

    if Bridge.ClothingName == 'custom' then
        return Standalone.Clothing.OpenCloakroom(cloakroom, Config.Job)
    end

    debug(locale('debug_clothing_missing'))
    return false
end

-- CLIENT: notificationType: inform, success, warning albo error.
function Standalone.Notify(message, notificationType, duration)
    return customNotConfigured('Notify')
end

-- CLIENT
function Standalone.BossMenu.Open(job)
    return customNotConfigured('BossMenu.Open')
end

-- CLIENT
function Standalone.Clothing.OpenCloakroom(cloakroom, job)
    return customNotConfigured('Clothing.OpenCloakroom')
end

-- CLIENT

function Standalone.ProgressBar.Start(actionName, action)
    return lib.progressCircle({
        duration = action.duration,
        label = action.label,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        },
        anim = action.animation
    })
end

-- SERVER
function Standalone.Inventory.GetItemCount(playerId, itemName, metadata)
    return customNotConfigured('Inventory.GetItemCount')
end

-- SERVER
function Standalone.Inventory.CanCarryItem(playerId, itemName, amount, metadata)
    return customNotConfigured('Inventory.CanCarryItem')
end

-- SERVER
function Standalone.Inventory.AddItem(playerId, itemName, amount, metadata)
    return customNotConfigured('Inventory.AddItem')
end

-- SERVER
function Standalone.Inventory.RemoveItem(playerId, itemName, amount, metadata)
    return customNotConfigured('Inventory.RemoveItem')
end

-- SERVER
function Standalone.Inventory.RegisterStash(stash)
    return customNotConfigured('Inventory.RegisterStash')
end

-- SERVER
function Standalone.Inventory.OpenStash(playerId, stash)
    return customNotConfigured('Inventory.OpenStash')
end

-- CLIENT
function Standalone.Target.AddLocalEntity(entity, options)
    return customNotConfigured('Target.AddLocalEntity')
end

-- CLIENT
function Standalone.Target.RemoveLocalEntity(entity, optionNames)
    return customNotConfigured('Target.RemoveLocalEntity')
end

-- CLIENT
function Standalone.Target.AddModel(models, options)
    return customNotConfigured('Target.AddModel')
end

-- CLIENT
function Standalone.Target.RemoveModel(models, optionNames)
    return customNotConfigured('Target.RemoveModel')
end

-- CLIENT
function Standalone.Target.AddBoxZone(data, options)
    return customNotConfigured('Target.AddBoxZone')
end

-- CLIENT
function Standalone.Target.RemoveZone(zone)
    return customNotConfigured('Target.RemoveZone')
end

-- CLIENT
function Standalone.Vehicle.GiveKeys(vehicle, plate)
    -- TriggerEvent('vehiclekeys:client:SetOwner', plate)
end

-- CLIENT
function Standalone.Vehicle.RemoveKeys(vehicle, plate)
    -- TriggerServerEvent('twoj-zasob:removeKeys', plate)
end
