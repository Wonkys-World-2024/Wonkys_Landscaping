local state = {}
local dirty = {}
local plotById = {}
for _, plot in ipairs(Config.Plots) do
    assert(not plotById[plot.id], 'Duplicate landscaping plot id: '..plot.id)
    plotById[plot.id] = plot
    state[plot.id] = {}
end
local function cellCount(plot)
    return math.floor(plot.width / Config.CellSize) * math.floor(plot.length / Config.CellSize)
end
local function localCell(plot, id)
    local cols = math.floor(plot.width / Config.CellSize)
    local row = math.floor((id-1)/cols)
    local col = (id-1)%cols
    local dx = -plot.width/2 + (col+.5)*Config.CellSize
    local dy = -plot.length/2 + (row+.5)*Config.CellSize
    local r = math.rad(plot.heading)
    return plot.x + dx*math.cos(r)-dy*math.sin(r), plot.y+dx*math.sin(r)+dy*math.cos(r)
end
local function withinPlot(plot, x, y, tolerance)
    local r = math.rad(-plot.heading)
    local dx,dy = x-plot.x,y-plot.y
    local lx = dx*math.cos(r)-dy*math.sin(r)
    local ly = dx*math.sin(r)+dy*math.cos(r)
    return math.abs(lx) <= plot.width/2+tolerance and math.abs(ly) <= plot.length/2+tolerance
