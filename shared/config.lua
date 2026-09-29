Config = {}

Config.Debug = false
Config.VersionCheck = {
    enabled = true,
    repository = 'Scriptify-pl/TobaccoJob',
    branch = 'main'
}

-- Framework: auto, esx
-- Target:    auto, ox_target, qtarget, custom
-- Inventory: auto, ox_inventory, esx_inventory, custom
-- Notify:    auto, ox_lib, esx_notify, custom
-- Clothing:  auto, skinchanger, illenium-appearance, rcore_clothing, custom
-- Boss menu: auto, esx_society, custom
Config.Integrations = {
    framework = 'auto',
    target = 'auto',
    inventory = 'auto',
    notify = 'auto',
    clothing = 'auto',
    bossmenu = 'auto'
}

Config.Job = {
    name = 'tobacco',
    label = locale('job_label'),
    required = false
}

Config.Items = {
    leaf = 'tobaco_tytnon',
    cigarettes = 'tobaco_papierosy',
    pack = 'tobaco_paczka'
}

Config.Actions = {
    gather = {
        model = `prop_sc_tobacco_plant`,
        area = {
            coords = vector3(2926.0, 4680.0, 50.0),
            radius = 30.0
        },
        distance = 2.5,
        duration = 5000,
        label = locale('action_gather_label'),
        targetLabel = locale('target_gather'),
        icon = 'fa-solid fa-seedling',
        animation = {
            dict = 'amb@prop_human_movie_bulb@base',
            clip = 'base',
            flag = 1
        },
        output = { item = Config.Items.leaf, count = 1, maximum = 10 }
    },
    process = {
        target = {
            name = 'tobacco_process',
            coords = vector3(2483.52, 3726.40, 43.22),
            size = vector3(1.2, 2.2, 4.0),
            rotation = 35.0
        },
        distance = 3.0,
        duration = 5000,
        label = locale('action_process_label'),
        targetLabel = locale('target_process'),
        icon = 'fa-solid fa-gears',
        animation = {
            dict = 'mini@repair',
            clip = 'fixing_a_ped',
            flag = 1
        },
        input = { item = Config.Items.leaf, count = 1 },
        output = { item = Config.Items.cigarettes, count = 1, maximum = 10 }
    },
    pack = {
        target = {
            name = 'tobacco_pack',
            coords = vector3(2680.99, 3507.40, 53.30),
            size = vector3(1.7, 3.9, 4.0),
            rotation = 250.0
        },
        distance = 3.0,
        duration = 3000,
        label = locale('action_pack_label'),
        targetLabel = locale('target_pack'),
        icon = 'fa-solid fa-box',
        animation = {
            dict = 'mp_am_hold_up',
            clip = 'purchase_beerbox_shopkeeper',
            flag = 1
        },
        input = { item = Config.Items.cigarettes, count = 2 },
        output = { item = Config.Items.pack, count = 1, maximum = 5 }
    },
    sell = {
        distance = 3.0,
        duration = 3000,
        label = locale('action_sell_label'),
        targetLabel = locale('target_sell'),
        icon = 'fa-solid fa-handshake',
        input = { item = Config.Items.pack, count = 1 },
        payment = {
            account = 'cash',
            minimum = 250,
            maximum = 1000
        }
    }
}

Config.PaymentAnimation = {
    dictionary = 'sc_tobacco@payment',
    clip = 'base',
    flag = 0,
    duration = 7100,
    transactionTimeout = 30000,
    serverMinimumDuration = 6500,
    playerPosition = {
        offset = vector3(0.0, 1.05, 0.0),
        speed = 1.0,
        timeout = 2500
    },
    receiver = {
        dictionary = 'mp_common',
        clip = 'givetake1_a',
        flag = 0,
        startTime = 4.15,
        duration = 1800
    },
    props = {
        {
            owner = 'seller',
            model = `prop_ld_wallet_02`,
            bone = 57005,
            transform = vector3(0.150, 0.070, -0.030),
            rotation = vector3(90.000, 30.000, 180.000),
            startTime = 2.35,
            endTime = 3.58
        },
        {
            owner = 'seller',
            model = `ba_prop_battle_wallet_pickup`,
            bone = 57005,
            transform = vector3(0.180, 0.090, -0.080),
            rotation = vector3(90.000, 30.000, 200.000),
            startTime = 3.58,
            endTime = 6.35
        },
        {
            owner = 'seller',
            model = `xs_prop_arena_cash_pile_s`,
            bone = 18905,
            transform = vector3(0.120, 0.040, 0.050),
            rotation = vector3(90.000, 0.000, 30.000),
            startTime = 4.22,
            endTime = 5.30
        },
        {
            owner = 'player',
            model = `xs_prop_arena_cash_pile_s`,
            bone = 57005,
            transform = vector3(0.110, 0.020, -0.020),
            rotation = vector3(90.000, 0.000, 30.000),
            startTime = 5.25,
            endTime = 6.10
        },
        {
            owner = 'seller',
            model = `prop_ld_wallet_02`,
            bone = 57005,
            transform = vector3(0.150, 0.070, -0.030),
            rotation = vector3(90.000, 30.000, 180.000),
            startTime = 6.35,
            endTime = 7.10
        }
    }
}

