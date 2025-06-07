local currentAdminLabsCache = {}

RegisterNetEvent('drug_labs:client:openAdminMenu', function(labsData)
    currentAdminLabsCache = labsData or {}
    local options = {
        {
            title = Strings['admin_menu_title'],
            icon = 'fas fa-user-shield',
            disabled = true,
        },
        {
            title = Strings['admin_create_lab'],
            icon = 'fas fa-plus-circle',
            onSelect = function() AdminCreateLabPrompt() end
        },
        {
            title = Strings['admin_view_labs'],
            icon = 'fas fa-eye',
            onSelect = function() AdminViewLabsList() end,
            disabled = (not currentAdminLabsCache or next(currentAdminLabsCache) == nil)
        }
    }

    exports.ox_lib:registerContext({
        id = 'drug_lab_admin_main_menu',
        title = Strings['admin_menu_title'],
        options = options
    })
    exports.ox_lib:showContext('drug_lab_admin_main_menu')
end)

function AdminCreateLabPrompt()
    Citizen.CreateThread(function()
        local selectOptionsForDialog = {}
        if Config.DrugTypes and type(Config.DrugTypes) == 'table' then
            for typeKey, data in pairs(Config.DrugTypes) do
                table.insert(selectOptionsForDialog, { value = typeKey, label = data.label })
            end
        else
            print("[DrugLabs][Admin] Error: Config.DrugTypes is not defined or not a table.")
            ShowNotification(nil, {description = "Error: Lab types not configured.", type = 'error'})
            return
        end

        if #selectOptionsForDialog == 0 then
            print("[DrugLabs][Admin] Error: No drug types found in Config.DrugTypes for admin select dialog.")
            ShowNotification(nil, {description = "Error: No lab types available to create.", type = 'error'})
            return
        end

        Citizen.CreateThread(function()
            local input = exports.ox_lib:inputDialog(Strings['admin_create_lab'], {
                { type = 'select', label = Strings['admin_lab_type_prompt'], required = true, options = selectOptionsForDialog },
                { type = 'number', label = Strings['admin_lab_price_prompt'], required = true, min = 1, icon = 'fas fa-dollar-sign' }
            })

            local timeout = 500
            while input == nil and timeout > 0 do
                Citizen.Wait(10)
                timeout = timeout - 1
            end

            if input and type(input) == 'table' and input[1] and input[2] then
                local labType = input[1]
                local price = tonumber(input[2])
                local playerPed = PlayerPedId()
                local coords = GetEntityCoords(playerPed)

                TriggerServerEvent('drug_labs:server:adminCreateLab', {type = labType, price = price, coords = coords})
            elseif input == false then
            elseif input == nil and timeout == 0 then
                ShowNotification(nil, {description = "Input dialog timed out.", type = 'warning'})
            else
                ShowNotification(nil, {description = Strings['invalid_input'], type = 'error'})
            end
        end) 
    end) 
end 

