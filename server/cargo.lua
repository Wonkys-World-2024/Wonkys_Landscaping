-- Server-authoritative inventory-to-trailer cargo. Cargo belongs to the trailer's network ID.
local cargo = {}
local cargoEntities = {}
local types = {grass='landscape_grass_clippings',leaves='landscape_leaf_bag',timber='landscape_timber_log',flowers=(Config.Gardening and Config.Gardening.harvestItem or 'landscape_flowers')}
local function trailerNear(src,netId)
    if type(netId)~='number' or netId<1 then return nil end
    local veh=NetworkGetEntityFromNetworkId(netId)
    local ped=GetPlayerPed(src)
    if veh==0 or ped==0 or not DoesEntityExist(veh) or GetEntityModel(veh)~=joaat(Config.Fleet.trailerModel) then return nil end
    if #(GetEntityCoords(ped)-GetEntityCoords(veh))>7.0 then return nil end
    if GetEntitySpeed(veh)>0.7 then return nil end
    if cargoEntities[netId] and cargoEntities[netId] ~= veh then return nil end
    return veh
end
local function update(netId)
    TriggerClientEvent('wonkys_landscaping:cargo:sync',-1,netId,cargo[netId] or {grass=0,leaves=0,timber=0,flowers=0})
end
lib.callback.register('wonkys_landscaping:cargo:load',function(src,netId,kind)
    if not LandscapingAuthorized(src) or not types[kind] or not trailerNear(src,netId) then return false,'Stop beside the company trailer while on shift' end
    local record=cargo[netId] or {grass=0,leaves=0,timber=0,flowers=0}
    if kind=='flowers' then
        if (record.flowers or 0)>=(Config.Cargo.flowerCrateCapacity or 12) then return false,'Flower crate rack is full' end
    elseif kind=='timber' then
        if (record.timber or 0)>=(Config.Cargo.timberCapacity or 6) then return false,'Trailer timber rack is full' end
    elseif record.grass+record.leaves>=Config.Cargo.capacity then
        return false,'Trailer waste rack is full'
    end
    if (exports.ox_inventory:GetItemCount(src,types[kind]) or 0)<1 then return false,'No bag of that type in inventory' end
    if not exports.ox_inventory:RemoveItem(src,types[kind],1) then return false,'Unable to remove bag' end
    record[kind]=(record[kind] or 0)+1;cargo[netId]=record;cargoEntities[netId]=NetworkGetEntityFromNetworkId(netId);update(netId)
    return true,(kind=='flowers' and 'Flower crate secured on trailer' or kind=='timber' and 'Timber secured on trailer' or 'Bag secured on trailer')
end)
lib.callback.register('wonkys_landscaping:cargo:unload',function(src,netId,kind)
    if not LandscapingAuthorized(src) or not types[kind] or not trailerNear(src,netId) then return false,'Stop beside the company trailer while on shift' end
    local record=cargo[netId]
    if not record or (record[kind] or 0)<1 then return false,'No such bags on the trailer' end
    if not exports.ox_inventory:CanCarryItem(src,types[kind],1) then return false,'Inventory is full' end
    record[kind]=record[kind]-1
    if not exports.ox_inventory:AddItem(src,types[kind],1) then record[kind]=(record[kind] or 0)+1;return false,'Unable to receive bag' end
    update(netId)
    return true,(kind=='flowers' and 'Flower crate returned to inventory' or kind=='timber' and 'Timber returned to inventory' or 'Bag unloaded into inventory')
end)
RegisterNetEvent('wonkys_landscaping:cargo:request',function(netId)
    if LandscapingEventAllowed(source,'cargo:request',1000) and trailerNear(source,netId) then TriggerClientEvent('wonkys_landscaping:cargo:sync',source,netId,cargo[netId] or {grass=0,leaves=0,timber=0,flowers=0}) end
end)
-- Cargo is intentionally not deleted on player disconnect; it remains with the spawned trailer.
CreateThread(function()
    while true do
        Wait(60000)
        for netId in pairs(cargo) do
            if NetworkGetEntityFromNetworkId(netId)==0 or (cargoEntities[netId] and cargoEntities[netId] ~= NetworkGetEntityFromNetworkId(netId)) then cargo[netId]=nil;cargoEntities[netId]=nil end
        end
    end
end)

-- v0.23.1: Sell trailer cargo directly at the recycling depot.
-- Server owns counts and computes prices; the client never supplies a payout.
local selling = {}
lib.callback.register('wonkys_landscaping:cargo:recycle',function(src,netId)
    if not LandscapingAuthorized(src) then return false,'Start your landscaping shift first' end
    local trailer=trailerNear(src,netId)
    if not trailer then return false,'Park beside your stationary trailer' end
    local depot=Config.Recycling.grass.coords
    if #(GetEntityCoords(trailer)-vector3(depot.x,depot.y,depot.z)) > (Config.Cargo.recycleRadius or 18.0) then
        return false,'Drive the trailer to the recycling depot first'
    end
    if selling[netId] then return false,'This trailer is already being processed' end
    local record=cargo[netId]
    if not record then return false,'There is no cargo on this trailer' end
    local grass=math.max(0,math.floor(tonumber(record.grass) or 0))
    local leaves=math.max(0,math.floor(tonumber(record.leaves) or 0))
    local timber=math.max(0,math.floor(tonumber(record.timber) or 0))
    local flowers=math.max(0,math.floor(tonumber(record.flowers) or 0))
    if grass+leaves+timber+flowers==0 then return false,'There is no cargo on this trailer' end
    selling[netId]=true
    local amount=grass*Config.Recycling.grass.price+leaves*Config.Recycling.leaves.price+timber*(Config.Cargo.timberSalePrice or 90)+flowers*(Config.Cargo.flowerCratePrice or 35)
    -- Remove the load before awarding money to prevent repeat claims.
    cargo[netId]={grass=0,leaves=0,timber=0,flowers=0}
    local success=exports.qbx_core:AddMoney(src,'bank',amount,'landscaping-trailer-recycling')
    if not success then
        cargo[netId]=record
        selling[netId]=nil
        return false,'Bank payment failed; trailer cargo retained'
    end
    update(netId)
    selling[netId]=nil
    -- The trailer's timber has already been removed and paid for; only now count it.
    if timber>0 and LandscapingContractTimberDelivery then
        LandscapingContractTimberDelivery(src,timber)
    end
    return true,('Processed %d grass bags, %d leaf bags, %d timber logs and %d flower crates for $%d'):format(grass,leaves,timber,flowers,amount)
end)
