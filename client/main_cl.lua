local PlayerData = {}
local CurrentLabs = {}
local PlayerLoaded = false
local MyIdentifier = nil
local MyMoney = 0
local isProcessingDrug = false
local insideLab = {}

Citizen.CreateThread(function()
    if Config.Framework == "ESX" then
        ESX = exports.es_extended:getSharedObject()
        while ESX == nil do Citizen.Wait(100) end
        while not ESX.IsPlayerLoaded() do Citizen.Wait(100) end
        PlayerData = ESX.GetPlayerData()
        MyIdentifier = PlayerData.identifier
        MyMoney = PlayerData.money
        PlayerLoaded = true

        RegisterNetEvent('esx:playerLoaded', function(xPlayer)
            PlayerData = xPlayer
            MyIdentifier = PlayerData.identifier
            MyMoney = PlayerData.money
            TriggerServerEvent('drug_labs:server:requestLabs')
            UpdateAllTargetZones()
        end)

        RegisterNetEvent('esx:setMoney')
        AddEventHandler('esx:setMoney', function(money)
            MyMoney = money
            if PlayerData then PlayerData.money = money end
            UpdateAllTargetZones()
        end)

    elseif Config.Framework == "QB" then
        QBCore = exports['qb-core']:GetCoreObject()
        while QBCore == nil do Citizen.Wait(100) end
        while true do
            PlayerData = QBCore.Functions.GetPlayerData()
            if PlayerData and PlayerData.citizenid then break end
            Citizen.Wait(100)
        end
        MyIdentifier = PlayerData.citizenid
        MyMoney = (PlayerData.money and (PlayerData.money.cash + PlayerData.money.bank)) or 0
        PlayerLoaded = true

        RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
        AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
            PlayerData = QBCore.Functions.GetPlayerData()
            MyIdentifier = PlayerData.citizenid
            MyMoney = (PlayerData.money and (PlayerData.money.cash + PlayerData.money.bank)) or 0
            TriggerServerEvent('drug_labs:server:requestLabs')
            UpdateAllTargetZones()
        end)

        RegisterNetEvent('QBCore:Player:SetPlayerData')
        AddEventHandler('QBCore:Player:SetPlayerData', function(playerData)
            PlayerData = playerData
            MyIdentifier = PlayerData.citizenid
            MyMoney = (PlayerData.money and (PlayerData.money.cash + PlayerData.money.bank)) or 0
            UpdateAllTargetZones()
        end)
    end

    if PlayerLoaded then
        TriggerServerEvent('drug_labs:server:requestLabs')
    end
end)

RegisterNetEvent('drug_labs:client:updateLabs')
AddEventHandler('drug_labs:client:updateLabs', function(labsData)
    CurrentLabs = labsData or {}
    CreateBlipsAndTargets()
end)

RegisterNetEvent('drug_labs:client:updateLabState')
AddEventHandler('drug_labs:client:updateLabState', function(labId, labData)
    if not labData then
        if CurrentLabs[labId] then
            if CurrentLabs[labId].blip and DoesBlipExist(CurrentLabs[labId].blip) then RemoveBlip(CurrentLabs[labId].blip) end
            exports.ox_target:removeZone('drug_lab_main_' .. labId)
            exports.ox_target:removeZone('drug_lab_stash_' .. labId)
            exports.ox_target:removeZone('drug_lab_process_' .. labId)
            exports.ox_target:removeZone('drug_lab_enter_' .. labId)
            exports.ox_target:removeZone('drug_lab_exit_' .. labId)
            CurrentLabs[labId] = nil
        end
        return
    end

    if CurrentLabs[labId] and CurrentLabs[labId].blip and DoesBlipExist(CurrentLabs[labId].blip) then RemoveBlip(CurrentLabs[labId].blip) end
    CurrentLabs[labId] = labData
    CreateOrUpdateLabTarget(labId, labData)
    CreateBlipForLab(labId, labData)
end)

