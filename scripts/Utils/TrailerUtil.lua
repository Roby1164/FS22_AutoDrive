function AutoDrive.isUnloadFillLevelReached(object, fillFreeCapacity, fillCapacity)
    if object == nil then
        Logging.error("[AD] AutoDrive.isUnloadFillLevelReached object == nil")
        return  false
    end
    local rootVehicle = object:getRootVehicle()
    if rootVehicle == nil then
        Logging.error("[AD] AutoDrive.isUnloadFillLevelReached object %s rootVehicle == nil", tostring(object))
        return  false
    end
    return (fillFreeCapacity / math.max(fillCapacity, 0.0001)) <= 1 - (AutoDrive.getSetting("unloadFillLevel", rootVehicle) * 0.999)
end

-- new, all fill levels, fuel fillTypes only from 2nd unit - to be used mainly for transportation
-- consider only dischargable fillUnits
function AutoDrive.getAllFillLevels(vehicles)
    if vehicles == nil or #vehicles == 0 then
        Logging.error("[AD] AutoDrive.getAllFillLevels vehicles == nil")
        return 0, 0, false, 0
    end

    local rootVehicle = vehicles[1]:getRootVehicle()
    if rootVehicle == nil then
        Logging.error("[AD] AutoDrive.getAllFillLevels rootVehicle == nil")
        return 0, 0, false, 0
    end

    local fillLevel, fillCapacity, fillFreeCapacity = 0, 0, 0
    local vehicleFillLevel, vehicleFillCapacity, vehicleFillFreeCapacity = 0, 0, 0
    local hasAL = false

    for _, vehicle in ipairs(vehicles) do
        hasAL = hasAL or AutoDrive:hasAL(vehicle)
    end

    for index, vehicle in ipairs(vehicles) do

        if hasAL then
            -- if AutoLoad is detected, use only AL fill levels
            vehicleFillLevel, vehicleFillCapacity, _, vehicleFillFreeCapacity = AutoDrive:getALObjectFillLevels(vehicle)
        else
            -- if index == 1 then
                -- do not consider fuel from 1st vehicle
                -- vehicleFillLevel, vehicleFillCapacity, _, vehicleFillFreeCapacity = AutoDrive.getObjectNonFuelFillLevels(vehicle)
            -- else
                vehicleFillLevel, vehicleFillCapacity, _, vehicleFillFreeCapacity = AutoDrive.getObjectFillLevels(vehicle)
            -- end
        end
        
        fillLevel    = fillLevel    + vehicleFillLevel
        fillCapacity = fillCapacity + vehicleFillCapacity
        fillFreeCapacity = fillFreeCapacity + vehicleFillFreeCapacity
    end
    local filledToUnload = AutoDrive.isUnloadFillLevelReached(rootVehicle, fillFreeCapacity, fillCapacity)
    return fillLevel, fillCapacity, filledToUnload, fillFreeCapacity
end

-- new - currently not used
function AutoDrive.getAllNonFuelFillLevels(vehicles)
    if vehicles == nil or #vehicles == 0 then
        Logging.error("[AD] AutoDrive.getAllNonFuelFillLevels vehicles == nil")
        return 0, 0, false, 0
    end

    local rootVehicle = vehicles[1]:getRootVehicle()
    if rootVehicle == nil then
        Logging.error("[AD] AutoDrive.getAllNonFuelFillLevels rootVehicle == nil")
        return 0, 0, false, 0
    end

    local fillLevel, fillCapacity, fillFreeCapacity = 0, 0, 0

    for index, vehicle in ipairs(vehicles) do

        local vehicleFillLevel, vehicleFillCapacity, _, vehicleFillFreeCapacity = AutoDrive.getObjectNonFuelFillLevels(vehicle)
        fillLevel    = fillLevel    + vehicleFillLevel
        fillCapacity = fillCapacity + vehicleFillCapacity
        fillFreeCapacity = fillFreeCapacity + vehicleFillFreeCapacity
    end
    local filledToUnload = AutoDrive.isUnloadFillLevelReached(rootVehicle, fillFreeCapacity, fillCapacity)
    return fillLevel, fillCapacity, filledToUnload, fillFreeCapacity
end

-- new - currently not used
-- return free capacity of all fillUnits considering the mass game setting
function AutoDrive.getFreeCapacity(object)
    if object == nil then
        Logging.error("[AD] AutoDrive.getFreeCapacity object == nil")
        return 0
    end

    local fillFreeCapacity = 0

    if object ~= nil and object.getFillUnits ~= nil and object.getFillUnitFreeCapacity ~= nil then
        for fillUnitIndex, _ in pairs(object:getFillUnits()) do
            fillFreeCapacity = fillFreeCapacity + object:getFillUnitFreeCapacity(fillUnitIndex)
        end
    end
    return fillFreeCapacity
end

-- new, consider all fillTypes not in AutoDrive.nonFillableFillTypes
function AutoDrive.getObjectFillLevels_old(object)
    if object == nil then
        Logging.error("[AD] AutoDrive.getObjectFillLevels object == nil")
        return 0, 0, false, 0
    end
    local rootVehicle = object:getRootVehicle()
    if rootVehicle == nil then
        Logging.error("[AD] AutoDrive.getObjectFillLevels rootVehicle == nil")
        return 0, 0, false, 0
    end

    local fillLevel, fillCapacity, fillFreeCapacity = 0, 0, 0

    if AutoDrive:hasAL(object) then
        return AutoDrive:getALObjectFillLevels(object)
    elseif object.getFillUnits ~= nil then
        for fillUnitIndex, _ in pairs(object:getFillUnits()) do

            for fillType, _ in pairs(object:getFillUnitSupportedFillTypes(fillUnitIndex)) do

                local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillType)

                if not table.contains(AutoDrive.nonFillableFillTypes, fillTypeName) then
                    local unitFillLevel = object:getFillUnitFillLevel(fillUnitIndex)
                    local unitCapacity = object:getFillUnitCapacity(fillUnitIndex)
                    local unitFreeCapacity = object:getFillUnitFreeCapacity(fillUnitIndex)
                    fillLevel    = fillLevel    + unitFillLevel
                    fillCapacity = fillCapacity + unitCapacity
                    fillFreeCapacity = fillFreeCapacity + unitFreeCapacity
                    break
                end
            end
        end
    end
    local filledToUnload = AutoDrive.isUnloadFillLevelReached(rootVehicle, fillFreeCapacity, fillCapacity)
    return fillLevel, fillCapacity, filledToUnload, fillFreeCapacity
