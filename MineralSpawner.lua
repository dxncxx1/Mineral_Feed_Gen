-- MineralSpawner.lua
-- Simple mineral feed pallet spawner specialization

MineralSpawner = {}

function MineralSpawner.prerequisitesPresent(specializations)
    return true
end

function MineralSpawner.initSpecialization()
    local schema = Placeable.xmlSchema
    schema:register(XMLValueType.VECTOR_3, "placeable.mineralSpawner.spawnPoint", "Spawn point for pallets")
    schema:register(XMLValueType.STRING, "placeable.mineralSpawner.fillType", "Fill type to spawn", "MINERAL_FEED")
    schema:register(XMLValueType.INT, "placeable.mineralSpawner.palletCapacity", "Capacity per pallet", 1000)
    schema:register(XMLValueType.INT, "placeable.mineralSpawner.spawnInterval", "Seconds between spawns", 150)
    schema:register(XMLValueType.INT, "placeable.mineralSpawner.costPerPallet", "Cost per pallet", 10)
    schema:register(XMLValueType.BOOL, "placeable.mineralSpawner.autoStart", "Auto start spawning", true)
end

function MineralSpawner.registerOverwrittenFunctions(placeableType)
    -- No overwritten functions needed
end

function MineralSpawner.registerFunctions(placeableType)
    SpecializationUtil.registerFunction(placeableType, "startSpawning", MineralSpawner.startSpawning)
    SpecializationUtil.registerFunction(placeableType, "stopSpawning", MineralSpawner.stopSpawning)
    SpecializationUtil.registerFunction(placeableType, "spawnPallet", MineralSpawner.spawnPallet)
    SpecializationUtil.registerFunction(placeableType, "updateSpawner", MineralSpawner.updateSpawner)
end

function MineralSpawner.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onLoad", MineralSpawner)
    SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", MineralSpawner)
    SpecializationUtil.registerEventListener(placeableType, "onDelete", MineralSpawner)
    SpecializationUtil.registerEventListener(placeableType, "onUpdate", MineralSpawner)
end

function MineralSpawner:onLoad(savegame)
    local spec = self.spec_mineralSpawner
    
    -- Load configuration
    local xmlFile = self.xmlFile
    spec.spawnPoint = xmlFile:getValue("placeable.mineralSpawner.spawnPoint", {0, 1, 5})
    spec.fillTypeName = xmlFile:getValue("placeable.mineralSpawner.fillType", "MINERAL_FEED")
    spec.palletCapacity = xmlFile:getValue("placeable.mineralSpawner.palletCapacity", 1000)
    spec.spawnInterval = xmlFile:getValue("placeable.mineralSpawner.spawnInterval", 150) * 1000 -- Convert to ms
    spec.costPerPallet = xmlFile:getValue("placeable.mineralSpawner.costPerPallet", 10)
    spec.autoStart = xmlFile:getValue("placeable.mineralSpawner.autoStart", true)
    
    -- Initialize state
    spec.isSpawning = false
    spec.nextSpawnTime = 0
    spec.totalSpawned = 0
    
    -- Get fill type index
    spec.fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(spec.fillTypeName)
    if spec.fillTypeIndex == nil then
        print("ERROR: MineralSpawner - Invalid fill type: " .. tostring(spec.fillTypeName))
        spec.fillTypeIndex = FillType.MINERAL_FEED
    end
    
    print("MineralSpawner: Loaded successfully")
    print("  - Fill Type: " .. spec.fillTypeName .. " (Index: " .. tostring(spec.fillTypeIndex) .. ")")
    print("  - Spawn Point: " .. table.concat(spec.spawnPoint, ", "))
    print("  - Interval: " .. (spec.spawnInterval / 1000) .. " seconds")
    print("  - Cost: $" .. spec.costPerPallet .. " per pallet")
end

function MineralSpawner:onFinalizePlacement()
    local spec = self.spec_mineralSpawner
    
    if spec.autoStart then
        print("MineralSpawner: Auto-starting in 3 seconds...")
        spec.nextSpawnTime = g_currentMission.time + 3000 -- Start after 3 seconds
        spec.isSpawning = true
    end
end

function MineralSpawner:onDelete()
    local spec = self.spec_mineralSpawner
    spec.isSpawning = false
    print("MineralSpawner: Deleted - Total pallets spawned: " .. spec.totalSpawned)
end

function MineralSpawner:onUpdate(dt)
    if self.isServer then
        self:updateSpawner(dt)
    end
end

function MineralSpawner:updateSpawner(dt)
    local spec = self.spec_mineralSpawner
    
    if spec.isSpawning and g_currentMission.time >= spec.nextSpawnTime then
        self:spawnPallet()
        spec.nextSpawnTime = g_currentMission.time + spec.spawnInterval
    end
end

function MineralSpawner:spawnPallet()
    local spec = self.spec_mineralSpawner
    
    -- Calculate world position
    local x, y, z = localToWorld(self.rootNode, spec.spawnPoint[1], spec.spawnPoint[2], spec.spawnPoint[3])
    
    -- Charge the player
    if g_currentMission.missionInfo.economicDifficulty > 1 then
        g_currentMission:addMoney(-spec.costPerPallet, self:getOwnerFarmId(), MoneyType.PURCHASE_SUPPLIES, true)
        print("MineralSpawner: Charged $" .. spec.costPerPallet .. " for pallet")
    end
    
    -- Spawn the pallet
    local palletFilename = g_fillTypeManager:getFillTypeByIndex(spec.fillTypeIndex).palletFilename
    if palletFilename ~= nil then
        local pallet = g_currentMission:loadVehicle(palletFilename, x, y, z, 0, 0, 0, true, 0, Property.NONE, self:getOwnerFarmId(), nil, nil)
        if pallet ~= nil then
            pallet:setFillUnitFillLevelToCapacity(1)
            spec.totalSpawned = spec.totalSpawned + 1
            print("MineralSpawner: Spawned pallet #" .. spec.totalSpawned .. " at " .. string.format("%.1f, %.1f, %.1f", x, y, z))
        else
            print("ERROR: MineralSpawner - Failed to spawn pallet")
        end
    else
        print("ERROR: MineralSpawner - No pallet filename for fill type: " .. spec.fillTypeName)
    end
end

function MineralSpawner:startSpawning()
    local spec = self.spec_mineralSpawner
    if not spec.isSpawning then
        spec.isSpawning = true
        spec.nextSpawnTime = g_currentMission.time + spec.spawnInterval
        print("MineralSpawner: Started spawning")
    end
end

function MineralSpawner:stopSpawning()
    local spec = self.spec_mineralSpawner
    spec.isSpawning = false
    print("MineralSpawner: Stopped spawning")
end 