function CreateBlipsAndTargets()
    for id, lab in pairs(CurrentLabs) do
        if lab and lab.blip and DoesBlipExist(lab.blip) then RemoveBlip(lab.blip); lab.blip = nil; end
        exports.ox_target:removeZone('drug_lab_main_' .. id)
        exports.ox_target:removeZone('drug_lab_stash_' .. id)
        exports.ox_target:removeZone('drug_lab_process_' .. id)
        exports.ox_target:removeZone('drug_lab_enter_' .. id)
        exports.ox_target:removeZone('drug_lab_exit_' .. id)
    end

    for id, lab in pairs(CurrentLabs) do
        if lab then
            CreateOrUpdateLabTarget(id, lab)
            CreateBlipForLab(id, lab)
        end
    end
end 

function UpdateAllTargetZones()
    if not PlayerLoaded then return end
    for id, labData in pairs(CurrentLabs) do
        if labData then
            CreateOrUpdateLabTarget(id, labData)
        end
    end
end 

function CreateBlipForLab(id, lab)
    if not PlayerLoaded or not lab then return end

    local blipCoord
    if lab.mlo_pos_x and lab.mlo_pos_x ~= 0 then
        blipCoord = vec3(lab.mlo_pos_x, lab.mlo_pos_y, lab.mlo_pos_z)
    else
        blipCoord = vec3(lab.pos_x, lab.pos_y, lab.pos_z)
    end

    if lab.blip and DoesBlipExist(lab.blip) then RemoveBlip(lab.blip) end

    local newBlip = AddBlipForCoord(blipCoord.x, blipCoord.y, blipCoord.z)
    SetBlipSprite(newBlip, Config.BlipSprite)
    SetBlipScale(newBlip, Config.BlipScale)
    SetBlipAsShortRange(newBlip, true)

    local drugCfg = Config.DrugTypes[lab.type]
    local blipText = drugCfg and drugCfg.label or "Drug Lab"
    local blipColor = Config.BlipColorUnowned

    if lab.owner_identifier then
        if lab.owner_identifier == MyIdentifier then
            blipColor = Config.BlipColorOwned
            blipText = "My " .. blipText
        else
            local hasKey = false
            for _, keyId in ipairs(lab.keys or {}) do if keyId == MyIdentifier then hasKey = true; break; end end
            if hasKey then
                blipColor = Config.BlipColorKeyed
                blipText = blipText .. " (Key)"
            else
                blipText = blipText .. " (Owned)"
            end
        end
    else
        blipText = "Unowned " .. blipText
    end

    SetBlipColour(newBlip, blipColor)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(blipText)
    EndTextCommandSetBlipName(newBlip)

    if CurrentLabs[id] then
        CurrentLabs[id].blip = newBlip
    end
end 

