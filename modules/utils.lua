-- utils.lua
local ox_items = exports.ox_inventory and exports.ox_inventory:Items() or {}
local Utils = {}

local playerSlots = {
    -- 1
    {
        { bone = 24817, pos = vec3(0.04, -0.15, 0.12), rot = vec3(0.0, 0.0, 0.0) },
        { bone = 24817, pos = vec3(0.04, -0.17, 0.02), rot = vec3(0.0, 0.0, 0.0) },
        { bone = 24817, pos = vec3(0.04, -0.19, -0.08), rot = vec3(0.0, 0.0, 0.0) },
    },

    -- 2
    {
        { bone = 24818, pos = vec3(0.30, -0.16, 0.10), rot = vec3(0.0, 115.0, 180.0) },
        { bone = 24818, pos = vec3(0.30, -0.16, -0.12), rot = vec3(0.0, 295.0, 0.0) },
    },

    -- 3
    {
        { bone = 24818, pos = vec3(-0.28, -0.14, 0.15), rot = vec3(0.0, 92.0, -13.0) },
        { bone = 24818, pos = vec3(-0.28, -0.14, 0.12), rot = vec3(0.0, 92.0, 13.0) },
    },

    -- 4 (duplicate fixed with variation)
    {
        { bone = 24818, pos = vec3(0.30, -0.16, 0.10), rot = vec3(0.0, 100.0, 100.0) },
        { bone = 24818, pos = vec3(0.32, -0.14, 0.12), rot = vec3(0.0, 100.0, 120.0) },
    },

    -- 5
    {
        { bone = 24818, pos = vec3(-0.30, -0.16, 0.10), rot = vec3(0.0, 115.0, 0.0) },
        { bone = 24818, pos = vec3(-0.30, -0.16, -0.12), rot = vec3(0.0, 295.0, 180.0) },
    },

    -- 6
    {
        { bone = 24818, pos = vec3(-0.80, -0.16, 0.10), rot = vec3(0.0, 90.0, 0.0) },
        { bone = 24818, pos = vec3(-0.65, -0.16, -0.12), rot = vec3(0.0, 295.0, 180.0) },
    },
}

-- initialize isBusy
for i = 1, #playerSlots do
    for v = 1, #playerSlots[i] do
        playerSlots[i][v].isBusy = false
    end
end

function Utils.resetSlots()
    for i = 1, #playerSlots do
        for v = 1, #playerSlots[i] do
            playerSlots[i][v].isBusy = false
        end
    end
end

function Utils.removeEntities(data)
    if not data then return end
    for i = 1, #data do
        local entry = data[i]
        local entity = entry and entry.entity
        if entity and DoesEntityExist(entity) then
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
        if not component then goto continue_hasvar end

        local ctype = component.type
        if ctype == 'skin' or ctype == 'upgrade' then
            local weaponComp = component.client and component.client.component
            if not weaponComp or #weaponComp == 0 then goto continue_hasvar end

            for j = 1, #weaponComp do
                local weaponComponent = weaponComp[j]
                if DoesWeaponTakeWeaponComponent(hash, weaponComponent) then
                    return GetWeaponComponentTypeModel(weaponComponent)
                end
            end
        end

        ::continue_hasvar::
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
            if not compDef then goto continue_getwc end

            local compClientComponents = compDef.client and compDef.client.component
            if not compClientComponents then goto continue_getwc end

            for j = 1, #compClientComponents do
                local weaponComponent = compClientComponents[j]
                if DoesWeaponTakeWeaponComponent(hash, weaponComponent) and varMod ~= weaponComponent then
                    amount = amount + 1
                    weaponComponents[amount] = weaponComponent

                    if compDef.type == 'magazine' then
                        hadClip = true
                    end

                    break -- found component for this compDef
                end
            end

            ::continue_getwc::
        end
    end

    if not hadClip then
        amount = amount + 1
        local suffix = name and name:sub(8) or ''
        weaponComponents[amount] = joaat(('COMPONENT_%s_CLIP_01'):format(suffix))
    end

    -- ensure table always returned
    return varMod, weaponComponents, hadClip
end

function Utils.findOpenSlot(tier)
    local slotTier = playerSlots[tier]

    if slotTier then
        local slotAmount = #slotTier

        for i = 1, slotAmount do
            local slot = slotTier[i]
            if not slot.isBusy then
                slot.isBusy = true
                return slot
            end
        end

        -- fallback: ensure last slot marked busy before returning
        slotTier[slotAmount].isBusy = true
        return slotTier[slotAmount]
    end

    return nil
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
        end, ('%s received invalid entity! (%s)'):format(keyName, bagName), 10000)

        return entity
    elseif tostring(bagName):find('player:') then
        local serverId = tonumber(tostring(bagName):gsub('player:', ''), 10)
        if not serverId then return nil end

        local playerId = GetPlayerFromServerId(serverId)
        local entity = lib.waitFor(function()
            local ped = GetPlayerPed(playerId)
            if ped and ped > 0 then return ped end
        end, ('%s received invalid entity! (%s)'):format(keyName, bagName), 10000)

        return serverId, entity
    end

    return nil
end

function Utils.AttachEntityToPlayer(item, entity, pedHandle)
    if not item or not entity or not pedHandle then return end
    local pos, rot = item.pos, item.rot

    if pos and rot and item.bone then
        AttachEntityToEntity(entity, pedHandle, GetPedBoneIndex(pedHandle, item.bone),
            pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, true, true, false, false, 2, true)
    end
end

local function createObject(item)
    if not item or not item.model then return 0 end
    lib.requestModel(item.model, 1000)
    local Object = CreateObject(item.model, 0.0, 0.0, 0.0, false, false, false)
    SetModelAsNoLongerNeeded(item.model)
    return Object
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

    local showDefault = true
    if hasLuxeMod and hadClip then
        showDefault = false
    end

    -- create weapon object
    local weaponObject = CreateWeaponObject(hash, 0, 0.0, 0.0, 0.0, showDefault, 1.0, hasLuxeMod or 0, false, true)

    -- give components (defensive: ensure components table)
    if components and #components > 0 then
        for i = 1, #components do
            local comp = components[i]
            if comp then
                pcall(function()
                    GiveWeaponComponentToWeaponObject(weaponObject, comp)
                end)
            end
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
        Wait(0) -- skip a frame so the light source is created before attaching
    end

    if hasLuxeMod then
        SetModelAsNoLongerNeeded(hasLuxeMod)
    end

    RemoveWeaponAsset(hash)

    return weaponObject or 0
end

function Utils.getEntity(payload)
    if not payload then return 0 end

    if payload.model then
        return createObject(payload)
    elseif payload.hash then
        return createWeapon(payload)
    end

    return 0
end

return Utils
