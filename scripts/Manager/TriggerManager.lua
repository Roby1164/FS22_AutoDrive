ADTriggerManager = {}

ADTriggerManager.tipTriggers = {}
ADTriggerManager.siloTriggers = {}
ADTriggerManager.repairTriggers = {}

ADTriggerManager.searchedForTriggers = false

AutoDrive.MAX_REFUEL_TRIGGER_DISTANCE = 15
AutoDrive.REFUEL_LEVEL = 0.15

function ADTriggerManager.load()
end

function ADTriggerManager:update(dt)
end

-- not used
--[[
function ADTriggerManager.checkForTriggerProximity(vehicle, distanceToTarget)
    local shouldLoad = vehicle.ad.stateModule:getCurrentMode():shouldLoadOnTrigger()
    local shouldUnload = vehicle.ad.stateModule:getCurrentMode():shouldUnloadAtTrigger()
    if (not shouldUnload) and (not shouldLoad) or distanceToTarget == nil then
        return false
    end

    local x, y, z = getWorldTranslation(vehicle.components[1].node)
    local allFillables, _ = AutoDrive.getAllUnits(vehicle)

    local totalMass = vehicle:getTotalMass(false)
    local massFactor = math.max(1, math.min(3, (totalMass + 20) / 30))
    if vehicle.lastSpeedReal * 3600 < 15 then
        massFactor = 1
    end
    local speedFactor = math.max(0.5, math.min(4, (((vehicle.lastSpeedReal * 3600) + 10) / 20.0)))
    local distanceToSlowDownAt = 15 * speedFactor * massFactor

    if vehicle.ad.trailerModule:isActiveAtTrigger() then
        return true
    end

    if shouldLoad then
        for _, trigger in pairs(ADTriggerManager.siloTriggers) do
            local triggerX, _, triggerZ = ADTriggerManager.getTriggerPos(trigger)
            if triggerX ~= nil then
                local distance = MathUtil.vector2Length(triggerX - x, triggerZ - z)

                if distance < distanceToSlowDownAt and distanceToTarget < AutoDrive.getSetting("maxTriggerDistance") then
                    local hasRequiredFillType = false
                    local allowedFillTypes = {vehicle.ad.stateModule:getFillType()}
                    local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(vehicle.ad.stateModule:getFillType())

                    if fillTypeName == 'SEEDS' or fillTypeName == 'FERTILIZER' or fillTypeName == 'LIQUIDFERTILIZER' then
                        -- seeds, fertilizer, liquidfertilizer
                        allowedFillTypes = {}
                        table.insert(allowedFillTypes, g_fillTypeManager:getFillTypeIndexByName('SEEDS'))
                        table.insert(allowedFillTypes, g_fillTypeManager:getFillTypeIndexByName('FERTILIZER'))
                        table.insert(allowedFillTypes, g_fillTypeManager:getFillTypeIndexByName('LIQUIDFERTILIZER'))
                    end

                    for _, trailer in pairs(allFillables) do
                        hasRequiredFillType = hasRequiredFillType or AutoDrive.fillTypesMatch(vehicle, trigger, trailer, allowedFillTypes)
                    end

                    if hasRequiredFillType then
                        return true
                    end
                end
            end
        end
    end

    if shouldUnload then
        for _, trigger in pairs(ADTriggerManager.tipTriggers) do
            local triggerX, _, triggerZ = ADTriggerManager.getTriggerPos(trigger)
            if triggerX ~= nil then
                local distance = MathUtil.vector2Length(triggerX - x, triggerZ - z)
                if distance < distanceToSlowDownAt and (distanceToTarget < AutoDrive.getSetting("maxTriggerDistance") or (trigger.bunkerSiloArea ~= nil and distanceToTarget < 300)) then
                    return true
                end
            end
        end
    end

    return false
end
]]

