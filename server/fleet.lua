local lastRequest = {}
local authorisedFleet = {}
lib.callback.register('wonkys_landscaping:fleetPermission', function(src)
    if not Config.Fleet or not Config.Fleet.enabled or not LandscapingOnShift(src) then return false end
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    local depot = Config.Fleet.depot
    local logging = Config.Fleet.loggingDepot
    local atGolf = #(pos - vector3(depot.x,depot.y,depot.z)) <= 25.0
    local atLogging = logging and #(pos - vector3(logging.x,logging.y,logging.z)) <= 25.0
    if not atGolf and not atLogging then return false end
    local now = GetGameTimer()
    if lastRequest[src] and now - lastRequest[src] < 1500 then return false end
    lastRequest[src] = now
    if Config.RequireJob then
        local player = exports.qbx_core:GetPlayer(src)
        if not player or not player.PlayerData or player.PlayerData.job.name ~= Config.Job then return false end
    end
    -- Short-lived, single fleet authorisation. A plate alone never grants keys.
    authorisedFleet[src] = {issued=GetGameTimer(), granted={}, origin=atLogging and 'logging' or 'golf'}
    return true, atLogging and 'logging' or 'golf'
end)
AddEventHandler('playerDropped', function() lastRequest[source] = nil end)

-- Server-authoritative key grants for fleet vehicles. Allow network replication to settle.
local keyRequests = {}
lib.callback.register('wonkys_landscaping:grantFleetKeys', function(src, netId, label)
    if not LandscapingOnShift(src) then return false end
    local permit = authorisedFleet[src]
    if not permit or GetGameTimer()-permit.issued > 60000 or GetGameTimer()-permit.issued < 0 then return false end
    if permit.granted[label] and permit.granted[label] ~= netId then return false end
    if GetResourceState('qbx_vehiclekeys') ~= 'started' then
        print('[Wonkys_Landscaping] Keys: qbx_vehiclekeys is not started')
        return false
    end
    if type(netId) ~= 'number' or netId <= 0 or (label ~= 'Van' and label ~= 'Mower') then return false end
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local depot = Config.Fleet.depot
    local logging = Config.Fleet.loggingDepot
    local playerPos = GetEntityCoords(ped)
    local atGolf = #(playerPos - vector3(depot.x,depot.y,depot.z)) <= 60.0
    local atLogging = logging and #(playerPos - vector3(logging.x,logging.y,logging.z)) <= 60.0
    if not atGolf and not atLogging then return false end
    if permit.origin=='golf' and not atGolf then return false end
    if permit.origin=='logging' and not atLogging then return false end
    local vehicle = 0
    for i = 1, 20 do
        vehicle = NetworkGetEntityFromNetworkId(netId)
        if vehicle ~= 0 and DoesEntityExist(vehicle) then break end
        Wait(150)
    end
    if vehicle == 0 or not DoesEntityExist(vehicle) then
        print(('[Wonkys_Landscaping] Keys: %s vehicle netId %s not resolved'):format(label,netId))
        return false
    end
    -- A permit and a matching plate are insufficient: require network ownership.
    if NetworkGetEntityOwner(vehicle) ~= src then return false end
    local model = GetEntityModel(vehicle)
    local allowed = false
    if label == 'Mower' then
        allowed = model == joaat(Config.Fleet.mowerModel)
    else
        allowed = model == joaat(Config.Fleet.vanModel)
        for _,option in ipairs(Config.Fleet.vehicleOptions or {}) do
            if type(option.model)=='string' and model == joaat(option.model) then allowed = true; break end
        end
    end
    if not allowed then
        print(('[Wonkys_Landscaping] Keys: %s model mismatch, hash=%s'):format(label,model))
        return false
    end
    local vehiclePos = GetEntityCoords(vehicle)
    local nearGolf = #(vehiclePos - vector3(depot.x,depot.y,depot.z)) <= 75.0
    local nearLogging = logging and #(vehiclePos - vector3(logging.x,logging.y,logging.z)) <= 75.0
    if not nearGolf and not nearLogging then return false end
    local plate = GetVehicleNumberPlateText(vehicle) or ''
    if not plate:match('^WONKY%d%d%d%s*$') then
        print(('[Wonkys_Landscaping] Keys: unexpected %s plate %s'):format(label,plate))
        return false
    end
    keyRequests[src] = keyRequests[src] or {}
    local last = keyRequests[src][netId]
    if last and GetGameTimer()-last < 3000 then return true end
    local ok,err = pcall(function() exports.qbx_vehiclekeys:GiveKeys(src,vehicle) end)
    if not ok then
        print(('[Wonkys_Landscaping] Keys: server GiveKeys failed for %s: %s'):format(label,tostring(err)))
        return false
    end
    keyRequests[src][netId] = GetGameTimer()
    permit.granted[label] = netId
    print(('[Wonkys_Landscaping] Keys granted: %s / %s / %s'):format(src,label,plate))
    return true
end)
AddEventHandler('playerDropped',function() keyRequests[source] = nil; authorisedFleet[source] = nil end)