function CreateOrUpdateLabTarget(labId, labData)
    if not PlayerLoaded or not labData then return end
    local drugConfig = Config.DrugTypes[labData.type]
    if not drugConfig then print(("[xrb-DrugLabs] Error: Missing drugConfig for type '%s' on lab ID %s"):format(labData.type, labId)); return end

    local mainTargetName = 'drug_lab_main_' .. labId
    local stashTargetName = 'drug_lab_stash_' .. labId
    local processTargetName = 'drug_lab_process_' .. labId
    local enterTargetName = 'drug_lab_enter_' .. labId
    local exitTargetName = 'drug_lab_exit_' .. labId

    exports.ox_target:removeZone(mainTargetName)
    exports.ox_target:removeZone(stashTargetName)
    exports.ox_target:removeZone(processTargetName)
    exports.ox_target:removeZone(enterTargetName)
    exports.ox_target:removeZone(exitTargetName)

    local mainCoords, mainHeading
    if labData.mlo_pos_x and labData.mlo_pos_x ~= 0 then
        mainCoords = vec3(labData.mlo_pos_x, labData.mlo_pos_y, labData.mlo_pos_z)
        mainHeading = labData.mlo_heading or 0
    else
        mainCoords = vec3(labData.pos_x, labData.pos_y, labData.pos_z)
        mainHeading = 0
    end

    local hasKeyAccess = function()
        if not labData.keys then return false end
        for _, keyId in ipairs(labData.keys) do
            if keyId == MyIdentifier then return true end
        end
        return false
    end 

    local mainOptions = {}
    if not labData.owner_identifier then
        table.insert(mainOptions, {
            icon = drugConfig.target_icon or Config.TargetIcon,
            label = Strings['lab_unowned_prompt']:format(drugConfig.label .. " ($" .. labData.price .. ")"),
            onSelect = function() BuyLab(labId, labData.price) end,
            canInteract = function() return not labData.owner_identifier and MyMoney >= labData.price end
        })
    elseif labData.owner_identifier == MyIdentifier then
        if labData.mlo_enter_x and labData.mlo_enter_x ~= 0 then
            table.insert(mainOptions, {
                icon = 'fas fa-door-open',
                label = "Enter Lab",
                onSelect = function() EnterLab(labId) end,
                canInteract = function() return labData.owner_identifier == MyIdentifier end
            })
        end
        
        table.insert(mainOptions, {
            icon = drugConfig.target_icon or Config.TargetIcon,
            label = Strings['lab_manage_prompt']:format(drugConfig.label),
            onSelect = function() OpenOwnerMenu(labId) end,
            canInteract = function() return labData.owner_identifier == MyIdentifier end
        })
    elseif hasKeyAccess() then
        if labData.mlo_enter_x and labData.mlo_enter_x ~= 0 then
            table.insert(mainOptions, {
                icon = 'fas fa-door-open',
                label = "Enter Lab",
                onSelect = function() EnterLab(labId) end,
                canInteract = function() return hasKeyAccess() end
            })
        end
        
        table.insert(mainOptions, {
            icon = drugConfig.target_icon or Config.TargetIcon,
            label = Strings['lab_access_prompt']:format(drugConfig.label),
            onSelect = function() OpenKeyHolderMenu(labId) end,
            canInteract = function() return hasKeyAccess() end
        })
    else
        table.insert(mainOptions, {
            icon = drugConfig.target_icon or Config.TargetIcon,
            label = Strings['owned_by_other']:format(labData.owner_name or 'Someone'),
            canInteract = function() return false end
        })
    end

    exports.ox_target:addBoxZone({
        name = mainTargetName,
        coords = mainCoords,
        size = Config.TargetBoxZoneSize,
        rotation = mainHeading,
        debug = false,
        options = mainOptions,
        distance = Config.TargetDistance
    })


    if labData.mlo_exit_x and labData.mlo_exit_x ~= 0 then
        exports.ox_target:addBoxZone({
            name = exitTargetName,
            coords = vec3(labData.mlo_exit_x, labData.mlo_exit_y, labData.mlo_exit_z),
            size = Config.TargetBoxZoneSize,
            rotation = labData.mlo_exit_h or 0,
            debug = false,
            options = {
                {
                    icon = 'fas fa-door-open',
                    label = "Exit Lab",
                    onSelect = function() ExitLab(labId) end
                }
            },
            distance = Config.TargetDistance
        })
    end

    if labData.owner_identifier == MyIdentifier or hasKeyAccess() then
        exports.ox_target:addBoxZone({
            name = stashTargetName,
            coords = vec3(labData.stash_pos_x, labData.stash_pos_y, labData.stash_pos_z),
            size = Config.TargetBoxZoneSize,
            rotation = 0,
            debug = false,
            options = {
                {
                    icon = 'fas fa-archive',
                    label = Strings['lab_stash_prompt'],
                    onSelect = function() OpenStashMenu(labId) end,
                    canInteract = function() return labData.owner_identifier == MyIdentifier or hasKeyAccess() end
                }
            },
            distance = Config.TargetDistance
        })

        exports.ox_target:addBoxZone({
            name = processTargetName,
            coords = vec3(labData.process_pos_x, labData.process_pos_y, labData.process_pos_z),
            size = Config.TargetBoxZoneSize,
            rotation = 0,
            debug = false,
            options = {
                {
                    icon = 'fas fa-cogs',
                    label = Strings['lab_process_prompt']:format(drugConfig.process_text),
                    onSelect = function() ManualProcess(labId) end,
                    canInteract = function()
                        return (labData.owner_identifier == MyIdentifier or hasKeyAccess()) and
                               labData.stock_raw > 0 and
                               labData.stock_raw < Config.AutoProcessThreshold
                    end,
                    disabled = not ((labData.owner_identifier == MyIdentifier or hasKeyAccess()) and labData.stock_raw > 0 and labData.stock_raw < Config.AutoProcessThreshold),
                    description = labData.stock_raw == 0 and Strings['not_enough_raw'] or (labData.stock_raw >= Config.AutoProcessThreshold and "Auto-processing active" or nil)
                }
            },
            distance = Config.TargetDistance
        })
    end
