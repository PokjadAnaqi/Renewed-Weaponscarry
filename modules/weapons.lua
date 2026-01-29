local WeaponConfig = require 'data.weapons'
local Config       = require 'config'
local Utils        = require 'modules.utils'
local Players = {}
local playerState = LocalPlayer.state

SetFlashLightKeepOnWhileMoving(true)

local function removePlayer(serverId)
    local Player = Players[serverId]
    if Player and table.type(Player) ~= 'empty' then
        Utils.removeEntities(Player)
        Players[serverId] = nil
    end
end

RegisterNetEvent('onPlayerDropped', function(serverId)
    removePlayer(serverId)
end)

local function formatPlayerInventory(inventory, currentWeapon)
    local items = {}
    local amount = 0

    for _, itemData in pairs(inventory) do
        local name = itemData and itemData.name and itemData.name:lower()
        local slot = itemData and tonumber(itemData.slot)

        local slotAllowed = false
        if Config.HotbarSlots then
            for i = 1, #Config.HotbarSlots do
                if slot == Config.HotbarSlots[i] then
                    slotAllowed = true
                    break
                end
            end
        end

        if currentWeapon and itemData
            and currentWeapon.name == itemData.name
            and lib.table.matches(itemData.metadata.components, currentWeapon.metadata.components)
        then
            currentWeapon = nil

        elseif name and WeaponConfig[name] and slotAllowed then
            amount += 1
            items[amount] = Utils.formatData(itemData, WeaponConfig[name])
        end
    end

    Utils.resetSlots()

    if amount > 1 then
        table.sort(items, function(a, b)
            return a.serial < b.serial
        end)
    end

    return items
end

local function createAllObjects(pedHandle, addItems, currentTable)
    if not pedHandle or pedHandle == 0 or not DoesEntityExist(pedHandle) then
        return
    end

    for i = 1, #addItems do
        local item = addItems[i]
        local name = item.name:lower()

        if WeaponConfig[name] then
            local object = Utils.getEntity(item)

            if object and object > 0 and DoesEntityExist(object) then
                Utils.AttachEntityToPlayer(item, object, pedHandle)
                currentTable[#currentTable + 1] = {
                    name   = item.name,
                    entity = object,
                }
            else
                print(('[WeaponsCarry] Failed to create entity for %s'):format(item.name or 'unknown'))
            end
        end
    end
end

AddStateBagChangeHandler('weapons_carry', nil, function(bagName, keyName, value, _, replicated)
    if replicated then return end

    local serverId, pedHandle = Utils.getEntityFromStateBag(bagName, keyName)

    if serverId and not value then
        return removePlayer(serverId)
    end

    if not pedHandle or pedHandle == 0 or not DoesEntityExist(pedHandle) then
        return
    end

    Players[serverId] = Players[serverId] or {}
    local currentTable = Players[serverId]

    if table.type(currentTable) ~= 'empty' then
        Utils.removeEntities(currentTable)
        table.wipe(currentTable)
    end

    Wait(50)

    if value and table.type(value) ~= 'empty' then
        createAllObjects(pedHandle, value, currentTable)
    end
end)

local function updateState(inventory, currentWeapon)
    while playerState.weapons_carry == nil do
        Wait(0)
    end

    local items = formatPlayerInventory(inventory, currentWeapon)

    if not playerState.hide_props and not lib.table.matches(items, playerState.weapons_carry or {}) then
        playerState:set('weapons_carry', items, true)
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end

    for _, v in pairs(Players) do
        if v then
            Utils.removeEntities(v)
        end
    end
end)

local function refreshProps(items, weapon)
    if Players[cache.serverId] then
        Utils.removeEntities(Players[cache.serverId])
        table.wipe(Players[cache.serverId])

        local formatted = formatPlayerInventory(items, weapon)

        if cache.ped and cache.ped > 0 and DoesEntityExist(cache.ped) then
            Wait(50)
            createAllObjects(cache.ped, formatted, Players[cache.serverId])
        end
    end
end

--- Loops the current flashlight to keep it enabled while the player is not aiming
---@param serial string
local function flashLightLoop(serial)
    serial = serial or 'scratched'

    local flashState = playerState.flashState and playerState.flashState[serial]

    -- Restore flashlight bila equip (kalau sebelum ni ON)
    if flashState then
        CreateThread(function()
            Wait(150)
            SetFlashLightEnabled(cache.ped, true)
        end)
    end

    -- Observe state semasa weapon dipegang
    while cache.weapon do
        local currentState = IsFlashLightOn(cache.ped)
        if currentState ~= flashState then
            flashState = currentState
        end
        Wait(100)
    end

    -- Simpan state terakhir sahaja (GTA akan auto-OFF bila holster)
    playerState.flashState = flashState and {
        [serial] = flashState
    }
end

return {
    updateWeapons  = updateState,
    loopFlashlight = flashLightLoop,
    refreshProps   = refreshProps,
}
