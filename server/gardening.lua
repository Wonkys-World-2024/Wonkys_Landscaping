local cfg=Config.Gardening
if not cfg or not cfg.enabled then return end
local beds,locks={},{}
local file='gardening_state.json'
local ok,stored=pcall(json.decode,LoadResourceFile(GetCurrentResourceName(),file) or '{}')
if not ok or type(stored)~='table' then stored={} end
for i=1,#cfg.plots do
 local old=stored[tostring(i)] or {}
 beds[i]={stage=math.max(0,math.min(5,tonumber(old.stage) or 0)),variety=math.max(1,math.min(#cfg.varieties,tonumber(old.variety) or 1)),readyAt=tonumber(old.readyAt) or 0}
end
local function save() local out={} for i,v in ipairs(beds) do out[tostring(i)]=v end SaveResourceFile(GetCurrentResourceName(),file,json.encode(out),-1) end
local function advance() local changed=false for _,v in ipairs(beds) do if v.stage==3 and v.readyAt>0 and os.time()>=v.readyAt then v.stage=4;changed=true end end if changed then save() end return changed end
local function sync(src) advance();TriggerClientEvent('wonkys_landscaping:garden:sync',src,beds) end
RegisterNetEvent('wonkys_landscaping:garden:request',function() if LandscapingEventAllowed(source,'garden:request',1500) then sync(source) end end)
local actions={dig={from=0,to=1,duration=6000},plant={from=1,to=2,duration=4500},water={from=2,to=3,duration=5000},prune={from=4,to=5,duration=5000},harvest={from=5,to=0,duration=4500}}
local function near(src,id) local ped=GetPlayerPed(src);if ped==0 then return false end local p=cfg.plots[id];if not p then return false end return #(GetEntityCoords(ped)-vector3(p.x,p.y,p.z))<3.5 end
lib.callback.register('wonkys_landscaping:garden:begin',function(src,id,action,variety)
 id=tonumber(id);local a=actions[action];local bed=id and beds[id]
 if not a or not bed then return false,'Invalid plot' end
 advance()
 if bed.stage~=a.from then return false,'This flower bed is not ready' end
 if locks[id] then return false,'Someone is working here' end
 if not LandscapingAuthorized(src) then return false,'Start your landscaping shift first' end
 if not near(src,id) then return false,'Move closer to the flower bed' end
 if action=='plant' and exports.ox_inventory:GetItemCount(src,cfg.seedItem)<1 then return false,'You need flower seeds' end
 if action=='harvest' and not exports.ox_inventory:CanCarryItem(src,cfg.harvestItem,1) then return false,'Inventory is full' end
 locks[id]={src=src,action=action,started=GetGameTimer(),variety=math.max(1,math.min(#cfg.varieties,tonumber(variety) or 1))}
 return true
end)
lib.callback.register('wonkys_landscaping:garden:cancel',function(src,id) id=tonumber(id);if locks[id] and locks[id].src==src then locks[id]=nil end return true end)
lib.callback.register('wonkys_landscaping:garden:finish',function(src,id,action)
 id=tonumber(id);local a=actions[action];local bed=id and beds[id];local lock=id and locks[id]
 if not a or not bed or not lock or lock.src~=src or lock.action~=action or bed.stage~=a.from then return false,'Task no longer available' end
 if GetGameTimer()-lock.started<a.duration-500 then return false,'Finish the animation first' end
 locks[id]=nil
 if not LandscapingAuthorized(src) or not near(src,id) then return false,'You left the flower bed' end
 if action=='plant' then
  if not exports.ox_inventory:RemoveItem(src,cfg.seedItem,1) then return false,'Flower seeds missing' end
  bed.variety=lock.variety
 elseif action=='harvest' then
  if not exports.ox_inventory:CanCarryItem(src,cfg.harvestItem,1) or not exports.ox_inventory:AddItem(src,cfg.harvestItem,1) then return false,'Cannot carry harvested flowers' end
  if LandscapingContractActivity then LandscapingContractActivity(src,'garden','garden_'..id) end
 end
 bed.stage=a.to;bed.readyAt=action=='water' and (os.time()+math.max(60,tonumber(cfg.growSeconds) or 1800)) or 0
 save();sync(-1)
 return true,({dig='Soil prepared',plant='Seeds planted',water='Watered - growing',prune='Flowers pruned',harvest='Flower bundle harvested'})[action]
end)
CreateThread(function() while true do Wait(15000);if advance() then sync(-1) end end end)
RegisterCommand('landscape_growplants',function(src)
 if src~=0 and not IsPlayerAceAllowed(src,'command.landscape_growplants') then return end
 for _,v in ipairs(beds) do if v.stage==3 then v.stage=4;v.readyAt=0 end end
 save();sync(-1)
end,false)
AddEventHandler('playerDropped',function() local src=source;for id,v in pairs(locks) do if v.src==src then locks[id]=nil end end end)
save()
