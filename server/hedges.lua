-- Bzzz flowering arch lifecycle: flowering -> flowers harvested -> hedge trimmed.
-- State is held server-side and shared with all clients. Restart/reset restores test bushes.
local bushes, workers = {}, {}
for i,loc in ipairs((Config.Hedges and Config.Hedges.sites) or {}) do
    local shape=(Config.Hedges.siteShapes and Config.Hedges.siteShapes[i]) or Config.Hedges.defaultShape or 'a'
    if not Config.Hedges.modelCatalog[shape] then shape='a' end
    bushes[tostring(i)]={x=loc.x,y=loc.y,z=loc.z,heading=loc.w or 0.0,stage=0,shape=shape}
end
local function sync(src) TriggerClientEvent('wonkys_landscaping:hedges:sync',src,bushes) end
local function near(src,entry)
    local ped=GetPlayerPed(src)
    return ped~=0 and #(GetEntityCoords(ped)-vector3(entry.x,entry.y,entry.z))<=4.0
end
local function actionInfo(action)
    if action=='flowers' then return 0, 'landscape_flowers', 'Collect flowers' end
    if action=='trim' then return 1, 'landscape_leaf_bag', 'Trim hedge' end
end
RegisterNetEvent('wonkys_landscaping:hedges:request',function() if LandscapingEventAllowed(source,'hedges:request',1500) then sync(source) end end)
lib.callback.register('wonkys_landscaping:hedges:begin',function(src,id,action)
    id=tostring(id or '')
    local expected=actionInfo(action)
    local entry=bushes[id]
    if not expected or not entry or entry.stage~=expected then return false,'This bush is not ready for that task' end
    if not LandscapingAuthorized(src) then return false,'Start your landscaping shift first' end
    if not near(src,entry) then return false,'Move closer to the bush' end
    if workers[id] then return false,'Someone is already working on this bush' end
    workers[id]={src=src,action=action,started=GetGameTimer()}
    return true,'Started'
end)
lib.callback.register('wonkys_landscaping:hedges:cancel',function(src,id)
    id=tostring(id or '')
    if workers[id] and workers[id].src==src then workers[id]=nil end
    return true
end)
lib.callback.register('wonkys_landscaping:hedges:finish',function(src,id,action)
    id=tostring(id or '')
    local expected,item=actionInfo(action)
    local entry=bushes[id]
    local work=workers[id]
    if not expected or not entry or entry.stage~=expected or not work or work.src~=src or work.action~=action then
        return false,'No matching task is active'
    end
    if GetGameTimer()-work.started<9600 then return false,'Finish the full progress timer' end
    workers[id]=nil
    if not LandscapingAuthorized(src) or not near(src,entry) then return false,'You left the work area' end
    if not exports.ox_inventory:CanCarryItem(src,item,1) then return false,'Not enough inventory space' end
    local success=exports.ox_inventory:AddItem(src,item,1)
    if not success then return false,'Could not add item. Check ox_inventory item definitions.' end
    entry.stage=entry.stage+1
    sync(-1)
    if LandscapingContractActivity then
        LandscapingContractActivity(src,action=='flowers' and 'flowers' or 'hedges',id)
        if action=='trim' then LandscapingContractActivity(src,'topiary',id) end
    end
    return true,action=='flowers' and 'Flowers harvested: +1 flower bundle' or 'Hedge trimmed: +1 leaf waste bag'
end)
-- Admin preview / live shape selection for any existing hedge site.
-- Uses the paired flowered/plain models; no contract or inventory logic changes.
RegisterCommand('landscape_hedgemodel',function(src,args)
    if src~=0 and not IsPlayerAceAllowed(src,'command.landscape_hedgemodel') then return end
    local id=tostring(tonumber(args[1]) or '')
    local shape=tostring(args[2] or ''):lower()
    if not bushes[id] or not Config.Hedges.modelCatalog[shape] then
        local message='Usage: /landscape_hedgemodel [site 1-'..#Config.Hedges.sites..'] [shape a-m]'
        if src==0 then print(message) else TriggerClientEvent('ox_lib:notify',src,{type='error',description=message}) end
        return
    end
    if workers[id] then return end -- Never swap a hedge while somebody is working.
    bushes[id].shape=shape
    sync(-1)
    if src==0 then print(('Hedge site %s changed to %s'):format(id,shape))
    else TriggerClientEvent('ox_lib:notify',src,{type='success',description=('Hedge %s: %s'):format(id,Config.Hedges.modelCatalog[shape])}) end
end,false)
RegisterCommand('landscape_resethedges',function(src)
    if src~=0 and not IsPlayerAceAllowed(src,'command.landscape_resethedges') then return end
    for _,entry in pairs(bushes) do entry.stage=0 end
    workers={}
    sync(-1)
end,false)
AddEventHandler('playerDropped',function()
    local src=source
    for id,work in pairs(workers) do if work.src==src then workers[id]=nil end end
end)
