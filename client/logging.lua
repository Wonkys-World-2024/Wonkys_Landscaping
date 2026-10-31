
local trees, entities, targets = {}, {}, {}
local treeBaseZ = {}
local logPiles = {}
local pileZones = {}
local pickupObjects, pickupZones = {}, {}
local function removeAll()
    for id,obj in pairs(entities) do
        if DoesEntityExist(obj) then
            exports.ox_target:removeLocalEntity(obj)
            DeleteEntity(obj)
        end
    end
    for _,zone in pairs(targets) do exports.ox_target:removeZone(zone) end
    targets={}
    for _,pile in pairs(logPiles) do if DoesEntityExist(pile) then exports.ox_target:removeLocalEntity(pile); DeleteEntity(pile) end end
    logPiles={}
    for _,zone in pairs(pileZones or {}) do exports.ox_target:removeZone(zone) end
    pileZones={}
    entities={}
    treeBaseZ={}
    for _,kinds in pairs(pickupObjects or {}) do
        for _,obj in pairs(kinds) do if DoesEntityExist(obj) then exports.ox_target:removeLocalEntity(obj); DeleteEntity(obj) end end
    end
    for _,kinds in pairs(pickupZones or {}) do
        for _,zone in pairs(kinds) do exports.ox_target:removeZone(zone) end
    end
end
local function makeTree(id,t)
    local model=joaat(Config.Logging.model)
    if not IsModelInCdimage(model) then
        print('[Wonkys Logging] Missing model: '..Config.Logging.model)
        return
    end
    RequestModel(model)
    local untilTime=GetGameTimer()+6000
    while not HasModelLoaded(model) and GetGameTimer()<untilTime do Wait(0) end
    if not HasModelLoaded(model) then return end
    local minDim,maxDim=GetModelDimensions(model)
    local baseZ=t.z -- preserve calibrated origin for the two original trees
    if id~=1 and id~=9 then
        local found,ground=GetGroundZFor_3dCoord(t.x,t.y,t.z+75.0,false)
        if found then baseZ=ground end
    end
    local obj=CreateObjectNoOffset(model,t.x,t.y,baseZ,false,false,false)
    if obj==0 then return end
    SetEntityHeading(obj,t.heading)
    SetEntityCollision(obj,true,true)
    FreezeEntityPosition(obj,true)
    entities[id]=obj
    treeBaseZ[id]=baseZ
    SetModelAsNoLongerNeeded(model)
    local function equipAxe(ped)
        local hash=joaat('w_me_hatchet')
        if not IsModelInCdimage(hash) then return nil end
        RequestModel(hash)
        local deadline=GetGameTimer()+4000
        while not HasModelLoaded(hash) and GetGameTimer()<deadline do Wait(0) end
        if not HasModelLoaded(hash) then return nil end
        local pos=GetEntityCoords(ped)
        local axe=CreateObjectNoOffset(hash,pos.x,pos.y,pos.z,false,false,false)
        SetModelAsNoLongerNeeded(hash)
        if axe==0 then return nil end
        SetEntityCollision(axe,false,false)
        -- Initial grip for GTA weapon-model chainsaw; fine tune after an in-game screenshot.
        AttachEntityToEntity(axe,ped,GetPedBoneIndex(ped,57005),0.09,0.02,-0.02,-80.0,0.0,0.0,true,true,false,true,1,true)
        return axe
    end
    local function clearAxe(axe)
        if axe and DoesEntityExist(axe) then
            DetachEntity(axe,true,true)
            DeleteEntity(axe)
        end
    end
    local function cut(kind)
        local ok,msg=lib.callback.await('wonkys_landscaping:logging:begin',false,id,kind)
        if not ok then lib.notify({type='error',description=msg}); return end
        local ped=PlayerPedId()
        local axe=equipAxe(ped)
        if not axe then
            lib.notify({type='warning',description='GTA hatchet prop unavailable; using cutting animation without a tool.'})
        end
        local done=lib.progressBar({
            duration=kind=='fell' and Config.Logging.cutDuration or Config.Logging.chopDuration,
            label=kind=='fell' and 'Chopping down tree...' or 'Chopping fallen trunk into logs...',
            canCancel=true,useWhileDead=false,
            disable={move=true,car=true,combat=true},
            anim={dict='amb@world_human_hammering@male@base',clip='base'}
        })
        clearAxe(axe)
        if not done then
            lib.callback.await('wonkys_landscaping:logging:cancel',false,id)
            return
        end
        local success,result=lib.callback.await('wonkys_landscaping:logging:finish',false,id,kind)
        lib.notify({type=success and 'success' or 'error',description=result})
    end
    local options={
        {name='wonkys_logging_fell_'..id,label='Chop Down Tree (test)',icon='fa-solid fa-tree',distance=3.0,
            canInteract=function() return trees[id] and trees[id].stage==0 end,
            onSelect=function() cut('fell') end},
        {name='wonkys_logging_chop_'..id,label='Chop Fallen Trunk into Logs',icon='fa-solid fa-axe',distance=4.0,
            canInteract=function() return trees[id] and trees[id].stage==1 end,
            onSelect=function() cut('chop') end}
    }
    exports.ox_target:addLocalEntity(obj,options)
    -- Reliable interaction zone near the trunk: raycasting against tall tree meshes is inconsistent.
    targets[id]=exports.ox_target:addSphereZone({
        coords=vec3(t.x,t.y,(treeBaseZ[id] or t.z)+0.9),radius=1.6,debug=false,
        options={
            {name='wonkys_logging_zone_fell_'..id,label='Chop Down Tree (test)',icon='fa-solid fa-tree',distance=3.0,
                canInteract=function() return trees[id] and trees[id].stage==0 end,
                onSelect=function() cut('fell') end},
            {name='wonkys_logging_zone_chop_'..id,label='Chop Fallen Trunk into Logs',icon='fa-solid fa-axe',distance=3.0,
                canInteract=function() return trees[id] and trees[id].stage==1 end,
                onSelect=function() cut('chop') end},
        }
    })
