-- Locally rendered, network-synchronised waste bag markers.
local objects={}
local model=joaat('bzzz_weed_plastic_bag_green')
local function clear()
    for _,obj in pairs(objects) do if DoesEntityExist(obj) then DeleteEntity(obj) end end
    objects={}
end
RegisterNetEvent('wonkys_landscaping:waste:sync',function(bags)
    clear()
    if not IsModelInCdimage(model) then return end
    RequestModel(model)
    local deadline=GetGameTimer()+2500
    while not HasModelLoaded(model) and GetGameTimer()<deadline do Wait(0) end
    if not HasModelLoaded(model) then return end
    for id,b in pairs(bags) do
        local obj=CreateObject(model,b.x,b.y,b.z-0.4,false,false,false)
        if obj~=0 then
            PlaceObjectOnGroundProperly(obj)
            FreezeEntityPosition(obj,true)
            objects[id]=obj
            exports.ox_target:addLocalEntity(obj,{{name='wonkys_waste_'..id,icon='fa-solid fa-leaf',label='Collect grass clippings',distance=2.0,onSelect=function()
                local ok,msg=lib.callback.await('wonkys_landscaping:waste:collect',false,id)
                lib.notify({type=ok and 'success' or 'error',description=msg})
            end}})
        end
    end
    SetModelAsNoLongerNeeded(model)
end)
CreateThread(function()
    Wait(1800)
    TriggerServerEvent('wonkys_landscaping:waste:requestSync')
    local stations = {
        {coords=Config.Recycling.grass.coords, kind='grass', label='Sell grass clippings ($25/bag)', name='wonkys_recycle_grass'},
        {coords=Config.Recycling.leaves.coords, kind='leaves', label='Sell collected leaves ($35/bag)', name='wonkys_recycle_leaves'},
        {coords=Config.Recycling.flowers.coords, kind='flowers', label='Sell flower bundles ($45/bundle)', name='wonkys_recycle_flowers'},
    }
    for _,station in ipairs(stations) do
        local point=station.coords
        exports.ox_target:addSphereZone({
            coords=vector3(point.x,point.y,point.z),radius=1.7,debug=false,
            options={{name=station.name,label=station.label,icon='fa-solid fa-recycle',distance=2.0,
                onSelect=function()
                    local ok,msg=lib.callback.await('wonkys_landscaping:waste:sell',false,station.kind)
                    lib.notify({type=ok and 'success' or 'error',description=msg})
                end}}
        })
        local blip=AddBlipForCoord(point.x,point.y,point.z)
        SetBlipSprite(blip,365);SetBlipColour(blip,2);SetBlipScale(blip,0.65)
        SetBlipAsShortRange(blip,true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(station.kind=='grass' and 'Landscaping - Grass Recycling' or 'Landscaping - Leaf Recycling')
        EndTextCommandSetBlipName(blip)
    end
end)
AddEventHandler('onResourceStop',function(res) if res==GetCurrentResourceName() then clear() end end)
