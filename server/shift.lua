local shifts = {}
local function nearSupervisor(src)
    local ped=GetPlayerPed(src)
    if ped==0 then return false end
    local coords=GetEntityCoords(ped)
    local h=Config.Headquarters.ped
    if #(coords-vector3(h.x,h.y,h.z))<=5.0 then return true end
    for _,hut in ipairs(Config.LoggingDuty or {}) do
        if #(coords-vector3(hut.x,hut.y,hut.z))<=5.0 then return true end
    end
    return false
end
local function hasTablet(src)
    return (exports.ox_inventory:GetItemCount(src,Config.Headquarters.tabletItem) or 0)>0
end
function LandscapingOnShift(src) return shifts[src] == true end
lib.callback.register('wonkys_landscaping:shift:status',function(src)
    return {active=shifts[src]==true,tablet=hasTablet(src)}
end)
lib.callback.register('wonkys_landscaping:shift:start',function(src)
    if not nearSupervisor(src) then return {ok=false,message='Speak to the supervisor at HQ or a logging hut'} end
    if Config.RequireJob then
        local player=exports.qbx_core:GetPlayer(src)
        if not player or not player.PlayerData or not player.PlayerData.job or player.PlayerData.job.name~=Config.Job then
            return {ok=false,message='You are not employed as a landscaper'}
        end
    end
    if shifts[src] then return {ok=true,message='You are already on shift'} end
    if not hasTablet(src) then
        local ok=exports.ox_inventory:AddItem(src,Config.Headquarters.tabletItem,1)
        if not ok then return {ok=false,message='Cannot issue tablet. Check ox_inventory item definition and free inventory space.'} end
    end
    shifts[src]=true
    return {ok=true,message='Shift started. Your company tablet has been issued.'}
end)
lib.callback.register('wonkys_landscaping:shift:finish',function(src)
    if not nearSupervisor(src) then return {ok=false,message='Return to HQ or a logging hut supervisor'} end
    if not shifts[src] then return {ok=false,message='You are not on shift'} end
    shifts[src]=nil
    local count=exports.ox_inventory:GetItemCount(src,Config.Headquarters.tabletItem) or 0
    if count>0 then exports.ox_inventory:RemoveItem(src,Config.Headquarters.tabletItem,count) end
    local tool='landscape_strimmer'
    local n=exports.ox_inventory:GetItemCount(src,tool) or 0
    if n>0 then exports.ox_inventory:RemoveItem(src,tool,n) end
    for _,item in ipairs({'landscape_pushmower','landscape_leafblower','landscape_rake'}) do
        local amount=exports.ox_inventory:GetItemCount(src,item) or 0
        if amount>0 then exports.ox_inventory:RemoveItem(src,item,amount) end
    end
    TriggerClientEvent('wonkys_landscaping:equipment:stop',src)
    return {ok=true,message='Shift finished. Company equipment returned.'}
end)
AddEventHandler('playerDropped',function() shifts[source]=nil end)
-- Tablet use event is emitted by the ox_inventory item client export.

