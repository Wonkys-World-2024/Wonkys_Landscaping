-- Bzzz garden arch: collect flowers first, then trim to plain green.
local bushes,busy={},false
local trimmer=nil
local trimMotionId=0
local trimActive=false
local function stopTrimmer()
    trimActive=false
    trimMotionId=trimMotionId+1
    if trimmer and DoesEntityExist(trimmer) then DetachEntity(trimmer,true,true); DeleteEntity(trimmer) end
    trimmer=nil
    ClearPedSecondaryTask(PlayerPedId())
end
local function startTrimmer(ped)
    -- Uses the uploaded hedge-trimmer minigun replacement streamed by Wonkys_HedgeTrimmer_Test.
    -- CreateWeaponObject creates the visible model only; no weapon is given to the player.
    local weapon=joaat('WEAPON_MINIGUN')
    -- Weapon replacement resources stream weapon models, not ordinary object models.
    -- Explicitly request the weapon asset before creating the prop.
    RequestWeaponAsset(weapon,31,0)
    local deadline=GetGameTimer()+8000
    while not HasWeaponAssetLoaded(weapon) and GetGameTimer()<deadline do Wait(0) end
    if HasWeaponAssetLoaded(weapon) then
        trimmer=CreateWeaponObject(weapon,0,GetEntityCoords(ped),false,1.0,0)
    end
    -- Fallback: some FiveM builds load the weapon model but reject CreateWeaponObject.
    if not trimmer or trimmer==0 or not DoesEntityExist(trimmer) then
        local model=GetWeapontypeModel(weapon)
        if model and model~=0 and IsModelInCdimage(model) then
            RequestModel(model)
            local modelDeadline=GetGameTimer()+5000
            while not HasModelLoaded(model) and GetGameTimer()<modelDeadline do Wait(0) end
            if HasModelLoaded(model) then
                trimmer=CreateObjectNoOffset(model,GetEntityCoords(ped),false,false,false)
                SetModelAsNoLongerNeeded(model)
            end
        end
    end
    RemoveWeaponAsset(weapon)
    if not trimmer or trimmer==0 or not DoesEntityExist(trimmer) then
        trimmer=nil
        lib.notify({type='error',description='Hedge trimmer prop could not load. Check F8 for weapon asset streaming errors.'})
        return false
    end
    SetEntityCollision(trimmer,false,false)
    AttachEntityToEntity(trimmer,ped,GetPedBoneIndex(ped,57005),0.12,0.02,-0.06,-85.0,15.0,15.0,false,false,false,false,2,true)
    local dict='amb@world_human_gardener_leaf_blower@base'
    RequestAnimDict(dict)
    local deadline=GetGameTimer()+3000
    while not HasAnimDictLoaded(dict) and GetGameTimer()<deadline do Wait(0) end
    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(ped,dict,'base',2.0,2.0,-1,49,0,false,false,false)
    end
    -- A small repeating cutting sweep while the ox_lib bar is active.
    -- The streamed weapon replacement remains attached; only its angle changes.
    trimMotionId=trimMotionId+1
    local myId=trimMotionId
    trimActive=true
    CreateThread(function()
        local bone=GetPedBoneIndex(ped,57005)
        local poses={
            {0.15,0.03,-0.04,-72.0,4.0,-10.0},
            {0.19,0.08,-0.01,-60.0,12.0,4.0},
            {0.15,0.03,-0.04,-72.0,4.0,-10.0},
            {0.11,-0.04,-0.07,-88.0,0.0,-24.0},
        }
        local i=1
        while trimActive and trimMotionId==myId and DoesEntityExist(ped) and trimmer and DoesEntityExist(trimmer) do
            local a=poses[i]
            AttachEntityToEntity(trimmer,ped,bone,a[1],a[2],a[3],a[4],a[5],a[6],false,false,false,false,2,true)
            i=i%#poses+1
            Wait(550)
        end
    end)
    return true
