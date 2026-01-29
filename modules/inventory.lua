local weaponModule  = require 'modules.weapons'
local carryModule   = require 'modules.carry'
local weaponsConfig = require 'data.weapons'
local Utils         = require 'modules.utils'
local Config        = require 'config'

local hotbarSet = {}
for _, s in ipairs(Config.HotbarSlots) do
    hotbarSet[tostring(s)] = true
end

local Inventory = {}
local hotbarInventoryCache = {}
local playerState = LocalPlayer.state
local currentWeapon = {}

local hasFlashLight = Utils.hasFlashLight

local function isHotbarSlot(slot)
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

local function rebuildHotbarCache()
    hotbarInventoryCache = filterHotbarInventory(Inventory)
    return hotbarInventoryCache
end

local function getHotbarInventory()
    return hotbarInventoryCache
end

Inventory = filterHotbarInventory(exports.ox_inventory and exports.ox_inventory:GetPlayerItems() or {})
rebuildHotbarCache()

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

            return weaponModule.updateWeapons(getHotbarInventory(), currentWeapon)
        end
    else
        local weaponName = currentWeapon?.name and currentWeapon.name:lower()

        currentWeapon = {}

        if weaponName and weaponsConfig[weaponName] then
            return weaponModule.updateWeapons(getHotbarInventory(), {})
        end
    end
end)

AddEventHandler('ox_inventory:updateInventory', function(changes)
    if not changes then return end

    local changed = false

    for slot, item in pairs(changes) do
        if isHotbarSlot(slot) then
            Inventory[slot] = item
            changed = true
        end
    end

    if not changed then return end

    rebuildHotbarCache()

    local hotbarInv = getHotbarInventory()
    weaponModule.updateWeapons(hotbarInv, currentWeapon)
    carryModule.updateCarryState(hotbarInv)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end
    Wait(150)

    Inventory = filterHotbarInventory(exports.ox_inventory and exports.ox_inventory:GetPlayerItems() or {})
    rebuildHotbarCache()

    if playerState.weapons_carry and table.type(playerState.weapons_carry) ~= 'empty' then
        playerState:set('weapons_carry', false, true)
        weaponModule.updateWeapons(getHotbarInventory(), currentWeapon)
    end

    if playerState.carry_items and table.type(playerState.carry_items) ~= 'empty' then
        playerState:set('carry_items', false, true)
        carryModule.updateCarryState(getHotbarInventory())
    end
end)

local function refreshWeapons()
    if playerState.weapons_carry and table.type(playerState.weapons_carry) ~= 'empty' then
        Inventory = filterHotbarInventory(exports.ox_inventory:GetPlayerItems())
        rebuildHotbarCache()

        playerState:set('weapons_carry', false, true)
        weaponModule.updateWeapons(getHotbarInventory(), currentWeapon)
    end
end
exports("RefreshWeapons", refreshWeapons)

AddStateBagChangeHandler('hide_props', ('player:%s'):format(cache.serverId), function(_, _, value)
    if value then
        if playerState.weapons_carry and table.type(playerState.weapons_carry) ~= 'empty' then
            playerState:set('weapons_carry', false, true)
        end

        if playerState.carry_items and table.type(playerState.carry_items) ~= 'empty' then
            playerState:set('carry_items', false, true)
            playerState:set('carry_loop', false, true)
        end
    else
        local hotbarInv = getHotbarInventory()
        weaponModule.updateWeapons(hotbarInv, currentWeapon)
        carryModule.updateCarryState(hotbarInv)
    end
end)

lib.onCache('ped', function()
    refreshWeapons()
end)

lib.onCache('vehicle', function(vehicle)
    if vehicle then
        if playerState.weapons_carry and table.type(playerState.weapons_carry) ~= 'empty' then
            playerState:set('weapons_carry', false, true)
        end
        if playerState.carry_items and table.type(playerState.carry_items) ~= 'empty' then
            playerState:set('carry_items', false, true)
            playerState:set('carry_loop', false, true)
        end
    else
        refreshWeapons()
        carryModule.updateCarryState(getHotbarInventory())
    end
end)

AddStateBagChangeHandler('instance', ('player:%s'):format(cache.serverId), function(_, _, value)
    if value == 0 then
        if playerState.weapons_carry and table.type(playerState.weapons_carry) ~= 'empty' then
            weaponModule.refreshProps(getHotbarInventory(), currentWeapon)
        end
    end
end)