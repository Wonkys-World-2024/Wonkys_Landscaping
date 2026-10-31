local states, syncedAt = {}, {}
local serverEpochAtSync = nil
local clientTimerAtSync = nil
local function serverNow()
    if not serverEpochAtSync then return nil end
    return serverEpochAtSync + ((GetGameTimer() - clientTimerAtSync) / 1000)
end
local spawned = {}
local function scatter(id, salt)
    local v = math.sin(id * 12.9898 + salt * 78.233) * 43758.5453
    return (v - math.floor(v)) * 2 - 1
end
local lastSnapshot = {}
local function grid(plot)
    return math.floor(plot.width/Config.CellSize),math.floor(plot.length/Config.CellSize)
end
local function point(plot,id)
    local cols = grid(plot)
    local row,col = math.floor((id-1)/cols),(id-1)%cols
    local dx = -plot.width/2+(col+.5)*Config.CellSize
    local dy = -plot.length/2+(row+.5)*Config.CellSize
    local r=math.rad(plot.heading)
    return vector3(plot.x+dx*math.cos(r)-dy*math.sin(r),plot.y+dx*math.sin(r)+dy*math.cos(r),plot.z)
end
local function growth(plotId,id)
    local cut = states[plotId] and states[plotId][id]
    if not cut then return 1 end
    local now = serverNow()
    if not now then return 1 end
    return math.min(1,math.max(0,(now-cut)/(Config.RegrowHours*3600)))
end
local function clearProps(plotId)
    if not spawned[plotId] then return end
    for id,entity in pairs(spawned[plotId]) do
        if DoesEntityExist(entity) then DeleteEntity(entity) end
        spawned[plotId][id] = nil
    end
end
local function syncPlot(plot)
    local result,stamp = lib.callback.await('wonkys_landscaping:snapshot',false,plot.id)
    if result and type(stamp) == "number" then
        states[plot.id] = result
        syncedAt[plot.id] = stamp
        serverEpochAtSync = stamp
        clientTimerAtSync = GetGameTimer()
    end
end
RegisterNetEvent('wonkys_landscaping:cutUpdate',function(plotId,ids,cutAt)
    states[plotId]=states[plotId] or {}
    for _,id in ipairs(ids) do
        states[plotId][id]=cutAt
        if spawned[plotId] and spawned[plotId][id] then
            DeleteEntity(spawned[plotId][id]); spawned[plotId][id]=nil
        end
    end
end)
RegisterNetEvent('wonkys_landscaping:regrowUpdate', function(plotId, stamp)
    states[plotId] = {}
    clearProps(plotId)
    lastSnapshot[plotId] = nil
    if type(stamp) == 'number' then
        serverEpochAtSync = stamp
        clientTimerAtSync = GetGameTimer()
    end
end)
local function getMower()
    local ped=PlayerPedId()
    local vehicle=GetVehiclePedIsIn(ped,false)
    if vehicle==0 or GetPedInVehicleSeat(vehicle,-1)~=ped then return nil end
    for _,model in ipairs(Config.MowerModels) do
        if GetEntityModel(vehicle)==joaat(model) then return vehicle end
    end
end
CreateThread(function()
    while true do
        Wait(1200)
        local pos=GetEntityCoords(PlayerPedId())
        for _,plot in ipairs(Config.Plots) do
            local dist=#(pos-vector3(plot.x,plot.y,plot.z))
            if dist<Config.SyncRadius and (not lastSnapshot[plot.id] or GetGameTimer()-lastSnapshot[plot.id]>60000) then
                syncPlot(plot); lastSnapshot[plot.id]=GetGameTimer()
            elseif dist>Config.SyncRadius then
                states[plot.id]=nil; lastSnapshot[plot.id]=nil; clearProps(plot.id)
            end
        end
    end
end)
-- Optional visual clippings. No networked particle spam; effects are local to the mower driver.
local clipFxLoaded = false
local lastClipFx = 0
local pendingCutFx = false
local function clippingBurst(vehicle)
    if not Config.CutParticles then return end
    local now = GetGameTimer()
    if now - lastClipFx < (Config.ParticleIntervalMs or 700) then return end
    lastClipFx = now
    local dict = Config.ParticleDictionary or 'core'
    if not HasNamedPtfxAssetLoaded(dict) then
        RequestNamedPtfxAsset(dict)
        return
    end
    local deck = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, Config.DeckForwardOffset, -0.35)
    UseParticleFxAssetNextCall(dict)
    local fx = StartParticleFxLoopedAtCoord(Config.ParticleName or 'ent_sht_grass', deck.x, deck.y, deck.z, 0.0, 0.0, 0.0, Config.ParticleScale or 0.4, false, false, false, false)
    if fx and fx ~= 0 then
        SetTimeout(180, function() StopParticleFxLooped(fx, false) end)
    end