end

-- new
-- consider only dischargable fillUnits
-- consider units which should be filled but will be consumed by unit itself, i.e. sprayer, sowingMachine
-- avoid fill levels which AD could not refill itself, i.e. additive for forage wagon / chopper, grease
function AutoDrive.getObjectFillLevels(object)
    if object == nil then
        Logging.error("[AD] AutoDrive.getObjectFillLevels object == nil")
        return 0, 0, false, 0
    end
    local rootVehicle = object:getRootVehicle()
    if rootVehicle == nil then
        Logging.error("[AD] AutoDrive.getObjectFillLevels rootVehicle == nil")
        return 0, 0, false, 0
    end

    local fillLevel, fillCapacity, fillFreeCapacity = 0, 0, 0

    local function updateFillLevels(fillUnitIndex)
        if object.getFillUnitFillLevel and object.getFillUnitCapacity and object.getFillUnitFreeCapacity then
            local unitFillLevel = object:getFillUnitFillLevel(fillUnitIndex)
            local unitCapacity = object:getFillUnitCapacity(fillUnitIndex)
            local unitFreeCapacity = object:getFillUnitFreeCapacity(fillUnitIndex)
            fillLevel    = fillLevel    + unitFillLevel
            fillCapacity = fillCapacity + unitCapacity
            fillFreeCapacity = fillFreeCapacity + unitFreeCapacity
        end
    end

    if AutoDrive:hasAL(object) then
        return AutoDrive:getALObjectFillLevels(object)
    elseif object.getFillUnits ~= nil then
        for fillUnitIndex, _ in pairs(object:getFillUnits()) do

            local spec_dischargeable = object.spec_dischargeable
            if spec_dischargeable and spec_dischargeable.dischargeNodes and #spec_dischargeable.dischargeNodes > 0 then
                for _, dischargeNode in ipairs(spec_dischargeable.dischargeNodes) do
                    if dischargeNode.fillUnitIndex and dischargeNode.fillUnitIndex > 0 and dischargeNode.fillUnitIndex == fillUnitIndex then
                        -- the fillUnit can be discharged
                        updateFillLevels(fillUnitIndex)
                        break
                    end
                end
            elseif object.spec_sowingMachine and object.getSowingMachineFillUnitIndex and object:getSowingMachineFillUnitIndex() > 0 then
                if object:getSowingMachineFillUnitIndex() == fillUnitIndex then
                    updateFillLevels(fillUnitIndex)
                end
            elseif object.spec_sprayer and object.getSprayerFillUnitIndex and object:getSprayerFillUnitIndex() > 0 then
                if object:getSprayerFillUnitIndex() == fillUnitIndex then
                    updateFillLevels(fillUnitIndex)
                end
            elseif object.spec_saltSpreader and object.spec_saltSpreader.fillUnitIndex and object.spec_saltSpreader.fillUnitIndex > 0 then
                if object.spec_saltSpreader.fillUnitIndex == fillUnitIndex then
                    updateFillLevels(fillUnitIndex)
                end
            elseif object.spec_baleLoader and object.spec_baleLoader.fillUnitIndex and object.spec_baleLoader.fillUnitIndex > 0 then
                if object.spec_baleLoader.fillUnitIndex == fillUnitIndex then
                    updateFillLevels(fillUnitIndex)
                end
            end
        end
    end
    local filledToUnload = AutoDrive.isUnloadFillLevelReached(rootVehicle, fillFreeCapacity, fillCapacity)
    return fillLevel, fillCapacity, filledToUnload, fillFreeCapacity
end

-- new - currently not used
-- new, consider all fillTypes not in AutoDrive.fuelFillTypes
function AutoDrive.getObjectNonFuelFillLevels(object)
    if object == nil then
        Logging.error("[AD] AutoDrive.getObjectNonFuelFillLevels object == nil")
        return 0, 0, false, 0
    end
    local rootVehicle = object:getRootVehicle()
    if rootVehicle == nil then
        Logging.error("[AD] AutoDrive.getObjectNonFuelFillLevels rootVehicle == nil")
        return 0, 0, false, 0
    end

    local fillLevel, fillCapacity, fillFreeCapacity = 0, 0, 0

    if object.getFillUnits ~= nil then
        for fillUnitIndex, _ in pairs(object:getFillUnits()) do

            for fillType, _ in pairs(object:getFillUnitSupportedFillTypes(fillUnitIndex)) do
                local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillType)

                if not table.contains(AutoDrive.fuelFillTypes, fillTypeName) then
                    local unitFillLevel = object:getFillUnitFillLevel(fillUnitIndex)
                    local unitCapacity = object:getFillUnitCapacity(fillUnitIndex)
                    local unitFreeCapacity = object:getFillUnitFreeCapacity(fillUnitIndex)
                    fillLevel    = fillLevel    + unitFillLevel
                    fillCapacity = fillCapacity + unitCapacity
                    fillFreeCapacity = fillFreeCapacity + unitFreeCapacity
                    break
                end
            end
        end
    end
    local filledToUnload = AutoDrive.isUnloadFillLevelReached(rootVehicle, fillFreeCapacity, fillCapacity)
    return fillLevel, fillCapacity, filledToUnload, fillFreeCapacity