function AdminViewLabsList()
    if not currentAdminLabsCache or next(currentAdminLabsCache) == nil then
        ShowNotification(nil, {description = Strings['admin_no_active_labs'], type = 'inform'})
        return
    end

    local labOptions = {
        {
            title = Strings['admin_view_labs'],
            icon = 'fas fa-clipboard-list',
            disabled = true
        }
    }

    for labId, labData in pairs(currentAdminLabsCache) do
        if labData then
            local labTypeConfig = Config.DrugTypes[labData.type]
            local ownerText = labData.owner_name and ("Owner: %s (%s)"):format(labData.owner_name, labData.owner_identifier) or "Owner: Unowned"
            local label = ("ID: %s | Type: %s | %s"):format(labId, labTypeConfig and labTypeConfig.label or labData.type, ownerText)
            table.insert(labOptions, {
                title = label,
                description = ("Stash: %s raw, %s packaged | Keys: %s"):format(labData.stock_raw, labData.stock_packaged, #(labData.keys or {})),
                icon = labTypeConfig and labTypeConfig.target_icon or Config.TargetIcon,
                onSelect = function() AdminShowLabDetails(labId) end
            })
        end
    end

    exports.ox_lib:registerContext({
        id = 'drug_lab_admin_view_labs_list',
        title = Strings['admin_view_labs'],
        options = labOptions
    })
    exports.ox_lib:showContext('drug_lab_admin_view_labs_list')
end 

function AdminShowLabDetails(labId)
    local labData = currentAdminLabsCache[labId]
    if not labData then ShowNotification(nil, {description = "Lab not found in cache.", type = 'error'}); return end

    local labTypeConfig = Config.DrugTypes[labData.type]
    local detailOptions = {
        {
            title = Strings['admin_lab_details_title']:format(labId) .. " (" .. (labTypeConfig and labTypeConfig.label or labData.type) .. ")",
            icon = labTypeConfig and labTypeConfig.target_icon or Config.TargetIcon,
            disabled = true
        },
        {
            title = labData.owner_name and Strings['admin_lab_owner']:format(labData.owner_name, labData.owner_identifier) or Strings['admin_lab_unowned'],
            icon = 'fas fa-user-tie',
            disabled = true
        },
        {
            title = ("Price: $%s | Raw: %s | Packaged: %s"):format(labData.price, labData.stock_raw, labData.stock_packaged),
            icon = 'fas fa-info-circle',
            disabled = true
        },
        {
            title = Strings['admin_edit_lab_positions'],
            icon = 'fas fa-map-marker-alt',
            onSelect = function() AdminEditPositionsMenu(labId) end
        },
        {
            title = Strings['admin_delete_lab'],
            icon = 'fas fa-trash-alt',
            color = 'orange',
            onSelect = function()
                Citizen.CreateThread(function()
                    local confirm = exports.ox_lib:alertDialog({
                        header = Strings['admin_delete_lab'],
                        content = Strings['admin_confirm_delete_lab']:format(labId),
                        centered = true, cancel = true, type = 'warning',
                        labels = { confirm = "Yes, Reset", cancel = "No" }
                    })
                    if confirm == "confirm" then
                        TriggerServerEvent('drug_labs:server:adminDeleteLab', labId)
                    end
                end)
            end
        },
        {
            title = "Delete Lab Permanently",
            icon = 'fas fa-trash',
            color = 'red',
            onSelect = function()
                Citizen.CreateThread(function()
                    local confirm = exports.ox_lib:alertDialog({
                        header = "Permanent Deletion",
                        content = "Are you sure? This will completely remove the lab from the database!",
                        centered = true, cancel = true, type = 'error',
                        labels = { confirm = "Delete", cancel = "Cancel" }
                    })
                    if confirm == "confirm" then
                        TriggerServerEvent('drug_labs:server:adminPermanentDeleteLab', labId)
                    end
                end)
            end
        }
    }


    table.insert(detailOptions, {
        title = ("MLO Position: X:%.1f Y:%.1f Z:%.1f"):format(labData.mlo_pos_x or 0, labData.mlo_pos_y or 0, labData.mlo_pos_z or 0),
        icon = 'fas fa-map-pin',
        disabled = true
    })
    table.insert(detailOptions, {
        title = ("Enter Position: X:%.1f Y:%.1f Z:%.1f"):format(labData.mlo_enter_x or 0, labData.mlo_enter_y or 0, labData.mlo_enter_z or 0),
        icon = 'fas fa-sign-in-alt',
        disabled = true
    })
    table.insert(detailOptions, {
        title = ("Exit Position: X:%.1f Y:%.1f Z:%.1f"):format(labData.mlo_exit_x or 0, labData.mlo_exit_y or 0, labData.mlo_exit_z or 0),
        icon = 'fas fa-sign-out-alt',
        disabled = true
    })

    table.insert(detailOptions, { title = Strings['admin_lab_keys_list'], icon = 'fas fa-key', disabled = true })
    if labData.keys and #labData.keys > 0 then
        for _, keyHolderId in ipairs(labData.keys) do
            table.insert(detailOptions, {
                title = Strings['admin_revoke_key_from']:format(keyHolderId),
                description = "Identifier: " .. keyHolderId,
                icon = 'fas fa-user-minus',
                color = 'orange',
                onSelect = function()
                    TriggerServerEvent('drug_labs:server:adminRevokeKey', labId, keyHolderId)
                end
            })
        end
    else
        table.insert(detailOptions, { title = Strings['admin_lab_no_keys'], icon = 'fas fa-times-circle', disabled = true })
    end

    exports.ox_lib:registerContext({
        id = 'drug_lab_admin_lab_details_' .. labId,
        title = Strings['admin_lab_details_title']:format(labId),
        options = detailOptions
    })
    exports.ox_lib:showContext('drug_lab_admin_lab_details_' .. labId)
end

function AdminEditPositionsMenu(labId)
    local labData = currentAdminLabsCache[labId]
    if not labData then ShowNotification(nil, {description = "Lab not found in cache.", type = 'error'}); return end

    local positionOptions = {
        {
            title = Strings['admin_edit_lab_positions'] .. " - ID: " .. labId,
            icon = 'fas fa-map-marked-alt',
            disabled = true
        },
        {
            title = Strings['admin_set_stash_pos'],
            description = ("Current Stash: X:%.1f Y:%.1f Z:%.1f"):format(labData.stash_pos_x or 0, labData.stash_pos_y or 0, labData.stash_pos_z or 0),
            icon = 'fas fa-archive',
            onSelect = function()
                local playerPed = PlayerPedId()
                local currentCoords = GetEntityCoords(playerPed)
                TriggerServerEvent('drug_labs:server:adminSetStashPos', labId, currentCoords)
                Citizen.Wait(500)
                TriggerServerEvent('drug_labs:server:requestAdminLabsForMenu', source) 
            end
        },
        {
            title = Strings['admin_set_process_pos'],
            description = ("Current Process: X:%.1f Y:%.1f Z:%.1f"):format(labData.process_pos_x or 0, labData.process_pos_y or 0, labData.process_pos_z or 0),
            icon = 'fas fa-cogs',
            onSelect = function()
                local playerPed = PlayerPedId()
                local currentCoords = GetEntityCoords(playerPed)
                TriggerServerEvent('drug_labs:server:adminSetProcessPos', labId, currentCoords)
                Citizen.Wait(500)
                TriggerServerEvent('drug_labs:server:requestAdminLabsForMenu', source)
            end
        },
        {
            title = "Set MLO Position (Current Location)",
            description = "Sets main exterior position",
            icon = 'fas fa-map-pin',
            onSelect = function()
                local playerPed = PlayerPedId()
                local currentCoords = GetEntityCoords(playerPed)
                local heading = GetEntityHeading(playerPed)
                TriggerServerEvent('drug_labs:server:adminSetMloPos', labId, currentCoords, heading)
                Citizen.Wait(500)
                TriggerServerEvent('drug_labs:server:requestAdminLabsForMenu', source)
            end
        },
        {
            title = "Set Enter Lab Position (Current Location)",
            description = "Sets the interior entrance position (where player enters the lab)",
            icon = 'fas fa-door-open',
            onSelect = function()
                local playerPed = PlayerPedId()
                local currentCoords = GetEntityCoords(playerPed)
                local heading = GetEntityHeading(playerPed)
                TriggerServerEvent('drug_labs:server:adminSetMloEnterPos', labId, currentCoords, heading)
                Citizen.Wait(500)
                TriggerServerEvent('drug_labs:server:requestAdminLabsForMenu', source)
            end
        },
        {
            title = "Set Exit Lab Position (Current Location)",
            description = "Sets the exterior exit position (where player exits the lab)",
            icon = 'fas fa-door-open',
            onSelect = function()
                local playerPed = PlayerPedId()
                local currentCoords = GetEntityCoords(playerPed)
                local heading = GetEntityHeading(playerPed)
                TriggerServerEvent('drug_labs:server:adminSetMloExitPos', labId, currentCoords, heading)
                Citizen.Wait(500)
                TriggerServerEvent('drug_labs:server:requestAdminLabsForMenu', source)
            end
        },
        {
            title = "Back to Lab Details",
            icon = 'fas fa-arrow-left',
            onSelect = function() AdminShowLabDetails(labId) end
        }
    }

    exports.ox_lib:registerContext({
        id = 'drug_lab_admin_edit_positions_menu_' .. labId,
        title = Strings['admin_edit_lab_positions'],
        options = positionOptions
    })
    exports.ox_lib:showContext('drug_lab_admin_edit_positions_menu_' .. labId)
end