end
MySQL.ready(function()
    local rows = MySQL.query.await('SELECT plot_id,cell_id,cut_at FROM wonkys_landscaping_cells') or {}
    for _, row in ipairs(rows) do
        local plot = plotById[row.plot_id]
        if plot and row.cell_id >= 1 and row.cell_id <= cellCount(plot) then
            state[row.plot_id][row.cell_id] = tonumber(row.cut_at)
        end
    end
    print(('[Wonkys_Landscaping] Loaded %s saved grass cells'):format(#rows))
end)
lib.callback.register('wonkys_landscaping:snapshot', function(source, plotId)
    local plot = plotById[plotId]
    if not plot then return nil end
    local ped = GetPlayerPed(source)
    if ped == 0 then return nil end
    local pos = GetEntityCoords(ped)
    if #(pos-vector3(plot.x,plot.y,plot.z)) > Config.SyncRadius then return nil end
    return state[plotId], os.time()
end)
local cooldown = {}
RegisterNetEvent('wonkys_landscaping:cut', function(plotId, ids, netId)
    local src = source
    local plot = plotById[plotId]
    if not LandscapingOnShift(src) then return end
    if not plot or type(ids) ~= 'table' or #ids > 30 or #ids == 0 then return end
    local nowMs = GetGameTimer()
    if cooldown[src] and nowMs-cooldown[src] < Config.CutIntervalMs-100 then return end
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local pos = GetEntityCoords(ped)
    if not withinPlot(plot,pos.x,pos.y,Config.CutRadius+5) or math.abs(pos.z-plot.z)>12 then return end
    if Config.RequireJob then
        if GetResourceState('qbx_core') ~= 'started' then return end
        local player = exports.qbx_core:GetPlayer(src)
        if not player or not player.PlayerData or player.PlayerData.job.name ~= Config.Job then return end
    end
    local vehicle = GetVehiclePedIsIn(ped, false) -- reliable server-side vehicle resolution; no network ID required
    if vehicle == 0 or not DoesEntityExist(vehicle) or GetPedInVehicleSeat(vehicle,-1) ~= ped then return end
    local validModel = false
    for _, model in ipairs(Config.MowerModels) do
        if GetEntityModel(vehicle) == joaat(model) then validModel = true break end
    end
    if not validModel then return end
    if GetEntitySpeed(vehicle) > Config.MaxSpeed then return end
    local vehPos = GetEntityCoords(vehicle)
    if #(vehPos-pos)>9 then return end
    local updated = {}
    local seen = {}
    local now = os.time()
    for _, rawId in ipairs(ids) do
        local id = tonumber(rawId)
        if id and id%1 == 0 and id>=1 and id<=cellCount(plot) and not seen[id] then
            seen[id] = true
            local x,y = localCell(plot,id)
            local heading = math.rad(GetEntityHeading(vehicle))
            local deckX = vehPos.x - math.sin(heading)*Config.DeckForwardOffset
            local deckY = vehPos.y + math.cos(heading)*Config.DeckForwardOffset
            local distance = math.sqrt((x-deckX)^2+(y-deckY)^2)
            local lastCutAt = tonumber(state[plotId][id])
            if distance <= Config.CutRadius+0.65 and (not lastCutAt or now-lastCutAt >= math.max(1,tonumber(Config.RegrowHours) or 48)*3600) then
                state[plotId][id] = now
                dirty[plotId..':'..id] = {plotId,id,now}
                updated[#updated+1] = id
            end
        end
    end
    if #updated == 0 then TriggerClientEvent('wonkys_landscaping:cutDebug',src,'Server received cells but none matched deck position'); return end
    if LandscapingWasteCut then LandscapingWasteCut(src, plotId, updated, vehPos) end
    if LandscapingContractCut then LandscapingContractCut(src, plotId, updated) end
    TriggerClientEvent('wonkys_landscaping:cutDebug',src,('Cut %d grass cells'):format(#updated))
    TriggerClientEvent('wonkys_landscaping:cutFxConfirmed', src)
    cooldown[src] = nowMs
    for _, target in ipairs(GetPlayers()) do
        local targetId = tonumber(target)
        local tped = GetPlayerPed(targetId)
        if tped ~= 0 and #(GetEntityCoords(tped)-vector3(plot.x,plot.y,plot.z)) <= Config.SyncRadius then
            TriggerClientEvent('wonkys_landscaping:cutUpdate',targetId,plotId,updated,now)
        end
    end
end)
local function flush()
    for key, data in pairs(dirty) do
        local ok = pcall(function()
            MySQL.update.await('INSERT INTO wonkys_landscaping_cells (plot_id,cell_id,cut_at) VALUES (?,?,?) ON DUPLICATE KEY UPDATE cut_at=VALUES(cut_at)',data)
        end)
        if ok then dirty[key] = nil end
    end
end
CreateThread(function()
    while true do Wait(Config.SaveIntervalSeconds*1000) flush() end
end)
AddEventHandler('playerDropped',function() cooldown[source]=nil end)
AddEventHandler('onResourceStop',function(resource)
    if resource == GetCurrentResourceName() then flush() end
end)

-- Admin-only test reset. Console always permitted; players need ACE permission.
RegisterCommand('landscape_regrow', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, 'wonkys.landscaping.admin') then
        TriggerClientEvent('ox_lib:notify', src, {type='error', description='You do not have permission to regrow grass.'})
        return
    end
    local plotId = args[1] or 'golf_course_test'
    if plotId == 'all' then
        if src ~= 0 then
            TriggerClientEvent('ox_lib:notify', src, {type='error', description='Use the server console to reset all plots.'})
            return
        end
        for id in pairs(plotById) do
            MySQL.update.await('DELETE FROM wonkys_landscaping_cells WHERE plot_id = ?', {id})
            state[id] = {}
            for key, data in pairs(dirty) do if data[1] == id then dirty[key] = nil end end
            TriggerClientEvent('wonkys_landscaping:regrowUpdate', -1, id, os.time())
        end
        print('[Wonkys_Landscaping] All plots regrown')
        return
    end
    local plot = plotById[plotId]
    if not plot then
        local msg = 'Unknown plot ID: '..tostring(plotId)
        if src == 0 then print('[Wonkys_Landscaping] '..msg) else TriggerClientEvent('ox_lib:notify',src,{type='error',description=msg}) end
        return
    end
    -- Clear queued writes before deleting persistent cut history.
    for key, data in pairs(dirty) do if data[1] == plotId then dirty[key] = nil end end
    MySQL.update.await('DELETE FROM wonkys_landscaping_cells WHERE plot_id = ?', {plotId})
    state[plotId] = {}
    TriggerClientEvent('wonkys_landscaping:regrowUpdate', -1, plotId, os.time())
    if src == 0 then print('[Wonkys_Landscaping] Regrew '..plotId)
    else TriggerClientEvent('ox_lib:notify',src,{type='success',description='Grass restored: '..plot.label}) end
end, false)

-- Server-side push-mower cutting. No client-selected plot or cell IDs.
function LandscapingEquipmentCut(src,pos,radius)
    if not LandscapingOnShift(src) then return end
    local now=os.time()
    for _,plot in ipairs(Config.Plots) do
        if math.abs(pos.z-plot.z)<=5 and withinPlot(plot,pos.x,pos.y,4) then
            local updated={}
            for id=1,cellCount(plot) do
                local x,y=localCell(plot,id)
                local distance=math.sqrt((x-pos.x)^2+(y-pos.y)^2)
                local previous=state[plot.id][id]
                if distance<=radius and (not previous or now-previous>=Config.RegrowHours*3600*Config.GrassMinGrowthToShow) then
                    state[plot.id][id]=now
                    dirty[plot.id..':'..id]={plot.id,id,now}
                    updated[#updated+1]=id
                    if #updated>=12 then break end
                end
            end
            if #updated>0 then
                if LandscapingWasteCut then LandscapingWasteCut(src,plot.id,updated,pos) end
                if LandscapingContractCut then LandscapingContractCut(src,plot.id,updated) end
                for _,player in ipairs(GetPlayers()) do
                    local target=tonumber(player)
                    local targetPed=GetPlayerPed(target)
                    if targetPed~=0 and #(GetEntityCoords(targetPed)-vector3(plot.x,plot.y,plot.z))<=Config.SyncRadius then
                        TriggerClientEvent('wonkys_landscaping:cutUpdate',target,plot.id,updated,now)
                    end
                end
            end
        end
    end
end
AddEventHandler('playerDropped',function() strimCooldown[source]=nil end)
