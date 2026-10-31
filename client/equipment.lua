-- v0.20.2: push mower and leaf blower. Strimmer retired.
local active=nil
local prop=nil
local session=0
local function cleanup()
    session=session+1
    active=nil
    SendNUIMessage({type='strimmerSound',playing=false})
    if prop and DoesEntityExist(prop) then DetachEntity(prop,true,true);DeleteEntity(prop) end
    prop=nil
    ClearPedSecondaryTask(PlayerPedId())
    lib.hideTextUI()
end
local function attach(model,offset,rotation,groundMower)
    local hash=joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return false end
    RequestModel(hash)
    local untilMs=GetGameTimer()+3000
    while not HasModelLoaded(hash) and GetGameTimer()<untilMs do Wait(0) end
    if not HasModelLoaded(hash) then return false end
    local p=GetEntityCoords(PlayerPedId())
    prop=CreateObject(hash,p.x,p.y,p.z,false,false,false)
    SetModelAsNoLongerNeeded(hash)
    if prop==0 then return false end
    SetEntityCollision(prop,false,false)
    -- A push mower belongs in front of the ped at ground height, not dangling from a hand.
    -- Root attachment keeps it centred and facing the same direction as the player.
    local bone = groundMower and 0 or GetPedBoneIndex(PlayerPedId(),57005)
    AttachEntityToEntity(prop,PlayerPedId(),bone,offset[1],offset[2],offset[3],rotation[1],rotation[2],rotation[3],false,false,false,false,2,true)
    return true
end
local function begin(kind)
    if active then
        if active==kind then return true end
        cleanup()
    end
    local shift=lib.callback.await('wonkys_landscaping:shift:status',false)
    if not shift or not shift.active then lib.notify({type='error',description='Start your landscaping shift first'});return end
    if (exports.ox_inventory:Search('count',(kind=='mower' and 'landscape_pushmower' or kind=='rake' and 'landscape_rake' or 'landscape_leafblower')) or 0)<1 then
        lib.notify({type='error',description='Collect this equipment from your supervisor first'});return
    end
    if IsPedInAnyVehicle(PlayerPedId(),false) then return end
    active=kind;session=session+1
    local token=session
    local model=kind=='mower' and 'prop_lawnmower_01' or kind=='rake' and 'bzzz_garden_rake_a' or 'prop_leaf_blower_01'
    -- Mower is centred on the ped root, not attached to a hand.
    local offset=kind=='mower' and {0.0,1.10,-0.95} or kind=='rake' and {0.12,0.02,-0.02} or {0.13,0.04,-0.05}
    local rotation=kind=='mower' and {0.0,0.0,180.0} or kind=='rake' and {-80.0,10.0,15.0} or {-95.0,15.0,15.0}
    if not attach(model,offset,rotation,kind=='mower') then
        cleanup();lib.notify({type='error',description='GTA prop unavailable: '..model});return
    end
    local dict=kind=='rake' and 'amb@world_human_gardener_plant@male@base' or 'amb@world_human_gardener_leaf_blower@base'
    RequestAnimDict(dict)
    local deadline=GetGameTimer()+2500
    while not HasAnimDictLoaded(dict) and GetGameTimer()<deadline do Wait(0) end
    if kind~='rake' then SendNUIMessage({type='strimmerSound',playing=true}) end
    lib.showTextUI((kind=='mower' and 'Push mowing' or kind=='rake' and 'Raking leaves' or 'Blowing leaves')..' | [X] Stop')
    CreateThread(function()
        while active==kind and session==token do
            Wait(0)
            if IsControlJustPressed(0,73) or IsDisabledControlJustPressed(0,73) or IsPedInAnyVehicle(PlayerPedId(),false) or IsEntityDead(PlayerPedId()) then cleanup();break end
            DisableControlAction(0,24,true);DisableControlAction(0,25,true)
        end
    end)
    CreateThread(function()
        while active==kind and session==token do
            local ped=PlayerPedId()
            if HasAnimDictLoaded(dict) and not IsEntityPlayingAnim(ped,dict,'base',3) then
                TaskPlayAnim(ped,dict,'base',2.0,2.0,-1,49,0,false,false,false)
            end
            if kind=='mower' then
                TriggerServerEvent('wonkys_landscaping:equipment:pushCut')
            elseif kind=='rake' then
                -- The rake is a held tool; targeting a leaf pile awards the bag server-side.
            else
                -- Leaf blower currently visual/sound only; paid leaf jobs will use BzZz leaf piles in the next phase.
            end
            Wait(kind=='mower' and 900 or 1200)
        end
    end)
    return true
end
exports('usePushMower',function() begin('mower') end)
exports('useLeafBlower',function() begin('blower') end)
exports('useRake',function() begin('rake') end)
-- Used by timed ox_target leaf tasks so the prop, animation and audio start automatically.
exports('startLeafWorkTool',function(kind)
    if kind~='blower' and kind~='rake' then return false end
    return begin(kind)==true
end)
exports('stopLeafWorkTool',function() cleanup() end)
RegisterCommand('landscape_stoptool',cleanup,false)
RegisterNetEvent('wonkys_landscaping:equipment:stop',cleanup)
AddEventHandler('onResourceStop',function(res) if res==GetCurrentResourceName() then cleanup() end end)
