local Config = require 'config'
local ox_items = exports.ox_inventory and exports.ox_inventory:Items() or {}
local Utils = {}
local playerSlots = Config.PlayerSlots

for i = 1, #playerSlots do
    for j = 1, #playerSlots[i] do
        playerSlots[i][j].isBusy = false
    end
end

function Utils.resetSlots()
    for i = 1, #playerSlots do
        for j = 1, #playerSlots[i] do
            playerSlots[i][j].isBusy = false
        end
    end
end

local function prepareEntity(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false
    end

    SetEntityAsMissionEntity(entity, true, true)
    FreezeEntityPosition(entity, false)
    SetEntityDynamic(entity, true)
    SetEntityCollision(entity, false, false)
    SetEntityAlpha(entity, 255, false)
    SetEntityVisible(entity, true, false)
    ActivatePhysics(entity)

    return true
end

function Utils.removeEntities(data)
    if not data then return end

    for i = 1, #data do
        local entry = data[i]
        local entity = entry and entry.entity

        if entity and DoesEntityExist(entity) then
            SetEntityAsMissionEntity(entity, true, true)
            DeleteEntity(entity)
        end
    end
end

function Utils.hasFlashLight(components)
    if not components or next(components) == nil then return false end
    for i = 1, #components do
        local component = components[i]
        if type(component) == 'string' and component:find('flashlight') then
            return true
        end
    end
    return false
end

function Utils.checkFlashState(weapon)
    local flashState = LocalPlayer and LocalPlayer.state and LocalPlayer.state.flashState
    if flashState and weapon and weapon.serial and Utils.hasFlashLight(weapon.components) and flashState[weapon.serial] then
        return true
    end
    return false
end

function Utils.hasVarMod(hash, components)
    if not components or #components == 0 then return nil end

    for i = 1, #components do
        local compId = components[i]
        local component = ox_items and ox_items[compId]
        if not component then goto continue end

        if component.type == 'skin' or component.type == 'upgrade' then
            local weaponComp = component.client and component.client.component
            if weaponComp then
                for j = 1, #weaponComp do
                    if DoesWeaponTakeWeaponComponent(hash, weaponComp[j]) then
                        return GetWeaponComponentTypeModel(weaponComp[j])
                    end
                end
            end
        end
        ::continue::
    end
    return nil
end

function Utils.getWeaponComponents(name, hash, components)
    local weaponComponents = {}
    local amount = 0
    local hadClip = false
    local varMod = Utils.hasVarMod(hash, components)

    if components then
        for i = 1, #components do
            local compId = components[i]
            local compDef = ox_items and ox_items[compId]
            if not compDef then goto skip end

            local compClient = compDef.client and compDef.client.component
            if not compClient then goto skip end

            for j = 1, #compClient do
                if DoesWeaponTakeWeaponComponent(hash, compClient[j]) and varMod ~= compClient[j] then
                    amount += 1
                    weaponComponents[amount] = compClient[j]
                    if compDef.type == 'magazine' then hadClip = true end
                    break
                end
            end
            ::skip::
        end
    end

    if not hadClip then
        amount += 1
        local suffix = name and name:sub(8) or ''
        weaponComponents[amount] = joaat(('COMPONENT_%s_CLIP_01'):format(suffix))
    end

    return varMod, weaponComponents, hadClip
end

function Utils.findOpenSlot(tier)
    local tierSlots = playerSlots[tier]
    if not tierSlots then return nil end

    for i = 1, #tierSlots do
        if not tierSlots[i].isBusy then
            tierSlots[i].isBusy = true
            return tierSlots[i]
        end
    end

    tierSlots[#tierSlots].isBusy = true
    return tierSlots[#tierSlots]
end

function Utils.formatData(itemData, itemConfig, ignoreSlot)
    if not itemData then return nil end

    local name = itemData.name
    local isWeapon = name and name:find('WEAPON_')
    local metadata = itemData.metadata or {}

    local slot = nil
    if not ignoreSlot and itemConfig and itemConfig.slot then
        slot = Utils.findOpenSlot(itemConfig.slot)
    end

    return {
        name = name,
        hash = isWeapon and itemConfig and itemConfig.hash or joaat(name or ''),
        components = isWeapon and metadata.components or nil,
        tint = isWeapon and metadata.tint or nil,
        serial = isWeapon and metadata.serial or 'unknown',
        model = itemConfig and itemConfig.model or nil,
        pos = (itemConfig and itemConfig.pos) or (slot and slot.pos),
        rot = (itemConfig and itemConfig.rot) or (slot and slot.rot),
        bone = (itemConfig and itemConfig.bone) or (slot and slot.bone),
    }
end

function Utils.getEntityFromStateBag(bagName, keyName)
    if not bagName or not keyName then return nil end

    if tostring(bagName):find('entity:') then
        local netId = tonumber(tostring(bagName):gsub('entity:', ''), 10)
        if not netId then return nil end

        local entity = lib.waitFor(function()
            if NetworkDoesEntityExistWithNetworkId(netId) then
                return NetworkGetEntityFromNetworkId(netId)
            end
        end, ('%s invalid entity (%s)'):format(keyName, bagName), 10000)

        return entity
    elseif tostring(bagName):find('player:') then
        local serverId = tonumber(tostring(bagName):gsub('player:', ''), 10)
        if not serverId then return nil end

        local playerId = GetPlayerFromServerId(serverId)
        local ped = lib.waitFor(function()
            local p = GetPlayerPed(playerId)
            if p and p > 0 then return p end
        end, ('%s invalid ped (%s)'):format(keyName, bagName), 10000)

        return serverId, ped
    end
end

function Utils.AttachEntityToPlayer(item, entity, pedHandle)
    if not item or not entity or not pedHandle then return end
    if not DoesEntityExist(entity) or not DoesEntityExist(pedHandle) then return end
    if not prepareEntity(entity) then return end

    local pos, rot = item.pos, item.rot
    if not pos or not rot or not item.bone then return end

    AttachEntityToEntity(
        entity,
        pedHandle,
        GetPedBoneIndex(pedHandle, item.bone),
        pos.x, pos.y, pos.z,
        rot.x, rot.y, rot.z,
        true, true, false, false, 2, true
    )
end

local function createObject(item)
    if not item or not item.model then return 0 end
    lib.requestModel(item.model, 2000)

    local obj = CreateObject(item.model, 0.0, 0.0, 0.0, false, false, false)
    if not prepareEntity(obj) then
        return 0
    end

    SetModelAsNoLongerNeeded(item.model)
    return obj
end

local function createWeapon(item)
    if not item or not item.hash then return 0 end

    local ok, hash = pcall(function()
        return lib.requestWeaponAsset(item.hash, 5000, 31, 0)
    end)

    if not ok or not hash or hash == 0 then
        return 0
    end

    local hasLuxeMod, components, hadClip = Utils.getWeaponComponents(item.name, hash, item.components)

    if hasLuxeMod then
        lib.requestModel(hasLuxeMod, 500)
    end

    local showDefault = not (hasLuxeMod and hadClip)

    local weaponObject = CreateWeaponObject(
        hash, 0,
        0.0, 0.0, 0.0,
        showDefault, 1.0,
        hasLuxeMod or 0,
        false, true
    )

    if not prepareEntity(weaponObject) then
        RemoveWeaponAsset(hash)
        return 0
    end

    if components then
        for i = 1, #components do
            pcall(function()
                GiveWeaponComponentToWeaponObject(weaponObject, components[i])
            end)
        end
    end

    if item.tint then
        pcall(function()
            SetWeaponObjectTintIndex(weaponObject, item.tint)
        end)
    end

    if Utils.checkFlashState(item) then
        pcall(function()
            SetCreateWeaponObjectLightSource(weaponObject, true)
        end)
        Wait(0)
    end

    if hasLuxeMod then
        SetModelAsNoLongerNeeded(hasLuxeMod)
    end

    RemoveWeaponAsset(hash)

    return weaponObject
end

function Utils.getEntity(payload)
    if not payload then return 0 end

    local entity = 0

    if payload.model then
        entity = createObject(payload)
    elseif payload.hash then
        entity = createWeapon(payload)
    end

    if entity and entity ~= 0 and DoesEntityExist(entity) then
        return entity
    end

    return 0
end

return Utils