end

-- new, consider game mass setting
function AutoDrive.getIsFillUnitFull(vehicle, fillUnitIndex)
    if vehicle == nil or fillUnitIndex == nil then
        -- Logging.error("[AD] AutoDrive.getIsFillUnitFull vehicles %s fillUnitIndex %s ", tostring(vehicles), tostring(fillUnitIndex))
        return false
    end
    local rootVehicle = vehicle:getRootVehicle()
    if rootVehicle == nil then
        Logging.error("[AD] AutoDrive.getIsFillUnitFull rootVehicle == nil")
        return false
    end
    local fillUnitFull = false

    if AutoDrive:hasAL(vehicle) then
        -- AutoLoad
        _, _, fillUnitFull, _ = AutoDrive:getALObjectFillLevels(vehicle)
    else
        if vehicle.getFillUnitFreeCapacity ~= nil and vehicle.getFillUnitCapacity ~= nil then
            local fillCapacity = vehicle:getFillUnitCapacity(fillUnitIndex)
            local fillFreeCapacity = vehicle:getFillUnitFreeCapacity(fillUnitIndex)
            fillUnitFull = AutoDrive.isUnloadFillLevelReached(rootVehicle, fillFreeCapacity, fillCapacity)
        else
            Logging.error("[AD] AutoDrive.getIsFillUnitFull getFillUnitFreeCapacity %s getFillUnitCapacity %s", tostring(vehicle.getFillUnitFreeCapacity), tostring(vehicle.getFillUnitCapacity))
            fillUnitFull = false
        end
    end
    return fillUnitFull
end

-- OK
function AutoDrive.getIsFillUnitEmpty(vehicle, fillUnitIndex)
    if vehicle == nil or fillUnitIndex == nil then
        Logging.error("[AD] AutoDrive.getIsFillUnitEmpty vehicle %s fillUnitIndex %s ", tostring(vehicle), tostring(fillUnitIndex))
        return false
    end

    local fillUnitEmpty = false

    if AutoDrive:hasAL(vehicle) then
        -- AutoLoad
        local fillLevel, _, _, _ = AutoDrive:getALObjectFillLevels(vehicle)
        fillUnitEmpty = fillLevel < 0.001
    elseif vehicle.getFillUnitFillLevelPercentage ~= nil then
        fillUnitEmpty = vehicle:getFillUnitFillLevelPercentage(fillUnitIndex) <= 0.001
    end

    return fillUnitEmpty
end

-- reworked, TODO: check all other trigger sources
function AutoDrive.fillTypesMatch(vehicle, fillTrigger, workTool, allowedFillTypes, fillUnit)
    if fillTrigger ~= nil then
        local typesMatch = false
        local selectedFillType = vehicle.ad.stateModule:getFillType() or FillType.UNKNOWN
        local fillUnits = workTool:getFillUnits()

        local fillTypesToCheck = {}
        if allowedFillTypes ~= nil then
            fillTypesToCheck = allowedFillTypes
        else
            if vehicle.ad.stateModule:getFillType() == nil then
                table.insert(fillTypesToCheck, FillType.UNKNOWN)
            else
                table.insert(fillTypesToCheck, vehicle.ad.stateModule:getFillType())
            end
        end

        -- go through the single fillUnits and check:
        -- does the trigger support the tools filltype ?
        -- does the trigger support the single fillUnits filltype ?
        -- does the trigger and the fillUnit match the selectedFilltype or do they ignore it ?
        for i = 1, #fillUnits do
            if fillUnit == nil or i == fillUnit then
                local selectedFillTypeIsNotInMyFillUnit = true
                local matchInThisUnit = false
                for index, _ in pairs(workTool:getFillUnitSupportedFillTypes(i)) do
                    --loadTriggers
                    -- standard silo
                    if fillTrigger.source ~= nil and fillTrigger.source.supportedFillTypes ~= nil and fillTrigger.source.supportedFillTypes[index] then
                        typesMatch = true
                        matchInThisUnit = true
                    end
                    if fillTrigger.source ~= nil and fillTrigger.source.aiSupportedFillTypes ~= nil and fillTrigger.source.aiSupportedFillTypes[index] then
                        typesMatch = true
                        matchInThisUnit = true
                    end
                    
                    --fillTriggers
                    if fillTrigger.sourceObject ~= nil then -- TODO: still available in FS22 ???
                        local fillTypes = fillTrigger.sourceObject:getFillUnitSupportedFillTypes(1)
                        if fillTypes[index] then
                            typesMatch = true
                            matchInThisUnit = true
                        end
                    end

                    for _, allowedFillType in pairs(fillTypesToCheck) do
                        if index == allowedFillType and allowedFillType ~= FillType.UNKNOWN then
                            selectedFillTypeIsNotInMyFillUnit = false
                        end
                    end
                end
                
                if matchInThisUnit and selectedFillTypeIsNotInMyFillUnit then
                    return false
                end
            end
        end

        if typesMatch then
            for _, allowedFillType in pairs(fillTypesToCheck) do
                if allowedFillType == FillType.UNKNOWN then
                    return true
                end
            end

            local isFillType = false
            for _, allowedFillType in pairs(fillTypesToCheck) do
                if fillTrigger.source then
                    for _, sourceStorage in pairs(fillTrigger.source.sourceStorages) do
                        if (sourceStorage.fillTypes ~= nil and sourceStorage.fillTypes[allowedFillType]) or 
                            (sourceStorage.fillLevels ~= nil and sourceStorage.fillLevels[allowedFillType]) then
                            return true
                        end    
                    end
                    
                    if fillTrigger.source ~= nil and fillTrigger.source.supportedFillTypes ~= nil and fillTrigger.source.supportedFillTypes[allowedFillType] then
                        return true
                    end
                    if fillTrigger.source ~= nil and fillTrigger.source.aiSupportedFillTypes ~= nil and fillTrigger.source.aiSupportedFillTypes[allowedFillType] then
                        return true
                    end
                elseif fillTrigger.sourceObject ~= nil then
                    local fillType = fillTrigger.sourceObject:getFillUnitFillType(1)
                    isFillType = (fillType == selectedFillType)
                end
            end
            return isFillType
        end
    end
    return false
