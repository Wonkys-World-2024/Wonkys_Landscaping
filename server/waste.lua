-- v0.21 first playable stage: authoritative mower clippings, pickup and recycling.
local bags, counts, nextId = {}, {}, 0
local BAG_CELLS = 18
local function nearby(src, position, maxDist)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and #(GetEntityCoords(ped)-position) <= maxDist
end
local function sync(target)
    TriggerClientEvent('wonkys_landscaping:waste:sync', target, bags)
end
function LandscapingWasteCut(src, plotId, ids, position)
    if not LandscapingAuthorized(src) then return end
    local key = tostring(src)..':'..plotId
    counts[key] = (counts[key] or 0) + #ids
    if counts[key] < BAG_CELLS then return end
    counts[key] = counts[key] - BAG_CELLS
    nextId = nextId + 1
    local id = tostring(nextId)
    bags[id] = {x=position.x,y=position.y,z=position.z,type='grass',owner=src}
    sync(-1)
    TriggerClientEvent('ox_lib:notify',src,{type='success',description='Grass clippings bag ready to collect'})
end
RegisterNetEvent('wonkys_landscaping:waste:requestSync',function() if LandscapingEventAllowed(source,'waste:requestSync',1500) then sync(source) end end)
lib.callback.register('wonkys_landscaping:waste:collect',function(src,id)
    id=tostring(id or '')
    local bag=bags[id]
    if not bag or not LandscapingAuthorized(src) then return false,'No available waste bag' end
    if not nearby(src,vector3(bag.x,bag.y,bag.z),3.0) then return false,'Move closer to the bag' end
    if not exports.ox_inventory:CanCarryItem(src,'landscape_grass_clippings',1) then return false,'Inventory full' end
    -- No yielding before removing the bag, preventing double collection.
    bags[id]=nil
    local success=exports.ox_inventory:AddItem(src,'landscape_grass_clippings',1)
    if not success then bags[id]=bag;return false,'Could not add item' end
    sync(-1)
    return true,'Grass clippings collected'
end)
lib.callback.register('wonkys_landscaping:waste:sell',function(src,kind)
    kind = (kind == 'leaves' or kind == 'flowers') and kind or 'grass'
    local station = Config.Recycling[kind]
    if not station then return false,'Unknown recycling station' end
    local coords=station.coords
    if not LandscapingAuthorized(src) or not nearby(src,vector3(coords.x,coords.y,coords.z),3.5) then
        return false,'Visit the correct recycling collection point while on shift'
    end
    local item=station.item
    local count=exports.ox_inventory:GetItemCount(src,item) or 0
    if count<1 then return false,kind=='grass' and 'No grass clippings to recycle' or 'No collected leaf bags to recycle' end
    if not exports.ox_inventory:RemoveItem(src,item,count) then return false,'Could not remove bags' end
    local amount=count*station.price
    local success=exports.qbx_core:AddMoney(src,'bank',amount,'landscaping-'..kind..'-recycling')
    if success==false then
        exports.ox_inventory:AddItem(src,item,count)
        return false,'Payment failed; bags restored'
    end
    return true,('Recycled %d bags for $%d'):format(count,amount)
end)
AddEventHandler('playerDropped',function() local src=source;for key in pairs(counts) do if key:match('^'..src..':') then counts[key]=nil end end end)
