-- Experimental GTA stock vehicle fleet. Existing grass system is not modified.
local fleet = {van=0, trailer=0, mower=0}
local selectedVehicle = Config.Fleet.vanModel
local activeJob = nil
local uiOpen = false
local loaded = false
local rampOpen = false
local function notify(message, kind)
    lib.notify({title='Wonky\'s Landscaping',description=message,type=kind or 'inform'})
end
local function requestModel(name)
    local hash = joaat(name)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return nil end
    RequestModel(hash)
    local deadline = GetGameTimer() + 6000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
    if not HasModelLoaded(hash) then return nil end
    return hash
end
local function spawnVehicle(name, position)
    local hash = requestModel(name)
    if not hash then notify('Vehicle model unavailable: '..name,'error'); return 0 end
    local vehicle = CreateVehicle(hash,position.x,position.y,position.z,position.w,true,true)
    SetModelAsNoLongerNeeded(hash)
    if vehicle == 0 then notify('Vehicle could not spawn','error'); return 0 end
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleNumberPlateText(vehicle,'WONKY'..math.random(100,999))
    SetVehicleDirtLevel(vehicle,0.0)
    return vehicle
end
local function exists(vehicle) return vehicle ~= 0 and DoesEntityExist(vehicle) end
-- Qbox GiveKeys is a SERVER export, never a client export.
local function grantFleetKeys(vehicle, label)
    if not exists(vehicle) then return end
    CreateThread(function()
        local netId = 0
        for attempt = 1, 20 do
            if not exists(vehicle) then return end
            if NetworkGetEntityIsNetworked(vehicle) then
                netId = NetworkGetNetworkIdFromEntity(vehicle)
                if netId and netId > 0 then break end
            end
            Wait(200)
        end
        if not netId or netId == 0 then
            notify(label..' is not networked; cannot issue keys.', 'error')
            return
        end
        for attempt=1,6 do
            if not exists(vehicle) then return end
            local success,ok = pcall(function()
                return lib.callback.await('wonkys_landscaping:grantFleetKeys', false, netId, label)
            end)
            if success and ok then
                notify(label..' keys issued.', 'success')
                return
            end
            Wait(650)
        end
        notify(label..' keys failed. Check server console for reason.', 'error')
    end)
end

local function spawnFleet()
    local permitted, location = lib.callback.await('wonkys_landscaping:fleetPermission',false)
    if not permitted then
        notify('Go to the golf club or logging pickup point to collect vehicles.','error'); return
    end
    if exists(fleet.van) or exists(fleet.trailer) or exists(fleet.mower) then
        notify('Return your existing fleet before requesting another.','error'); return
    end
    -- Explicit, individually surveyed fleet positions; no heading-based offsets.
    local logging = location == 'logging'
    local spawn = logging and Config.Fleet.loggingSpawnPositions or Config.Fleet.spawnPositions
    local positions = logging and {spawn.pickup,spawn.trailer} or {spawn.pickup,spawn.trailer,spawn.mower}
    for _,pos in ipairs(positions) do
        if IsAnyVehicleNearPoint(pos.x,pos.y,pos.z,2.5) then
            notify('A fleet parking bay is blocked. Move vehicles away and retry.','error')
            return
        end
    end
    fleet.van = spawnVehicle(selectedVehicle,positions[1])
    fleet.trailer = spawnVehicle(Config.Fleet.trailerModel,positions[2])
    if not logging then fleet.mower = spawnVehicle(Config.Fleet.mowerModel,positions[3]) end
    if exists(fleet.van) then
        local ped=PlayerPedId()
        TaskWarpPedIntoVehicle(ped,fleet.van,-1)
        grantFleetKeys(fleet.van, 'Van')
    end
    if exists(fleet.mower) then grantFleetKeys(fleet.mower, 'Mower') end
    notify(logging and 'Logging fleet collected: Sandstorm EV and cotrailer.' or 'Fleet collected. Reverse to hitch naturally, lower ramps and drive mower aboard.','success')
