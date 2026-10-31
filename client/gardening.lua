local cfg=Config.Gardening
if not cfg or not cfg.enabled then return end
local beds,objects={},{}
local actions={[0]='dig',[1]='plant',[2]='water',[4]='prune',[5]='harvest'}
local labels={dig='Dig flower bed',plant='Plant flower seeds',water='Water seedlings',prune='Prune grown flowers',harvest='Harvest flowers'}
local function model(name) local hash=joaat(name);RequestModel(hash);local untilTime=GetGameTimer()+4000 while not HasModelLoaded(hash) and GetGameTimer()<untilTime do Wait(25) end return HasModelLoaded(hash) and hash or nil end
local function clearObjects() for _,group in pairs(objects) do for _,obj in ipairs(group) do if obj and DoesEntityExist(obj) then DeleteEntity(obj) end end end objects={} end
local function spawnProp(name,x,y,z,heading)
 local hash=model(name)
 if not hash then return nil end
 local obj=CreateObjectNoOffset(hash,x,y,z,false,false,false)
 if obj==0 then return nil end
 SetEntityHeading(obj,heading or 0.0)
 SetEntityCollision(obj,false,false)
 FreezeEntityPosition(obj,true)
 SetModelAsNoLongerNeeded(hash)
 return obj
end
local function refresh()
 clearObjects()
 for id,p in ipairs(cfg.plots) do
  local bed=beds[id] or {stage=0,variety=1}
  local stage=tonumber(bed.stage) or 0
  local group={}
  -- The empty planter becomes a soil-filled planter once the player digs.
  group[#group+1]=spawnProp(stage==0 and cfg.boxEmpty or cfg.boxSoil,p.x,p.y,p.z+(cfg.boxOffsetZ or 0.0), (p.w or cfg.boxHeading or 0.0))
  if stage>=2 and stage<=5 then
   local variety=cfg.varieties[tonumber(bed.variety) or 1] or cfg.varieties[1]
   -- Use small flowering pots, not the large Bzzz topiary/arch models.
   -- Show one young plant until watering, then three when grown.
   local count=(stage==2 or stage==3) and 1 or 3
   for n=1,count do
    local offset=(n-(count+1)/2)*(cfg.plantSpacing or 0.34)
    local radians=math.rad(p.w or cfg.boxHeading or 0.0)
    local x=p.x+offset*math.cos(radians)
    local y=p.y+offset*math.sin(radians)
    group[#group+1]=spawnProp(variety,x,y,p.z+(cfg.boxOffsetZ or 0.0)+(cfg.plantOffsetZ or 0.12),(p.w or cfg.boxHeading or 0.0))
   end
  end
  objects[id]=group
 end
end
RegisterNetEvent('wonkys_landscaping:garden:sync',function(state) beds=state or {};refresh() end)
local function work(id,action)
 local choice=1
 if action=='plant' then
  local opts={} for i,name in ipairs(cfg.varieties) do opts[#opts+1]={value=i,label='Flower variety '..i} end
  local input=lib.inputDialog('Choose flower seeds',{{type='select',label='Variety',options=opts,required=true}})
  if not input then return end;choice=tonumber(input[1]) or 1
 end
 local ok,msg=lib.callback.await('wonkys_landscaping:garden:begin',false,id,action,choice)
 if not ok then lib.notify({description=msg or 'Cannot start',type='error'});return end
 local prop,anim
 if action=='dig' then prop={model='bzzz_garden_shovel_a',bone=57005,pos=vec3(0.14,0.08,0.01),rot=vec3(25.0,310.0,140.0)};anim={dict='amb@world_human_gardener_plant@female@base',clip='base_female'}
 elseif action=='water' then prop={model='bzzz_garden_hose_b',bone=57005,pos=vec3(0.12,0.04,-0.01),rot=vec3(-80.0,90.0,-10.0)};anim={dict='anim@amb@business@weed@weed_inspecting_lo_med_hi@',clip='weed_spraybottle_crouch_spraying_02_inspector'}
 elseif action=='plant' then prop={model='bzzz_garden_seeds_a',bone=18905,pos=vec3(0.12,0.0,0.05),rot=vec3(-100.0,-35.0,0.0)};anim={dict='amb@world_human_gardener_plant@female@base',clip='base_female'}
 else anim={dict='amb@world_human_gardener_plant@female@base',clip='base_female'} end
 local durations={dig=6000,plant=4500,water=5000,prune=5000,harvest=4500}
 local success=lib.progressBar({duration=durations[action],label=labels[action],canCancel=true,useWhileDead=false,disable={move=true,car=true,combat=true},anim=anim,prop=prop})
 if not success then lib.callback.await('wonkys_landscaping:garden:cancel',false,id);return end
 local done,info=lib.callback.await('wonkys_landscaping:garden:finish',false,id,action)
 lib.notify({description=info or (done and 'Complete' or 'Could not complete'),type=done and 'success' or 'error'})
end
CreateThread(function()
 for id,p in ipairs(cfg.plots) do
  exports.ox_target:addSphereZone({coords=vec3(p.x,p.y,p.z),radius=0.72,debug=false,options={{name='wonky_garden_'..id,icon='fa-solid fa-seedling',label='Gardening plot '..id,distance=2.5,onSelect=function() local bed=beds[id];local action=bed and actions[bed.stage];if action then work(id,action) else lib.notify({description='Flowers are growing. Come back later.',type='inform'}) end end}}})
 end
 TriggerServerEvent('wonkys_landscaping:garden:request')
end)
AddEventHandler('onResourceStop',function(resource) if resource==GetCurrentResourceName() then clearObjects() end end)
