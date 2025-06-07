local ESX, QBCore
if Config.Framework == "ESX" then
    ESX = exports["es_extended"]:getSharedObject()
elseif Config.Framework == "QB" then
    QBCore = exports['qb-core']:GetCoreObject()
end

function HasAdminPermission(source)
    if Config.Framework == "ESX" then
        local xPlayer = ESX.GetPlayerFromId(source)
        return xPlayer and (xPlayer.getGroup() == Config.AdminPermission or xPlayer.getGroup() == "superadmin")
    elseif Config.Framework == "QB" then
        return QBCore.Functions.HasPermission(source, Config.AdminPermission)
    end
    return false
end

RegisterCommand(Config.AdminCommand, function(source, args, rawCommand)
    if HasAdminPermission(source) then
        TriggerClientEvent('drug_labs:client:openAdminMenu', source, _G.ActiveDrugLabs)
    else
        ShowNotification(source, {description = Strings['admin_must_be_admin'], type = 'error'})
    end
end, false)

RegisterNetEvent('drug_labs:server:adminCreateLab', function(labDetails)
    local src = source
    if not HasAdminPermission(src) then return end

    local labType = labDetails.type:lower()
    local price = tonumber(labDetails.price)
    local coords = labDetails.coords

    if not Config.DrugTypes[labType] then
        local validTypes = ""
        for k, _ in pairs(Config.DrugTypes) do validTypes = validTypes .. k .. ", " end
        ShowNotification(src, {description = Strings['admin_invalid_lab_type']:format(validTypes:sub(1, -3)), type = 'error'})
        return
    end
    if not price or price <= 0 then ShowNotification(src, {description = Strings['invalid_input'], type = 'error'}); return end

    local stashOffset = vec3(1.0, 1.0, 0.0)
    local processOffset = vec3(-1.0, 1.0, 0.0)
    local stashCoords = coords + stashOffset
    local processCoords = coords + processOffset
    local heading = GetEntityHeading(GetPlayerPed(src))

    MySQL.Async.insert(
        'INSERT INTO drug_labs (type, price, pos_x, pos_y, pos_z, stash_pos_x, stash_pos_y, stash_pos_z, process_pos_x, process_pos_y, process_pos_z, `keys`, mlo_pos_x, mlo_pos_y, mlo_pos_z, mlo_heading, mlo_enter_x, mlo_enter_y, mlo_enter_z, mlo_enter_h, mlo_exit_x, mlo_exit_y, mlo_exit_z, mlo_exit_h) VALUES (@type, @price, @px, @py, @pz, @sx, @sy, @sz, @prx, @pry, @prz, @keys, @mlox, @mloy, @mloz, @mloh, @enterx, @entery, @enterz, @enterh, @exitx, @exity, @exitz, @exith)',
        {
            ['@type'] = labType, ['@price'] = price,
            ['@px'] = coords.x, ['@py'] = coords.y, ['@pz'] = coords.z,
            ['@sx'] = stashCoords.x, ['@sy'] = stashCoords.y, ['@sz'] = stashCoords.z,
            ['@prx'] = processCoords.x, ['@pry'] = processCoords.y, ['@prz'] = processCoords.z,
            ['@keys'] = json.encode({}),
            ['@mlox'] = coords.x, ['@mloy'] = coords.y, ['@mloz'] = coords.z, ['@mloh'] = heading,
            ['@enterx'] = 0, ['@entery'] = 0, ['@enterz'] = 0, ['@enterh'] = 0,
            ['@exitx'] = 0, ['@exity'] = 0, ['@exitz'] = 0, ['@exith'] = 0
        },
        function(newLabId)
            if newLabId then
                ShowNotification(src, {description = Strings['admin_lab_created_success']:format(Config.DrugTypes[labType].label, newLabId), type = 'success'})
                LoadLabsFromDB()
            else
                ShowNotification(src, {description = Strings['admin_error_creating_lab'], type = 'error'})
            end
        end
    )
end)