function ADTriggerManager.loadAllTriggers()
    ADTriggerManager.searchedForTriggers = true
    ADTriggerManager.tipTriggers = {}
    ADTriggerManager.siloTriggers = {}
    ADTriggerManager.repairTriggers = {}
    for _, ownedItem in pairs(g_currentMission.ownedItems) do
        if ownedItem.storeItem ~= nil then
            if ownedItem.storeItem.categoryName == "SILOS" then
                for _, item in pairs(ownedItem.items) do
                    if item.spec_bunkerSilo ~= nil then
                        if not table.contains(ADTriggerManager.tipTriggers, item.spec_bunkerSilo.bunkerSilo) then
                            table.insert(ADTriggerManager.tipTriggers, item.spec_bunkerSilo.bunkerSilo)
                        end
                    end

                    if item.loadingStation ~= nil then
                        for _, loadTrigger in pairs(item.loadingStation.loadTriggers) do
                            if not table.contains(ADTriggerManager.siloTriggers, loadTrigger) then
                                table.insert(ADTriggerManager.siloTriggers, loadTrigger)
                            end
                        end
                    end
                end
            end
        end

        for _, item in pairs(ownedItem.items) do
            if item.spec_workshop ~= nil and  item.spec_workshop.sellingPoint ~= nil then
                if item.spec_workshop.sellingPoint.sellTriggerNode ~= nil then
                    table.insert(ADTriggerManager.repairTriggers, {node=item.spec_workshop.sellingPoint.sellTriggerNode, owner=item.ownerFarmId })
                end
            end

            if item.unloadTriggers then
                for _, unloadTrigger in pairs(item.unloadTriggers) do
                    if not table.contains(ADTriggerManager.tipTriggers, unloadTrigger) then
                        table.insert(ADTriggerManager.tipTriggers, unloadTrigger)
                    end
                end
            end

            if item.unloadingStation and item.unloadingStation.unloadTriggers then
                for _, unloadTrigger in pairs(item.unloadingStation.unloadTriggers) do
                    if not table.contains(ADTriggerManager.tipTriggers, unloadTrigger) then
                        table.insert(ADTriggerManager.tipTriggers, unloadTrigger)
                    end
                end
            end

            if item.spec_silo and item.spec_silo.unloadingStation and item.spec_silo.unloadingStation.unloadTriggers then
                for _, unloadTrigger in pairs(item.spec_silo.unloadingStation.unloadTriggers) do
                    if not table.contains(ADTriggerManager.tipTriggers, unloadTrigger) then
                        table.insert(ADTriggerManager.tipTriggers, unloadTrigger)
                    end
                end
            end

            if item.spec_husbandry and item.spec_husbandry.unloadingStation and item.spec_husbandry.unloadingStation.unloadTriggers then
                for _, unloadTrigger in pairs(item.spec_husbandry.unloadingStation.unloadTriggers) do
                    if not table.contains(ADTriggerManager.tipTriggers, unloadTrigger) then
                        table.insert(ADTriggerManager.tipTriggers, unloadTrigger)
                    end
                end
            end

            if item.spec_sellingStation and item.spec_sellingStation.sellingStation and item.spec_sellingStation.sellingStation.unloadTriggers then
                for _, unloadTrigger in pairs(item.spec_sellingStation.sellingStation.unloadTriggers) do
                    if not table.contains(ADTriggerManager.tipTriggers, unloadTrigger) then
                        table.insert(ADTriggerManager.tipTriggers, unloadTrigger)
                    end
                end
            end
        end
    end

    if g_currentMission.placeables ~= nil then
        for _, placeable in pairs(g_currentMission.placeables) do
            if placeable.sellingStation ~= nil then
                for _, unloadTrigger in pairs(placeable.sellingStation.unloadTriggers) do
                    if not table.contains(ADTriggerManager.tipTriggers, unloadTrigger) then
                        table.insert(ADTriggerManager.tipTriggers, unloadTrigger)
                    end
                end
            end

            if placeable.unloadingStation ~= nil then
                for _, unloadTrigger in pairs(placeable.unloadingStation.unloadTriggers) do
                    if not table.contains(ADTriggerManager.tipTriggers, unloadTrigger) then
                        table.insert(ADTriggerManager.tipTriggers, unloadTrigger)
                    end
                end
            end

            if placeable.modulesById ~= nil then
                for i = 1, #placeable.modulesById do
                    local myModule = placeable.modulesById[i]
                    if myModule.unloadPlace ~= nil then
                        if not table.contains(ADTriggerManager.tipTriggers, myModule.unloadPlace) then
                            table.insert(ADTriggerManager.tipTriggers, myModule.unloadPlace)
                        end
                    end

                    if myModule.feedingTrough ~= nil then
                        if not table.contains(ADTriggerManager.tipTriggers, myModule.feedingTrough) then
                            table.insert(ADTriggerManager.tipTriggers, myModule.feedingTrough)
                        end
                    end

                    if myModule.loadPlace ~= nil then
                        if not table.contains(ADTriggerManager.siloTriggers, myModule.loadPlace) then
                            table.insert(ADTriggerManager.siloTriggers, myModule.loadPlace)
                        end
                    end
                end
            end

            if placeable.buyingStation ~= nil then
                for _, loadTrigger in pairs(placeable.buyingStation.loadTriggers) do
                    if not table.contains(ADTriggerManager.siloTriggers, loadTrigger) then
                        table.insert(ADTriggerManager.siloTriggers, loadTrigger)
                    end
                end
            end

            if placeable.loadingStation ~= nil then
                for _, loadTrigger in pairs(placeable.loadingStation.loadTriggers) do
                    if not table.contains(ADTriggerManager.siloTriggers, loadTrigger) then
                        table.insert(ADTriggerManager.siloTriggers, loadTrigger)
                    end
                end
            end

            if placeable.bunkerSilos ~= nil then
                for _, bunker in pairs(placeable.bunkerSilos) do
                    if not table.contains(ADTriggerManager.tipTriggers, bunker) then
                        table.insert(ADTriggerManager.tipTriggers, bunker)
                    end
                end
            end
        end
    end

    if g_currentMission.nodeToObject ~= nil then
        for _, object in pairs(g_currentMission.nodeToObject) do
            if object.triggerNode ~= nil then
                if not table.contains(ADTriggerManager.siloTriggers, object) then
                    table.insert(ADTriggerManager.siloTriggers, object)
                end
            end

            if object.exactFillRootNode ~= nil then
                table.insert(ADTriggerManager.tipTriggers, object)
			end
        end
    end

    if g_currentMission.bunkerSilos ~= nil then
        for _, trigger in pairs(g_currentMission.bunkerSilos) do
            if trigger.bunkerSilo then
                if not table.contains(ADTriggerManager.tipTriggers, trigger) then
                    table.insert(ADTriggerManager.tipTriggers, trigger)
                end
            end
        end
    end
    
    for _, trigger in pairs(ADTriggerManager.siloTriggers) do
        if trigger.stoppedTimer == nil then
            trigger.stoppedTimer = AutoDriveTON:new()
        end
    end