end
CreateThread(function()
    while true do
        Wait(Config.CutIntervalMs)
        local vehicle=getMower()
        if vehicle and GetEntitySpeed(vehicle)<Config.MaxSpeed and GetIsVehicleEngineRunning(vehicle) then
            local pos=GetEntityCoords(vehicle)
            local netId=nil -- server resolves vehicle from player; avoid invalid network-ID warnings
            if true then
                for _,plot in ipairs(Config.Plots) do
                    if states[plot.id] and #(pos-vector3(plot.x,plot.y,plot.z))<math.max(plot.width,plot.length)+8 then
                        local ids={}
                        local cols,rows=grid(plot)
                        for id=1,cols*rows do
                            local p=point(plot,id)
                            local deck=GetOffsetFromEntityInWorldCoords(vehicle,0.0,Config.DeckForwardOffset,0.0)
                            local planar=math.sqrt((p.x-deck.x)^2+(p.y-deck.y)^2)
                            if planar<Config.CutRadius and growth(plot.id,id)>Config.GrassMinGrowthToShow then
                                ids[#ids+1]=id
                                if #ids>=30 then break end
                            end
                        end
                        if #ids>0 then TriggerServerEvent('wonkys_landscaping:cut',plot.id,ids,netId) elseif Config.Debug then print('[Landscaping CUT] Mower detected; no grown grass cells under deck') end
                    end
                end
            end
        end
    end
end)
-- Only show cutting FX after the server confirms that grass cells were cut.
-- The local driver renders the effect; other clients do not receive networked FX spam.
RegisterNetEvent('wonkys_landscaping:cutFxConfirmed', function()
    local mower = getMower()
    if mower then clippingBurst(mower) end
end)
-- Local, non-networked grass props. The database remains authoritative for cut timestamps.
-- Growth stage is represented by density; no unverified scale native or particle assets are used.
local loadedModels = {}
local function stageFor(g)
    local selected = nil
    for _, stage in ipairs(Config.GrowthStages or {}) do
        if g >= stage.threshold then selected = stage end
    end
    return selected
end
local function modelReady(name)
    local hash = joaat(name)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    if not HasModelLoaded(hash) then RequestModel(hash); return nil end
    loadedModels[name] = true
    return hash
end
CreateThread(function()
    while true do
        Wait(1200)
        if Config.EnableGrassProps then
            local pos = GetEntityCoords(PlayerPedId())
            local count = 0
            for _, plot in ipairs(Config.Plots) do
                spawned[plot.id] = spawned[plot.id] or {}
                if states[plot.id] then
                    local cols, rows = grid(plot)
                    for id=1,cols*rows do
                        local p = point(plot,id)
                        local g = growth(plot.id,id)
                        local stage = stageFor(g)
                        local visible = stage and #(pos-p) < Config.RenderRadius
                            and scatter(id,7) * 0.5 + 0.5 < stage.density
                            and count < Config.GrassPropLimit
                        local existing = spawned[plot.id][id]
                        if visible then
                            count = count + 1
                            local name = stage.model or Config.GrassModel
                            local hash = modelReady(name)
                            if existing and (not DoesEntityExist(existing) or GetEntityModel(existing) ~= joaat(name)) then
                                if DoesEntityExist(existing) then DeleteEntity(existing) end
                                spawned[plot.id][id] = nil
                                existing = nil
                            end
                            if not existing and hash then
                                local offset = Config.GrassRandomOffset or 0
                                local sx = p.x + scatter(id,1) * offset
                                local sy = p.y + scatter(id,2) * offset
                                local found, groundZ = GetGroundZFor_3dCoord(sx,sy,p.z+30.0,false)
                                local z = (found and groundZ or p.z) + Config.GrassZOffset
                                local entity = CreateObjectNoOffset(hash,sx,sy,z,false,false,false)
                                if entity ~= 0 then
                                    if Config.GrassRandomRotation then SetEntityHeading(entity,(scatter(id,3)+1)*180) end
                                    SetEntityCollision(entity,false,false)
                                    FreezeEntityPosition(entity,true)
                                    spawned[plot.id][id] = entity
                                end
                            end
                        elseif existing then
                            if DoesEntityExist(existing) then DeleteEntity(existing) end
                            spawned[plot.id][id] = nil
                        end
                    end
                else
                    clearProps(plot.id)
                end
            end
        else
            for _,plot in ipairs(Config.Plots) do clearProps(plot.id) end
        end
    end
end)
RegisterCommand('landscape_status',function()
    local pos=GetEntityCoords(PlayerPedId())
    for _,plot in ipairs(Config.Plots) do
        if #(pos-vector3(plot.x,plot.y,plot.z))<Config.SyncRadius then
            if not states[plot.id] then lib.notify({description='Grass data still loading',type='inform'}) return end
            local cols,rows=grid(plot)
            local sum=0
            for id=1,cols*rows do sum=sum+growth(plot.id,id) end
            lib.notify({title=plot.label,description=('Average grass growth: %.0f%% (%d cells)'):format(sum/(cols*rows)*100,cols*rows),type='inform'})
            return
        end
    end
    lib.notify({description='No landscaping plot nearby',type='inform'})
end,false)
AddEventHandler('onResourceStop',function(resource)
    if resource~=GetCurrentResourceName() then return end
    for _,plot in ipairs(Config.Plots) do clearProps(plot.id) end
    if clipFxLoaded then RemoveNamedPtfxAsset(Config.ParticleDictionary or 'core') end
end)

RegisterCommand('landscape_propcheck',function()
    local hash=joaat(Config.GrassModel)
    local valid=IsModelInCdimage(hash) and IsModelValid(hash)
    lib.notify({title='Wonkys Landscaping',description=('Grass prop %s: %s'):format(Config.GrassModel,valid and 'VALID model (visual appearance still needs testing)' or 'NOT FOUND - choose another grass model'),type=valid and 'success' or 'error'})
end,false)

RegisterCommand('landscape_debug',function()
    Config.Debug=not Config.Debug
    lib.notify({title='Landscaping',description='Cut debug '..(Config.Debug and 'ON' or 'OFF')})
end,false)
RegisterNetEvent('wonkys_landscaping:cutDebug',function(message)
    if Config.Debug then print('[Landscaping CUT] '..message) end
    if Config.CutNotifications and message:find('^Cut %d+ grass cells') then lib.notify({description=message,type='inform'}) end
end)

-- Strimmer feature retired in v0.20.2. Ride-on and push mowers handle grass cutting.
