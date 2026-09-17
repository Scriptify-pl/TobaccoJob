<div align="center">

# SC Tobacco Job

A configurable and secure tobacco job for FiveM servers running ESX.

![FiveM](https://img.shields.io/badge/FiveM-Cerulean-orange)
![Framework](https://img.shields.io/badge/Framework-ESX-blue)
![Dependency](https://img.shields.io/badge/Dependency-ox__lib-blueviolet)

</div>

## Features

- Complete tobacco production process:
  - Gather tobacco leaves
  - Process tobacco
  - Pack cigarettes
  - Sell cigarette packs
- Secure server-side validation
- Automatic integration detection
- Configurable target and inventory systems
- Optional job requirement
- Custom tobacco plant model and field
- Animated boss office with table, chair and computer
- Configurable and cancellable progress bar
- Configurable male and female work outfits
- Polish and English translations
- GitHub version checker
- Custom integration support
- Included job vehicle, stash, seller and map blips

## Requirements

### Required

- [ox_lib](https://github.com/overextended/ox_lib)
- [es_extended](https://github.com/esx-framework/esx_core)

### Target

Select one:

- [ox_target](https://github.com/overextended/ox_target)
- qtarget
- Custom target integration

### Inventory

Select one:

- [ox_inventory](https://github.com/overextended/ox_inventory)
- Default ESX inventory
- Custom inventory integration

### Optional integrations

- esx_notify
- skinchanger with esx_skin
- illenium-appearance
- rcore_clothing
- esx_society

## Supported integrations

| System | Available options |
|---|---|
| Framework | `auto`, `esx` |
| Target | `auto`, `ox_target`, `qtarget`, `custom` |
| Inventory | `auto`, `ox_inventory`, `esx_inventory`, `custom` |
| Notifications | `auto`, `ox_lib`, `esx_notify`, `custom` |
| Clothing | `auto`, `skinchanger`, `illenium-appearance`, `rcore_clothing`, `custom` |
| Boss menu | `auto`, `esx_society`, `custom` |

Integration detection is performed on the server. Clients receive only the selected integration names.

## Installation

### 1. Install the resource

Place the resource in your server resources directory:

```text
resources/sc_tobaccojob
```

Keep the resource folder name as:

```text
sc_tobaccojob
```

### 2. Install the required resources

Make sure `ox_lib`, `es_extended`, your inventory and your target system start before `sc_tobaccojob`.

Example:

```cfg
ensure ox_lib
ensure es_extended
ensure ox_inventory
ensure ox_target
ensure esx_society
ensure sc_tobaccojob
```

Replace the example inventory, target and boss menu resources with those used by your server.

### 3. Import the job SQL

The ESX job and society SQL is located here:

```text
sc_tobaccojob/sql/install.sql
```

This file creates:

- Society account
- Shared datastore
- Shared society inventory
- Tobacco job
- Tobacco job grades

> **Important:** `sql/install.sql` does not create the inventory items. Install the items separately using the instructions below.

## Items and icons

All item definitions and icons are located inside:

```text
sc_tobaccojob/items/
```

| Icon | Item name | Label | Weight |
|:---:|---|---|---:|
| <img src="./items/tobaco_tytnon.png" width="64" alt="Tobacco Leaf"> | `tobaco_tytnon` | Liść Tytoniu | 500 |
| <img src="./items/tobaco_papierosy.png" width="64" alt="Cigarettes"> | `tobaco_papierosy` | Papierosy | 750 |
| <img src="./items/tobaco_paczka.png" width="64" alt="Cigarette Pack"> | `tobaco_paczka` | Paczka Papierosów | 1500 |

### ox_inventory

The item definitions are available here:

```text
sc_tobaccojob/items/ox_inventory.md
```

Copy the definitions from that file to:

```text
ox_inventory/data/items.lua
```

Copy these icons:

```text
sc_tobaccojob/items/tobaco_tytnon.png
sc_tobaccojob/items/tobaco_papierosy.png
sc_tobaccojob/items/tobaco_paczka.png
```

Into:

```text
ox_inventory/web/images/
```

Restart `ox_inventory` after installing the items.

### Default ESX inventory

The SQL item definitions are available here:

```text
sc_tobaccojob/items/esx_inventory.md
```

Execute the SQL query from that file in your database.

After importing it, restart:

```text
es_extended
sc_tobaccojob
```

The default ESX inventory does not use item icons. If your inventory interface supports images, copy the PNG files from `sc_tobaccojob/items/` to the image directory used by that interface.

## Default production process

| Step | Required item | Reward | Default limit |
|---|---|---|---:|
| Gather tobacco | None | 1 tobacco leaf | 10 |
| Process tobacco | 1 tobacco leaf | 1 cigarette item | 10 |
| Pack cigarettes | 2 cigarette items | 1 cigarette pack | 5 |
| Sell a pack | 1 cigarette pack | $250–$1,000 cash | None |

Amounts, limits, action durations and payments can be changed in `Config.Actions`.

## Configuration

The main configuration is located here:

```text
sc_tobaccojob/shared/config.lua
```

### Integration configuration

Use `auto` to let the server detect running resources:

```lua
Config.Integrations = {
    framework = 'auto',
    target = 'auto',
    inventory = 'auto',
    notify = 'auto',
    clothing = 'auto',
    bossmenu = 'auto'
}
```

You can also select every integration manually.

Example:

```lua
Config.Integrations = {
    framework = 'esx',
    target = 'ox_target',
    inventory = 'ox_inventory',
    notify = 'ox_lib',
    clothing = 'skinchanger',
    bossmenu = 'esx_society'
}
```

### Working without a job

To allow every player to use the tobacco production process:

```lua
Config.Job = {
    name = 'tobacco',
    label = locale('job_label'),
    required = false
}
```

To require the `tobacco` job:

```lua
Config.Job = {
    name = 'tobacco',
    label = locale('job_label'),
    required = true
}
```

Boss menu access always requires the configured boss job grade.

### Items

Item names can be changed here:

```lua
Config.Items = {
    leaf = 'tobaco_tytnon',
    cigarettes = 'tobaco_papierosy',
    pack = 'tobaco_paczka'
}
```

Remember to use the same names in your inventory configuration.

### Available configuration sections

- `Config.Actions`  
  Gathering, processing, packing and selling settings.

- `Config.Peds`  
  Vehicle worker and seller ped models and positions.

- `Config.Vehicle`  
  Job vehicle model, spawn position and return distance.

- `Config.Stash`  
  Stash identifier, capacity and target position.

- `Config.Cloakroom`  
  Cloakroom target and male/female work outfits.

- `Config.Blips`  
  Map marker positions, colours, sizes and job visibility.

- `Config.BossMenus`  
  Boss office table, computer, chair and target configuration.

## Custom integrations

Custom integration functions are located here:

```text
sc_tobaccojob/data/settings.lua
```

The `Standalone` table contains custom hooks for:

- Inventory
- Target
- Notifications
- Clothing
- Boss menu
- Vehicle keys
- Progress bar

After implementing a custom integration, select `custom` in `Config.Integrations`.

Example:

```lua
Config.Integrations = {
    framework = 'esx',
    target = 'custom',
    inventory = 'custom',
    notify = 'custom',
    clothing = 'custom',
    bossmenu = 'custom'
}
```

## Custom progress bar

The default progress bar uses `lib.progressCircle`.

You can replace it inside:

```text
sc_tobaccojob/data/settings.lua
```

Function:

```lua
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
```

The function must:

- Wait until the progress bar finishes
- Return `true` when completed
- Return `false` when cancelled

## Locales

Available languages:

- English
- Polish

Locale files:

```text
sc_tobaccojob/locales/en.json
sc_tobaccojob/locales/pl.json
```

Set the language in `server.cfg`:

```cfg
setr ox:locale en
```

For Polish:

```cfg
setr ox:locale pl
```

## Debug mode

Debug mode can be enabled in `shared/config.lua`:

```lua
Config.Debug = true
```

When enabled, the server prints diagnostic messages and the formatted integration detection summary.

Disable it for production:

```lua
Config.Debug = false
```

## Version check

Version check settings are located in `shared/config.lua`:

```lua
Config.VersionCheck = {
    enabled = true,
    repository = 'Scriptify-pl/TobaccoJob',
    branch = 'main'
}
```

The version checker:

- Runs on the server
- Works independently of `Config.Debug`
- Reads the local `version` file
- Checks the configured GitHub branch
- Supports semantic version comparison
- Prints the result in the FXServer console

## Security

The server validates:

- Player job
- Player position
- Action distance
- Action cooldown
- Required item amounts
- Inventory capacity
- Maximum item limits
- Item removal
- Item rewards
- Sale payments
- Stash access

Job actions use secure ox_lib callbacks.

## Resource structure

```text
sc_tobaccojob/
├── bridge/
│   └── bridge.lua
├── client/
│   ├── bossmenu.lua
│   ├── functions.lua
│   ├── main.lua
│   └── targets.lua
├── data/
│   └── settings.lua
├── items/
│   ├── esx_inventory.md
│   ├── ox_inventory.md
│   ├── tobaco_paczka.png
│   ├── tobaco_papierosy.png
│   └── tobaco_tytnon.png
├── locales/
│   ├── en.json
│   └── pl.json
├── server/
│   ├── bridge.lua
│   ├── main.lua
│   └── versioncheck.lua
├── shared/
│   ├── config.lua
│   └── locale.lua
├── sql/
│   └── install.sql
├── stream/
├── CHANGELOG.md
├── fxmanifest.lua
└── version
```
## Author

Created by **Scriptify**