end

-- new
function AutoDrive.getAllUnits(vehicle)
    if vehicle == nil then
        Logging.error("[AD] AutoDrive.getAllUnits vehicle == nil")
        return nil, 0
    end
    vehicle = vehicle:getRootVehicle()
    if vehicle ~= nil then
        if vehicle.ad == nil then
            vehicle.ad = {}
        end
        if vehicle.ad.tempVehicles == nil then
            vehicle.ad.tempVehicles = {}
        end

        vehicle.ad.tempVehicles = {}
        table.insert(vehicle.ad.tempVehicles, vehicle)  -- first is the vehicle itself

        local onlyDischargeable = false
        if vehicle.getAttachedImplements ~= nil then
            for _, implement in pairs(vehicle:getAttachedImplements()) do
                AutoDrive.getTrailersOfImplement(vehicle, implement.object, onlyDischargeable)
            end
        end

        return vehicle.ad.tempVehicles, #vehicle.ad.tempVehicles
    end
    return nil, 0
end

-- reworked, valid
function AutoDrive.getTrailersOfImplement(vehicle, attachedImplement, onlyDischargeable)
    if vehicle == nil then
        Logging.error("[AD] AutoDrive.getTrailersOfImplement vehicle == nil")
        return
    end
    if attachedImplement ~= nil then
        if (((attachedImplement.typeDesc == g_i18n:getText("typeDesc_tipper") or attachedImplement.spec_dischargeable ~= nil) or not (onlyDischargeable == true)) and attachedImplement.getFillUnits ~= nil) or AutoDrive:hasAL(attachedImplement) then
            if not (attachedImplement.typeDesc == g_i18n:getText("typeDesc_frontloaderTool") or attachedImplement.typeDesc == g_i18n:getText("typeDesc_wheelLoaderTool")) then --avoid trying to fill shovels and levellers atached
                table.insert(vehicle.ad.tempVehicles, attachedImplement)
            end
        end
        if attachedImplement.getAttachedImplements ~= nil then
            for _, implement in pairs(attachedImplement:getAttachedImplements()) do
                AutoDrive.getTrailersOfImplement(vehicle, implement.object)
            end
        end
    end
end

-- new, return list of all fillUnits of vehicle and trailers for nonFuel or nil
function AutoDrive.getAllNonFuelFillUnits_old(vehicle, initialize)
    local nonFuelFillUnits = nil
    if vehicle == nil or vehicle.ad == nil then
        return nonFuelFillUnits
    end
    if vehicle.ad.nonFuelFillUnits == nil or initialize then

        local trailers = AutoDrive.getAllUnits(vehicle)
        for trailerIndex, trailer in ipairs(trailers) do
            if trailer.getFillUnits then
                for fillUnitIndex, fillUnit in pairs(trailer:getFillUnits()) do
                    for fillType, _ in pairs(trailer:getFillUnitSupportedFillTypes(fillUnitIndex)) do

                        local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillType)
                        if not table.contains(AutoDrive.fuelFillTypes, fillTypeName) then

                            if fillUnit.exactFillRootNode then
                                if nonFuelFillUnits == nil then
                                    nonFuelFillUnits = {}
                                end
                                table.insert(nonFuelFillUnits, {fillUnit = fillUnit, node = fillUnit.exactFillRootNode, object = trailer, fillUnitIndex = fillUnitIndex})
                            elseif fillUnit.fillRootNode then
                                if nonFuelFillUnits == nil then
                                    nonFuelFillUnits = {}
                                end
                                table.insert(nonFuelFillUnits, {fillUnit = fillUnit, node = fillUnit.fillRootNode, object = trailer, fillUnitIndex = fillUnitIndex})
                            end
                            break
                        end
                    end
                end
            end
        end
        vehicle.ad.nonFuelFillUnits = nonFuelFillUnits
    end
    return vehicle.ad.nonFuelFillUnits
end

-- consider only dischargable fillUnits
function AutoDrive.getAllNonFuelFillUnits(vehicle, initialize)
    local nonFuelFillUnits = nil
    if vehicle == nil or vehicle.ad == nil then
        return nonFuelFillUnits
    end
    if vehicle.ad.nonFuelFillUnits == nil or initialize then

        local trailers = AutoDrive.getAllUnits(vehicle)
        for _, trailer in ipairs(trailers) do
            if trailer.getFillUnits then
                for fillUnitIndex, fillUnit in pairs(trailer:getFillUnits()) do

                    local spec_dischargeable = trailer.spec_dischargeable
                    if spec_dischargeable and spec_dischargeable.dischargeNodes and #spec_dischargeable.dischargeNodes > 0 then
                        for _, dischargeNode in ipairs(spec_dischargeable.dischargeNodes) do
                            if dischargeNode.fillUnitIndex and dischargeNode.fillUnitIndex > 0 and dischargeNode.fillUnitIndex == fillUnitIndex then
                                -- the fillUnit can be discharged
                                if fillUnit.exactFillRootNode then
                                    if nonFuelFillUnits == nil then
                                        nonFuelFillUnits = {}
                                    end
                                    table.insert(nonFuelFillUnits, {fillUnit = fillUnit, node = fillUnit.exactFillRootNode, object = trailer, fillUnitIndex = fillUnitIndex})
                                elseif fillUnit.fillRootNode then
                                    if nonFuelFillUnits == nil then
                                        nonFuelFillUnits = {}
                                    end
                                    table.insert(nonFuelFillUnits, {fillUnit = fillUnit, node = fillUnit.fillRootNode, object = trailer, fillUnitIndex = fillUnitIndex})
                                end
                                break
                            end
                        end
                    end
                end
            end
        end
        vehicle.ad.nonFuelFillUnits = nonFuelFillUnits
    end
    return vehicle.ad.nonFuelFillUnits
