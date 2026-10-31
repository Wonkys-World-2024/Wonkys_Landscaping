-- Server-authoritative timed leaf work, one active worker per site.
local sites={}
for i,p in ipairs(Config.LeafSites or {}) do sites[tostring(i)]={x=p.x,y=p.y,z=p.z,stage='loose'} end
local working={}
local durations={blow=15,rake=12}
local function sync(target) TriggerClientEvent('wonkys_landscaping:leaves:sync',target,sites) end
local function near(src,site)
    local ped=GetPlayerPed(src)
    return ped~=0 and #(GetEntityCoords(ped)-vector3(site.x,site.y,site.z))<=5.0
end
RegisterNetEvent('wonkys_landscaping:leaves:request',function() if LandscapingEventAllowed(source,'leaves:request',1500) then sync(source) end end)
lib.callback.register('wonkys_landscaping:leaves:begin',function(src,id,action)
    id=tostring(id or '')
    local site=sites[id]
    if not site or not LandscapingAuthorized(src) then return false,'Start your landscaping shift first' end
    if not near(src,site) then return false,'Move closer to the leaves' end
    if not durations[action] then return false,'Invalid activity' end
    if site.stage~=(action=='blow' and 'loose' or 'pile') then return false,'These leaves are not ready for that tool' end
    local item=action=='blow' and 'landscape_leafblower' or 'landscape_rake'
    if (exports.ox_inventory:GetItemCount(src,item) or 0)<1 then return false,'You need your '..(action=='blow' and 'leaf blower' or 'rake') end
    if working[id] then return false,'Someone is already working on these leaves' end
    working[id]={src=src,action=action,started=GetGameTimer()}
    return true,'Started'
end)
lib.callback.register('wonkys_landscaping:leaves:cancel',function(src,id)
    id=tostring(id or '')
    if working[id] and working[id].src==src then working[id]=nil end
    return true
end)
lib.callback.register('wonkys_landscaping:leaves:finish',function(src,id,action)
    id=tostring(id or '')
    local site=sites[id]
    local job=working[id]
    if not site or not job or job.src~=src or job.action~=action then return false,'No active leaf task' end
    if GetGameTimer()-job.started < durations[action]*1000-400 then return false,'Keep working until the timer finishes' end
    working[id]=nil
    if not LandscapingAuthorized(src) or not near(src,site) then return false,'You moved too far away or ended your shift' end
    if site.stage~=(action=='blow' and 'loose' or 'pile') then return false,'This site has already changed' end
    local item=action=='blow' and 'landscape_leafblower' or 'landscape_rake'
    if (exports.ox_inventory:GetItemCount(src,item) or 0)<1 then return false,'Required tool missing' end
    site.stage=action=='blow' and 'pile' or 'bag'
    sync(-1)
    return true,action=='blow' and 'Leaves gathered! Now rake the pile for 12 seconds.' or 'Yellow leaf bag ready. Use ox_target to pick it up.'
end)
lib.callback.register('wonkys_landscaping:leaves:collect',function(src,id)
    id=tostring(id or '')
    local site=sites[id]
    if not site or site.stage~='bag' then return false,'No bag to collect' end
    if not LandscapingAuthorized(src) or not near(src,site) then return false,'Move closer and start your shift' end
    if working[id] then return false,'Site is busy' end
    working[id]={src=src,action='collect'}
    if not exports.ox_inventory:CanCarryItem(src,'landscape_leaf_bag',1) then working[id]=nil;return false,'Inventory full' end
    local success=exports.ox_inventory:AddItem(src,'landscape_leaf_bag',1)
    if not success then working[id]=nil;return false,'Could not add leaf bag' end
    site.stage='cleared';working[id]=nil;sync(-1)
    if LandscapingContractActivity then LandscapingContractActivity(src,'leaves',id) end
    return true,'Collected one yellow bag of leaves'
end)
RegisterCommand('landscape_resetleaves',function(src)
    if src~=0 and not IsPlayerAceAllowed(src,'command.landscape_resetleaves') then return end
    for id,site in pairs(sites) do site.stage='loose';working[id]=nil end
    sync(-1)
    if src~=0 then TriggerClientEvent('ox_lib:notify',src,{type='success',description='Leaf cleanup sites reset'}) end
end,false)
AddEventHandler('playerDropped',function()
    local src=source
    for id,job in pairs(working) do if job.src==src then working[id]=nil end end
end)