end
local function clear()
    for _,obj in pairs(bushes) do
        if DoesEntityExist(obj) then exports.ox_target:removeLocalEntity(obj);DeleteEntity(obj) end
    end
    bushes={}
end
local function getModel(name)
    local hash=joaat(name)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local timeout=GetGameTimer()+5000
    while not HasModelLoaded(hash) and GetGameTimer()<timeout do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end
local function workBush(id,action)
    if busy then return end
    local ok,msg=lib.callback.await('wonkys_landscaping:hedges:begin',false,id,action)
    if not ok then lib.notify({type='error',description=msg});return end
    busy=true
    local ped=PlayerPedId()
    if action=='trim' then
        startTrimmer(ped)
    else
        TaskStartScenarioInPlace(ped,'WORLD_HUMAN_GARDENER_PLANT',0,true)
    end
    local completed=lib.progressBar({duration=10000,label=action=='flowers' and 'Collecting garden flowers...' or 'Trimming hedge and bagging cuttings...',canCancel=true,disable={move=true,car=true,combat=true}})
    stopTrimmer()
    ClearPedTasks(ped)
    busy=false
    if not completed then lib.callback.await('wonkys_landscaping:hedges:cancel',false,id);return end
    local success,response=lib.callback.await('wonkys_landscaping:hedges:finish',false,id,action)
    lib.notify({type=success and 'success' or 'error',description=response})
end
RegisterNetEvent('wonkys_landscaping:hedges:sync',function(state)
    clear()
    for id,entry in pairs(state or {}) do
        local stage=entry.stage or (entry.trimmed and 2 or 0)
        local shape=entry.shape or Config.Hedges.defaultShape or 'a'
        if not (Config.Hedges.modelCatalog and Config.Hedges.modelCatalog[shape]) then shape='a' end
        -- Bzzz convention: unsuffixed = plain; '2' = flowers.
        -- Preserve the original flowering -> harvested -> trimmed lifecycle.
        local name=stage==0 and ('bzzz_garden_plant_'..shape..'2') or ('bzzz_garden_plant_'..shape)
        local hash=getModel(name)
        if not hash then
            print(('[Wonkys_Landscaping] Missing Bzzz plant model: %s'):format(name))
        else
            local obj=CreateObject(hash,entry.x,entry.y,entry.z,false,false,false)
            if obj~=0 then
                -- Bzzz garden models have unusual bounding boxes. Do NOT apply
                -- -GetModelDimensions().z or PlaceObjectOnGroundProperly(): both
                -- can suspend these arches metres above the lawn.
                -- Site z is the intended model origin height; tune individually
                -- with Config.Hedges.sites and the shared groundOffset.
                SetEntityCoordsNoOffset(obj,entry.x,entry.y,entry.z + (Config.Hedges.groundOffset or 0.0),false,false,false)
                SetEntityHeading(obj,entry.heading or 0.0)
                FreezeEntityPosition(obj,true)
                bushes[id]=obj
                if stage==0 then
                    exports.ox_target:addLocalEntity(obj,{{name='wonkys_hedge_flowers_'..id,label='Collect flowers (10 seconds)',icon='fa-solid fa-seedling',distance=2.5,onSelect=function() workBush(id,'flowers') end}})
                elseif stage==1 then
                    exports.ox_target:addLocalEntity(obj,{{name='wonkys_hedge_trim_'..id,label='Trim hedge / collect green waste (10 seconds)',icon='fa-solid fa-scissors',distance=2.5,onSelect=function() workBush(id,'trim') end}})
                end
            end
            SetModelAsNoLongerNeeded(hash)
        end
    end
end)
CreateThread(function() Wait(2000);TriggerServerEvent('wonkys_landscaping:hedges:request') end)
AddEventHandler('onResourceStop',function(res) if res==GetCurrentResourceName() then stopTrimmer();clear() end end)