end

-- new, return next fillUnit with room to fill or RootVehicle as default
function AutoDrive.getNextFreeNonFuelFillUnit(vehicle)
    local nextFreeNonFuelFillUnit = nil
    local rootVehicle = vehicle.getRootVehicle and vehicle:getRootVehicle() -- default in case no free fill unit will be found
    local nextFreeNonFuelFillNode = rootVehicle and rootVehicle.components[1].node
    
    if vehicle == nil then
        return nextFreeNonFuelFillUnit, nextFreeNonFuelFillNode
    end
    local allNonFuelFillUnits = AutoDrive.getAllNonFuelFillUnits(vehicle)
    if allNonFuelFillUnits == nil then
        allNonFuelFillUnits = AutoDrive.getAllNonFuelFillUnits(vehicle, true)
    end

    if allNonFuelFillUnits ~= nil then
        for index, item in ipairs(allNonFuelFillUnits) do
            if item.fillUnit and item.node and item.object and item.object.getFillUnitFreeCapacity and item.fillUnitIndex then
                local freeCapacity = item.object:getFillUnitFreeCapacity(item.fillUnitIndex) -- needed to consider mass feature
                if freeCapacity > 0.1 then
                    nextFreeNonFuelFillUnit = item.fillUnit
                    nextFreeNonFuelFillNode = item.node
                    break
                end
            end
        end
    end
    return nextFreeNonFuelFillUnit, nextFreeNonFuelFillNode
end

-- ###################################################################################################

function AutoDrive.getMostBackImplementOf(vehicle)
    local mostBackImplement = nil
    local backDistance = 0

    if vehicle and vehicle.getAttachedImplements ~= nil then
        for _, implement in pairs(vehicle:getAttachedImplements()) do
            if implement ~= nil and implement.object ~= nil and implement.object ~= vehicle then
                local implementX, implementY, implementZ = getWorldTranslation(implement.object.components[1].node)
                local _, _, diffZ = worldToLocal(vehicle.components[1].node, implementX, implementY, implementZ)
                if diffZ < backDistance then
                    backDistance = diffZ
                    mostBackImplement = implement.object
                end
            end
        end
    end

    return mostBackImplement
end

function AutoDrive.getDistanceToTargetPosition(vehicle)
    -- returns the distance to load destination depending on mode
    if vehicle.ad.stateModule:getFirstMarker() == nil then
        return math.huge
    end
    local x, _, z = getWorldTranslation(vehicle.components[1].node)
    local destination = ADGraphManager:getWayPointById(vehicle.ad.stateModule:getFirstMarker().id)

    if vehicle.ad.stateModule:getMode() == AutoDrive.MODE_LOAD then
        -- in pickup mode return distance to second destination
        if vehicle.ad.stateModule:getSecondMarker() == nil then
            return math.huge
        end
        destination = ADGraphManager:getWayPointById(vehicle.ad.stateModule:getSecondMarker().id)
    end
    if destination == nil then
        return math.huge
    end
    return MathUtil.vector2Length(x - destination.x, z - destination.z)
end

function AutoDrive.getDistanceToUnloadPosition(vehicle)
    -- returns the distance to unload destination depending on mode
    local x, _, z = getWorldTranslation(vehicle.components[1].node)
    local destination = nil
    if vehicle.ad.stateModule:getMode() == AutoDrive.MODE_DELIVERTO then
        -- in deliver mode only 1st target in HUD is taken
        if vehicle.ad.stateModule:getFirstMarker() == nil then
            return math.huge
        end
        destination = ADGraphManager:getWayPointById(vehicle.ad.stateModule:getFirstMarker().id)
    elseif vehicle.ad.stateModule:getMode() == AutoDrive.MODE_LOAD then
        -- in pickup mode no unload in this mode, so return huge distance
        return math.huge
    else
        if vehicle.ad.stateModule:getSecondMarker() == nil then
            return math.huge
        end
        destination = ADGraphManager:getWayPointById(vehicle.ad.stateModule:getSecondMarker().id)
    end
    if destination == nil then
        return math.huge
    end
    local distance = MathUtil.vector2Length(x - destination.x, z - destination.z)
    local rootVehicle = vehicle:getRootVehicle()
    if rootVehicle and rootVehicle.ad and rootVehicle.ad.drivePathModule and rootVehicle.ad.drivePathModule:getIsReversing() then
        -- if revers driving sub the train length as the vehicle is the last position on the move to target
        local trainLength = AutoDrive.getTractorTrainLength(rootVehicle, true)
        distance = distance - trainLength
    end
    return distance
end

function AutoDrive.setTrailerCoverOpen(vehicle, trailers, open)
    if trailers == nil then
        return
    end
    if (AutoDrive.getSetting("autoTrailerCover", vehicle) ~= true) then
        return
    end

    for _, trailer in pairs(trailers) do
        local targetState = 0
        if open then
            targetState = 1
        end
        if trailer.spec_cover ~= nil and trailer.spec_cover.state ~= nil then
            if trailer.spec_cover.covers ~= nil then
                targetState = targetState * #trailer.spec_cover.covers
            end
            if trailer.spec_cover.state ~= targetState and trailer:getIsNextCoverStateAllowed(targetState) then
                trailer:setCoverState(targetState, false)
            end
        end
    end
