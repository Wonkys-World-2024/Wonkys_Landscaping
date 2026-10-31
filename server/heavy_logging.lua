-- Separate heavy timber ledger; existing cotrailer cargo is untouched.
local loads, locks, fleet = {}, {}, {}
local authorisedRigKeys = {}
local cfg = Config.HeavyLogging
local function near(src, ent, radius)
    local ped=GetPlayerPed(src)
    return ped~=0 and ent~=0 and DoesEntityExist(ent) and #(GetEntityCoords(ped)-GetEntityCoords(ent))<=radius
end
local function trailer(src,id)
    if type(id)~='number' or id<1 then return nil end
    local ent=NetworkGetEntityFromNetworkId(id)
    if ent==0 or not DoesEntityExist(ent) or GetEntityModel(ent)~=joaat(cfg.trailerModel) or not near(src,ent,9.0) or GetEntitySpeed(ent)>0.6 then return nil end
    return ent
end
local function send(id,target)
    TriggerClientEvent('wonkys_landscaping:heavy:sync',target or -1,id,loads[id] or 0)
end
lib.callback.register('wonkys_landscaping:heavy:permit',function(src)
    if not LandscapingAuthorized(src) then return false,'Start your landscaping shift first' end
    local p=GetEntityCoords(GetPlayerPed(src)); local close=false
    for _,hut in ipairs(Config.LoggingDuty or {}) do
        if #(p-vector3(hut.x,hut.y,hut.z))<30 then close=true;break end
    end
    if not close then return false,'Visit a forestry hut to collect the logging rig' end
    if fleet[src] and GetGameTimer()-fleet[src]<60000 then return false,'Please wait before collecting another rig' end
    fleet[src]=GetGameTimer()
    authorisedRigKeys[src]={issued=GetGameTimer(),netId=nil}
    return true,'Logging rig authorised'
end)
lib.callback.register('wonkys_landscaping:heavy:load',function(src,id)
    if not LandscapingAuthorized(src) then return false,'Start your shift first' end
    if not trailer(src,id) then return false,'Park beside a stationary trflat trailer' end
    if locks[id] then return false,'Trailer is busy' end
    locks[id]=true
    local n=loads[id] or 0
    if n>=cfg.capacity then locks[id]=nil;return false,'Timber trailer is full' end
    if (exports.ox_inventory:GetItemCount(src,Config.Logging.logItem) or 0)<1 then locks[id]=nil;return false,'Collect timber logs first' end
    if not exports.ox_inventory:RemoveItem(src,Config.Logging.logItem,1) then locks[id]=nil;return false,'Unable to remove timber from inventory' end
    loads[id]=n+1;send(id);locks[id]=nil
    return true,('Timber secured: %d/%d'):format(loads[id],cfg.capacity)
end)
lib.callback.register('wonkys_landscaping:heavy:unload',function(src,id)
    if not LandscapingAuthorized(src) then return false,'Start your shift first' end
    local ent=trailer(src,id)
    if not ent then return false,'Park beside your stationary trflat trailer' end
    if locks[id] then return false,'Trailer is busy' end
    locks[id]=true
    local n=loads[id] or 0
    if n<1 then locks[id]=nil;return false,'Trailer is empty' end
    local bay=cfg.sawmill
    if #(GetEntityCoords(ent)-vector3(bay.x,bay.y,bay.z))>cfg.deliveryRadius then
        locks[id]=nil;return false,'Deliver to the Paleto sawmill unloading bay first'
    end
    -- Sale and contract progress are awarded only after a validated sawmill delivery.
    local price=cfg.pricePerLog
    local ok=exports.qbx_core:AddMoney(src,'bank',price,'wonkys-heavy-timber-sale')
    if not ok then locks[id]=nil;return false,'Bank payment failed; timber retained' end
    loads[id]=n-1;send(id)
    if LandscapingContractHeavyTimberDelivery then LandscapingContractHeavyTimberDelivery(src,1) end
    locks[id]=nil
    return true,('Delivered 1 timber log (+$%d). Remaining: %d'):format(price,loads[id])
end)
RegisterNetEvent('wonkys_landscaping:heavy:request',function(id)
    local src=source
    if LandscapingEventAllowed(src,'heavy:request',1200) and trailer(src,id) then send(id,src) end
end)
CreateThread(function()
    while true do
        Wait(60000)
        for id in pairs(loads) do
            if NetworkGetEntityFromNetworkId(id)==0 then loads[id]=nil;locks[id]=nil end
        end
    end
end)
AddEventHandler('playerDropped',function() fleet[source]=nil;authorisedRigKeys[source]=nil end)
lib.callback.register('wonkys_landscaping:heavy:canReturn',function(src,id)
    if not LandscapingAuthorized(src) then return false,'Start your shift first' end
    if not trailer(src,id) then return false,'Park beside your stationary trailer' end
    if (loads[id] or 0)>0 then return false,'Unload your timber before returning the trailer' end
    return true,'Ready to return'
end)

lib.callback.register('wonkys_landscaping:heavy:keys', function(src, id)
    if not LandscapingAuthorized(src) then return false end
    local permit=authorisedRigKeys[src]
    if not permit or GetGameTimer()-permit.issued>60000 or GetGameTimer()-permit.issued<0 then return false end
    if permit.netId and permit.netId~=id then return false end
    if GetResourceState('qbx_vehiclekeys') ~= 'started' then
        print('[Heavy Logging Keys] qbx_vehiclekeys not started')
        return false
    end
    if type(id) ~= 'number' or id <= 0 then return false end
    local veh = 0
    for i = 1, 12 do
        veh = NetworkGetEntityFromNetworkId(id)
        if veh ~= 0 and DoesEntityExist(veh) then break end
        Wait(150)
    end
    if veh == 0 or not DoesEntityExist(veh) then return false end
    if NetworkGetEntityOwner(veh) ~= src then return false end
    if GetEntityModel(veh) ~= joaat(cfg.truckModel) or not near(src, veh, 55.0) then return false end
    local p = GetEntityCoords(veh)
    local atHut = false
    for _, hut in ipairs(Config.LoggingDuty or {}) do
        if #(p - vector3(hut.x, hut.y, hut.z)) < 100.0 then atHut = true; break end
    end
    if not atHut then return false end
    local plate = GetVehicleNumberPlateText(veh) or ''
    if not plate:match('^WONKY%d%d%d%s*$') then return false end
    local ok, err = pcall(function() exports.qbx_vehiclekeys:GiveKeys(src, veh) end)
    if not ok then
        print(('[Heavy Logging Keys] GiveKeys failed: %s'):format(tostring(err)))
        return false
    end
    permit.netId=id
    print(('[Heavy Logging Keys] Issued to player %d for %s'):format(src, plate))
    return true
end)