end 

function EnterLab(labId)
    local lab = CurrentLabs[labId]
    if not lab then return end
    
    if lab.mlo_enter_x and lab.mlo_enter_x ~= 0 then
        DoScreenFadeOut(500)
        while not IsScreenFadedOut() do Citizen.Wait(10) end
        
        SetEntityCoords(PlayerPedId(), lab.mlo_enter_x, lab.mlo_enter_y, lab.mlo_enter_z, false, false, false, false)
        SetEntityHeading(PlayerPedId(), lab.mlo_enter_h or 0)
        
        insideLab[labId] = true
        Citizen.Wait(500)
        DoScreenFadeIn(1000)
        
        ShowNotification(nil, {description = "You entered the lab", type = 'inform'})
    else
        ShowNotification(nil, {description = "This lab has no interior setup", type = 'error'})
    end
end

function ExitLab(labId)
    local lab = CurrentLabs[labId]
    if not lab then return end
    
    if lab.mlo_pos_x and lab.mlo_pos_x ~= 0 then
        DoScreenFadeOut(500)
        while not IsScreenFadedOut() do Citizen.Wait(10) end
        
        SetEntityCoords(PlayerPedId(), lab.mlo_pos_x, lab.mlo_pos_y, lab.mlo_pos_z, false, false, false, false)
        SetEntityHeading(PlayerPedId(), lab.mlo_heading or 0)
        
        insideLab[labId] = nil
        Citizen.Wait(500)
        DoScreenFadeIn(1000)
        
        ShowNotification(nil, {description = "You exited the lab", type = 'inform'})
    else
        ShowNotification(nil, {description = "Exit position not set", type = 'error'})
    end
end

function BuyLab(labId, price)
    local lab = CurrentLabs[labId]
    if not lab then ShowNotification(nil, {description = "Lab data not found.", type = 'error'}); return end
    local confirm = exports.ox_lib:alertDialog({
        header = Strings['confirm_purchase'] .. " (" .. Config.DrugTypes[lab.type].label .. ")",
        content = ('Are you sure you want to buy this lab for $%s?'):format(price),
        centered = true,
        cancel = true,
        labels = { confirm = "Yes, Buy", cancel = "No" }
    })
    if confirm == "confirm" then
        TriggerServerEvent('drug_labs:server:buyLab', labId)
    end
end

function OpenOwnerMenu(labId)
    local lab = CurrentLabs[labId]
    if not lab then ShowNotification(nil, {description = "Lab data not found.", type = 'error'}); return end
    local drugConfig = Config.DrugTypes[lab.type]
    local options = {
        { title = drugConfig.label .. " - Owner Menu", icon = drugConfig.target_icon or Config.TargetIcon, disabled = true },
        { title = Strings['keys_title'], icon = 'fas fa-key', onSelect = function() ManageKeysMenu(labId) end },
        {
            title = ("Sell Lab (for $%s)"):format(math.floor(lab.price * Config.SellBackPercentage)),
            icon = 'fas fa-hand-holding-usd',
            onSelect = function()
                local confirm = exports.ox_lib:alertDialog({
                    header = Strings['confirm_sell'],
                    content = ('Are you sure you want to sell this lab for $%s?'):format(math.floor(lab.price * Config.SellBackPercentage)),
                    centered = true, cancel = true,
                    labels = { confirm = "Yes, Sell", cancel = "No" }
                })
                if confirm == "confirm" then TriggerServerEvent('drug_labs:server:sellLab', labId) end
            end
        },
        { title = Strings['lab_info'], icon = 'fas fa-info-circle', onSelect = function() ShowLabInfo(labId) end }
    }
    exports.ox_lib:registerContext({
        id = 'drug_lab_owner_menu_' .. labId,
        title = drugConfig.label .. " - Owner",
        options = options,
        coords = vec3(lab.pos_x, lab.pos_y, lab.pos_z)
    })
    exports.ox_lib:showContext('drug_lab_owner_menu_' .. labId)