end

function AutoDrive.setAugerPipeOpen(trailers, open)
    if trailers == nil then
        return
    end

    local targetState = 1
    if open then
        targetState = 2
    end
    for _, trailer in pairs(trailers) do
        if trailer.spec_pipe ~= nil and trailer.spec_pipe.currentState ~= nil and trailer.getIsPipeStateChangeAllowed ~= nil then
            if trailer.spec_pipe.currentState ~= targetState and trailer:getIsPipeStateChangeAllowed(targetState) then
                trailer:setPipeState(targetState, false)
            end
        end
    end
end

function AutoDrive.findGrainBackDoorTipSideIndex(vehicle, trailer)
    local grainDoorSideIndex = 0
    local backDoorSideIndex = 0
    if vehicle == nil or trailer == nil then
        return grainDoorSideIndex, backDoorSideIndex
    end
    if trailer.ad ~= nil and trailer.ad.grainDoorSideIndex ~= nil and trailer.ad.backDoorSideIndex ~= nil then
        return trailer.ad.grainDoorSideIndex, trailer.ad.backDoorSideIndex
    end
    local spec = trailer.spec_trailer
    if spec == nil then
        return grainDoorSideIndex, backDoorSideIndex
    end
    if trailer.ad == nil then
        trailer.ad = {}
    end
    local tipSideIndex1 = 0
    local tipSideIndex2 = 0
    local dischargeSpeed1 = math.huge
    local dischargeSpeed2 = math.huge
    local backDistance1 = math.huge
    local backDistance2 = math.huge

    for i = 1, spec.tipSideCount, 1 do
        local tipSide = spec.tipSides[i]
        trailer:setCurrentDischargeNodeIndex(tipSide.dischargeNodeIndex)
        local currentDischargeNode = trailer:getCurrentDischargeNode()
        local tx, ty, tz = getWorldTranslation(currentDischargeNode.node)
        local _, _, diffZ = worldToLocal(trailer.components[1].node, tx, ty, tz + 50)
        -- get the 2 most back doors
        if diffZ < backDistance1 then
            backDistance1 = diffZ
            dischargeSpeed1 = currentDischargeNode.emptySpeed
            tipSideIndex1 = i
        elseif diffZ < backDistance2 then
            backDistance2 = diffZ
            dischargeSpeed2 = currentDischargeNode.emptySpeed
            tipSideIndex2 = i
        end
    end
    local foundTwoBackDoors = math.abs(backDistance2 - backDistance1) < 1
    if foundTwoBackDoors then
        grainDoorSideIndex = tipSideIndex1
        backDoorSideIndex = tipSideIndex2
        if dischargeSpeed2 < dischargeSpeed1 then
            grainDoorSideIndex = tipSideIndex2
            backDoorSideIndex = tipSideIndex1
        end
    end
    trailer.ad.grainDoorSideIndex = grainDoorSideIndex
    trailer.ad.backDoorSideIndex = backDoorSideIndex
    return trailer.ad.grainDoorSideIndex, trailer.ad.backDoorSideIndex
end

function AutoDrive.findAndSetBestTipPoint(vehicle, trailer)
    local dischargeCondition = true
    if trailer.getCanDischargeToObject ~= nil and trailer.getCurrentDischargeNode ~= nil then
        dischargeCondition = (not trailer:getCanDischargeToObject(trailer:getCurrentDischargeNode()))
    end
    if (AutoDrive.getSetting("autoTipSide", vehicle) == true) and dischargeCondition and (not vehicle.ad.isLoading) and (not vehicle.ad.isUnloading) and trailer.getCurrentDischargeNode ~= nil and trailer:getCurrentDischargeNode() ~= nil then
        local spec = trailer.spec_trailer
        if spec == nil then
            return
        end
        local currentDischargeNodeIndex = trailer:getCurrentDischargeNode().index
        local grainDoorSideIndex, backDoorSideIndex = AutoDrive.findGrainBackDoorTipSideIndex(vehicle, trailer)
        if grainDoorSideIndex > 0 then
            -- grain door avaialable - select back door
            if spec.preferedTipSideIndex ~= backDoorSideIndex then
                if trailer:getCanTogglePreferdTipSide() then
                    trailer:setPreferedTipSide(backDoorSideIndex)
                    trailer:updateRaycast(trailer:getCurrentDischargeNode())
                end
            end
        end
        for i = 1, spec.tipSideCount, 1 do
            if grainDoorSideIndex ~= i then
                -- avoid grain door if back door available
                local tipSide = spec.tipSides[i]
                trailer:setCurrentDischargeNodeIndex(tipSide.dischargeNodeIndex)
                trailer:updateRaycast(trailer:getCurrentDischargeNode())
                if trailer:getCanDischargeToObject(trailer:getCurrentDischargeNode()) then
                    if trailer:getCanTogglePreferdTipSide() then
                        trailer:setPreferedTipSide(i)
                        trailer:updateRaycast(trailer:getCurrentDischargeNode())
                        AutoDrive.debugPrint(vehicle, AutoDrive.DC_VEHICLEINFO, "Changed tip side to %s", i)
                        return
                    end
                end
            end
        end
        trailer:setCurrentDischargeNodeIndex(currentDischargeNodeIndex)
    end
end

