local weaponModule = require 'modules.weapons'
local carryModule = require 'modules.carry'
local weaponsConfig = require 'data.weapons'
local hotbarSlots = {1,2,3,4,5,6} -- change this list to match your hotbar (e.g. {1,2,3,4,5,6} or {10,11,12})
local hotbarSet = {}
for _, s in ipairs(hotbarSlots) do hotbarSet[tostring(s)] = true end
-- =========================================

local Inventory = {}
local playerState = LocalPlayer.state
local currentWeapon = {}

local hasFlashLight = require 'modules.utils'.hasFlashLight

local function isHotbarSlot(slot)
    -- slot might be numeric or string key depending on your ox_inventory structure
    return hotbarSet[tostring(slot)] == true
end

local function filterHotbarInventory(inv)
    if not inv then return {} end
    local out = {}
    for slot, item in pairs(inv) do
        if isHotbarSlot(slot) then
            out[slot] = item
        end
    end
    return out
end

-- initialize Inventory as hotbar-only snapshot
Inventory = filterHotbarInventory(exports.ox_inventory and exports.ox_inventory:GetPlayerItems() or {})

AddEventHandler('ox_inventory:currentWeapon', function(weapon)
    if weapon and weapon.name then
        local searchName = weapon.name:lower()
        if weaponsConfig[searchName] then
            currentWeapon = weapon

            if hasFlashLight(currentWeapon.metadata.components) then
                CreateThread(function()
                    weaponModule.loopFlashlight(currentWeapon.metadata.serial)
                end)
            end

            -- pass hotbar-only inventory
            return weaponModule.updateWeapons(filterHotbarInventory(Inventory), currentWeapon)
        end
    else
        local weaponName = currentWeapon?.name and currentWeapon.name:lower()

        currentWeapon = {}

        if weaponName and weaponsConfig[weaponName] then
            return weaponModule.updateWeapons(filterHotbarInventory(Inventory), {})
        end
    end
end)

--- Updates the inventory with the changes (hotbar-only)
AddEventHandler('ox_inventory:updateInventory', function(changes)
    if not changes then
        return
    end

    -- Apply only hotbar slot changes
    for slot, item in pairs(changes) do
        if isHotbarSlot(slot) then
            Inventory[slot] = item
        end
    end

    weaponModule.updateWeapons(filterHotbarInventory(Inventory), currentWeapon)
    carryModule.updateCarryState(filterHotbarInventory(Inventory))
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == cache.resource then
        Wait(100)
        -- refresh Inventory from ox_inventory but keep only hotbar
        Inventory = filterHotbarInventory(exports.ox_inventory and exports.ox_inventory:GetPlayerItems() or {})

        if table.type(playerState.weapons_carry or {}) ~= 'empty' then
            playerState:set('weapons_carry', false, true)
            weaponModule.updateWeapons(filterHotbarInventory(Inventory), currentWeapon)
        end

        if table.type(playerState.carry_items or {}) ~= 'empty' then
            playerState:set('carry_items', false, true)
            carryModule.updateCarryState(filterHotbarInventory(Inventory))
        end
    end
end)

-- Utility: refreshWeapons (hotbar-only)
local function refreshWeapons()
    if playerState.weapons_carry and table.type(playerState.weapons_carry) ~= 'empty' then
        Inventory = filterHotbarInventory(exports.ox_inventory:GetPlayerItems())
        playerState:set('weapons_carry', false, true)
        weaponModule.updateWeapons(filterHotbarInventory(Inventory), currentWeapon)
    end
end
exports("RefreshWeapons", refreshWeapons)

AddStateBagChangeHandler('hide_props', ('player:%s'):format(cache.serverId), function(_, _, value)
    if value then
        local items = playerState.weapons_carry

        if items and table.type(items) ~= 'empty' then
            playerState:set('weapons_carry', false, true)
        end

        local carryItems = playerState.carry_items

        if carryItems and table.type(carryItems) ~= 'empty' then
            playerState:set('carry_items', false, true)
            playerState:set('carry_loop', false, true)
        end
    else
        CreateThread(function()
            weaponModule.updateWeapons(filterHotbarInventory(Inventory), currentWeapon)
            carryModule.updateCarryState(filterHotbarInventory(Inventory))
        end)
    end
end)

-- To be fair I don't know if this is needed but it's here just in case
lib.onCache('ped', function()
   refreshWeapons()
end)

-- Some components like flashlights are being removed whenever a player enters a vehicle so we need to refresh the weapons_carry state when they exit
lib.onCache('vehicle', function(value)
    if not value then
        local items = playerState.weapons_carry

        if items and table.type(items) ~= 'empty' then
            for i = 1, #items do
                local item = items[i]

                if item.components and table.type(item.components) ~= 'empty' then
                    return refreshWeapons()
                end
            end
        end
    end
end)

AddStateBagChangeHandler('instance', ('player:%s'):format(cache.serverId), function(_, _, value)
    if value == 0 then
        if playerState.weapons_carry and table.type(playerState.weapons_carry) ~= 'empty' then
            weaponModule.refreshProps(filterHotbarInventory(Inventory), currentWeapon)
        end
    end
end)
