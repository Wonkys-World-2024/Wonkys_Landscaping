-- Server-authoritative, per-player paid mowing contracts.
local active = {}
local function notify(src, kind, message)
    TriggerClientEvent('ox_lib:notify',src,{title="Wonky's Landscaping",type=kind,description=message})
end
local jobs = {}
for _,job in ipairs(Config.Contracts.jobs) do jobs[job.id] = job end
local plots = {}
for _,plot in ipairs(Config.Plots) do plots[plot.id] = plot end
local function cells(plot)
    return math.floor(plot.width / Config.CellSize) * math.floor(plot.length / Config.CellSize)
end
lib.callback.register('wonkys_landscaping:contracts:status',function(src)
    local a = active[src]
    return a and {id=a.id,label=a.label,progress=a.count,required=a.required} or nil
end)
lib.callback.register('wonkys_landscaping:contracts:start',function(src,id)
    if not LandscapingAuthorized(src) then return {ok=false,message='Start your shift at HQ first'} end
    if type(id) ~= 'string' or not jobs[id] or (not plots[id] and not jobs[id].type) then return {ok=false,message='Contract unavailable'} end
    if active[src] then return {ok=false,message='Finish or cancel your current contract first'} end
    local job,plot = jobs[id],plots[id]
    local ped=GetPlayerPed(src)
    if ped==0 then return {ok=false,message='Player not ready'} end
    -- Contracts can be accepted at the depot or at the plot, not remotely across the map.
    local pos=GetEntityCoords(ped)
    local depot=vector3(Config.Fleet.depot.x,Config.Fleet.depot.y,Config.Fleet.depot.z)
    local target = plot and vector3(plot.x,plot.y,plot.z) or vector3(Config.Headquarters.blip.x,Config.Headquarters.blip.y,Config.Headquarters.blip.z)
    if job.type=='logging' or job.type=='trees' or job.type=='heavy_logging' then
        target=vector3(Config.WasteDepot.clerk.x,Config.WasteDepot.clerk.y,Config.WasteDepot.clerk.z)
    elseif job.type=='garden' then
        target=Config.Gardening.centre
    elseif job.type then
        target=job.type=='leaves' and Config.LeafSites[1] or vector3(Config.Hedges.sites[1].x,Config.Hedges.sites[1].y,Config.Hedges.sites[1].z)
    end
    local atForestryHut=false
    if job.type=='logging' or job.type=='trees' or job.type=='heavy_logging' then
        for _,hut in ipairs(Config.LoggingDuty or {}) do
            if #(pos-vector3(hut.x,hut.y,hut.z))<=55.0 then
                atForestryHut=true
                break
            end
        end
    end
    if #(pos-depot)>55.0 and #(pos-target)>55.0 and not atForestryHut then
        return {ok=false,message=(job.type=='logging' or job.type=='trees' or job.type=='heavy_logging') and 'Visit either logging hut, the landscaping depot or waste depot to accept forestry contracts' or 'Visit the landscaping depot to accept contracts'}
    end
    local required=job.type and job.required or math.max(1,math.ceil(cells(plot)*Config.Contracts.completionFraction))
    active[src]={id=id,label=job.label,type=job.type,count=0,required=required,seen={},payment=job.payment}
    TriggerClientEvent('wonkys_landscaping:contractBlips:accepted',src,id)
    return {ok=true,label=job.label,progress=0,required=required}
end)
lib.callback.register('wonkys_landscaping:contracts:cancel',function(src)
    if not active[src] then return {ok=false,message='No active contract'} end
    active[src]=nil
    TriggerClientEvent('wonkys_landscaping:contractBlips:clear',src)
    return {ok=true}
end)
-- Invoked ONLY by server/main.lua after it verifies the driver, mower, plot and cells.
function LandscapingContractCut(src,plotId,updated)
    local a=active[src]
    if not a or a.id~=plotId then return end
    for _,id in ipairs(updated) do
        if not a.seen[id] then a.seen[id]=true; a.count=a.count+1 end
    end
    TriggerClientEvent('wonkys_landscaping:contracts:progress',src,a.count,a.required,a.label)
    if a.count<a.required then return end
    LandscapingContractPay(src,a)

end

-- Payment is triggered only after server-validated work. Never accept client progress or amounts.
function LandscapingContractPay(src,a)
    active[src]=nil -- prevent duplicate rewards even if payment fails
    local ok,err=pcall(function()
        if GetResourceState('qbx_core')~='started' then error('qbx_core not started') end
        local player=exports.qbx_core:GetPlayer(src)
        if not player or not player.Functions or not player.Functions.AddMoney then error('Qbox player payment function unavailable') end
        local result=player.Functions.AddMoney('bank',a.payment,'wonkys-landscaping-contract')
        if result==false then error('bank payment rejected') end
    end)
    if ok then
        if LandscapingAwardProgress then LandscapingAwardProgress(src,a.payment) end
        notify(src,'success',('Contract complete! $%d paid to your bank.'):format(a.payment))
        TriggerClientEvent('wonkys_landscaping:contracts:completed',src,a.payment)
    else
        print(('[Wonkys_Landscaping] PAYMENT FAILED player %d contract %s: %s'):format(src,a.id,tostring(err)))
        notify(src,'error','Contract finished but payment failed. Contact an administrator; check server console.')
    end
end

function LandscapingContractActivity(src,kind,siteId)
    local a=active[src]
    if not a or a.type~=kind then return end
    siteId=tostring(siteId)
    if a.seen[siteId] then return end
    a.seen[siteId]=true
    a.count=a.count+1
    TriggerClientEvent('wonkys_landscaping:contracts:progress',src,a.count,a.required,a.label)
    if a.count>=a.required then
        LandscapingContractPay(src,a)
    end
end

-- Only server/logging.lua can report a successfully felled tree.
function LandscapingContractTreeFelled(src,treeId)
    LandscapingContractActivity(src,'trees','tree_'..tostring(treeId))
end

-- Called only by server/cargo.lua after a verified trailer delivery and bank sale.
-- A single qualifying delivery completes the contract; small partial deliveries don't count.
function LandscapingContractTimberDelivery(src,deliveredCount)
    local a=active[src]
    if not a or a.type~='logging' then return end
    local count=math.max(0,math.floor(tonumber(deliveredCount) or 0))
    if count<1 then return end
    a.count=math.min(a.required,a.count+count)
    TriggerClientEvent('wonkys_landscaping:contracts:progress',src,a.count,a.required,a.label)
    if a.count>=a.required then
        LandscapingContractPay(src,a)
    else
        notify(src,'inform',('Logging delivery: %d/%d timber logs delivered.'):format(a.count,a.required))
    end
end

AddEventHandler('playerDropped',function() active[source]=nil end)

-- Only verified sawmill unloading in server/heavy_logging.lua can advance these jobs.
function LandscapingContractHeavyTimberDelivery(src,delivered)
    local a=active[src]
    if not a or a.type~='heavy_logging' then return end
    a.count=math.min(a.required,a.count+math.max(0,math.floor(tonumber(delivered) or 0)))
    TriggerClientEvent('wonkys_landscaping:contracts:progress',src,a.count,a.required,a.label)
    if a.count>=a.required then LandscapingContractPay(src,a) end
end
