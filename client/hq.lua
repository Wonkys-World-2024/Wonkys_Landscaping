local supervisor=0
local function notify(result)
    lib.notify({title="Wonky's Landscaping",description=result.message or 'Unknown result',type=result.ok and 'success' or 'error'})
end
local function shift(action)
    local result=lib.callback.await(('wonkys_landscaping:shift:'..action),false)
    if result then notify(result) end
end
CreateThread(function()
    local h=Config.Headquarters
    local blip=AddBlipForCoord(h.blip.x,h.blip.y,h.blip.z)
    SetBlipSprite(blip,280)
    SetBlipColour(blip,2)
    SetBlipScale(blip,0.85)
    SetBlipAsShortRange(blip,true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString("Wonky's Landscaping HQ")
    EndTextCommandSetBlipName(blip)
    local hash=joaat(h.model)
    RequestModel(hash)
    local untilTime=GetGameTimer()+10000
    while not HasModelLoaded(hash) and GetGameTimer()<untilTime do Wait(100) end
    if not HasModelLoaded(hash) then print('[Wonkys_Landscaping] Could not load HQ supervisor model');return end
    supervisor=CreatePed(4,hash,h.ped.x,h.ped.y,h.ped.z-1.0,h.ped.w,false,true)
    SetEntityAsMissionEntity(supervisor,true,true)
    SetBlockingOfNonTemporaryEvents(supervisor,true)
    FreezeEntityPosition(supervisor,true)
    SetEntityInvincible(supervisor,true)
    exports.ox_target:addLocalEntity(supervisor,{
        {name='wonkys_landscape_start_shift',icon='fa-solid fa-tablet-screen-button',label='Start shift / Collect company tablet',distance=2.5,onSelect=function() shift('start') end},
        {name='wonkys_landscape_collect_pushmower',icon='fa-solid fa-seedling',label='Collect push mower',distance=2.5,onSelect=function() local r=lib.callback.await('wonkys_landscaping:equipment:pushmower',false);if r then notify(r) end end},
        {name='wonkys_landscape_collect_leafblower',icon='fa-solid fa-wind',label='Collect leaf blower',distance=2.5,onSelect=function() local r=lib.callback.await('wonkys_landscaping:equipment:leafblower',false);if r then notify(r) end end},
        {name='wonkys_landscape_collect_rake',icon='fa-solid fa-leaf',label='Collect garden rake',distance=2.5,onSelect=function() local r=lib.callback.await('wonkys_landscaping:equipment:rake',false);if r then notify(r) end end},
        {name='wonkys_landscape_finish_shift',icon='fa-solid fa-clipboard-check',label='Finish shift / Return tablet',distance=2.5,onSelect=function() shift('finish') end},
        {name='wonkys_landscape_open_hq',icon='fa-solid fa-briefcase',label='Open landscaping office',distance=2.5,onSelect=function() TriggerEvent('wonkys_landscaping:tablet:open') end},
    })
    SetModelAsNoLongerNeeded(hash)
end)
AddEventHandler('onResourceStop',function(resource)
    if resource==GetCurrentResourceName() and supervisor~=0 and DoesEntityExist(supervisor) then DeleteEntity(supervisor) end
end)
