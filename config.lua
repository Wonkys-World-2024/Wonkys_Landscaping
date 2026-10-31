Config = {}
Config.Debug = false
Config.CutNotifications = false -- no spam while mowing
Config.GrassRandomOffset = 0.42 -- subtle deterministic scatter (metres)
Config.GrassRandomRotation = true
Config.CutParticles = true -- play only for server-confirmed grass cuts
Config.Job = 'ambulance'
Config.RequireJob = false -- enable once job is registered in qbx_core
Config.RegrowHours = 48 -- real-world hours for cut grass to regrow
Config.SaveIntervalSeconds = 15
Config.SyncRadius = 110.0
Config.RenderRadius = 55.0
Config.CellSize = 1.6
Config.CutRadius = 2.0
Config.DeckForwardOffset = 0.9 -- GTA mower deck sits ahead of driver
Config.MaxSpeed = 13.0 -- metres per second
Config.CutIntervalMs = 450
Config.GrassModel = 'prop_veg_grass_01_a' -- candidate GTA prop; validate in-game using /landscape_propcheck
Config.EnableGrassProps = true -- visible prototype; if model unavailable, use /landscape_propcheck
Config.GrassZOffset = -0.06 -- adjust if clumps float or sink
Config.GrassMinGrowthToShow = 0.25
-- Growth stages use density and optional different GTA props; GTA props cannot be scaled with a native.
-- Stage 1 is sparse, stage 2 medium, stage 3 full coverage. Default model is known to work on this server.
Config.GrowthStages = {
    { threshold = 0.25, density = 0.35, model = 'prop_veg_grass_01_a' },
    { threshold = 0.55, density = 0.70, model = 'prop_veg_grass_01_a' },
    { threshold = 0.85, density = 1.00, model = 'prop_veg_grass_01_a' },
}
Config.GrassPropLimit = 100 -- maximum live props across all plots
-- Cutting FX is configured above (avoid duplicate overrides)
Config.ParticleDictionary = 'core'
Config.ParticleName = 'ent_sht_grass' -- candidate effect; GTA builds may differ
Config.ParticleScale = 0.13 -- much smaller than previous brown dust clouds
Config.ParticleIntervalMs = 900
Config.GrassScaleSupported = false -- GTA has no general SetEntityScale native
Config.Plots = {
    -- Golf course provisional test patch. Confirm exact ground elevation and unobstructed turf in-game before enabling visual props.
    { id = 'golf_course_test', label = 'Los Santos Golf Club Test Lawn', x = -1325.0, y = 155.0, z = 56.0, width = 16, length = 16, heading = 0.0 },
    -- NEW SITES: provisional GTA V lawn coordinates; check ground level and obstacles in-game.
    -- Each plot is deliberately modest; edit coordinates/width/length to suit your map.
    { id = 'mirror_park_lawn', label = 'Mirror Park Lawn', x = 1103.0, y = -645.0, z = 56.0, width = 12, length = 12, heading = 0.0 },
    { id = 'vinewood_garden', label = 'Vinewood Garden', x = 686.0, y = 581.0, z = 130.0, width = 12, length = 12, heading = 0.0 },
    { id = 'sandy_community', label = 'Sandy Shores Grounds', x = 1862.0, y = 3685.0, z = 33.0, width = 12, length = 12, heading = 0.0 },
    { id = 'grapeseed_grounds', label = 'Grapeseed Grounds', x = 1705.0, y = 4805.0, z = 42.0, width = 12, length = 12, heading = 0.0 }
}
Config.MowerModels = { 'mower' } -- GTA stock ride-on mower; additional verified models can be added

-- v0.9 experimental company fleet. Move depot after confirming a clear parking area.
Config.Fleet = {
    enabled = true,
    depot = vector4(-1383.79, 113.96, 54.86, 184.77), -- pickup / fleet collection point
    spawnPositions = {
        pickup = vector4(-1383.79, 113.96, 54.86, 184.77),
        trailer = vector4(-1384.4, 122.18, 55.4, 182.58),
        mower = vector4(-1385.67, 135.23, 55.76, 183.95),
    }, -- exact in-game surveyed coordinates; no automatic offsets
    vanModel = 'sandstormev',
    vehicleOptions = { {model='sandstormev',label='Sandstorm EV'} }, -- add verified tow-capable vehicles here
    trailerModel = 'cotrailer',
    mowerModel = 'mower',
    spawnOffset = 7.0,
    loadDistance = 8.0,
    maxLoadSpeed = 0.7,
    -- Bounds in trailer-local metres; adjust if the mower cannot be secured while visibly on the deck.
    deckHalfWidth = 1.65,
    deckFrontY = 1.0,
    deckRearY = -4.8,
    deckMinZ = -0.2,
    deckMaxZ = 2.5,
}

