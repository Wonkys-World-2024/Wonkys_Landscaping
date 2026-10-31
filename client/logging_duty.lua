local peds={}
local function openForestryContracts()
    local options={}
    for _,job in ipairs((Config.Contracts and Config.Contracts.jobs) or {}) do
        if job.type=='logging' or job.type=='heavy_logging' then
            options[#options+1]={
                title=job.label,
                description=(job.description or '')..(' | Required: %d logs | Bonus: $%d'):format(job.required or 0,job.payment or 0),
                icon='tree',
                onSelect=function()
                    local result=lib.callback.await('wonkys_landscaping:contracts:start',false,job.id)
                    if result and result.ok then TriggerEvent('wonkys_landscaping:contractBlips:accepted',job.id) end
                    lib.notify({title="Wonky's Logging",description=(result and (result.message or result.label)) or "Unable to accept contract",type=result and result.ok and "success" or "error"})
                end
            }
        end
    end
    options[#options+1]={title='Open landscaping tablet',icon='tablet-screen-button',onSelect=function()
        TriggerEvent('wonkys_landscaping:tablet:open')
    end}
    lib.registerContext({id='wonkys_forestry_contracts',title='Wonky’s Forestry Contracts',options=options})
    lib.showContext('wonkys_forestry_contracts')
end
local function notify(r)
    if r then lib.notify({title="Wonky's Logging",description=r.message or 'Unknown',type=r.ok and 'success' or 'error'}) end
end
CreateThread(function()
    local model=joaat(Config.Headquarters.model)
    RequestModel(model)
    local deadline=GetGameTimer()+10000
    while not HasModelLoaded(model) and GetGameTimer()<deadline do Wait(100) end
    if not HasModelLoaded(model) then return end
    for i,spot in ipairs(Config.LoggingDuty or {}) do
        local ped=CreatePed(4,model,spot.x,spot.y,spot.z-1.0,spot.w,false,false)
        if ped~=0 then
            FreezeEntityPosition(ped,true)
            SetEntityInvincible(ped,true)
            SetBlockingOfNonTemporaryEvents(ped,true)
            peds[#peds+1]=ped
            exports.ox_target:addLocalEntity(ped,{
                {name='wonkys_logging_shift_start_'..i,label='Start landscaping shift / Collect tablet',icon='fa-solid fa-user-check',distance=2.5,onSelect=function()
                    notify(lib.callback.await('wonkys_landscaping:shift:start',false))
                end},
                {name='wonkys_logging_shift_finish_'..i,label='Finish landscaping shift',icon='fa-solid fa-user-xmark',distance=2.5,onSelect=function()
                    notify(lib.callback.await('wonkys_landscaping:shift:finish',false))
                end},
                {name='wonkys_logging_contracts_'..i,label='Accept logging delivery contract',icon='fa-solid fa-tree',distance=2.5,onSelect=openForestryContracts},
                {name='wonkys_heavy_fleet_'..i,label='Commercial logging truck and trailer',icon='fa-solid fa-truck',distance=2.5,onSelect=function() TriggerEvent('wonkys_landscaping:heavy:menu') end},
                {name='wonkys_logging_tablet_'..i,label='Open landscaping tablet',icon='fa-solid fa-tablet-screen-button',distance=2.5,onSelect=function()
                    TriggerEvent('wonkys_landscaping:tablet:open')
                end},
            })
        end
    end
    SetModelAsNoLongerNeeded(model)
end)
AddEventHandler('onResourceStop',function(res)
    if res~=GetCurrentResourceName() then return end
    for _,ped in ipairs(peds) do if DoesEntityExist(ped) then DeleteEntity(ped) end end
end)
