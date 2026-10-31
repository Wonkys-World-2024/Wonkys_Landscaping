-- Local-only prop preview: no gardening state is modified.
local groups = {box={}, pot={}, plant={}}
for _, suffix in ipairs({'a','a2','b','b2'}) do groups.box[#groups.box+1]='bzzz_garden_box_'..suffix end
for c=string.byte('a'),string.byte('f') do
 for n=1,3 do groups.pot[#groups.pot+1]=('bzzz_garden_pot_%s%d'):format(string.char(c),n) end
end
for c=string.byte('a'),string.byte('m') do
 for _,suffix in ipairs({'','2'}) do groups.plant[#groups.plant+1]='bzzz_garden_plant_'..string.char(c)..suffix end
end
local category='box'
local indices={box=1,pot=1,plant=1}
local entity=nil
local function clear()
 if entity and DoesEntityExist(entity) then DeleteEntity(entity) end
 entity=nil
end
local function notify(msg, typ)
 lib.notify({title='Bzzz garden prop preview',description=msg,type=typ or 'inform',duration=8500})
end
local function show()
 clear()
 local list=groups[category]
 local i=indices[category]
 local name=list[i]
 local hash=joaat(name)
 if not IsModelInCdimage(hash) then notify(name..' is unavailable','error') return end
 RequestModel(hash)
 local timeout=GetGameTimer()+5000
 while not HasModelLoaded(hash) and GetGameTimer()<timeout do Wait(50) end
 if not HasModelLoaded(hash) then notify('Could not load '..name,'error') return end
 local ped=PlayerPedId()
 local pos=GetOffsetFromEntityInWorldCoords(ped,0.0,2.7,0.0)
 local found,z=GetGroundZFor_3dCoord(pos.x,pos.y,pos.z+3.0,false)
 entity=CreateObjectNoOffset(hash,pos.x,pos.y,(found and z or pos.z-1.0),false,false,false)
 if entity and entity~=0 and DoesEntityExist(entity) then
  SetEntityCollision(entity,false,false)
  PlaceObjectOnGroundProperly(entity)
  FreezeEntityPosition(entity,true)
  notify(('%s %d/%d: %s | /gardenpreviewnext | /gardenpreviewprev | /gardenpreviewstop'):format(category,i,#list,name))
 else entity=nil notify('Could not spawn '..name,'error') end
 SetModelAsNoLongerNeeded(hash)
end
RegisterCommand('gardenpreview',function(_,args)
 local requested=args[1] and string.lower(args[1]) or nil
 if requested and groups[requested] then category=requested
 elseif requested then
  local number=tonumber(requested)
  if number then indices[category]=math.max(1,math.min(#groups[category],math.floor(number)))
  else notify('Usage: /gardenpreview box | pot | plant [number]','error') return end
 end
 if args[2] and tonumber(args[2]) then indices[category]=math.max(1,math.min(#groups[category],math.floor(tonumber(args[2])))) end
 show()
end,false)
RegisterCommand('gardenpreviewnext',function() indices[category]=indices[category]%#groups[category]+1 show() end,false)
RegisterCommand('gardenpreviewprev',function() indices[category]=(indices[category]-2)%#groups[category]+1 show() end,false)
RegisterCommand('gardenpreviewstop',function() clear() notify('Preview removed','success') end,false)
AddEventHandler('onResourceStop',function(resource) if resource==GetCurrentResourceName() then clear() end end)