end

function ADTriggerManager.getUnloadTriggers()
    if not ADTriggerManager.searchedForTriggers then
        ADTriggerManager.loadAllTriggers()
    end
    return ADTriggerManager.tipTriggers
end

function ADTriggerManager.getLoadTriggers()
    if not ADTriggerManager.searchedForTriggers then
        ADTriggerManager.loadAllTriggers()
    end
    return ADTriggerManager.siloTriggers
end

function ADTriggerManager.getRepairTriggers()
    if not ADTriggerManager.searchedForTriggers then
        ADTriggerManager.loadAllTriggers()
    end
    return ADTriggerManager.repairTriggers
end

-- returns only suitable fuel triggers according to used fuel types
function ADTriggerManager.getRefuelTriggers(vehicle, ignoreFillLevel)


    local refuelTriggers = {}
    local refuelFillTypes = AutoDrive.getRequiredRefuels(vehicle, ignoreFillLevel)
    if #refuelFillTypes > 0 then

        for _, trigger in pairs(ADTriggerManager.getLoadTriggers()) do
            --loadTriggers
            -- vanilla LoadingStation
            local fillLevels = {}
            if trigger.source ~= nil and trigger.source.getAllFillLevels ~= nil then
                fillLevels, _ = trigger.source:getAllFillLevels(vehicle:getOwnerFarmId())
            end
            -- GC trigger
            local gcFillLevels = {}
            if trigger.source ~= nil and trigger.source.getAllProvidedFillLevels ~= nil then
                gcFillLevels, _ = trigger.source:getAllProvidedFillLevels(vehicle:getOwnerFarmId(), trigger.managerId)
            end
            if table.count(fillLevels) == 0 and table.count(gcFillLevels) == 0 and trigger.source ~= nil and trigger.source.gcId ~= nil and trigger.source.fillLevels ~= nil then
                for index, fillLevel in pairs(trigger.source.fillLevels) do
                    if fillLevel ~= nil and fillLevel[1] ~= nil then
                        fillLevels[index] = fillLevel[1]
                    end
                end
            end

            if #refuelFillTypes > 0 then
                for _, refuelFillType in pairs(refuelFillTypes) do
                    local hasCapacity = (fillLevels[refuelFillType] ~= nil and fillLevels[refuelFillType] > 0) or (gcFillLevels[refuelFillType] ~= nil and gcFillLevels[refuelFillType] > 0)

                    if hasCapacity and not table.contains(refuelTriggers, trigger) then
                        table.insert(refuelTriggers, trigger)
                    end
                end
            end
        end
    end

    return refuelTriggers
