-- Wonky's Landscaping: conservative server-side abuse protection.
-- This layer does not trust client-supplied payout amounts or progress.
local limits = {}
local intervals = {
  ['wonkys_landscaping:shift:start']=1200,
  ['wonkys_landscaping:shift:finish']=1200,
  ['wonkys_landscaping:equipment:pushmower']=1200,
  ['wonkys_landscaping:equipment:leafblower']=1200,
  ['wonkys_landscaping:equipment:rake']=1200,
  ['wonkys_landscaping:grantFleetKeys']=1500,
  ['wonkys_landscaping:heavy:keys']=1500,
  ['wonkys_landscaping:heavy:permit']=1500,
  ['wonkys_landscaping:fleetPermission']=1500,
  ['wonkys_landscaping:heavy:canReturn']=500,
  ['wonkys_landscaping:garden:finish']=300,
  ['wonkys_landscaping:logging:collect']=350,
  ['wonkys_landscaping:leaves:collect']=350,
  ['wonkys_landscaping:waste:collect']=350,
  ['wonkys_landscaping:heavy:load']=350,
  ['wonkys_landscaping:heavy:unload']=350,
  ['wonkys_landscaping:cargo:load']=350,
  ['wonkys_landscaping:cargo:unload']=350,
  ['wonkys_landscaping:cargo:recycle']=1500,
  ['wonkys_landscaping:logging:sellTimber']=1500,
  ['wonkys_landscaping:waste:sell']=1500,
  ['wonkys_landscaping:contracts:start']=1000,
  ['wonkys_landscaping:contracts:cancel']=600,
  ['wonkys_landscaping:garden:begin']=300,
  ['wonkys_landscaping:hedges:begin']=300,
  ['wonkys_landscaping:leaves:begin']=300,
  ['wonkys_landscaping:logging:begin']=300,
}
local originalRegister = lib.callback.register
lib.callback.register = function(name, fn)
  local interval = intervals[name]
  if not interval then return originalRegister(name,fn) end
  return originalRegister(name,function(src,...)
    if type(src)~='number' or src<1 or not GetPlayerName(src) then return false,'Invalid player' end
    local now=GetGameTimer()
    local perPlayer=limits[src]
    if not perPlayer then perPlayer={};limits[src]=perPlayer end
    local previous=perPlayer[name]
    if previous and now-previous>=0 and now-previous<interval then
      return false,'Please wait before trying again'
    end
    perPlayer[name]=now
    return fn(src,...)
  end)
end
AddEventHandler('playerDropped',function() limits[source]=nil end)

-- Shared security helpers for all server modules. Never trust a client-side shift flag.
function LandscapingAuthorized(src)
    if type(src) ~= 'number' or src < 1 or not GetPlayerName(src) then return false end
    if not LandscapingOnShift or not LandscapingOnShift(src) then return false end
    if Config.RequireJob then
        local player = exports.qbx_core:GetPlayer(src)
        if not player or not player.PlayerData or not player.PlayerData.job
            or player.PlayerData.job.name ~= Config.Job then return false end
    end
    return true
end
local eventLimits = {}
function LandscapingEventAllowed(src, name, interval)
    if type(src) ~= 'number' or src < 1 or not GetPlayerName(src) then return false end
    local now=GetGameTimer()
    eventLimits[src]=eventLimits[src] or {}
    local last=eventLimits[src][name]
    if last and now-last >= 0 and now-last < (interval or 1000) then return false end
    eventLimits[src][name]=now
    return true
end
AddEventHandler('playerDropped',function() eventLimits[source]=nil end)
