-- Timed leaf cleanup: blow loose patches -> rake consolidated pile -> collect visible yellow bag.
local objects = {}
local function clear()
    for _,obj in ipairs(objects) do
        if DoesEntityExist(obj) then exports.ox_target:removeLocalEntity(obj); DeleteEntity(obj) end
    end
    objects={}
end
local function work(id,action)
    local duration=action=='blow' and 15000 or 12000
    local ok,msg=lib.callback.await('wonkys_landscaping:leaves:begin',false,id,action)
    if not ok then lib.notify({type='error',description=msg});return end
    -- Automatically equip the correct tool when ox_target begins a leaf task.
    local tool=action=='blow' and 'blower' or 'rake'
    local equipped=exports[GetCurrentResourceName()]:startLeafWorkTool(tool)
    if not equipped then
        lib.callback.await('wonkys_landscaping:leaves:cancel',false,id)
        lib.notify({type='error',description='Unable to equip '..tool..'. Check your shift and inventory.'})
        return
    end
    local completed=lib.progressBar({duration=duration,label=action=='blow' and 'Blowing loose leaves into a pile...' or 'Raking leaves into a waste bag...',canCancel=true,disable={car=true,combat=true,move=true}})
    exports[GetCurrentResourceName()]:stopLeafWorkTool()
    if not completed then
        lib.callback.await('wonkys_landscaping:leaves:cancel',false,id)
        lib.notify({type='inform',description='Leaf work cancelled'})
        return
    end
    local success,message=lib.callback.await('wonkys_landscaping:leaves:finish',false,id,action)
    lib.notify({type=success and 'success' or 'error',description=message})
end
local function collect(id)
    local ok,msg=lib.callback.await('wonkys_landscaping:leaves:collect',false,id)
    lib.notify({type=ok and 'success' or 'error',description=msg})
end
local function loadModel(name)
    local hash=joaat(name)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then print('[Wonkys_Landscaping] Missing model '..name);return nil end
    RequestModel(hash)
    local deadline=GetGameTimer()+5000
    while not HasModelLoaded(hash) and GetGameTimer()<deadline do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end
RegisterNetEvent('wonkys_landscaping:leaves:sync',function(data)
    clear()
    local leaf=loadModel('bzzz_garden_leaves_a')
    local yellow=loadModel('bzzz_weed_plastic_bag_yellow')
    for id,site in pairs(data or {}) do
        if site.stage=='bag' then
            if yellow then
                local obj=CreateObject(yellow,site.x,site.y,site.z-0.2,false,false,false)
                if obj~=0 then
                    PlaceObjectOnGroundProperly(obj);FreezeEntityPosition(obj,true);objects[#objects+1]=obj
                    exports.ox_target:addLocalEntity(obj,{{name='landscape_leaf_collect_'..id,label='Collect bag of leaves',icon='fa-solid fa-bag-shopping',distance=2.5,onSelect=function() collect(id) end}})
                end
            end
        elseif site.stage=='loose' or site.stage=='pile' then
            if leaf then
                local offsets=site.stage=='loose' and {{-1.2,-0.8},{1.1,0.8},{-0.5,1.5}} or {{0,0}}
                for n,offset in ipairs(offsets) do
                    local obj=CreateObject(leaf,site.x+offset[1],site.y+offset[2],site.z-0.2,false,false,false)
                    if obj~=0 then
                        PlaceObjectOnGroundProperly(obj);SetEntityHeading(obj,(n*73)%360);FreezeEntityPosition(obj,true);objects[#objects+1]=obj
                        local blowing=site.stage=='loose'
                        exports.ox_target:addLocalEntity(obj,{{name='landscape_leaf_'..id..'_'..n,label=blowing and 'Blow leaves (15 seconds)' or 'Rake pile (12 seconds)',icon=blowing and 'fa-solid fa-wind' or 'fa-solid fa-leaf',distance=2.5,onSelect=function() work(id,blowing and 'blow' or 'rake') end}})
                    end
                end
            end
        end
    end
    if leaf then SetModelAsNoLongerNeeded(leaf) end
    if yellow then SetModelAsNoLongerNeeded(yellow) end
end)
CreateThread(function() Wait(1700);TriggerServerEvent('wonkys_landscaping:leaves:request') end)
AddEventHandler('onResourceStop',function(res) if res==GetCurrentResourceName() then clear() end end)