end

function ADTriggerManager.getClosestRefuelTrigger(vehicle, ignoreFillLevel)
    local refuelTriggers = ADTriggerManager.getRefuelTriggers(vehicle, ignoreFillLevel)
    local x, _, z = getWorldTranslation(vehicle.components[1].node)

    local closestRefuelTrigger = nil
    local closestDistance = math.huge

    for _, refuelTrigger in pairs(refuelTriggers) do
        local triggerX, _, triggerZ = ADTriggerManager.getTriggerPos(refuelTrigger)
        local distance = MathUtil.vector2Length(triggerX - x, triggerZ - z)

        if distance < closestDistance then
            closestDistance = distance
            closestRefuelTrigger = refuelTrigger
        end
    end

    return closestRefuelTrigger
end

function ADTriggerManager.getRefuelDestinations(vehicle, ignoreFillLevel)
    local refuelDestinations = {}

    local refuelTriggers = ADTriggerManager.getRefuelTriggers(vehicle, ignoreFillLevel)

    for mapMarkerID, mapMarker in pairs(ADGraphManager:getMapMarkers()) do
        for _, refuelTrigger in pairs(refuelTriggers) do
            local triggerX, _, triggerZ = ADTriggerManager.getTriggerPos(refuelTrigger)
            local distance = MathUtil.vector2Length(triggerX - ADGraphManager:getWayPointById(mapMarker.id).x, triggerZ - ADGraphManager:getWayPointById(mapMarker.id).z)
            if distance < AutoDrive.MAX_REFUEL_TRIGGER_DISTANCE then
                table.insert(refuelDestinations, {mapMarkerID = mapMarkerID, refuelTrigger = refuelTrigger, distance = distance})
            end
        end
    end

    return refuelDestinations
end

function ADTriggerManager.getClosestRefuelDestination(vehicle, ignoreFillLevel)
    local refuelDestinations = ADTriggerManager.getRefuelDestinations(vehicle, ignoreFillLevel)

    local x, _, z = getWorldTranslation(vehicle.components[1].node)
    local closestRefuelDestination = nil
    local closestDistance = math.huge
    local closestRefuelTrigger = nil

    -- for _, refuelDestination in pairs(refuelDestinations) do
    for _, item in pairs(refuelDestinations) do
        local refuelX, refuelZ = ADGraphManager:getWayPointById(ADGraphManager:getMapMarkerById(item.mapMarkerID).id).x, ADGraphManager:getWayPointById(ADGraphManager:getMapMarkerById(item.mapMarkerID).id).z
        local distance = MathUtil.vector2Length(refuelX - x, refuelZ - z)       -- vehicle to destination
        if distance <= closestDistance then
            closestRefuelDestination = item.mapMarkerID
            closestRefuelTrigger = item.refuelTrigger
            closestDistance = distance
        end
    end
    if closestRefuelTrigger ~= nil then
        -- now find the closest mapMarker for the found refuel trigger
        local closestDistance2 = math.huge
        for _, item in pairs(refuelDestinations) do
            if item.refuelTrigger == closestRefuelTrigger and item.distance < closestDistance2 then
                closestRefuelTrigger = item.refuelTrigger
                closestDistance2 = item.distance
                closestRefuelDestination = item.mapMarkerID
            end
        end
    end

    return closestRefuelDestination