function AutoDrive.isTrailerInBunkerSiloArea(trailer, trigger)
    if trailer.getCurrentDischargeNode ~= nil then
        local dischargeNode = trailer:getCurrentDischargeNode()
        if dischargeNode ~= nil then
            local x, y, z = getWorldTranslation(dischargeNode.node)
            local tx, _, tz = x, y, z + 1
            if trigger ~= nil and trigger.bunkerSiloArea ~= nil then
                local x1, z1 = trigger.bunkerSiloArea.sx, trigger.bunkerSiloArea.sz
                local x2, z2 = trigger.bunkerSiloArea.wx, trigger.bunkerSiloArea.wz
                local x3, z3 = trigger.bunkerSiloArea.hx, trigger.bunkerSiloArea.hz
                return MathUtil.hasRectangleLineIntersection2D(x1, z1, x2 - x1, z2 - z1, x3 - x1, z3 - z1, x, z, tx - x, tz - z)
            end
        end
    end
    return false
end

function AutoDrive.getTriggerAndTrailerPairs(vehicle, dt)
    AutoDrive.debugPrint(vehicle, AutoDrive.DC_TRAILERINFO, "AutoDrive.getTriggerAndTrailerPairs start...")
    local trailerTriggerPairs = {}
    -- local trailers, _ = AutoDrive.getTrailersOf(vehicle, false)
    local trailers, _ = AutoDrive.getAllUnits(vehicle)
    local maxTriggerDistance = AutoDrive.getSetting("maxTriggerDistance") 
    for index, trailer in ipairs(trailers) do
        if trailer.getFillUnits ~= nil then
            local fillUnits = trailer:getFillUnits()
            local trailerX, _, trailerZ = getWorldTranslation(trailer.components[1].node)
            for _, trigger in pairs(ADTriggerManager:getLoadTriggers()) do
                local triggerX, _, triggerZ = ADTriggerManager.getTriggerPos(trigger)
                if triggerX ~= nil then
                    local distance = MathUtil.vector2Length(triggerX - trailerX, triggerZ - trailerZ)
                    if distance <= maxTriggerDistance then
                        AutoDrive.debugPrint(vehicle, AutoDrive.DC_TRAILERINFO, "AutoDrive.getTriggerAndTrailerPairs distance %s", tostring(distance))
                        vehicle.ad.debugTrigger = trigger
                        local allowedFillTypes = {vehicle.ad.stateModule:getFillType()}

                        -- seeds, fertilizer, liquidfertilizer should always be loaded if in trigger available
                        if #fillUnits > 1 then
                            local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(vehicle.ad.stateModule:getFillType())
                            AutoDrive.debugPrint(vehicle, AutoDrive.DC_TRAILERINFO, "AutoDrive.getTriggerAndTrailerPairs #fillUnits > 1 fillTypeName %s", tostring(fillTypeName))
                            if fillTypeName == 'SEEDS' or fillTypeName == 'FERTILIZER' or fillTypeName == 'LIQUIDFERTILIZER' then
                                -- seeds, fertilizer, liquidfertilizer
                                allowedFillTypes = {}
                                table.insert(allowedFillTypes, g_fillTypeManager:getFillTypeIndexByName('SEEDS'))
                                table.insert(allowedFillTypes, g_fillTypeManager:getFillTypeIndexByName('FERTILIZER'))
                                table.insert(allowedFillTypes, g_fillTypeManager:getFillTypeIndexByName('LIQUIDFERTILIZER'))
                            end
                        end

                        local fillLevels = {}
                        if trigger.source ~= nil and trigger.source.getAllFillLevels ~= nil then
                            fillLevels, _ = trigger.source:getAllFillLevels(vehicle:getOwnerFarmId())
                            AutoDrive.debugPrint(vehicle, AutoDrive.DC_TRAILERINFO, "AutoDrive.getTriggerAndTrailerPairs fillLevels %s", tostring(fillLevels))
                        end

                        local hasRequiredFillType = false
                        for i = 1, #fillUnits do
                            local hasFill = trigger.hasInfiniteCapacity 
                            local isFillAllowed = false
                            hasRequiredFillType = AutoDrive.fillTypesMatch(vehicle, trigger, trailer, allowedFillTypes, i)
                            local isNotFilled = not AutoDrive.getIsFillUnitFull(trailer, i)

                            AutoDrive.debugPrint(vehicle, AutoDrive.DC_TRAILERINFO, "AutoDrive.getTriggerAndTrailerPairs hasRequiredFillType %s isNotFilled %s", tostring(hasRequiredFillType), tostring(isNotFilled))

                            for _, allowedFillType in pairs(allowedFillTypes) do
                                if trailer:getFillUnitSupportsFillType(i, allowedFillType) then
                                    isFillAllowed = isFillAllowed or (fillLevels[allowedFillType] ~= nil)
                                    hasFill = hasFill or (fillLevels[allowedFillType] ~= nil and fillLevels[allowedFillType] > 0)
                                end
                            end
                            AutoDrive.debugPrint(vehicle, AutoDrive.DC_TRAILERINFO, "AutoDrive.getTriggerAndTrailerPairs isFillAllowed %s hasFill %s", tostring(isFillAllowed), tostring(hasFill))

                            local trailerIsInRange = AutoDrive.trailerIsInTriggerList(trailer, trigger, i)
                            if trailer.inRangeTimers == nil then
                                trailer.inRangeTimers = {}
                            end
                            if trailer.inRangeTimers[i] == nil then
                                trailer.inRangeTimers[i] = {}
                            end
                            if trailer.inRangeTimers[i][trigger] == nil then
                                trailer.inRangeTimers[i][trigger] = AutoDriveTON:new()
                            end
                            AutoDrive.debugPrint(vehicle, AutoDrive.DC_TRAILERINFO, "AutoDrive.getTriggerAndTrailerPairs trailerIsInRange %s", tostring(trailerIsInRange))

                            local timerDone = trailer.inRangeTimers[i][trigger]:timer(trailerIsInRange, 200, dt) -- vehicle.ad.stateModule:getFieldSpeedLimit()*100

                            if timerDone and hasRequiredFillType and isNotFilled and isFillAllowed then
                                AutoDrive.debugPrint(vehicle, AutoDrive.DC_TRAILERINFO, "AutoDrive.getTriggerAndTrailerPairs timerDone %s", tostring(timerDone))
                                local pair = {trailer = trailer, trigger = trigger, fillUnitIndex = i, hasFill = hasFill}
                                table.insert(trailerTriggerPairs, pair)
                            end
                        end
                    end
                end
            end
        end
    end

    AutoDrive.debugPrint(vehicle, AutoDrive.DC_TRAILERINFO, "AutoDrive.getTriggerAndTrailerPairs end #trailerTriggerPairs %s", tostring(#trailerTriggerPairs))
    return trailerTriggerPairs
end

function AutoDrive.trailerIsInTriggerList(trailer, trigger, fillUnitIndex)
    
    if trigger ~= nil and trigger.fillableObjects ~= nil then
        for _, fillableObject in pairs(trigger.fillableObjects) do
            if fillableObject == trailer or (fillableObject.object ~= nil and fillableObject.object == trailer and fillableObject.fillUnitIndex == fillUnitIndex) then
                --print("trailerIsInTriggerList")
                return true
            end
        end
    end
    
    local activatable = true
    if trigger.getIsActivatable ~= nil then
        activatable = trigger:getIsActivatable(trailer)
    end

    if trigger ~= nil and trigger.validFillableObject ~= nil and trigger.validFillableFillUnitIndex ~= nil and activatable then
        --print("Activateable: " .. tostring(activatable) .. " isLoading: " .. tostring(trigger.isLoading))
        if activatable and trigger.validFillableObject == trailer and trigger.validFillableFillUnitIndex == fillUnitIndex then
            --print("Is trailer and correctFillUnitIndex: " .. fillUnitIndex)
            return true
        end
    end

    return false
end

function AutoDrive.getTractorTrainLength(vehicle, includeTractor, onlyFirstTrailer)
    local totalLength = 0
    if vehicle ~= nil then
        local trailers, _ = AutoDrive.getAllUnits(vehicle)

        for i, trailer in ipairs(trailers) do

            if includeTractor and i == 1 then
                -- first is the rootVehicle
                totalLength = totalLength + trailer.size.length
            end
            if i > 1 then
                -- trailers
                totalLength = totalLength + trailer.size.length
                if onlyFirstTrailer then
                    break
                end
            end
        end
    end
    return totalLength
end

function AutoDrive.checkForContinueOnEmptyLoadTrigger(vehicle)
    return AutoDrive.getSetting("continueOnEmptySilo") or ((AutoDrive.getSetting("rotateTargets", vehicle) == AutoDrive.RT_ONLYPICKUP or AutoDrive.getSetting("rotateTargets", vehicle) == AutoDrive.RT_PICKUPANDDELIVER) and AutoDrive.getSetting("useFolders"))
end

function AutoDrive.getWaterTrailerInWater(vehicle, trailers)
    if vehicle ~= nil and trailers ~= nil then
        for _, trailer in pairs(trailers) do
            local spec = trailer.spec_waterTrailer
            if spec ~= nil and spec.waterFillNode ~= nil then
                local isNearWater = vehicle.isInWater
                local fillUnits = trailer:getFillUnits()
                for i = 1, #fillUnits do
                    local isNotFilled = not AutoDrive.getIsFillUnitFull(trailer, i)
                    local allowedFillType = vehicle.ad.stateModule:getFillType() == FillType.WATER
                    if isNearWater and isNotFilled and allowedFillType then
                        return trailer
                    end
                end
            end
        end
    end
    return nil
end

function AutoDrive.startFillTrigger(trailers)
    local ret = nil
    if trailers == nil then
        return ret
    end
    for _, trailer in pairs(trailers) do
        local spec = trailer.spec_fillUnit
        if spec ~= nil and spec.fillTrigger ~= nil and spec.fillTrigger.triggers ~= nil and #spec.fillTrigger.triggers >0 then
            if not spec.fillTrigger.isFilling then
                AutoDrive.debugPrint(vehicle, AutoDrive.DC_TRAILERINFO, "AutoDrive.startFillTrigger currentTrigger %s #triggers %s", tostring(spec.fillTrigger.currentTrigger), tostring(#spec.fillTrigger.triggers))
                spec:setFillUnitIsFilling(true)
            end
            if spec.fillTrigger.isFilling ~= nil and spec.fillTrigger.currentTrigger ~= nil then
                return spec.fillTrigger
            end
        end
    end
    return ret
end

function AutoDrive.isInRangeToLoadUnloadTarget(vehicle)
    if vehicle == nil or vehicle.ad == nil or vehicle.ad.stateModule == nil or vehicle.ad.drivePathModule == nil then
        return false
    end
    local ret = false
    ret =
            (
                ((vehicle.ad.stateModule:getCurrentMode():shouldLoadOnTrigger() == true) and AutoDrive.getDistanceToTargetPosition(vehicle) <= AutoDrive.getSetting("maxTriggerDistance"))
                or
                ((vehicle.ad.stateModule:getCurrentMode():shouldUnloadAtTrigger() == true) and AutoDrive.getDistanceToUnloadPosition(vehicle) <= AutoDrive.getSetting("maxTriggerDistance"))
            )
    return ret
end

function AutoDrive.isBaleUnloading(trailer)
    local spec = trailer.spec_baleLoader
    if spec then 
        if spec.emptyState ~= BaleLoader.EMPTY_NONE then
           return true
        end
    end
end
