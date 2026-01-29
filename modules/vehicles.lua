local Utils = require 'modules.utils'
local Vehicles = {}

CreateThread(function()
    while true do
        for bagname, baggedVehicles in pairs(Vehicles) do
            if baggedVehicles and table.type(baggedVehicles) ~= 'empty' then
                for vehicle, props in pairs(baggedVehicles) do
                    if not DoesEntityExist(vehicle) then
                        if props and table.type(props) ~= 'empty' then
                            Utils.removeEntities(props)
                        end
                        Vehicles[bagname][vehicle] = nil
                    end
                end
            end
        end
        Wait(1500)
    end
end)

local function attachObject(item, entity, vehicle)
    if not item or not entity or not vehicle then return end
    if not DoesEntityExist(entity) or not DoesEntityExist(vehicle) then return end

    local pos, rot = item.pos, item.rot
    if not pos or not rot then return end

    AttachEntityToEntity(
        entity,
        vehicle,
        item.bone and GetEntityBoneIndexByName(vehicle, item.bone) or 0,
        pos.x, pos.y, pos.z,
        rot.x, rot.y, rot.z,
        true, true, false, false, 2, true
    )
end

local function createAllObjects(vehicle, addItems, currentTable)
    for i = 1, #addItems do
        local item = addItems[i]
        local object = Utils.getEntity(item)

        if object and object > 0 and DoesEntityExist(object) then
            -- make sure entity is active and safe
            FreezeEntityPosition(object, false)
            SetEntityDynamic(object, true)
            SetEntityCollision(object, false, false)
            SetEntityVisible(object, true, false)
            ActivatePhysics(object)

            attachObject(item, object, vehicle)

            currentTable[#currentTable + 1] = {
                name = item.name,
                entity = object,
            }
        else
            print(('[CarryVehicle] Failed to create entity for %s'):format(item.name or 'unknown'))
        end
    end
end

local function addVehicleStateBag(name)
    AddStateBagChangeHandler(name, '', function(bagName, keyName, value, _, replicated)
        if replicated then return end

        local vehicle = Utils.getEntityFromStateBag(bagName, keyName)
        if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
            return -- silently ignore invalid vehicle instead of crashing
        end

        Vehicles[keyName] = Vehicles[keyName] or {}
        local currentTable = Vehicles[keyName][vehicle] or {}

        -- remove old props
        if table.type(currentTable) ~= 'empty' then
            Utils.removeEntities(currentTable)
            table.wipe(currentTable)
        end

        -- create new props
        if value and table.type(value) ~= 'empty' then
            -- small delay to ensure vehicle fully streamed
            Wait(50)
            createAllObjects(vehicle, value, currentTable)
        end

        Vehicles[keyName][vehicle] = currentTable
    end)
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for _, baggedVehicles in pairs(Vehicles) do
        if baggedVehicles and table.type(baggedVehicles) ~= 'empty' then
            for _, props in pairs(baggedVehicles) do
                if props and table.type(props) ~= 'empty' then
                    Utils.removeEntities(props)
                end
            end
        end
    end
end)

return {
    addVehicleStateBag = addVehicleStateBag
}