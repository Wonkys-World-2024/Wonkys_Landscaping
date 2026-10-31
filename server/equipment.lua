-- v0.20 equipment issuing. Grass cutting reuses the validated strimmer endpoint.
local function issue(src,item,label)
    if not LandscapingAuthorized(src) then return {ok=false,message='Start your shift first'} end
    local p=Config.Headquarters.ped
    local ped=GetPlayerPed(src)
    if ped==0 or #(GetEntityCoords(ped)-vector3(p.x,p.y,p.z))>5 then return {ok=false,message='Speak to the HQ supervisor'} end
    if (exports.ox_inventory:GetItemCount(src,item) or 0)>0 then return {ok=true,message='You already have '..label} end
    if not exports.ox_inventory:CanCarryItem(src,item,1) then return {ok=false,message='Not enough inventory space'} end
    local ok=exports.ox_inventory:AddItem(src,item,1)
    return {ok=ok==true,message=ok and (label..' issued') or 'Could not issue equipment'}
end
lib.callback.register('wonkys_landscaping:equipment:pushmower',function(src) return issue(src,'landscape_pushmower','Push mower') end)
lib.callback.register('wonkys_landscaping:equipment:leafblower',function(src) return issue(src,'landscape_leafblower','Leaf blower') end)
-- Reuse the existing server-authoritative cell validation through a dedicated event.
-- The server calculates nearby cells, never trusting arbitrary client cell IDs.
local lastCut={}
RegisterNetEvent('wonkys_landscaping:equipment:pushCut',function()
    local src=source
    if not LandscapingAuthorized(src) or (exports.ox_inventory:GetItemCount(src,'landscape_pushmower') or 0)<1 then return end
    local now=GetGameTimer()
    if lastCut[src] and now-lastCut[src]<800 then return end
    lastCut[src]=now
    local ped=GetPlayerPed(src)
    if ped==0 or GetVehiclePedIsIn(ped,false)~=0 then return end
    local pos=GetEntityCoords(ped)
    -- Client/server cell calculation is shared with the existing strimmer path via a server event handler.
    -- Forwarding through TriggerEvent does not preserve source, so use a dedicated internal function exposed by main.lua.
    if LandscapingEquipmentCut then LandscapingEquipmentCut(src,pos,1.65) end
end)
AddEventHandler('playerDropped',function() lastCut[source]=nil end)

lib.callback.register('wonkys_landscaping:equipment:rake',function(src) return issue(src,'landscape_rake','Garden rake') end)
