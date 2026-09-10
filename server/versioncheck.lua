local resourceName = GetCurrentResourceName()
local header = '^6═════════════════════[ Version Check ]═══════════════════════^7'
local footer = '^6═════════════════════════════════════════════════════════════^7'

local function printCheckFailed()
    print(header)
    print(' ')
    print('^8ERROR: ^0Failed to check for update.')
    print(' ')
    print(footer)
end

local function decodeVersionFile(contents)
    if type(contents) ~= 'string' or contents == '' then return end
    local success, data = pcall(json.decode, contents)
    if not success or type(data) ~= 'table' or type(data.version) ~= 'string' then return end

    return data
end

local function parseVersion(version)
    local major, minor, patch = version:match('^v?(%d+)%.(%d+)%.(%d+)')
    if not major then return end

    return tonumber(major), tonumber(minor), tonumber(patch)
end

local function isRemoteNewer(current, remote)
    local currentMajor, currentMinor, currentPatch = parseVersion(current)
    local remoteMajor, remoteMinor, remotePatch = parseVersion(remote)

    if not currentMajor or not remoteMajor then return end
    if remoteMajor ~= currentMajor then return remoteMajor > currentMajor end
    if remoteMinor ~= currentMinor then return remoteMinor > currentMinor end
    return remotePatch > currentPatch
end

local function checkVersion()
    local config = Config.VersionCheck
    if type(config) ~= 'table' or config.enabled ~= true then return end

    local repository = config.repository
    local branch = config.branch or 'main'

    if type(repository) ~= 'string' or repository == '' then
        printCheckFailed()
        return
    end

    local current = decodeVersionFile(LoadResourceFile(resourceName, 'version'))
    if not current then
        printCheckFailed()
        return
    end

    local rawUrl = ('https://raw.githubusercontent.com/%s/%s/version'):format(repository, branch)
    local repositoryUrl = ('https://github.com/%s'):format(repository)

    PerformHttpRequest(rawUrl, function(statusCode, responseText)
        if statusCode ~= 200 then
            printCheckFailed()
            return
        end

        local remote = decodeVersionFile(responseText)
        if not remote then
            printCheckFailed()
            return
        end

        local remoteIsNewer = isRemoteNewer(current.version, remote.version)
        if remoteIsNewer == nil then
            printCheckFailed()
            return
        end

        if not remoteIsNewer then
            print(header)
            print('^2[sc_tobaccojob] - The Script is up to date!')
            print('^7Current Version: ^4' .. current.version .. '^7.')
            print('^7Branch: ^4' .. branch .. '^7.')
            print(footer)
            return
        end

        print(header)
        print('^8[sc_tobaccojob] - New update available now!')
        print('^7Current Version: ^4' .. current.version .. '^7.')
        print('^7New Version: ^4' .. remote.version .. '^7.')
        print('^7Branch: ^4' .. branch .. '^7.')
        print('^7Notes: ^4' .. tostring(remote.message or '-') .. '^7.')
        print(' ')
        print('^4Download it now on ' .. repositoryUrl)
        print(footer)
    end, 'GET', '', {
        ['Cache-Control'] = 'no-cache'
    })
end

CreateThread(function()
    Wait(3000)
    checkVersion()
end)
