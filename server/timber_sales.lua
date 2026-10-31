-- Timber sales are server-authoritative and limited to the existing waste depot.
local saleBusy={}
lib.callback.register('wonkys_landscaping:logging:sellTimber',function(src)
    if saleBusy[src] then return false,'A timber sale is already processing' end
    if not LandscapingAuthorized(src) then return false,'Start your landscaping shift first' end
    local ped=GetPlayerPed(src)
    if ped==0 then return false,'Player unavailable' end
    local clerk=Config.WasteDepot and Config.WasteDepot.clerk
    if not clerk or #(GetEntityCoords(ped)-vector3(clerk.x,clerk.y,clerk.z))>4.0 then
        return false,'Speak to the waste depot attendant to sell timber'
    end
    saleBusy[src]=true
    local inv=exports.ox_inventory
    local item=Config.Logging.logItem
    local count=inv:GetItemCount(src,item) or 0
    if count<1 then saleBusy[src]=nil;return false,'You have no timber logs to sell' end
    if not inv:RemoveItem(src,item,count) then
        saleBusy[src]=nil
        return false,'Could not remove timber logs'
    end
    local total=count*(Config.Logging.timberSalePrice or 90)
    local paid=exports.qbx_core:AddMoney(src,'bank',total,'landscaping-timber-sale')
    if paid==false then
        inv:AddItem(src,item,count)
        saleBusy[src]=nil
        return false,'Bank payment failed; timber refund attempted'
    end
    saleBusy[src]=nil
    return true,('Sold %d timber logs for $%d (bank)'):format(count,total)
end)
AddEventHandler('playerDropped',function() saleBusy[source]=nil end)
