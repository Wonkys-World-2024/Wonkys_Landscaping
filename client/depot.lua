
local clerk, blip
local function notice(text, kind)
    lib.notify({title="Wonky's Waste Depot", description=text, type=kind or 'inform'})
end
local function openDepot()
    lib.registerContext({
        id='wonkys_landscape_depot_menu',
        title="Wonky's Waste Depot",
        options={
            {title='Trailer recycling',description='Park your loaded cotrailer in the marked bay. Target the trailer and choose Recycle all trailer bags.',icon='recycle',onSelect=function()
                local p=Config.WasteDepot.bay
                SetNewWaypoint(p.x,p.y)
                notice('GPS set to unloading bay. Use ox_target on your trailer to sell the bags.')
            end},
            {title='Waste prices',description=('Grass $%d/bag • Leaves $%d/bag • Capacity %d'):format(Config.Recycling.grass.price,Config.Recycling.leaves.price,Config.Cargo.capacity),icon='dollar-sign'},
            {title='Sell timber logs',description=('Sell all collected timber logs for $%d each.'):format(Config.Logging.timberSalePrice or 90),icon='tree',
                onSelect=function()
                    local ok,msg=lib.callback.await('wonkys_landscaping:logging:sellTimber',false)
                    notice(msg or 'Unable to sell timber',ok and 'success' or 'error')
                end},
            {title='Flower sales',description='Flowers are sold at the existing recycling flower collection point.',icon='seedling',onSelect=function()
                local p=Config.Recycling.flowers.coords
                SetNewWaypoint(p.x,p.y)
            end},
        }
    })
    lib.showContext('wonkys_landscape_depot_menu')
end
CreateThread(function()
    if not Config.WasteDepot or not Config.WasteDepot.enabled then return end
    local cfg=Config.WasteDepot
    if cfg.showBlip then
        blip=AddBlipForCoord(cfg.bay.x,cfg.bay.y,cfg.bay.z)
        SetBlipSprite(blip,318); SetBlipColour(blip,3); SetBlipScale(blip,0.8)
        SetBlipAsShortRange(blip,true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentString("Wonky's Waste Depot"); EndTextCommandSetBlipName(blip)
    end
    local hash=joaat(cfg.clerkModel)
    if not IsModelInCdimage(hash) then return end
    RequestModel(hash)
    local deadline=GetGameTimer()+6000
    while not HasModelLoaded(hash) and GetGameTimer()<deadline do Wait(0) end
    if not HasModelLoaded(hash) then return end
    clerk=CreatePed(4,hash,cfg.clerk.x,cfg.clerk.y,cfg.clerk.z-1.0,cfg.clerk.w,false,false)
    SetModelAsNoLongerNeeded(hash)
    if clerk~=0 then
        FreezeEntityPosition(clerk,true)
        SetEntityInvincible(clerk,true)
        SetBlockingOfNonTemporaryEvents(clerk,true)
        exports.ox_target:addLocalEntity(clerk,{
            {name='wonkys_landscape_depot_clerk',label='Speak to recycling attendant',icon='fa-solid fa-recycle',distance=2.5,onSelect=openDepot}
        })
    end
end)
CreateThread(function()
    while true do
        if not Config.WasteDepot or not Config.WasteDepot.enabled then Wait(5000)
        else
            local p=Config.WasteDepot.bay
            local dist=#(GetEntityCoords(PlayerPedId())-p)
            if dist<65 then
                DrawMarker(1,p.x,p.y,p.z-1.0,0,0,0,0,0,0,Config.WasteDepot.markerRadius*2,Config.WasteDepot.markerRadius*2,0.18,0,150,255,95,false,false,2,false,nil,nil,false)
                Wait(0)
            else Wait(1500) end
        end
    end
end)
AddEventHandler('onResourceStop',function(name)
    if name~=GetCurrentResourceName() then return end
    if clerk and DoesEntityExist(clerk) then DeleteEntity(clerk) end
    if blip then RemoveBlip(blip) end
end)
