local models={grass='bzzz_weed_plastic_bag_green',leaves='prop_rub_binbag_01'}
local function loadFirst(names)
    for _,name in ipairs(names) do
        local hash=joaat(name)
        if IsModelInCdimage(hash) then
            RequestModel(hash)
            local deadline=GetGameTimer()+1500
            while not HasModelLoaded(hash) and GetGameTimer()<deadline do Wait(0) end
            if HasModelLoaded(hash) then return hash end
        end
    end
    return nil
end
local rendered={}
local carryObj=nil
local carrying=nil
local function loadModel(name)
    local hash=joaat(name)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local deadline=GetGameTimer()+3000
    while not HasModelLoaded(hash) and GetGameTimer()<deadline do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end
local function clearRendered(netId)
    for _,obj in ipairs(rendered[netId] or {}) do if DoesEntityExist(obj) then DeleteEntity(obj) end end
    rendered[netId]=nil
end
RegisterNetEvent('wonkys_landscaping:cargo:sync',function(netId,counts)
    clearRendered(netId)
    local trailer=NetworkGetEntityFromNetworkId(netId)
    if trailer==0 or not DoesEntityExist(trailer) then return end
    rendered[netId]={}
    local index=0
    for _,kind in ipairs({'grass','leaves'}) do
        for _=1,math.min(tonumber(counts[kind]) or 0,Config.Cargo.capacity) do
            index=index+1
            local hash
            if kind=='leaves' then
                hash=loadFirst({'prop_rub_binbag_01','prop_cs_rub_binbag_01','bzzz_weed_plastic_bag_yellow'})
            else
                hash=loadModel(models[kind])
            end
            if hash then
                local p=GetEntityCoords(trailer)
                local obj=CreateObject(hash,p.x,p.y,p.z,false,false,false)
                if obj~=0 then
                    SetEntityCollision(obj,false,false)
                    -- 24 bags in two layers of 12 (3 columns x 4 rows).
                    -- Keep the full stack at the hitch/pickup end of cotrailer,
                    -- leaving the rear ramps and mower section unobstructed.
                    -- GTA local +Y faces the pickup; local -Y faces the ramps.
                    local slot=(index-1)%12
                    local layer=math.floor((index-1)/12)
                    local col=slot%3
                    local row=math.floor(slot/3)
                    local x=(col-1)*0.68
                    local y=1.85-row*0.63
                    -- First layer uses the previously tested deck height.
                    -- Second layer rests above the first, not at trailer origin.
                    local z=0.12+layer*0.43
                    AttachEntityToEntity(obj,trailer,0,x,y,z,0,0,0,false,false,false,false,2,true)
                    rendered[netId][#rendered[netId]+1]=obj
                end
                SetModelAsNoLongerNeeded(hash)
            end
        end
    end
    -- Flower crates occupy a separate, compact rack at the rear of the cotrailer.
    -- The server owns counts; these are cosmetic local attachments only.
    for i=1,math.min(tonumber(counts.flowers) or 0,Config.Cargo.flowerCrateCapacity or 12) do
        local hash=loadFirst({'m23_1_prop_m31_crate_pk_01a','prop_box_wood02a_pu','prop_box_wood01a','prop_cs_cardbox_01'})
        if hash then
            local pos=GetEntityCoords(trailer)
            local obj=CreateObject(hash,pos.x,pos.y,pos.z,false,false,false)
            if obj~=0 then
                SetEntityCollision(obj,false,false)
                local slot=(i-1)%6
                local layer=math.floor((i-1)/6)
                local col=slot%2
                local row=math.floor(slot/2)
                local x=(col==0 and -0.43 or 0.43)
                local y=-0.65-row*0.62
                local z=0.20+layer*0.48
                AttachEntityToEntity(obj,trailer,0,x,y,z,0.0,0.0,0.0,false,false,false,false,2,true)
                rendered[netId][#rendered[netId]+1]=obj
            end
            SetModelAsNoLongerNeeded(hash)
        end
    end
    -- Dedicated timber rack down the trailer sides, independent of the 24-bag front rack.
    -- Models are client-side decorative objects; server owns inventory and counts.
    for i=1,math.min(tonumber(counts.timber) or 0,Config.Cargo.timberCapacity or 6) do
        local hash=loadFirst({
            Config.Logging.logPileModel or 'bzzz_lumberjack_wood_pack_2a_static',
            'bzzz_lumberjack_wood_pack_1a_static',
            Config.Cargo.timberModel or 'prop_log_01',
            'prop_log_01'
        })
        if hash then
            local pos=GetEntityCoords(trailer)
            local obj=CreateObject(hash,pos.x,pos.y,pos.z,false,false,false)
            if obj~=0 then
                SetEntityCollision(obj,false,false)
                -- Timber lies lengthways on the trailer (GTA local Y axis),
                -- in two narrow columns, three positions each. Keep it
                -- within the deck rather than hanging over the side rails.
                -- Fine tuning values are in config.lua for cotrailer models.
                local layout=Config.Cargo.timberLayout or {}
                local side=(i%2==1) and -1 or 1
                local row=math.floor((i-1)/2)
                local x=side*(layout.sideOffset or 0.48)
                local y=(layout.startY or -0.10)-row*(layout.rowSpacing or 0.62)
                local z=(layout.height or 0.20)+row*(layout.rowLift or 0.00)
                AttachEntityToEntity(obj,trailer,0,x,y,z,0.0,0.0,
                    layout.heading or 0.0,false,false,false,false,2,true)
                rendered[netId][#rendered[netId]+1]=obj
            end
            SetModelAsNoLongerNeeded(hash)
        end
    end
end)
local function action(netId,kind,mode)
    local ok,msg=lib.callback.await('wonkys_landscaping:cargo:'..mode,false,netId,kind)
    lib.notify({type=ok and 'success' or 'error',description=msg})
end
CreateThread(function()
    Wait(1500)
    exports.ox_target:addModel(joaat(Config.Fleet.trailerModel),{
        {name='landscape_cargo_load_grass',label='Load grass clippings bag',icon='fa-solid fa-box',distance=3.0,onSelect=function(data) action(NetworkGetNetworkIdFromEntity(data.entity),'grass','load') end},
        {name='landscape_cargo_load_timber',label='Load timber log',icon='fa-solid fa-tree',distance=3.0,onSelect=function(data) action(NetworkGetNetworkIdFromEntity(data.entity),'timber','load') end},
        {name='landscape_cargo_unload_timber',label='Unload timber log',icon='fa-solid fa-box-open',distance=3.0,onSelect=function(data) action(NetworkGetNetworkIdFromEntity(data.entity),'timber','unload') end},
        {name='landscape_cargo_load_flowers',label='Secure harvested flower crate',icon='fa-solid fa-box',distance=3.0,onSelect=function(data) action(NetworkGetNetworkIdFromEntity(data.entity),'flowers','load') end},
        {name='landscape_cargo_unload_flowers',label='Remove flower crate',icon='fa-solid fa-box-open',distance=3.0,onSelect=function(data) action(NetworkGetNetworkIdFromEntity(data.entity),'flowers','unload') end},
        {name='landscape_cargo_load_leaves',label='Load leaf bag',icon='fa-solid fa-box',distance=3.0,onSelect=function(data) action(NetworkGetNetworkIdFromEntity(data.entity),'leaves','load') end},
        {name='landscape_cargo_unload_grass',label='Unload grass bag',icon='fa-solid fa-box-open',distance=3.0,onSelect=function(data) action(NetworkGetNetworkIdFromEntity(data.entity),'grass','unload') end},
        {name='landscape_cargo_recycle_all',label='Unload and sell all trailer cargo (at depot)',icon='fa-solid fa-recycle',distance=3.0,
            canInteract=function(entity)
                local depot=Config.Recycling.grass.coords
                return #(GetEntityCoords(entity)-vector3(depot.x,depot.y,depot.z)) <= (Config.Cargo.recycleRadius or 18.0)
            end,
            onSelect=function(data)
                local netId=NetworkGetNetworkIdFromEntity(data.entity)
                local done=lib.progressBar({
                    duration=4500,label='Unloading trailer cargo and flower crates...',
                    useWhileDead=false,canCancel=true,
                    disable={move=true,car=true,combat=true},
                    anim={dict='amb@prop_human_bum_bin@base',clip='base'}
                })
                if not done then return end
                local ok,msg=lib.callback.await('wonkys_landscaping:cargo:recycle',false,netId)
                if ok then
                    lib.alertDialog({header="Wonky's Waste Depot — Delivery Receipt",content=msg,centered=true,labels={confirm='Done'}})
                else
                    lib.notify({type='error',description=msg})
                end
            end},
        {name='landscape_cargo_unload_leaves',label='Unload leaf bag',icon='fa-solid fa-box-open',distance=3.0,onSelect=function(data) action(NetworkGetNetworkIdFromEntity(data.entity),'leaves','unload') end},
    })
end)
-- Sync when approaching trailers, including after joining the server.
CreateThread(function()
    local requested={}
    while true do
        Wait(5000)
        local ped=PlayerPedId();local p=GetEntityCoords(ped)
        for _,veh in ipairs(GetGamePool('CVehicle')) do
            if GetEntityModel(veh)==joaat(Config.Fleet.trailerModel) and #(GetEntityCoords(veh)-p)<45.0 then
                local id=NetworkGetNetworkIdFromEntity(veh)
                if id>0 and not requested[id] then requested[id]=true;TriggerServerEvent('wonkys_landscaping:cargo:request',id) end
            end
        end
    end
end)
local function stopCarry()
    carrying=nil
    if carryObj and DoesEntityExist(carryObj) then DeleteEntity(carryObj) end
    carryObj=nil
    ClearPedSecondaryTask(PlayerPedId())
end
local function carry(kind)
    if carrying then stopCarry();return end
    local item=kind=='grass' and 'landscape_grass_clippings' or 'landscape_leaf_bag'
    if (exports.ox_inventory:Search('count',item) or 0)<1 then return end
    local hash=kind=='leaves' and loadFirst({'prop_rub_binbag_01','prop_cs_rub_binbag_01','bzzz_weed_plastic_bag_yellow'}) or loadModel(models[kind]);if not hash then lib.notify({type='error',description='BzZz bag model not loaded'});return end
    local ped=PlayerPedId();local p=GetEntityCoords(ped)
    carryObj=CreateObject(hash,p.x,p.y,p.z,false,false,false)
    SetEntityCollision(carryObj,false,false)
    AttachEntityToEntity(carryObj,ped,GetPedBoneIndex(ped,57005),0.13,0.02,-0.08,0,90,15,false,false,false,false,2,true)
    SetModelAsNoLongerNeeded(hash)
    carrying=kind
    lib.notify({description='Carrying '..kind..' bag. Use item again to put it away.'})
end
exports('carryGrassBag',function() carry('grass') end)
exports('carryLeafBag',function() carry('leaves') end)
RegisterCommand('landscape_putbagaway',stopCarry,false)
AddEventHandler('onResourceStop',function(res)
    if res==GetCurrentResourceName() then
        stopCarry()
        for netId in pairs(rendered) do clearRendered(netId) end
    end
end)