-- v0.15 paid mowing contract. Additional plots can be added after surveying their turf.
Config.Contracts = {
    completionFraction = 0.90,
    jobs = {
        {id='golf_leaf_cleanup',type='leaves',label='Golf Club Leaf Clearance',description='Blow and rake all five leaf sites, then collect their bags.',payment=425,required=5},
        {id='golf_garden_beds',type='garden',label='Golf Club Flower Growing',description='Grow, prune and harvest flowers from 3 separate wooden garden beds.',payment=425,required=3},
        {id='golf_garden_beds_large',type='garden',label='Golf Club Garden Restoration',description='Grow, prune and harvest flowers from all 6 wooden garden beds.',payment=800,required=6},
        {id='golf_flower_harvest',type='flowers',label='Golf Club Flower Harvest',description='Collect flowers from all six flowering garden arches.',payment=360,required=6},
        {id='golf_hedge_trimming',type='hedges',label='Golf Club Hedge Maintenance',description='Trim all six garden arches after collecting their flowers.',payment=540,required=6},
        {id='golf_topiary_shaping',type='topiary',label='Golf Club Topiary Shaping',description='Collect flowers, then shape the three decorative topiary bushes at the golf club.',payment=475,required=3},
        {id='golf_topiary_restoration',type='topiary',label='Golf Club Topiary Restoration',description='Trim all six decorative topiary sites after collecting their flowers.',payment=875,required=6},
        {id='tree_cutting_small',type='trees',label='Forestry Tree Felling',description='Safely fell 3 designated forestry trees at either logging hut. Chop and collect timber separately.',payment=375,required=3},
        {id='tree_cutting_large',type='trees',label='Woodland Clearance Contract',description='Fell 6 designated forestry trees across the forestry sites. Timber collection and delivery are separate.',payment=825,required=6},
        {id='heavy_timber_4',type='heavy_logging',label='Local Timber Haul (trflat)',description='Deliver 4 timber logs to Paleto sawmill using the trflat.',payment=450,required=4},
        {id='heavy_timber_8',type='heavy_logging',label='Paleto Sawmill Supply',description='Deliver 8 timber logs to Paleto sawmill using the trflat.',payment=850,required=8},
        {id='heavy_timber_12',type='heavy_logging',label='Commercial Timber Transport',description='Deliver 12 timber logs to Paleto sawmill using the trflat.',payment=1350,required=12},
        {id='logging_small_delivery',type='logging',label='Forestry Timber Delivery',description='Deliver 3 timber logs on your cotrailer to Wonky’s Waste Depot. Earn a $300 contract bonus plus normal timber sale value.',payment=300,required=3},
        {id='logging_large_delivery',type='logging',label='Commercial Timber Haul',description='Deliver 6 timber logs on your cotrailer to Wonky’s Waste Depot. Earn a $650 contract bonus plus normal timber sale value.',payment=650,required=6},
        {id='golf_course_test', label='Golf Club Grounds Maintenance', description='Mow the designated practice lawn at Los Santos Golf Club.', payment=650},
        {id='mirror_park_lawn', label='Mirror Park Garden Care', description='Residential mowing contract in Mirror Park (provisional site).', payment=350},
        {id='vinewood_garden', label='Vinewood Estate Maintenance', description='Maintain a Vinewood garden (provisional site).', payment=525},
        {id='sandy_community', label='Sandy Shores Community Grounds', description='Cut overgrown grounds in Sandy Shores (provisional site).', payment=425},
        {id='grapeseed_grounds', label='Grapeseed Rural Maintenance', description='Mow rural grounds in Grapeseed (provisional site).', payment=475},
    }
}

Config.Headquarters = {
    blip = vector3(-1360.32,129.34,56.44),
    ped = vector4(-1366.96,118.57,56.43,19.33),
    model = 's_m_m_gardener_01',
    tabletItem = 'landscape_tablet',
}

-- Strimmer retired. Old inventory item is removed on shift finish for compatibility.