RegisterNetEvent('drug_labs:server:adminDeleteLab', function(labId)
    local src = source
    if not HasAdminPermission(src) then return end

    local lab = _G.ActiveDrugLabs[labId]
    if not lab then ShowNotification(src, {description = "Lab not found.", type = 'error'}); return end

    lab.owner_identifier = nil
    lab.owner_name = nil
    lab.keys = {}
    lab.stock_raw = 0
    lab.stock_packaged = 0

    MySQL.Async.execute(
        'UPDATE drug_labs SET owner_identifier = NULL, owner_name = NULL, `keys` = @keys, stock_raw = 0, stock_packaged = 0 WHERE id = @labId',
        { ['@keys'] = json.encode(lab.keys), ['@labId'] = labId },
        function(affectedRows)
            if affectedRows > 0 then
                ShowNotification(src, {description = Strings['admin_lab_deleted']:format(labId), type = 'success'})
                UpdateAndBroadcastLabChange(labId)
            else
                ShowNotification(src, {description = "Database error deleting lab.", type = 'error'})
            end
        end
    )
end)

RegisterNetEvent('drug_labs:server:adminPermanentDeleteLab', function(labId)
    local src = source
    if not HasAdminPermission(src) then return end

    MySQL.Async.execute(
        'DELETE FROM drug_labs WHERE id = @labId',
        { ['@labId'] = labId },
        function(affectedRows)
            if affectedRows > 0 then
                _G.ActiveDrugLabs[labId] = nil
                TriggerClientEvent('drug_labs:client:updateLabState', -1, labId, nil)
                ShowNotification(src, {description = "Lab ID " .. labId .. " permanently deleted", type = 'success'})
            else
                ShowNotification(src, {description = "Error deleting lab", type = 'error'})
            end
        end
    )
end)

RegisterNetEvent('drug_labs:server:adminRevokeKey', function(labId, keyHolderIdentifier)
    local src = source
    if not HasAdminPermission(src) then return end

    local success, message = RevokeKeyInternal(labId, keyHolderIdentifier, nil)
    if success then
        ShowNotification(src, {description = ("Admin: Key for %s revoked from lab ID %s."):format(keyHolderIdentifier, labId), type = 'success'})
    else
        ShowNotification(src, {description = ("Admin: Failed to revoke key. %s"):format(message or ""), type = 'error'})
    end
end)

RegisterNetEvent('drug_labs:server:adminSetStashPos', function(labId, newCoords)
    local src = source
    if not HasAdminPermission(src) then return end
    if not _G.ActiveDrugLabs or not _G.ActiveDrugLabs[labId] then
        ShowNotification(src, {description = "Lab not found.", type = 'error'})
        return
    end

    local lab = _G.ActiveDrugLabs[labId]
    lab.stash_pos_x = newCoords.x
    lab.stash_pos_y = newCoords.y
    lab.stash_pos_z = newCoords.z

    MySQL.Async.execute(
        'UPDATE drug_labs SET stash_pos_x = @sx, stash_pos_y = @sy, stash_pos_z = @sz WHERE id = @labId',
        {
            ['@sx'] = lab.stash_pos_x, ['@sy'] = lab.stash_pos_y, ['@sz'] = lab.stash_pos_z,
            ['@labId'] = labId
        },
        function(affectedRows)
            if affectedRows > 0 then
                ShowNotification(src, {description = Strings['admin_pos_updated_stash']:format(labId), type = 'success'})
                UpdateAndBroadcastLabChange(labId)
            else
                ShowNotification(src, {description = Strings['admin_error_updating_pos']:format(labId), type = 'error'})
            end
        end
    )
end)