end

function ADTriggerManager.getTriggerPos(trigger)
    local x, y, z = 0, 0, 0
    if trigger.triggerNode ~= nil and g_currentMission.nodeToObject[trigger.triggerNode] ~= nil and entityExists(trigger.triggerNode) then 
        x, y, z = getWorldTranslation(trigger.triggerNode)
    end
    if trigger.exactFillRootNode ~= nil and g_currentMission.nodeToObject[trigger.exactFillRootNode] ~= nil and entityExists(trigger.exactFillRootNode) then
        x, y, z = getWorldTranslation(trigger.exactFillRootNode)
    end
    if trigger.baleTrigger ~= nil then
        local node = trigger.baleTrigger.triggerNode
        if node ~= nil and g_currentMission.nodeToObject[node] ~= nil and entityExists(node) then
            x, y, z = getWorldTranslation(node)
        end
    end
    if trigger.interactionTriggerNode ~= nil and g_currentMission.nodeToObject[trigger.interactionTriggerNode] ~= nil and entityExists(trigger.interactionTriggerNode) then
        x, y, z = getWorldTranslation(trigger.interactionTriggerNode)
    end
    return x, y, z
end

function ADTriggerManager:loadTriggerLoad(superFunc, ...)
    local result = superFunc(self, ...)

    if ADTriggerManager ~= nil and ADTriggerManager.siloTriggers ~= nil then
        if not table.contains(ADTriggerManager.siloTriggers, self) then
            table.insert(ADTriggerManager.siloTriggers, self)
        end
    end

    return result
end

function ADTriggerManager:loadTriggerDelete(superFunc)
    if ADTriggerManager ~= nil and ADTriggerManager.siloTriggers ~= nil then
        table.removeValue(ADTriggerManager.siloTriggers, self)
    end
    superFunc(self)
end

function ADTriggerManager:onPlaceableBuy()
    ADTriggerManager.searchedForTriggers = false
end

function ADTriggerManager.triggerSupportsFillType(trigger, fillType)
    if fillType > 0 then
        if trigger ~= nil and trigger.getIsFillTypeSupported then
            return trigger:getIsFillTypeSupported(fillType)
        end
    end  
    return false  
end

function ADTriggerManager.getAllTriggersForFillType(fillType)
    local triggers = {}

    for _, trigger in pairs(ADTriggerManager.getUnloadTriggers()) do
        if ADTriggerManager.triggerSupportsFillType(trigger, fillType) then
            table.insert(triggers, trigger)
        end
    end

    return triggers
end

function ADTriggerManager:getHighestPayingSellStation(fillType)
    local bestSellingStation = nil
    local bestPrice = -1

    for _, station in pairs(g_currentMission.storageSystem:getUnloadingStations()) do
        --AutoDrive.dumpTable(station, "Station:", 1)
		if station:isa(SellingStation) and not station.hideFromPricesMenu and station.isSellingPoint and station.supportedFillTypes[fillType] and station.unloadTriggers ~= nil and #station.unloadTriggers > 0 then
			station.uiName = station:getName()
            local price = station:getEffectiveFillTypePrice(fillType)
            if price > bestPrice then
                bestPrice = price
                bestSellingStation = station
            end
		end
	end

    return bestSellingStation
end

