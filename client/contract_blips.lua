-- Active-contract-only destination markers. No permanent map clutter.
local markers, currentId = {}, nil
local lastWaypoint = nil
local function clearMarkers()
    for _, blip in ipairs(markers) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    markers = {}
    lastWaypoint = nil
end
local function addMarker(pos, name, sprite, colour, route)
    if not pos then return end
    local blip = AddBlipForCoord(pos.x + 0.0, pos.y + 0.0, pos.z + 0.0)
    SetBlipSprite(blip, sprite or 1)
    SetBlipColour(blip, colour or 3)
    SetBlipScale(blip, 1.05)
    SetBlipHighDetail(blip, true)
    SetBlipPriority(blip, 10)
    SetBlipAsShortRange(blip, false)
    SetBlipDisplay(blip, 4)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(name)
    EndTextCommandSetBlipName(blip)
    if route then
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, 3)
        SetNewWaypoint(pos.x + 0.0, pos.y + 0.0)
        lastWaypoint = pos
    end
    markers[#markers+1] = blip
end
local function nearestHut()
    local here = GetEntityCoords(PlayerPedId())
    local nearest, distance
    for _, spot in ipairs(Config.LoggingDuty or {}) do
        local d = #(here - vector3(spot.x,spot.y,spot.z))
        if not distance or d < distance then nearest, distance = spot, d end
    end
    return nearest
end
local routeToDepot = false
local function destination(job)
    local jobType = job.type
    if jobType == 'trees' or jobType == 'logging' or jobType == 'heavy_logging' then
        local hut = nearestHut()
        if jobType == 'heavy_logging' and routeToDepot then
            addMarker(Config.HeavyLogging.sawmill,'ACTIVE JOB: Paleto Sawmill',318,3,true)
        elseif jobType == 'logging' and routeToDepot then
            local depot = Config.WasteDepot and (Config.WasteDepot.bay or Config.WasteDepot.clerk)
            if depot then addMarker(depot, 'ACTIVE JOB: Deliver Timber - Waste Depot', 318, 3, true) end
        else
            local target = hut
            if jobType == 'trees' and hut then
                local best
                for _, site in ipairs((Config.Logging and Config.Logging.sites) or {}) do
                    local d = #(vector3(site.x,site.y,site.z) - vector3(hut.x,hut.y,hut.z))
                    if not best or d < best then target, best = site, d end
                end
            end
            if target then
                addMarker(target, jobType == 'trees' and 'ACTIVE JOB: Fell Forestry Trees' or 'ACTIVE JOB: Collect Timber', 1, 3, true)
            end
        end
        for _, spot in ipairs(Config.LoggingDuty or {}) do
            addMarker(spot, 'Wonky Forestry Hut', 1, 2, false)
        end
        if jobType == 'heavy_logging' then
            addMarker(Config.HeavyLogging.sawmill,'Paleto Sawmill Delivery',318,2,false)
        end
        if jobType == 'logging' and not routeToDepot and Config.WasteDepot then
            local depot = Config.WasteDepot.bay or Config.WasteDepot.clerk
            if depot then addMarker(depot, 'Timber Delivery - Waste Depot', 318, 2, false) end
        end
    elseif jobType == 'leaves' then
        local spot = Config.LeafSites and Config.LeafSites[1]
        if spot then addMarker(spot,'Leaf Clearing Contract', 1, 3, true) end
    elseif jobType == 'flowers' or jobType == 'hedges' or jobType == 'topiary' then
        local spot = Config.Hedges and Config.Hedges.sites and Config.Hedges.sites[1]
        if spot then addMarker(spot, jobType == 'flowers' and 'Flower Collection' or 'Hedge Trimming', 1, 3, true) end
    else
        for _, plot in ipairs(Config.Plots or {}) do
            if plot.id == job.id then
                addMarker(plot, 'Grass Cutting - '..(job.label or 'Contract'), 1, 3, true)
                break
            end
        end
    end
end

local jobsById = {}
for _, job in ipairs((Config.Contracts and Config.Contracts.jobs) or {}) do jobsById[job.id] = job end
local function apply(id)
    if id == currentId and #markers > 0 then return end
    if id ~= currentId then routeToDepot = false end
    clearMarkers()
    currentId = id
    if id and jobsById[id] then destination(jobsById[id]) end
end
RegisterNetEvent('wonkys_landscaping:contractBlips:accepted', function(id) apply(id) end)
RegisterNetEvent('wonkys_landscaping:contractBlips:clear', function() apply(nil) end)
CreateThread(function()
    Wait(2500)
    while true do
        if GetResourceState('ox_lib') == 'started' then
            local ok, status = pcall(function() return lib.callback.await('wonkys_landscaping:contracts:status', false) end)
            if ok then apply(status and status.id or nil) end
        end
        Wait(7000)
    end
end)
AddEventHandler('onResourceStop',function(resource)
    if resource == GetCurrentResourceName() then clearMarkers() end
end)

RegisterCommand('landscape_gps', function()
    currentId = nil
    local ok, status = pcall(function() return lib.callback.await('wonkys_landscaping:contracts:status', false) end)
    if not ok then print('[Wonkys GPS] Contract status request failed: '..tostring(status)); return end
    apply(status and status.id or nil)
    lib.notify({title="Wonky's Landscaping GPS",description=status and ('Active contract: '..tostring(status.label)..' | markers: '..#markers) or 'No active contract found on server',type=status and 'success' or 'inform'})
    print(('[Wonkys GPS] active=%s markers=%d'):format(status and tostring(status.id) or 'none',#markers))
end,false)

-- Once the contracted number of logs is secured on a nearby company trailer,
-- change the route from the forestry hut to the recycling delivery bay.
RegisterNetEvent('wonkys_landscaping:cargo:sync', function(netId, counts)
    if not currentId or not jobsById[currentId] or jobsById[currentId].type ~= 'logging' then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) or GetEntityModel(veh) ~= joaat(Config.Fleet.trailerModel) then return end
    if #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(veh)) > 20.0 then return end
    local enough = (tonumber(counts and counts.timber) or 0) >= (jobsById[currentId].required or 3)
    if enough ~= routeToDepot then
        routeToDepot = enough
        local id = currentId
        currentId = nil
        apply(id)
        lib.notify({title="Wonky's Forestry GPS", description=enough and 'Timber loaded. GPS now routes to the Waste Depot.' or 'GPS now routes to the forestry hut.', type='inform'})
    end
end)
RegisterCommand('landscape_delivery', function()
    if not currentId or not jobsById[currentId] or jobsById[currentId].type ~= 'logging' then
        lib.notify({title="Wonky's Forestry GPS", description='Accept a logging delivery contract first.', type='error'})
        return
    end
    routeToDepot = true
    local id = currentId
    currentId = nil
    apply(id)
end, false)

RegisterNetEvent('wonkys_landscaping:heavy:sync',function(id,count)
    if not currentId or not jobsById[currentId] or jobsById[currentId].type~='heavy_logging' then return end
    local veh=NetworkGetEntityFromNetworkId(id)
    if veh==0 or not DoesEntityExist(veh) or #(GetEntityCoords(PlayerPedId())-GetEntityCoords(veh))>30 then return end
    local enough=(tonumber(count) or 0)>=(jobsById[currentId].required or 4)
    if enough~=routeToDepot then
        routeToDepot=enough
        local current=currentId;currentId=nil;apply(current)
        lib.notify({title='Wonky Heavy Logging',description=enough and 'Trailer loaded. Route set to Paleto sawmill.' or 'GPS returned to forestry.',type='inform'})
    end
end)