end
-- Keep the mower at its driven-on position, rather than snapping to a guessed offset.
local function secureMower()
    local mower,trailer = fleet.mower,fleet.trailer
    if not exists(mower) or not exists(trailer) then notify('Collect the fleet first.','error'); return end
    if loaded then notify('Mower is already secured.'); return end
    if GetEntitySpeed(mower) > Config.Fleet.maxLoadSpeed or GetEntitySpeed(trailer) > Config.Fleet.maxLoadSpeed then
        notify('Stop the mower and trailer first.','error'); return
    end
    local ped=PlayerPedId()
    if IsPedInVehicle(ped,mower,false) then
        notify('Get off the mower before securing it.','error'); return
    end
    local p=GetEntityCoords(mower)
    local rel=GetOffsetFromEntityGivenWorldCoords(trailer,p.x,p.y,p.z)
    local cfg=Config.Fleet
    -- Reserve the front of the deck for the 2 x 3 waste-bag rack.
    -- The mower must be driven towards the rear ramps before securing.
    if rel.y > -1.65 then
        notify('Move the mower further back towards the ramps; the front is reserved for waste bags.','error')
        return
    end
    if math.abs(rel.x)>cfg.deckHalfWidth or rel.y>cfg.deckFrontY or rel.y<cfg.deckRearY or rel.z<cfg.deckMinZ or rel.z>cfg.deckMaxZ then
        notify('Drive the mower fully onto the trailer deck first.','error'); return
    end
    local timeout=GetGameTimer()+2000
    while not NetworkHasControlOfEntity(mower) and GetGameTimer()<timeout do
        NetworkRequestControlOfEntity(mower)
        Wait(50)
    end
    if not NetworkHasControlOfEntity(mower) then notify('Cannot control mower; try again.','error'); return end
    SetVehicleEngineOn(mower,false,true,true)
    SetVehicleHandbrake(mower,true)
    local rotation=GetEntityRotation(mower,2)
    local trailerRotation=GetEntityRotation(trailer,2)
    SetEntityCollision(mower,false,false)
    AttachEntityToEntity(mower,trailer,0,rel.x,rel.y,rel.z,
        rotation.x-trailerRotation.x,rotation.y-trailerRotation.y,rotation.z-trailerRotation.z,
        false,false,false,false,2,true)
    if not IsEntityAttachedToEntity(mower,trailer) then
        SetEntityCollision(mower,true,true)
        notify('Unable to secure mower.','error'); return
    end
    loaded=true
    notify('Mower secured in its parked position. Raise the ramps before towing.','success')
end
local function unloadMower()
    if not loaded or not exists(fleet.mower) then notify('No secured mower.','error'); return end
    local mower,trailer=fleet.mower,fleet.trailer
    if not exists(trailer) or GetEntitySpeed(trailer)>Config.Fleet.maxLoadSpeed then notify('Stop the trailer first.','error'); return end
    local timeout=GetGameTimer()+2000
    while not NetworkHasControlOfEntity(mower) and GetGameTimer()<timeout do
        NetworkRequestControlOfEntity(mower)
        Wait(50)
    end
    if not NetworkHasControlOfEntity(mower) then notify('Cannot control mower; try again.','error'); return end
    DetachEntity(mower,true,true)
    SetEntityCollision(mower,true,true)
    SetVehicleHandbrake(mower,true)
    loaded=false
    notify('Mower released on trailer. Lower ramps, get on and drive off.','success')
end

local function toggleRamp()
    if not exists(fleet.trailer) then notify('Collect the fleet first.','error'); return end
    local trailer = fleet.trailer
    if GetEntitySpeed(trailer) > 0.5 then notify('Stop the trailer before operating its ramp.','error'); return end
    if not NetworkHasControlOfEntity(trailer) then NetworkRequestControlOfEntity(trailer); Wait(350) end
    if not NetworkHasControlOfEntity(trailer) then notify('Could not control the trailer.','error'); return end
    -- The original single-player script uses a boot toggle. GTA door index 5 is the boot.
    -- Whether this model animates a ramp through the boot bone must be confirmed in game.
    if rampOpen then
        SetVehicleDoorShut(trailer,5,false)
    else
        SetVehicleDoorOpen(trailer,5,false,false)
    end
    rampOpen = not rampOpen
    notify(rampOpen and 'Rear ramp opening requested.' or 'Rear ramp closing requested.')
end

local function returnFleet()
    if loaded and exists(fleet.mower) then DetachEntity(fleet.mower,true,true) end
    loaded=false
    rampOpen=false
    for key,vehicle in pairs(fleet) do
        if exists(vehicle) then
            if not NetworkHasControlOfEntity(vehicle) then NetworkRequestControlOfEntity(vehicle); Wait(250) end
            if NetworkHasControlOfEntity(vehicle) then DeleteVehicle(vehicle) end
        end
        fleet[key]=0
    end
    notify('Fleet return attempted. Check for any remaining vehicles.')
end
RegisterCommand('landscape_fleet',function()
    local shift=lib.callback.await('wonkys_landscaping:shift:status',false)
    if not shift or not shift.active then notify('Start a shift at HQ first.','error');return end
    if not Config.Fleet or not Config.Fleet.enabled then return end
    lib.registerContext({id='wonkys_landscape_fleet',title="Wonky's Landscaping | Fleet",options={
        {title='Collect company fleet',description='Golf: truck, trailer, mower | Logging: truck and trailer',icon='truck',onSelect=spawnFleet},
        {title='Toggle trailer rear ramp',description='Open or close the working trailer ramps',icon='arrow-down-to-line',onSelect=toggleRamp},
        {title='Secure mower on trailer',description='Park mower on deck first, then secure',icon='link',onSelect=secureMower},
        {title='Release mower on trailer',icon='unlink',onSelect=unloadMower},
        {title='Return fleet',icon='warehouse',onSelect=returnFleet},
    }})
    lib.showContext('wonkys_landscape_fleet')
end,false)
AddEventHandler('onResourceStop',function(name)
    if name ~= GetCurrentResourceName() then return end
    -- Do not delete occupied network vehicles when a script is restarted.
    if loaded and exists(fleet.mower) then DetachEntity(fleet.mower,true,true); SetEntityCollision(fleet.mower,true,true) end
end)

