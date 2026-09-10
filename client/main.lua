local function refreshJobState(playerData)
    Wait(250)
    if Tobacco.RefreshJobState(playerData and (playerData.job or playerData)) then
        Tobacco.RefreshBlips()
    end
end

RegisterNetEvent('esx:playerLoaded', refreshJobState)
RegisterNetEvent('esx:setJob', refreshJobState)

CreateThread(function()
    if not Bridge.AwaitReady(10000) then return end

    Tobacco.RefreshJobState()
    Tobacco.SpawnPeds()
    Tobacco.RegisterTargets()
    Tobacco.SpawnBossMenus()
    Tobacco.RefreshBlips()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Tobacco.Cleanup()
    end
end)
