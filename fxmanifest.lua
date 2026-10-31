fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'Wonkys_Landscaping'
author 'Wonky’s World'
description 'Wonky’s Landscaping - integrated jobs, gardening, cargo and heavy logging v0.29.2 security review'
shared_scripts {'@ox_lib/init.lua','config.lua'}
client_scripts {'client/main.lua'}
server_scripts {'@oxmysql/lib/MySQL.lua','server/security.lua','server/progression.lua','server/contracts.lua','server/main.lua'}
dependencies {'ox_lib','oxmysql','ox_target','ox_inventory'}
client_scripts {'client/fleet.lua','client/hq.lua','client/equipment.lua'}
server_scripts {'server/shift.lua','server/fleet.lua','server/equipment.lua'}

ui_page 'web/index.html'
files {'web/index.html','web/style.css','web/app.js','web/wonkys_landscaping_logo.png','web/strimmer_loop.wav'}

client_scripts {'client/waste.lua'}
server_scripts {'server/waste.lua'}

client_scripts {'client/cargo.lua'}
server_scripts {'server/cargo.lua'}

client_scripts {'client/leaves.lua'}
server_scripts {'server/leaves.lua'}

-- Hedge trimming
client_script 'client/hedges.lua'
server_script 'server/hedges.lua'

client_script 'client/depot.lua'

client_script 'client/logging.lua'
server_script 'server/logging.lua'

client_script 'client/logging_duty.lua'

-- Bzzz lumberjack prop archetypes (external dependency)
-- Install the creator's Bzzz resource separately; no third-party YTYP is bundled.

server_script 'server/timber_sales.lua'

client_script 'client/forestry_xp.lua'

client_script 'client/contract_blips.lua'

-- Gardening beds (external Bzzz garden assets)
client_script 'client/gardening.lua'
server_script 'server/gardening.lua'
-- Install the creator's Bzzz garden pack separately; no third-party YTYP is bundled.

-- Optional local flower model preview commands
client_script 'client/garden_prop_preview.lua'

client_script 'client/heavy_logging.lua'
server_script 'server/heavy_logging.lua'
