fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Scriptify'
description 'Tobacco job'
version '1.1.0'

files {
    'version',
    'locales/*.json',
    'stream/[models]/prop_sc_tobacco_plant.ytyp',
    'stream/[interior]/slth_warehouse.ytyp'
}

data_file 'DLC_ITYP_REQUEST' 'stream/[models]/prop_sc_tobacco_plant.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/[interior]/slth_warehouse.ytyp'

this_is_a_map 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/locale.lua',
    'shared/config.lua',
    'data/settings.lua',
    'bridge/bridge.lua'
}

client_scripts {
    'client/bossmenu.lua',
    'client/functions.lua',
    'client/targets.lua',
    'client/main.lua'
}

server_scripts {
    'server/bridge.lua',
    'server/main.lua',
    'server/versioncheck.lua'
}

dependency 'ox_lib'
