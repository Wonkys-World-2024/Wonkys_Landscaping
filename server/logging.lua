
local trees, locks = {}, {}
local stateFile='logging_state.json'
local regrowSeconds=math.max(1,tonumber(Config.Logging.regrowHours) or 48)*3600
local saved={}
do
    local raw=LoadResourceFile(GetCurrentResourceName(),stateFile)
    if raw then
        local ok,decoded=pcall(json.decode,raw)
        if ok and type(decoded)=='table' then saved=decoded end
    end
end
local function saveState()
    local data={}
    for i,t in ipairs(trees) do
        data[tostring(i)]={stage=t.stage,collected=t.collected,regrowAt=t.regrowAt}
    end
    SaveResourceFile(GetCurrentResourceName(),stateFile,json.encode(data),-1)
end
for i,loc in ipairs(Config.Logging.sites) do
    local old=saved[tostring(i)] or {}
    local stage=tonumber(old.stage) or 0
    if stage<0 or stage>3 then stage=0 end
    local deadline=tonumber(old.regrowAt)
    if stage==3 and (not deadline or deadline<=os.time()) then stage=0;deadline=nil end
    trees[i]={stage=stage,x=loc.x,y=loc.y,z=loc.z,heading=loc.w,
        collected=stage==2 and old.collected or nil,regrowAt=deadline}
end
saveState()
local function sync(target) TriggerClientEvent('wonkys_landscaping:logging:sync',target,trees) end
RegisterNetEvent('wonkys_landscaping:logging:request',function() if LandscapingEventAllowed(source,'logging:request',1500) then sync(source) end end)
local function near(src,t)
    local ped=GetPlayerPed(src)
    if ped==0 then return false end
    local pos=GetEntityCoords(ped)
    -- New tree Z is resolved against terrain client-side; validate XY and a generous Z band.
    return #(vector2(pos.x,pos.y)-vector2(t.x,t.y))<=6.0 and math.abs(pos.z-t.z)<=35.0
end
lib.callback.register('wonkys_landscaping:logging:begin',function(src,id,kind)
    id=tonumber(id)
    local t=trees[id]
    local required=kind=='fell' and 0 or kind=='chop' and 1 or nil
    if not t or required==nil or t.stage~=required then return false,'Tree is not ready' end
    if not LandscapingAuthorized(src) then return false,'Start your landscaping shift first' end
    if not near(src,t) then return false,'Move closer to the tree' end
    if locks[id] then return false,'Another worker is using this tree' end
    locks[id]={source=src,kind=kind,started=GetGameTimer()}
    return true
end)
lib.callback.register('wonkys_landscaping:logging:cancel',function(src,id)
    id=tonumber(id)
    if locks[id] and locks[id].source==src then locks[id]=nil end
end)
lib.callback.register('wonkys_landscaping:logging:finish',function(src,id,kind)
    id=tonumber(id)
    local t=trees[id]
    local lock=locks[id]
    local required=kind=='fell' and 0 or kind=='chop' and 1 or nil
    if not t or required==nil or t.stage~=required or not lock or lock.source~=src or lock.kind~=kind then
        return false,'No matching logging task'
    end
    local duration=kind=='fell' and Config.Logging.cutDuration or Config.Logging.chopDuration
    if GetGameTimer()-lock.started<duration-450 then return false,'Finish the cutting animation' end
    locks[id]=nil
    if not LandscapingAuthorized(src) or not near(src,t) then return false,'You left the logging area' end
    t.stage=t.stage+1
    if kind=='chop' then t.collected={logs=false,leaves=false} end
    saveState()
    sync(-1)
    if kind=='fell' and LandscapingContractTreeFelled then LandscapingContractTreeFelled(src,id) end
    if kind=='fell' then return true,'Tree felled. Chop the fallen trunk into logs.' end
    return true,'Trunk chopped. Collect the timber log and leaf bag separately.'
end)
-- Each reward is collected independently; both must be claimed before site is cleared.
lib.callback.register('wonkys_landscaping:logging:collect',function(src,id,kind)
    id=tonumber(id)
    local t=id and trees[id]
    if not t or t.stage~=2 then return false,'No timber waiting here' end
    if kind~='logs' and kind~='leaves' then return false,'Invalid collection type' end
    if not LandscapingAuthorized(src) then return false,'Start your landscaping shift first' end
    if not near(src,t) then return false,'Move closer to the collection site' end
    if locks[id] then return false,'Another worker is collecting here' end
    t.collected=t.collected or {logs=false,leaves=false}
    if t.collected[kind] then return false,'Already collected' end
    locks[id]={source=src,kind='collect',started=GetGameTimer()}
    local item=kind=='logs' and Config.Logging.logItem or (Config.Logging.leavesItem or 'landscape_leaf_bag')
    local amount=kind=='logs' and (Config.Logging.logsPerTree or 3) or (Config.Logging.leavesPerTree or 2)
    local inv=exports.ox_inventory
    if not inv:CanCarryItem(src,item,amount) then locks[id]=nil;return false,'Not enough inventory space' end
    if not inv:AddItem(src,item,amount) then locks[id]=nil;return false,'Could not collect item' end
    t.collected[kind]=true
    if t.collected.logs and t.collected.leaves then
        t.stage=3
        t.regrowAt=os.time()+regrowSeconds
    end
    locks[id]=nil
    saveState()
    sync(-1)
    if LandscapingAwardForestryXP then LandscapingAwardForestryXP(src,kind) end
    return true,('Collected %d %s.'):format(amount,kind=='logs' and 'timber logs' or 'leaf waste bags')
end)
-- Admin-only instant forestry regrowth for testing. Existing 48-hour timer remains active.
-- ACE: add_ace group.admin command.landscape_regrowtrees allow
RegisterCommand('landscape_regrowtrees',function(src)
    if src ~= 0 and not IsPlayerAceAllowed(src,'command.landscape_regrowtrees') then
        TriggerClientEvent('ox_lib:notify',src,{title='Wonky’s Landscaping',description='You do not have permission to regrow forestry trees.',type='error'})
        return
    end
    local restored=0
    for id,t in ipairs(trees) do
        if not locks[id] and t.stage ~= 0 then
            t.stage=0
            t.collected=nil
            t.regrowAt=nil
            restored=restored+1
        end
    end
    saveState()
    sync(-1)
    local message=('Forestry reset: %d harvested trees restored.'):format(restored)
    print('[Wonkys_Landscaping] '..message)
    if src ~= 0 then
        TriggerClientEvent('ox_lib:notify',src,{title='Wonky’s Landscaping',description=message,type='success'})
    end
end,false)

RegisterCommand('landscape_resetlogging',function(src)
    if src~=0 and not IsPlayerAceAllowed(src,'command.landscape_resetlogging') then return end
    for _,t in pairs(trees) do t.stage=0; t.collected=nil;t.regrowAt=nil end
    locks={}
    saveState()
    sync(-1)
end,false)
AddEventHandler('playerDropped',function()
    for id,lock in pairs(locks) do if lock.source==source then locks[id]=nil end end
end)

-- Regrowth is measured in real-world time, including server downtime.
CreateThread(function()
    while true do
        Wait(60000)
        local now=os.time()
        local changed=false
        for id,t in ipairs(trees) do
            if t.stage==3 and t.regrowAt and t.regrowAt<=now and not locks[id] then
                t.stage=0;t.collected=nil;t.regrowAt=nil
                changed=true
            end
        end
        if changed then saveState();sync(-1) end
    end
end)