RegisterNetEvent('drug_labs:server:adminSetProcessPos', function(labId, newCoords)
    local src = source
    if not HasAdminPermission(src) then return end
    if not _G.ActiveDrugLabs or not _G.ActiveDrugLabs[labId] then
        ShowNotification(src, {description = "Lab not found.", type = 'error'})
        return
    end

    local lab = _G.ActiveDrugLabs[labId]
    lab.process_pos_x = newCoords.x
    lab.process_pos_y = newCoords.y
    lab.process_pos_z = newCoords.z

    MySQL.Async.execute(
        'UPDATE drug_labs SET process_pos_x = @prx, process_pos_y = @pry, process_pos_z = @prz WHERE id = @labId',
        {
            ['@prx'] = lab.process_pos_x, ['@pry'] = lab.process_pos_y, ['@prz'] = lab.process_pos_z,
            ['@labId'] = labId
        },
        function(affectedRows)
            if affectedRows > 0 then
                ShowNotification(src, {description = Strings['admin_pos_updated_process']:format(labId), type = 'success'})
                UpdateAndBroadcastLabChange(labId)
            else
                ShowNotification(src, {description = Strings['admin_error_updating_pos']:format(labId), type = 'error'})
            end
        end
    )
end)

RegisterNetEvent('drug_labs:server:adminSetMloEnterPos', function(labId, newCoords, newHeading)
    local src = source
    if not HasAdminPermission(src) then return end
    if not _G.ActiveDrugLabs or not _G.ActiveDrugLabs[labId] then
        ShowNotification(src, {description = "Lab not found.", type = 'error'})
        return
    end

    local lab = _G.ActiveDrugLabs[labId]
    lab.mlo_enter_x = newCoords.x
    lab.mlo_enter_y = newCoords.y
    lab.mlo_enter_z = newCoords.z
    lab.mlo_enter_h = newHeading

    MySQL.Async.execute(
        'UPDATE drug_labs SET mlo_enter_x = @x, mlo_enter_y = @y, mlo_enter_z = @z, mlo_enter_h = @h WHERE id = @labId',
        {
            ['@x'] = lab.mlo_enter_x, ['@y'] = lab.mlo_enter_y, ['@z'] = lab.mlo_enter_z,
            ['@h'] = lab.mlo_enter_h, ['@labId'] = labId
        },
        function(affectedRows)
            if affectedRows > 0 then
                ShowNotification(src, {description = "Enter position updated for Lab ID " .. labId, type = 'success'})
                UpdateAndBroadcastLabChange(labId)
            else
                ShowNotification(src, {description = "Error updating enter position.", type = 'error'})
            end
        end
    )
end)

RegisterNetEvent('drug_labs:server:adminSetMloExitPos', function(labId, newCoords, newHeading)
    local src = source
    if not HasAdminPermission(src) then return end
    if not _G.ActiveDrugLabs or not _G.ActiveDrugLabs[labId] then
        ShowNotification(src, {description = "Lab not found.", type = 'error'})
        return
    end

    local lab = _G.ActiveDrugLabs[labId]
    lab.mlo_exit_x = newCoords.x
    lab.mlo_exit_y = newCoords.y
    lab.mlo_exit_z = newCoords.z
    lab.mlo_exit_h = newHeading

    MySQL.Async.execute(
        'UPDATE drug_labs SET mlo_exit_x = @x, mlo_exit_y = @y, mlo_exit_z = @z, mlo_exit_h = @h WHERE id = @labId',
        {
            ['@x'] = lab.mlo_exit_x, ['@y'] = lab.mlo_exit_y, ['@z'] = lab.mlo_exit_z,
            ['@h'] = lab.mlo_exit_h, ['@labId'] = labId
        },
        function(affectedRows)
            if affectedRows > 0 then
                ShowNotification(src, {description = "Exit position updated for Lab ID " .. labId, type = 'success'})
                UpdateAndBroadcastLabChange(labId)
            else
                ShowNotification(src, {description = "Error updating exit position.", type = 'error'})
            end
        end
    )
end)