-- v0.21.1 dedicated recycling points; leaf bags become obtainable in the next leaf-collection update.
Config.Recycling = {
    grass = { coords = vector4(-355.1, -1544.8, 27.72, 95.38), item = 'landscape_grass_clippings', price = 25 },
    leaves = { coords = vector4(-355.45, -1547.66, 27.72, 87.41), item = 'landscape_leaf_bag', price = 35 },
    flowers = { coords = vector4(-355.45, -1547.66, 27.72, 87.41), item = 'landscape_flowers', price = 45 },
}

Config.Cargo = {capacity=24, recycleRadius=18.0}

-- Test leaf piles on golf-club grounds; relocate after in-game placement check.
Config.LeafSites = {
    vector3(-1346.76, 158.69, 57.59),
    vector3(-1344.76, 158.69, 57.59),
    vector3(-1348.76, 158.69, 57.59),
    vector3(-1346.76, 160.69, 57.59),
    vector3(-1346.76, 156.69, 57.59),
}

-- v0.22.1 Bzzz garden bush prototype. Two visual states from the Bzzz garden pack.
-- The five test placements are close to the golf-club leaf site; move them after inspecting in-game.
Config.Hedges = {
    groundOffset = -0.03, -- model-origin height adjustment; do not use bounding box dimensions
    -- All 13 Bzzz plant shapes have a plain and a flowered variant.
    -- Existing sites retain their original arch models unless changed below.
    -- Set model='e' (for example) on any site to use that shape.
    modelCatalog = {
        a='Archway', b='Circular hedge', c='Cone topiary', d='Small hedge',
        e='Rectangular hedge', f='Corner hedge', g='Long hedge',
        h='Round planter', i='Round topiary', j='Tall hedge wall',
        k='Stepped corner', l='Hedge sphere', m='Sculpted shrub'
    },
    defaultShape = 'a',
    siteShapes = {[1]='e',[2]='l',[3]='c',[4]='m',[5]='b',[6]='g'}, -- mixed garden shapes; edit to taste
    overgrownModel = 'bzzz_garden_plant_a',
    trimmedModel = 'bzzz_garden_plant_a2',
    sites = {
        -- First two positions supplied and tested in-game.
        vector4(-1359.66, 168.69, 56.96, 267.47),
        vector4(-1359.50, 165.91, 56.82, 269.34),
        -- Continue the same line at 2.8m spacing, following the measured slope.
        vector4(-1359.34, 163.13, 56.68, 269.34),
        vector4(-1359.18, 160.35, 56.54, 269.34),
        vector4(-1359.02, 157.57, 56.40, 269.34),
        vector4(-1358.86, 154.79, 56.26, 269.34),
    }
}

-- v0.24.0 recycling depot (provisional NPC position; adjust in-game if obstructed)
Config.WasteDepot = {
    enabled = true,
    clerk = vector4(-351.51, -1572.94, 25.57, 350.92),
    clerkModel = 's_m_y_garbage',
    bay = vector3(-350.84, -1558.71, 24.91),
    markerRadius = 3.2,
    showBlip = true,
}

-- Logging test: positions are PROVISIONAL, not surveyed tree positions.
-- Move each test tree to a clear spot near its hut after checking in-game.
Config.Logging = {
    model='prop_tree_pine_01',
    fallDuration=4500,
    cutDuration=9000,
    chopDuration=7500,
    logItem='landscape_timber_log',
    -- Eight trees per hut. Only the first position at each hut has been tested.
    -- New XY locations are provisional; the client probes terrain Z for new trees.
    sites={
        vector4(-379.74,2600.98,87.16,90.0), -- Hut 1 original
        vector4(-392.74,2605.98,87.16,120.0),
        vector4(-396.74,2596.98,87.16,55.0),
        vector4(-387.74,2588.98,87.16,180.0),
        vector4(-374.74,2587.98,87.16,20.0),
        vector4(-366.74,2597.98,87.16,95.0),
        vector4(-369.74,2610.98,87.16,150.0),
        vector4(-384.74,2615.98,87.16,240.0),
        vector4(310.03,4346.31,48.55,90.0), -- Hut 2 original
        vector4(296.03,4351.31,48.55,120.0),
        vector4(292.03,4340.31,48.55,55.0),
        vector4(300.03,4332.31,48.55,180.0),
        vector4(314.03,4331.31,48.55,20.0),
        vector4(324.03,4340.31,48.55,95.0),
        vector4(322.03,4355.31,48.55,150.0),
        vector4(306.03,4361.31,48.55,240.0),
    },
    regrowHours=48,
}