Config.Peds = {
    vehicle = {
        model = `s_m_y_airworker`,
        coords = vector4(934.1537, -1469.2609, 29.2024, 177.1132)
    },
    seller = {
        model = `s_m_y_airworker`,
        coords = vector4(943.8273, -1473.7754, 29.2024, 91.9922)
    }
}

Config.Vehicle = {
    model = `speedo`,
    spawn = vector4(939.6543, -1467.7646, 30.1024, 176.2909),
    returnRadius = 5.0
}

Config.Stash = {
    id = 'tobaccofactory',
    label = locale('stash_label'),
    slots = 100,
    weight = 300000,
    target = {
        name = 'tobacco_stash',
        coords = vector3(944.47, -1459.73, 33.61),
        size = vector3(0.9, 2.7, 4.0),
        rotation = 0.0
    }
}

Config.Cloakroom = {
    target = {
        name = 'tobacco_cloakroom',
        coords = vector3(930.28, -1462.18, 33.94),
        size = vector3(1.0, 5.2, 4.0),
        rotation = 270.0
    },
    outfits = {
        male = {
            tshirt_1 = 15, tshirt_2 = 0,
            torso_1 = 270, torso_2 = 1,
            decals_1 = 0, decals_2 = 0,
            arms = 0, arms_2 = 0,
            pants_1 = 33, pants_2 = 0,
            shoes_1 = 25, shoes_2 = 0,
            bproof_1 = 64, bproof_2 = 1,
            helmet_1 = 150, helmet_2 = 0
        },
        female = {
            tshirt_1 = 188, tshirt_2 = 0,
            torso_1 = 44, torso_2 = 0,
            decals_1 = 0, decals_2 = 0,
            arms = 3,
            pants_1 = 72, pants_2 = 1,
            shoes_1 = 29, shoes_2 = 0,
            mask_1 = 0, mask_2 = 0,
            bproof_1 = 0, bproof_2 = 0,
            chain_1 = 0, chain_2 = 0
        }
    }
}

Config.Blips = {
    {
        coords = vector3(2918.6150, 4676.8984, 49.4370),
        label = locale('blip_field'),
        sprite = 569,
        colour = 21,
        scale = 0.5,
        jobOnly = true
    },
    {
        coords = vector3(2483.0349, 3727.2400, 43.3444),
        label = locale('blip_processing'),
        sprite = 569,
        colour = 21,
        scale = 0.5,
        jobOnly = true
    },
    {
        coords = vector3(2677.6499, 3510.7268, 52.7121),
        label = locale('blip_packing'),
        sprite = 569,
        colour = 21,
        scale = 0.5,
        jobOnly = true
    },
    {
        coords = vector3(943.2993, -1474.0209, 30.1026),
        label = locale('blip_sales'),
        sprite = 569,
        colour = 21,
        scale = 0.5,
        jobOnly = true
    },
    {
        coords = vector3(947.3734, -1483.5995, 32.2976),
        label = locale('job_label'),
        sprite = 569,
        colour = 66,
        scale = 0.8,
        jobOnly = false
    }
}


Config.BossMenus = {
    {
        table = {
            model = `h4_prop_office_desk_01`,
            coords = vector4(934.4948, -1463.0862, 33.61 - 1.0, 90.00)
        },
        computer = {
            model = `xm_prop_x17_computer_01`,
            offset = vector4(0.0, 0.0, 0.80, 0.0)
        },
        chair = {
            model = 1339364336,
            offset = vector4(0.0, -1.05, 0.60, 180.0)
        },
        target = {
            open = {
                icon = 'fa-solid fa-computer',
                label = locale('target_bossmenu_open'),
                distance = 2.5
            },
            close = {
                icon = 'fa-solid fa-right-from-bracket',
                label = locale('target_bossmenu_close'),
                distance = 2.5
            }
        }
    }
}