end
local function collectPile(id,kind)
    local done=lib.progressBar({duration=1700,label=kind=='logs' and 'Picking up timber logs...' or 'Picking up leaf waste bags...',canCancel=true,
        disable={move=true,car=true,combat=true},anim={dict='pickup_object',clip='pickup_low'}})
    if not done then return end
    local ok,msg=lib.callback.await('wonkys_landscaping:logging:collect',false,id,kind)
    lib.notify({type=ok and 'success' or 'error',description=msg})
end
local function pileCoords(t)
    local offset=Config.Logging.logPileOffset or vec3(1.8,0,0)
    local x,y,z=t.x+offset.x,t.y+offset.y,t.z+offset.z
    local found,ground=GetGroundZFor_3dCoord(x,y,z+12.0,false)
    if found then z=ground end
    return vec3(x,y,z)
end
local function removePickup(id,kind)
    if pickupObjects[id] and pickupObjects[id][kind] then
        local obj=pickupObjects[id][kind]
        if DoesEntityExist(obj) then exports.ox_target:removeLocalEntity(obj); DeleteEntity(obj) end
        pickupObjects[id][kind]=nil
    end
    if pickupZones[id] and pickupZones[id][kind] then
        exports.ox_target:removeZone(pickupZones[id][kind]); pickupZones[id][kind]=nil
    end
end
local function spawnPickup(id,kind,t)
    pickupObjects[id]=pickupObjects[id] or {}
    pickupZones[id]=pickupZones[id] or {}
    if pickupZones[id][kind] then return end
    local base=pileCoords(t)
    local pos=kind=='logs' and (base+vec3(0.0,0.0,0.0)) or (base+vec3(1.35,0.1,0.0))
    local candidates=kind=='logs' and {
        Config.Logging.logPileModel,'bzzz_lumberjack_wood_pack_1a_static','prop_log_01','prop_woodpile_01a'
    } or {'prop_rub_binbag_01','prop_cs_rub_binbag_01','prop_rub_binbag_03'}
    for _,name in ipairs(candidates) do
        if name then
            local model=joaat(name)
            if IsModelInCdimage(model) then
                RequestModel(model)
                local deadline=GetGameTimer()+1800
                while not HasModelLoaded(model) and GetGameTimer()<deadline do Wait(0) end
                if HasModelLoaded(model) then
                    local obj=CreateObjectNoOffset(model,pos.x,pos.y,pos.z,false,false,false)
                    SetModelAsNoLongerNeeded(model)
                    if obj~=0 and DoesEntityExist(obj) then
                        SetEntityHeading(obj,t.heading)
                        PlaceObjectOnGroundProperly(obj)
                        FreezeEntityPosition(obj,true)
                        pickupObjects[id][kind]=obj
                        print(('[Wonkys Logging] %s prop at site %d: %s'):format(kind,id,name))
                        break
                    end
                end
            end
        end
    end
    local label=kind=='logs' and 'Collect Timber Logs (3)' or 'Collect Leaf Waste (2)'
    pickupZones[id][kind]=exports.ox_target:addSphereZone({
        coords=pos+vec3(0,0,0.45),radius=0.95,debug=false,
        options={{name='wonkys_logging_pickup_'..kind..'_'..id,label=label,
            icon=kind=='logs' and 'fa-solid fa-tree' or 'fa-solid fa-bag-shopping',distance=2.4,
            canInteract=function()
                local tree=trees[id]
                return tree and tree.stage==2 and not (tree.collected and tree.collected[kind])
            end,
            onSelect=function() collectPile(id,kind) end}}
    })
end
local function updateLogPile(id,t)
    for _,kind in ipairs({'logs','leaves'}) do
        if t.stage==2 and not (t.collected and t.collected[kind]) then
            spawnPickup(id,kind,t)
        else
            removePickup(id,kind)
        end
    end
end
local function positionTree(id,t,animate)
    local obj=entities[id]
    if not obj or not DoesEntityExist(obj) then return end
    if t.stage==0 then
        SetEntityCoordsNoOffset(obj,t.x,t.y,treeBaseZ[id] or t.z,false,false,false)
        SetEntityRotation(obj,0,0,t.heading,2,true)
        SetEntityVisible(obj,true,false)
    elseif t.stage==1 then
        -- A scripted tip is used because static map trees cannot be felled by physics.
        -- Pivot is at the model origin: ground placement must be calibrated for each tree model.
        local steps=animate and 90 or 1
        for n=1,steps do
            if not DoesEntityExist(obj) then return end
            local ratio=n/steps
            SetEntityRotation(obj,0,ratio*87,t.heading,2,true)
            if animate then Wait(math.floor(Config.Logging.fallDuration/steps)) end
        end
        SetEntityVisible(obj,true,false)
    else
        SetEntityVisible(obj,false,false)
    end
end
RegisterNetEvent('wonkys_landscaping:logging:sync',function(nextTrees)
    local old=trees
    trees=nextTrees
    for id,t in pairs(trees) do
        local i=tonumber(id)
        if not entities[i] then makeTree(i,t) end
        local prev=old[id] or old[i]
        positionTree(i,t,prev and prev.stage==0 and t.stage==1)
        updateLogPile(i,t)
    end
end)
CreateThread(function()
    Wait(1500)
    TriggerServerEvent('wonkys_landscaping:logging:request')
end)
AddEventHandler('onResourceStop',function(name)
    if name==GetCurrentResourceName() then removeAll() end
end)