Config.LoggingDuty = {
    vector4(-387.74,2600.98,89.16,0.0),
    vector4(302.03,4346.31,50.55,0.0),
}

-- v0.25.6 logging rewards and Bzzz log pile
Config.Logging.logsPerTree = 3
Config.Logging.leavesPerTree = 2
Config.Logging.leavesItem = 'landscape_leaf_bag'
Config.Logging.logPileModel = 'bzzz_lumberjack_wood_pack_2a_static'
Config.Logging.logPileOffset = vector3(1.8, 0.0, 0.0) -- visual only, adjust if needed

-- v0.26.0: Timber sales at the existing waste depot clerk.
Config.Logging.timberSalePrice = 90

-- v0.26.1: Separate timber rack; does not reduce the existing 24 waste-bag slots.
Config.Cargo.timberCapacity = 6
Config.Cargo.timberModel = 'prop_log_01' -- GTA fallback; Bzzz candidate is attempted first
Config.Cargo.timberSalePrice = Config.Logging.timberSalePrice or 90

-- v0.26.2: timber positions on cotrailer (local trailer offsets in metres).
-- Existing grass/leaf bag positions and mower attachment are unchanged.
Config.Cargo.timberLayout = {
    sideOffset = 0.48, -- two log columns inside trailer sides
    startY = -0.10,    -- begin behind the front bag area
    rowSpacing = 0.62,
    height = 0.20,
    rowLift = 0.00,
    heading = 0.0,     -- lengthways; previous sideways 90 degrees removed
}

-- v0.26.5: XP earned once per server-verified pickup (not per inventory item).
Config.Logging.xpTimberPickup = 30
Config.Logging.xpLeafPickup = 15

-- v0.26.6: Logging-hut fleet pickup. The supplied coordinate is the pickup position.
-- The trailer bay is offset sideways to avoid spawning the trailer inside the truck.
Config.Fleet.loggingDepot = vector4(-427.3, 2609.17, 80.34, 24.9)
Config.Fleet.loggingSpawnPositions = {
    pickup = vector4(-432.17, 2627.42, 75.1, 24.8),
    trailer = vector4(-427.28, 2615.38, 79.08, 22.8),
}

-- v0.27.0: Six persistent gardening beds near the golf clubhouse.
Config.Gardening = { enabled=true, centre = vector3(-1370.0, 148.7, 56.00),
  growSeconds=1800, waterRequired=true, seedItem='landscape_flower_seeds', harvestItem='landscape_flowers',
  plots={
    vector4(-1370.94, 148.61, 56.00, 271.94),vector4(-1373.25, 148.46, 56.00, 271.94),vector4(-1375.62, 148.32, 56.00, 271.94),
    vector4(-1364.4, 149.01, 56.00, 271.94),vector4(-1366.04, 148.84, 56.00, 271.94),vector4(-1367.93, 148.81, 56.00, 271.94)
  },
  varieties={'bzzz_garden_pot_e3','bzzz_garden_pot_f3','bzzz_garden_pot_d3'},
  boxEmpty='bzzz_garden_box_a', boxSoil='bzzz_garden_box_a2',
  -- Pots are small flowering plants; adjust offsets after an in-game fit check.
  plantOffsetZ=0.12, plantSpacing=0.34, boxHeading=0.0, boxOffsetZ=-0.10
}

-- Commercial logging. Sawmill coordinates are a STARTING POINT: verify bay in-game.
Config.HeavyLogging = {
    truckModel='phantom', trailerModel='trflat', capacity=18,
    -- Fixed heavy-rig spawn positions; independent of the small cotrailer fleet.
    spawnPositions = {
        truck = vector4(-432.17, 2627.42, 75.1, 24.8),
        trailer = vector4(-427.28, 2615.38, 79.08, 22.8),
    },
    logModel=Config.Logging.logPileModel or 'bzzz_lumberjack_wood_pack_2a_static',
    deckOffsetZ=0.59, layerSpacing=0.45,
    sawmill=vector3(-552.0,5348.0,74.0), deliveryRadius=32.0,
    pricePerLog=90,
}

-- Flower crate cargo: one harvested flower bundle fills one crate.
Config.Cargo.flowerCrateCapacity = 12
Config.Cargo.flowerCratePrice = 35 -- bank payment per delivered crate at existing waste depot
