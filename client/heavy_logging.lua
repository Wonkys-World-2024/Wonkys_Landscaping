local cfg=Config.HeavyLogging
local truck,trailer=0,0
local rendered={}
local lastCounts={}
local rotationOverride=nil
local function timberRotation(hash)
    if rotationOverride~=nil then return rotationOverride end
    -- GTA attachments use vehicle-local X across the trailer and Y front-to-rear.
    -- Determine which horizontal axis is longer for the actual streamed timber model.
    local minDim,maxDim=GetModelDimensions(hash)
    local lengthX=math.abs(maxDim.x-minDim.x)
    local lengthY=math.abs(maxDim.y-minDim.y)
    return lengthX>lengthY and 90.0 or 0.0, lengthX, lengthY
end
local function notice(msg,kind)
    lib.notify({title="Wonky's Heavy Logging",description=msg,type=kind or 'inform'})
end
local function model(name)
    local hash=joaat(name)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local deadline=GetGameTimer()+6000
    while not HasModelLoaded(hash) and GetGameTimer()<deadline do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end
local function clear(id)
    for _,obj in ipairs(rendered[id] or {}) do if DoesEntityExist(obj) then DeleteEntity(obj) end end
    rendered[id]=nil
end
RegisterNetEvent('wonkys_landscaping:heavy:sync',function(id,count)
    lastCounts[id]=count
    clear(id)
    local veh=NetworkGetEntityFromNetworkId(id)
    if veh==0 or not DoesEntityExist(veh) then return end
    rendered[id]={}
    local hash=model(cfg.logModel)
    if not hash then return end
    local angle,lengthX,lengthY=timberRotation(hash)
    print(('[Wonkys Heavy Logging] Timber model axes X=%.2f Y=%.2f, attach rotation=%.0f degrees'):format(lengthX or 0,lengthY or 0,angle))
    for i=1,math.min(tonumber(count) or 0,cfg.capacity) do
        -- Three lengthways lanes, six loading positions per lane (18 total).
        -- Slight longitudinal overlap creates a continuous timber stack.
        local slot=i-1
        local lane=slot%3                  -- left / centre / right
        local position=math.floor(slot/3) -- front to back (six positions)
        local p=GetEntityCoords(veh)
        local obj=CreateObject(hash,p.x,p.y,p.z,false,false,false)
        if obj~=0 then
            SetEntityCollision(obj,false,false)
            local x=(lane-1)*0.78
            local y=3.6-position*1.42
            local z=cfg.deckOffsetZ
            -- Align the actual model's longest axis to the trailer's local Y axis.
            AttachEntityToEntity(obj,veh,0,x,y,z,0,0,angle,false,false,false,false,2,true)
            rendered[id][#rendered[id]+1]=obj
        end
    end
    SetModelAsNoLongerNeeded(hash)
end)

-- Local testing: /timberangle auto | 0 | 90 | 180 | 270
-- Rebuilds visible timber immediately without changing server-side cargo counts.
RegisterCommand('timberangle',function(_,args)
    local value=(args[1] or 'auto'):lower()
    if value=='auto' then
        rotationOverride=nil
    else
        local n=tonumber(value)
        if not n or (n~=0 and n~=90 and n~=180 and n~=270) then
            notice('Usage: /timberangle auto, 0, 90, 180 or 270','error')
            return
        end
        rotationOverride=n
    end
    local refreshed=0
    for id,count in pairs(lastCounts) do
        local veh=NetworkGetEntityFromNetworkId(id)
        if veh~=0 and DoesEntityExist(veh) then
            TriggerEvent('wonkys_landscaping:heavy:sync',id,count)
            refreshed=refreshed+1
        end
    end
    notice(('Timber angle: %s. Updated %d trailer(s).'):format(value,refreshed),'success')
end,false)

local function action(ent,mode)
    if GetEntitySpeed(ent)>0.6 then notice('Stop the trailer first','error');return end
    local id=NetworkGetNetworkIdFromEntity(ent)
    if not id or id==0 then notice('Trailer is not networked','error');return end
    if not lib.progressBar({duration=mode=='load' and 3000 or 3500,label=mode=='load' and 'Securing timber...' or 'Unloading timber at sawmill...',canCancel=true,disable={car=true,move=true,combat=true},anim={dict='amb@world_human_gardener_plant@male@base',clip='base'}}) then return end
    local ok,msg=lib.callback.await('wonkys_landscaping:heavy:'..mode,false,id)
    notice(msg or 'Action failed',ok and 'success' or 'error')
end
CreateThread(function()
    exports.ox_target:addModel(joaat(cfg.trailerModel),{
        {name='wonkys_heavy_load',label='Load timber log onto flatbed',icon='fa-solid fa-tree',distance=3.5,onSelect=function(data) action(data.entity,'load') end},
        {name='wonkys_heavy_unload',label='Deliver timber log at sawmill',icon='fa-solid fa-truck-ramp-box',distance=3.5,onSelect=function(data) action(data.entity,'unload') end},
    })
end)
local function spawnOne(name,pos)
    local hash=model(name)
    if not hash or not IsModelAVehicle(hash) then return 0 end
    local veh=CreateVehicle(hash,pos.x,pos.y,pos.z,pos.w,true,true)
    SetModelAsNoLongerNeeded(hash)
    if veh~=0 then
        SetVehicleOnGroundProperly(veh)
        SetVehicleNumberPlateText(veh,'WONKY'..math.random(100,999))
        SetEntityAsMissionEntity(veh,true,true)
    end
    return veh
end
local function collectRig()
    if (truck~=0 and DoesEntityExist(truck)) or (trailer~=0 and DoesEntityExist(trailer)) then notice('Return your previous logging rig first','error');return end
    local ok,msg=lib.callback.await('wonkys_landscaping:heavy:permit',false)
    if not ok then notice(msg,'error');return end
    local positions = cfg.spawnPositions
    if not positions or not positions.truck or not positions.trailer then
        notice('Heavy logging spawnPositions missing in config.lua', 'error')
        return
    end
    local truckPos, trailerPos = positions.truck, positions.trailer
    if IsAnyVehicleNearPoint(truckPos.x, truckPos.y, truckPos.z, 5.5)
        or IsAnyVehicleNearPoint(trailerPos.x, trailerPos.y, trailerPos.z, 5.5) then
        notice('Heavy logging parking bay blocked. Move nearby vehicles and retry.', 'error')
        return
    end
    truck=spawnOne(cfg.truckModel,truckPos)
    if truck==0 then notice('Phantom spawn failed','error');return end
    trailer=spawnOne(cfg.trailerModel,trailerPos)
    if trailer==0 then DeleteEntity(truck);truck=0;notice('trflat spawn failed','error');return end
    -- Client-spawned vehicles can take a moment to become visible server-side.
    -- Retry the server-authoritative Qbox key grant instead of silently failing.
    local spawnedTruck = truck
    CreateThread(function()
        for attempt = 1, 20 do
            if not DoesEntityExist(spawnedTruck) then return end
            local id = NetworkGetNetworkIdFromEntity(spawnedTruck)
            if id and id > 0 then
                local called, granted = pcall(function()
                    return lib.callback.await('wonkys_landscaping:heavy:keys', false, id)
                end)
                if called and granted then
                    notice('Phantom keys issued.', 'success')
                    return
                end
            end
            Wait(500)
        end
        notice('Phantom keys could not be issued. Check server console [Heavy Logging Keys].', 'error')
    end)
    notice('Phantom and trflat collected. Hitch the trailer manually.','success')
end
local function returnRig()
    if trailer~=0 and DoesEntityExist(trailer) then
        local id=NetworkGetNetworkIdFromEntity(trailer)
        -- Loaded trailers cannot be returned: timber must first be delivered.
        local ok,msg=lib.callback.await('wonkys_landscaping:heavy:canReturn',false,id)
        if not ok then notice(msg,'error');return end
        DeleteEntity(trailer)
    end
    if truck~=0 and DoesEntityExist(truck) then DeleteEntity(truck) end
    truck,trailer=0,0
    notice('Logging rig returned','success')
end
RegisterNetEvent('wonkys_landscaping:heavy:menu',function()
    lib.registerContext({id='wonkys_heavy_fleet',title='Commercial Timber Fleet',options={
        {title='Collect Phantom + trflat',description='Spawn Phantom and trflat in their configured parking bays',icon='truck',onSelect=collectRig},
        {title='Return logging rig',icon='rotate-left',onSelect=returnRig},
        {title='Route to Paleto sawmill',icon='route',onSelect=function() SetNewWaypoint(cfg.sawmill.x,cfg.sawmill.y);notice('Sawmill waypoint set (confirm unloading bay in-game)') end}
    }})
    lib.showContext('wonkys_heavy_fleet')
end)
CreateThread(function()
    local requested={}
    while true do
        Wait(4000)
        local p=GetEntityCoords(PlayerPedId())
        for _,veh in ipairs(GetGamePool('CVehicle')) do
            if GetEntityModel(veh)==joaat(cfg.trailerModel) and #(p-GetEntityCoords(veh))<65 then
                local id=NetworkGetNetworkIdFromEntity(veh)
                if id>0 and not requested[id] then requested[id]=true;TriggerServerEvent('wonkys_landscaping:heavy:request',id) end
            end
        end
    end
end)
AddEventHandler('onResourceStop',function(res)
    if res~=GetCurrentResourceName() then return end
    for id in pairs(rendered) do clear(id) end
end)