-- Neon-blue NUI dashboard. Existing /landscape_fleet remains as a lightweight fallback.
local function closeDashboard()
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({type='close'})
end
local function openDashboard()
    if uiOpen then return end
    local shift=lib.callback.await('wonkys_landscaping:shift:status',false)
    if not shift or not shift.active or not shift.tablet then
        notify('Start your shift and collect a company tablet from the HQ supervisor.','error')
        return
    end
    uiOpen = true
    SetNuiFocus(true, true)
    local jobs = {}
    for _,job in ipairs(Config.Contracts.jobs or {}) do
        local plot
        for _,candidate in ipairs(Config.Plots) do if candidate.id==job.id then plot=candidate break end end
        if plot or job.type then jobs[#jobs+1]={id=job.id,type=job.type or 'grass',label=job.label,description=job.description..' · $'..job.payment..' bank payment'} end
    end
    local status=lib.callback.await('wonkys_landscaping:contracts:status',false)
    activeJob=nil
    if status then for _,plot in ipairs(Config.Plots) do if plot.id==status.id then activeJob=plot break end end end
    SendNUIMessage({type='open',data={progression=nil,vehicles=Config.Fleet.vehicleOptions or {{model='sandstormev',label='Sandstorm EV'}},jobs=jobs,selected=selectedVehicle,active=status and (status.label..' ('..status.progress..'/'..status.required..')') or nil}})
    -- Never block tablet opening on database/leaderboard queries.
    CreateThread(function()
        local ok,progression=pcall(function()
            return lib.callback.await('wonkys_landscaping:progression:dashboard',false)
        end)
        if uiOpen then
            SendNUIMessage({type='progression',data=ok and progression or nil})
        end
    end)
end
RegisterNetEvent('wonkys_landscaping:tablet:open',openDashboard)
-- ox_inventory already invokes this client export when the item is used.
-- Do not call ox_inventory:useItem again here: that can prevent the NUI opening.
exports('useTablet', function(data, slot)
    openDashboard()
end)
RegisterNetEvent('wonkys_landscaping:tablet:use', function()
    openDashboard()
end)
RegisterCommand('landscape',openDashboard,false)
RegisterCommand('landscape_ui',openDashboard,false)
RegisterNUICallback('close',function(_,cb) closeDashboard(); cb({ok=true}) end)
RegisterNUICallback('selectJob',function(data,cb)
    local result=lib.callback.await('wonkys_landscaping:contracts:start',false,data.id)
    if result and result.ok then
        TriggerEvent('wonkys_landscaping:contractBlips:accepted', data.id)
        for _,plot in ipairs(Config.Plots) do if plot.id==data.id then activeJob=plot; SetNewWaypoint(plot.x,plot.y) break end end
        if data.id=='golf_leaf_cleanup' then local p=Config.LeafSites[1];SetNewWaypoint(p.x,p.y) end
        if data.id=='golf_flower_harvest' or data.id=='golf_hedge_trimming' then local p=Config.Hedges.sites[1];SetNewWaypoint(p.x,p.y) end
        notify('Contract accepted: '..result.label..'. Complete the required tasks to earn payment.','success')
        closeDashboard()
    else notify(result and result.message or 'Unable to accept contract','error') end
    cb(result or {ok=false})
end)
RegisterNUICallback('cancelJob',function(_,cb)
    local result=lib.callback.await('wonkys_landscaping:contracts:cancel',false)
    if result and result.ok then TriggerEvent('wonkys_landscaping:contractBlips:clear'); activeJob=nil; notify('Contract cancelled.','inform'); closeDashboard()
    else notify(result and result.message or 'No active contract','error') end
    cb(result or {ok=false})
end)
RegisterNetEvent('wonkys_landscaping:contracts:progress',function(count,required,label)
    SendNUIMessage({type='activeJob',label=('%s: %d/%d'):format(label or 'Contract',count,required)})
end)
RegisterNetEvent('wonkys_landscaping:contracts:completed',function(payment)
    TriggerEvent('wonkys_landscaping:contractBlips:clear')
    activeJob=nil
    SendNUIMessage({type='activeJob',label=nil})
end)
RegisterNUICallback('fleetAction',function(data,cb)
    local action=data.action
    if action=='collect' then
        if type(data.vehicle)=='string' then
            for _,v in ipairs(Config.Fleet.vehicleOptions or {}) do
                if v.model==data.vehicle then selectedVehicle=v.model break end
            end
        end
        closeDashboard()
        spawnFleet()
    elseif action=='ramp' then closeDashboard(); toggleRamp()
    elseif action=='secure' then closeDashboard(); secureMower()
    elseif action=='release' then closeDashboard(); unloadMower()
    elseif action=='return' then closeDashboard(); returnFleet()
    end
    cb({ok=true})
end)
AddEventHandler('onResourceStop',function(name)
    if name==GetCurrentResourceName() and uiOpen then SetNuiFocus(false,false) end
end)