function ADTriggerManager:getBestPickupLocationFor(vehicle, trailer, fillType)
    local farmId = -1
    if vehicle.spec_enterable ~= nil and vehicle.spec_enterable.controllerFarmId ~= nil and vehicle.spec_enterable.controllerFarmId ~= 0 then
        farmId = vehicle.spec_enterable.controllerFarmId
    elseif vehicle.spec_aiVehicle ~= nil and vehicle.spec_aiVehicle.startedFarmId ~= nil and vehicle.spec_aiVehicle.startedFarmId ~= 0 then
        farmId = vehicle.spec_aiVehicle.startedFarmId
    end

    if farmId <= 0 then
        return
    end

    local validLoadingStations = {}
    local closestDistance = math.huge

	for _, loadingStation in pairs(g_currentMission.storageSystem:getLoadingStations()) do
		if g_currentMission.accessHandler:canFarmAccess(farmId, loadingStation) then			
            local aifillTypes = loadingStation:getAISupportedFillTypes()
			if aifillTypes[fillType] and loadingStation:getFillLevel(fillType, farmId) > 0 then        
                if loadingStation.getAITargetPositionAndDirection ~= nil then
                    x, z, xDir, zDir = loadingStation:getAITargetPositionAndDirection(FillType.UNKNOWN)
                    
                    table.insert(validLoadingStations, loadingStation)
                end

			end
		end
	end

    -- Todo: Sort by owned first and then by distance
    if #validLoadingStations > 0 then
        local vehicleX, _, vehicleZ = getWorldTranslation(vehicle.components[1].node)
        local closestLoadingStation = validLoadingStations[1]
        local closestDistance = math.huge
        for _, loadingStation in pairs(validLoadingStations) do
            if loadingStation.getAITargetPositionAndDirection ~= nil then
                local x, z, xDir, zDir = loadingStation:getAITargetPositionAndDirection(FillType.UNKNOWN)
                local dis = MathUtil.vector2Length(vehicleX - x, vehicleZ - z)
                if dis < closestDistance then
                    closestDistance = dis
                    closestLoadingStation = loadingStation
                end
            end
        end
        return closestLoadingStation
    end
end

function ADTriggerManager:getMarkerAtStation(sellingStation, vehicle, maxTriggerDistance)
    local maxTriggerDis = maxTriggerDistance or 6
    local closest = -1
    if sellingStation ~= nil then
        local x, z, xDir, zDir = 0,0,0,0
        
        if sellingStation.getAITargetPositionAndDirection ~= nil and sellingStation:getAITargetPositionAndDirection(FillType.UNKNOWN) ~= nil then
            x, z, xDir, zDir = sellingStation:getAITargetPositionAndDirection(FillType.UNKNOWN)
        elseif sellingStation.unloadTriggers ~= nil and #sellingStation.unloadTriggers > 0 then
            if sellingStation.unloadTriggers[1].supportsAIUnloading then
                x, z, xDir, zDir = sellingStation.unloadTriggers[1]:getAITargetPositionAndDirection()
            elseif sellingStation.unloadTriggers[1].exactFillRootNode ~= nil then
                x, _, z = getWorldTranslation(sellingStation.unloadTriggers[1].exactFillRootNode)
            elseif sellingStation.unloadTriggers[1].baleTrigger ~= nil then
                local node = sellingStation.unloadTriggers[1].baleTrigger.triggerNode
                x, _, z = getWorldTranslation(node)
            else
                return -1
            end
        else
            return -1
        end

        -- Now find suitable node in the network
        local minDistance = AutoDrive.getTractorTrainLength(vehicle, true, false) + 3
        local distance = minDistance + 10

        --First look for suitable marker
        for mapMarkerID, mapMarker in pairs(ADGraphManager:getMapMarkers()) do
            local dis = MathUtil.vector2Length(ADGraphManager:getWayPointById(mapMarker.id).x - x, ADGraphManager:getWayPointById(mapMarker.id).z - z)
            if dis < distance and dis > minDistance then
                -- check if this is in the right direction
                local wp = ADGraphManager:getWayPointById(mapMarker.id)
                local isOnPathOverTrigger = AutoDrive:checkIfPathTraversedOverPosition(wp, {x=x, z=z}, maxTriggerDis, 20)

                if wp.incoming ~= nil and #wp.incoming > 0 and isOnPathOverTrigger then
                    local disIncoming = MathUtil.vector2Length(ADGraphManager:getWayPointById(wp.incoming[1]).x - x, ADGraphManager:getWayPointById(wp.incoming[1]).z - z)
                    if disIncoming < dis then
                        closest = mapMarker.id
                        distance = dis
                    end
                end
            end
        end

        if closest == -1 then
            -- Else look for waypoint and create marker
            -- Todo: first check for a closest point and then traverse until one meets the requirements

            local closestNode = nil
            local closestNodeDistance = math.huge
            for i in pairs(ADGraphManager:getWayPoints()) do
                local dis = MathUtil.vector2Length(ADGraphManager:getWayPointById(i).x - x, ADGraphManager:getWayPointById(i).z - z)
                if dis < closestNodeDistance and dis < maxTriggerDis then
                    closestNode = i
                    closestNodeDistance = dis
                end
            end

            if closestNode ~= nil then
                local pointWithEnoughDistance = AutoDrive:getNodeWithMinDistanceTo(ADGraphManager:getWayPointById(closestNode), {x=x, z=z}, minDistance, 20)
                if pointWithEnoughDistance ~= nil then
                    closest = pointWithEnoughDistance.id
                end
            end

            if closest >= 0 then
                local markerName = "NoName"
                if sellingStation.uiName ~= nil then
                    markerName = sellingStation.uiName
                elseif sellingStation.getName ~= nil then
                    markerName = sellingStation:getName()
                end
                ADGraphManager:createMapMarker(closest, markerName)
            end
        end
    end
    return closest