end 

function OpenKeyHolderMenu(labId)
    local lab = CurrentLabs[labId]
    if not lab then ShowNotification(nil, {description = "Lab data not found.", type = 'error'}); return end
    local drugConfig = Config.DrugTypes[lab.type]
    local options = {
        { title = drugConfig.label .. " - Key Access", icon = drugConfig.target_icon or Config.TargetIcon, disabled = true, },
    }
    exports.ox_lib:registerContext({
        id = 'drug_lab_keyholder_menu_' .. labId,
        title = drugConfig.label .. " - Key Access",
        options = options,
        coords = vec3(lab.pos_x, lab.pos_y, lab.pos_z)
    })
    exports.ox_lib:showContext('drug_lab_keyholder_menu_' .. labId)
end 

function ShowLabInfo(labId)
    local lab = CurrentLabs[labId]
    if not lab then ShowNotification(nil, {description = "Lab data not found.", type = 'error'}); return end
    local drugConfig = Config.DrugTypes[lab.type]
    local keyHoldersText = ""
    if lab.keys and #lab.keys > 0 then
        for i, keyId in ipairs(lab.keys) do keyHoldersText = keyHoldersText .. keyId .. (i < #lab.keys and ", " or "") end
    else
        keyHoldersText = "None"
    end
    local content = string.format(
        "**Type:** %s\n**Owner:** %s\n**Raw %s:** %s\n**Packaged %s:** %s\n**Keys (%s/%s):** %s\n**Interior Set:** %s",
        drugConfig.label, lab.owner_name or "Unowned",
        drugConfig.raw_item, lab.stock_raw,
        drugConfig.packaged_item, lab.stock_packaged,
        #lab.keys, Config.MaxKeysPerLab, keyHoldersText,
        (lab.mlo_enter_x and lab.mlo_enter_x ~= 0) and "Yes" or "No"
    )
    exports.ox_lib:alertDialog({
        header = Strings['lab_info'] .. " - " .. drugConfig.label,
        content = content, centered = true, cancel = false,
        labels = { confirm = "OK" }
    })
end 

function ManageKeysMenu(labId)
    local lab = CurrentLabs[labId]
    if not lab then
        ShowNotification(nil, {description = "Lab data not found (ManageKeysMenu).", type = 'error'})
        return
    end

    local options = {}

    table.insert(options, {
        title = Strings['keys_title'],
        icon = 'fas fa-key',
        disabled = true
    })

    table.insert(options, {
        title = Strings['give_key_label'],
        icon = 'fas fa-user-plus',
        onSelect = function()
            Citizen.CreateThread(function()
                local targetIdInput = exports.ox_lib:inputDialog(Strings['target_id_prompt'], {
                    { type = 'number', label = 'Player Server ID', required = true, icon = 'fas fa-id-badge' }
                })
                while targetIdInput == nil do Citizen.Wait(10) end
                if targetIdInput and type(targetIdInput) == 'table' and targetIdInput[1] ~= nil and tostring(targetIdInput[1]) ~= '' then
                    TriggerServerEvent('drug_labs:server:giveKey', labId, tonumber(targetIdInput[1]))
                elseif targetIdInput == false then
                else
                    ShowNotification(nil, {description = Strings['invalid_input'], type = 'error'})
                end
            end) 
        end,
        disabled = (#(lab.keys or {}) >= Config.MaxKeysPerLab),
        description = (#(lab.keys or {}) >= Config.MaxKeysPerLab) and Strings['max_keys_reached'] or nil
    })

    if lab.keys and #lab.keys > 0 then
        table.insert(options, {
            title = Strings['revoke_key_label'],
            icon = 'fas fa-user-minus',
            onSelect = function() OpenRevokeKeySubMenu(labId) end
        })
        table.insert(options, { title = "--- Current Keys (" .. #lab.keys .. "/" .. Config.MaxKeysPerLab .. ") ---", disabled = true})
        for _, keyHolderId in ipairs(lab.keys) do
            table.insert(options, {title = keyHolderId, icon = 'fas fa-user-tag', disabled = true})
        end
    end

    if exports.ox_lib and exports.ox_lib.registerContext then
        exports.ox_lib:registerContext({
            id = 'drug_lab_manage_keys_menu_' .. labId,
            title = Strings['keys_title'],
            options = options,
            coords = vec3(lab.pos_x, lab.pos_y, lab.pos_z)
        })
        exports.ox_lib:showContext('drug_lab_manage_keys_menu_' .. labId)
    else
        print("ERROR: ox_lib.registerContext is not available in ManageKeysMenu!")
    end
end

function OpenRevokeKeySubMenu(labId)
    local lab = CurrentLabs[labId]
    if not lab then ShowNotification(nil, {description = "Lab data not found.", type = 'error'}); return end
    local revokeOptions = {{ title = Strings['revoke_key_label'], icon = 'fas fa-user-minus', disabled = true }}
    if not lab.keys or #lab.keys == 0 then
        ShowNotification(nil, {description = Strings['no_one_to_revoke'], type = 'inform'})
        return
    end
    for _, keyHolderId in ipairs(lab.keys) do
        table.insert(revokeOptions, {
            title = "Revoke from: " .. keyHolderId,
            description = "Identifier: " .. keyHolderId,
            icon = 'fas fa-user-slash',
            onSelect = function()
                TriggerServerEvent('drug_labs:server:revokeKey', labId, keyHolderId)
            end
        })
    end
    exports.ox_lib:registerContext({
        id = 'drug_lab_revoke_keys_submenu_' .. labId,
        title = Strings['revoke_key_label'],
        options = revokeOptions,
        coords = vec3(lab.pos_x, lab.pos_y, lab.pos_z)
    })
    exports.ox_lib:showContext('drug_lab_revoke_keys_submenu_' .. labId)
end 

function OpenStashMenu(labId)
    local lab = CurrentLabs[labId]
    if not lab then ShowNotification(nil, {description = "Lab data not found.", type = 'error'}); return end
    local drugConfig = Config.DrugTypes[lab.type]
    local options = {
        { title = Strings['stash_title'] .. " (" .. drugConfig.label .. ")", icon = 'fas fa-archive', disabled = true },
        {
            title = Strings['deposit_raw_label'],
            description = Strings['raw_stock_info']:format(lab.stock_raw .. " " .. drugConfig.raw_item),
            icon = 'fas fa-arrow-down',
            onSelect = function()
                Citizen.CreateThread(function()
                    local amountInput = exports.ox_lib:inputDialog(Strings['amount_prompt'], {
                        { type = 'number', label = ('Amount of %s to deposit'):format(drugConfig.raw_item), required = true, min = 1, icon = 'fas fa-hashtag' }
                    })
                    while amountInput == nil do Citizen.Wait(10) end
                    if amountInput and type(amountInput) == 'table' and amountInput[1] ~= nil and tostring(amountInput[1]) ~= '' then
                        TriggerServerEvent('drug_labs:server:addRawToStash', labId, drugConfig.raw_item, tonumber(amountInput[1]))
                    elseif amountInput ~= false then
                         ShowNotification(nil, {description = Strings['invalid_input'], type = 'error'})
                    end
                end) 
            end
        },
        {
            title = Strings['withdraw_packaged_label'],
            description = Strings['packaged_stock_info']:format(lab.stock_packaged .. " " .. drugConfig.packaged_item),
            icon = 'fas fa-arrow-up',
            onSelect = function()
                Citizen.CreateThread(function()
                    local amountInput = exports.ox_lib:inputDialog(Strings['amount_prompt'], {
                        { type = 'number', label = ('Amount of %s to withdraw'):format(drugConfig.packaged_item), required = true, min = 1, max = lab.stock_packaged, icon = 'fas fa-hashtag' }
                    })
                    while amountInput == nil do Citizen.Wait(10) end
                    if amountInput and type(amountInput) == 'table' and amountInput[1] ~= nil and tostring(amountInput[1]) ~= '' then
                        TriggerServerEvent('drug_labs:server:takePackagedFromStash', labId, drugConfig.packaged_item, tonumber(amountInput[1]))
                    elseif amountInput ~= false then
                        ShowNotification(nil, {description = Strings['invalid_input'], type = 'error'})
                    end
                end) 
            end,
            disabled = (lab.stock_packaged == 0) 
        } 
    } 
    exports.ox_lib:registerContext({
        id = 'drug_lab_stash_menu_' .. labId,
        title = Strings['stash_title'],
        options = options,
        coords = vec3(lab.stash_pos_x, lab.stash_pos_y, lab.stash_pos_z)
    })
    exports.ox_lib:showContext('drug_lab_stash_menu_' .. labId)
end 

RegisterNetEvent('drug_labs:client:processFinished')
AddEventHandler('drug_labs:client:processFinished', function(success)
    isProcessingDrug = false
end) 

function ManualProcess(labId)
    if isProcessingDrug then return end
    local lab = CurrentLabs[labId]
    if not lab then 
        ShowNotification(nil, {description = "Lab data not found.", type = 'error'})
        return 
    end
    isProcessingDrug = true
    local drugConfig = Config.DrugTypes[lab.type]

    local success = exports.ox_lib:progressBar({
        duration = Config.ManualProcessTime,
        label = Strings['processing_drugs'] .. " (" .. drugConfig.label .. ")",
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true, combat = true },
    })

    if success then
        TriggerServerEvent('drug_labs:server:manualProcess', labId)
    else
        isProcessingDrug = false
        ShowNotification(nil, {description = "Processing cancelled.", type = 'warning'})
    end
end --

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for id, lab in pairs(CurrentLabs) do
            if lab and lab.blip and DoesBlipExist(lab.blip) then RemoveBlip(lab.blip) end
            exports.ox_target:removeZone('drug_lab_main_' .. id)
            exports.ox_target:removeZone('drug_lab_stash_' .. id)
            exports.ox_target:removeZone('drug_lab_process_' .. id)
            exports.ox_target:removeZone('drug_lab_enter_' .. id)
            exports.ox_target:removeZone('drug_lab_exit_' .. id)
        end
        CurrentLabs = {}
        print("[xrb-DrugLabs] Client script (Player Module) stopped, cleaned up blips and targets.")
    end
end)

function ShowNotification(source, data)
    if source then
        print("Warning: ShowNotification called with source on client-side. This is unusual.")
        return
    end
    if type(data) == 'string' then
        data = { title = 'Drug Lab', description = data, type = 'inform', duration = 5000 }
    end
    data.duration = data.duration or 5000
    if exports.ox_lib and exports.ox_lib.notify then
        exports.ox_lib:notify(data)
    else
        print("[xrb-DrugLabs] Error: ox_lib or ox_lib.notify is not available for ShowNotification.")
        if Config.Framework == "ESX" then
            local ESX = exports.es_extended:getSharedObject()
            if ESX then ESX.ShowNotification(data.description or "Notification") end
        elseif Config.Framework == "QB" then
            local QBCore = exports['qb-core']:GetCoreObject()
            if QBCore then QBCore.Functions.Notify(data.description or "Notification", data.type or "primary", 5000) end
        end
    end
end