end

function AutoDrive:checkIfPathTraversedOverPosition(wayPoint, targetPosition, radius, maxSteps)
    local maxSearchSteps = maxSteps or 30
    if maxSearchSteps <= 0 then
        return false
    end
    local distance = MathUtil.vector2Length(wayPoint.x - targetPosition.x, wayPoint.z - targetPosition.z)
    if distance < radius then
        return true
    end
    for _, incomingId in pairs(wayPoint.incoming) do
        if AutoDrive:checkIfPathTraversedOverPosition(ADGraphManager:getWayPointById(incomingId), targetPosition, radius, maxSearchSteps - 1) then
            return true
        end
    end
    return false
end

function AutoDrive:getNodeWithMinDistanceTo(wayPoint, targetPosition, minDistance, maxSteps)
    local maxSearchSteps = maxSteps or 30
    if maxSearchSteps <= 0 then
        return nil
    end
    local distance = MathUtil.vector2Length(wayPoint.x - targetPosition.x, wayPoint.z - targetPosition.z)
    if distance > minDistance then
        return wayPoint
    end
    for _, outId in pairs(wayPoint.out) do
        local result = AutoDrive:getNodeWithMinDistanceTo(ADGraphManager:getWayPointById(outId), targetPosition, minDistance, maxSearchSteps - 1)
        if result ~= nil then
            return result
        end
    end
    return nil
end

function AutoDrive:getClosestRepairTrigger(vehicle)
    local x, y, z = getWorldTranslation(vehicle.components[1].node)
    local distance = math.huge
    local maxDistance = 15
    local closest = nil

    -- Check ownerFarmId
    local repairMarkers = {}
    local ownedRepairMarkers = {}
    for _, repairTrigger in pairs(ADTriggerManager.getRepairTriggers()) do
        local triggerX, _, triggerZ = getWorldTranslation(repairTrigger.node)

        --First look for suitable marker
        for mapMarkerID, mapMarker in pairs(ADGraphManager:getMapMarkers()) do
            local dis = MathUtil.vector2Length(ADGraphManager:getWayPointById(mapMarker.id).x - triggerX, ADGraphManager:getWayPointById(mapMarker.id).z - triggerZ)
            if dis < distance and dis < maxDistance then            
                closest = mapMarker.id
                distance = dis
            end
        end

        if closest ~= nil then
            table.insert(repairMarkers, {marker=closest, distance=MathUtil.vector2Length(ADGraphManager:getWayPointById(closest).x - x, ADGraphManager:getWayPointById(closest).z - z)})
            if vehicle.getOwnerFarmId ~= nil and vehicle:getOwnerFarmId() == repairTrigger.owner then
                table.insert(ownedRepairMarkers, {marker=closest, distance=MathUtil.vector2Length(ADGraphManager:getWayPointById(closest).x - x, ADGraphManager:getWayPointById(closest).z - z)})
            end
        end

        distance = math.huge
        closest = nil
    end
    
    if #ownedRepairMarkers > 0 then 
        repairMarkers = ownedRepairMarkers
    end

    for _, repairMarker in pairs(repairMarkers) do
        if repairMarker.distance < distance then
            closest = repairMarker
            distance = repairMarker.distance
        end
    end

    return closest
end