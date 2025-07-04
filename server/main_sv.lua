local ESX, QBCore
if Config.Framework == "ESX" then
    ESX = exports["es_extended"]:getSharedObject()
elseif Config.Framework == "QB" then
    QBCore = exports['qb-core']:GetCoreObject()
end

_G.ActiveDrugLabs = {}

local function GetPlayerIdentifier(playerSource)
    if Config.Framework == "ESX" then
        local xPlayer = ESX.GetPlayerFromId(playerSource)
        return xPlayer and xPlayer.identifier
    elseif Config.Framework == "QB" then
        local Player = QBCore.Functions.GetPlayer(playerSource)
        return Player and Player.PlayerData.citizenid
    end
    return nil
end

local function GetPlayerName(playerSource)
     if Config.Framework == "ESX" then
        local xPlayer = ESX.GetPlayerFromId(playerSource)
        return xPlayer and xPlayer.getName()
    elseif Config.Framework == "QB" then
        local Player = QBCore.Functions.GetPlayer(playerSource)
        return Player and (Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname)
    end
    return "Unknown"
end

local function GetPlayerMoney(playerSource)
    if Config.Framework == "ESX" then
        local xPlayer = ESX.GetPlayerFromId(playerSource)
        return xPlayer and xPlayer.getMoney() or 0
    elseif Config.Framework == "QB" then
        local Player = QBCore.Functions.GetPlayer(playerSource)
        return Player and (Player.Functions.GetMoney('cash') + Player.Functions.GetMoney('bank')) or 0
    end
    return 0
end

local function RemovePlayerMoney(playerSource, amount, reason)
    reason = reason or "drug_lab_purchase"
    if Config.Framework == "ESX" then
        local xPlayer = ESX.GetPlayerFromId(playerSource)
        if xPlayer then xPlayer.removeMoney(amount); return true end
    elseif Config.Framework == "QB" then
        local Player = QBCore.Functions.GetPlayer(playerSource)
        if Player then
            if Player.Functions.GetMoney('bank') >= amount then
                return Player.Functions.RemoveMoney('bank', amount, reason)
            elseif Player.Functions.GetMoney('cash') >= amount then
                return Player.Functions.RemoveMoney('cash', amount, reason)
            end
        end
    end
    return false
end

local function AddPlayerMoney(playerSource, amount, reason)
    reason = reason or "drug_lab_sale"
    if Config.Framework == "ESX" then
        local xPlayer = ESX.GetPlayerFromId(playerSource)
        if xPlayer then xPlayer.addMoney(amount) end
    elseif Config.Framework == "QB" then
        local Player = QBCore.Functions.GetPlayer(playerSource)
        if Player then Player.Functions.AddMoney('bank', amount, reason) end
    end
end

local function GetPlayerFromServerId(serverId)
    if Config.Framework == "ESX" then
        return ESX.GetPlayerFromId(tonumber(serverId))
    elseif Config.Framework == "QB" then
        return QBCore.Functions.GetPlayer(tonumber(serverId))
    end
    return nil
end

local function GetPlayerByIdentifier(identifier)
    if Config.Framework == "ESX" then
        local xPlayers = ESX.GetPlayers()
        for i=1, #xPlayers do
            local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
            if xPlayer and xPlayer.identifier == identifier then
                return xPlayer
            end
        end
    elseif Config.Framework == "QB" then
        return QBCore.Functions.GetPlayerByCitizenId(identifier)
    end
    return nil
end

function LoadLabsFromDB()
    MySQL.Async.fetchAll('SELECT * FROM drug_labs', {}, function(result)
        _G.ActiveDrugLabs = {}
        if result then
            for i = 1, #result do
                local lab = result[i]
                lab.keys = json.decode(lab.keys or '[]')
                _G.ActiveDrugLabs[lab.id] = lab
            end
        end
        print(('[DrugLabs] Loaded %s labs from database.'):format(table.Count(_G.ActiveDrugLabs)))
        TriggerClientEvent('drug_labs:client:updateLabs', -1, _G.ActiveDrugLabs)
    end)
end

function UpdateAndBroadcastLabChange(labId)
    if _G.ActiveDrugLabs[labId] then
        TriggerClientEvent('drug_labs:client:updateLabState', -1, labId, _G.ActiveDrugLabs[labId])
    else
        TriggerClientEvent('drug_labs:client:updateLabState', -1, labId, nil)
    end
end

Citizen.CreateThread(function()
    if Config.Framework == "ESX" then while ESX == nil do Citizen.Wait(100) end end
    if Config.Framework == "QB" then while QBCore == nil do Citizen.Wait(100) end end
    Citizen.Wait(2000)
    LoadLabsFromDB()
end)

RegisterNetEvent('drug_labs:server:requestLabs', function()
    TriggerClientEvent('drug_labs:client:updateLabs', source, _G.ActiveDrugLabs)
end)

RegisterNetEvent('drug_labs:server:requestAdminLabsForMenu', function()
    if HasAdminPermission(source) then 
        TriggerClientEvent('drug_labs:client:openAdminMenu', source, _G.ActiveDrugLabs)
    end
end)

-- BUY LAB
RegisterNetEvent('drug_labs:server:buyLab', function(labId)
    local src = source
    local playerIdentifier = GetPlayerIdentifier(src)
    if not playerIdentifier then return end
    local lab = _G.ActiveDrugLabs[labId]

    if not lab then ShowNotification(src, {description = Strings['no_labs_nearby'], type = 'error'}); return end
    if lab.owner_identifier then ShowNotification(src, {description = "This lab is already owned.", type = 'error'}); return end
    if GetPlayerMoney(src) < lab.price then ShowNotification(src, {description = Strings['not_enough_money'], type = 'error'}); return end

    if RemovePlayerMoney(src, lab.price) then
        lab.owner_identifier = playerIdentifier
        lab.owner_name = GetPlayerName(src)
        lab.keys = {}

        MySQL.Async.execute(
            'UPDATE drug_labs SET owner_identifier = @ownerId, owner_name = @ownerName, `keys` = @keys, stock_raw = 0, stock_packaged = 0 WHERE id = @labId',
            {
                ['@ownerId'] = lab.owner_identifier, ['@ownerName'] = lab.owner_name,
                ['@keys'] = json.encode(lab.keys), ['@labId'] = labId
            },
            function(affectedRows)
                if affectedRows > 0 then
                    ShowNotification(src, {description = Strings['lab_purchased']:format(Config.DrugTypes[lab.type].label, lab.price), type = 'success'})
                    UpdateAndBroadcastLabChange(labId)
                else
                    AddPlayerMoney(src, lab.price)
                    ShowNotification(src, {description = "Database error during purchase.", type = 'error'})
                end
            end
        )
    else
        ShowNotification(src, {description = Strings['not_enough_money'], type = 'error'})
    end
end)

-- SELL LAB
RegisterNetEvent('drug_labs:server:sellLab', function(labId)
    local src = source
    local playerIdentifier = GetPlayerIdentifier(src)
    if not playerIdentifier then return end
    local lab = _G.ActiveDrugLabs[labId]

    if not lab or lab.owner_identifier ~= playerIdentifier then
        ShowNotification(src, {description = Strings['not_owner'], type = 'error'}); return
    end

    local sellPrice = math.floor(lab.price * Config.SellBackPercentage)
    AddPlayerMoney(src, sellPrice)

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
                ShowNotification(src, {description = Strings['lab_sold']:format(sellPrice), type = 'success'})
                UpdateAndBroadcastLabChange(labId)
            else
                ShowNotification(src, {description = "Database error during sale.", type = 'error'})
            end
        end
    )
end)


RegisterNetEvent('drug_labs:server:giveKey', function(labId, targetPlayerServerId)
    local src = source
    local ownerIdentifier = GetPlayerIdentifier(src)
    if not ownerIdentifier then return end
    local lab = _G.ActiveDrugLabs[labId]

    if not lab or lab.owner_identifier ~= ownerIdentifier then ShowNotification(src, {description = Strings['not_owner'], type = 'error'}); return end
    if #(lab.keys or {}) >= Config.MaxKeysPerLab then ShowNotification(src, {description = Strings['max_keys_reached'], type = 'error'}); return end

    local targetPlayerObj = GetPlayerFromServerId(targetPlayerServerId)
    if not targetPlayerObj then ShowNotification(src, {description = Strings['player_not_found'], type = 'error'}); return end

    local targetIdentifier = GetPlayerIdentifier(targetPlayerObj.source or targetPlayerServerId)
    local targetName = GetPlayerName(targetPlayerObj.source or targetPlayerServerId)

    if not targetIdentifier then ShowNotification(src, {description = "Could not get target identifier.", type = 'error'}); return end

    for _, keyHolderId in ipairs(lab.keys or {}) do
        if keyHolderId == targetIdentifier then
            ShowNotification(src, {description = Strings['player_already_has_key'], type = 'error'})
            return
        end
    end

    table.insert(lab.keys, targetIdentifier)
    MySQL.Async.execute('UPDATE drug_labs SET `keys` = @keys WHERE id = @labId',
        { ['@keys'] = json.encode(lab.keys), ['@labId'] = labId },
        function(affectedRows)
            if affectedRows > 0 then
                ShowNotification(src, {description = Strings['key_given']:format(targetName), type = 'success'})
                ShowNotification(targetPlayerObj.source or targetPlayerServerId, {description = ("You received a key to %s's %s lab."):format(lab.owner_name or "a", Config.DrugTypes[lab.type].label), type = 'inform'})
                UpdateAndBroadcastLabChange(labId)
            else
                for i, kId in ipairs(lab.keys) do if kId == targetIdentifier then table.remove(lab.keys, i); break; end end
                ShowNotification(src, {description = "Database error giving key.", type = 'error'})
            end
        end
    )
end)


function RevokeKeyInternal(labId, keyHolderIdentifierToRevoke, revokerSource)
    local lab = _G.ActiveDrugLabs[labId]
    if not lab then
        if revokerSource then ShowNotification(revokerSource, {description = "Lab not found.", type = 'error'}) end
        return false, "Lab not found."
    end

    local keyFound = false
    local originalKeys = json.decode(json.encode(lab.keys or {}))

    for i, id in ipairs(lab.keys or {}) do
        if id == keyHolderIdentifierToRevoke then
            table.remove(lab.keys, i)
            keyFound = true
            break
        end
    end

    if keyFound then
        MySQL.Async.execute(
            'UPDATE drug_labs SET `keys` = @keys WHERE id = @labId',
            { ['@keys'] = json.encode(lab.keys), ['@labId'] = labId },
            function(affectedRows)
                if affectedRows > 0 then
                    if revokerSource then
                        ShowNotification(revokerSource, {description = Strings['key_revoked']:format(keyHolderIdentifierToRevoke), type = 'success'})
                    end
                    local targetPlayer = GetPlayerByIdentifier(keyHolderIdentifierToRevoke)
                    if targetPlayer then
                        local targetSource = targetPlayer.source or (targetPlayer.PlayerData and targetPlayer.PlayerData.source)
                        if targetSource then
                            ShowNotification(targetSource, {description = ("Your key to %s's %s lab has been revoked."):format(lab.owner_name or "a", Config.DrugTypes[lab.type].label), type = 'warning'})
                        end
                    end
                    UpdateAndBroadcastLabChange(labId)
                    return true
                else
                    lab.keys = originalKeys
                    if revokerSource then ShowNotification(revokerSource, {description = "Database error revoking key.", type = 'error'}) end
                    return false, "Database error."
                end
            end
        )
    else
        if revokerSource then ShowNotification(revokerSource, {description = "Key not found for this identifier.", type = 'error'}) end
        return false, "Key not found."
    end
end

RegisterNetEvent('drug_labs:server:revokeKey', function(labId, keyHolderIdentifierToRevoke)
    local src = source
    local playerIdentifier = GetPlayerIdentifier(src)
    if not playerIdentifier then return end
    local lab = _G.ActiveDrugLabs[labId]
    if not lab or lab.owner_identifier ~= playerIdentifier then ShowNotification(src, {description = Strings['not_owner'], type = 'error'}); return end
    RevokeKeyInternal(labId, keyHolderIdentifierToRevoke, src)
end)


RegisterNetEvent('drug_labs:server:addRawToStash', function(labId, itemName, itemCount)
    local src = source
    itemCount = tonumber(itemCount)
    if not itemCount or itemCount <= 0 then ShowNotification(src, {description = Strings['invalid_input'], type = 'error'}); return end

    local playerIdentifier = GetPlayerIdentifier(src)
    if not playerIdentifier then return end
    local lab = _G.ActiveDrugLabs[labId]

    if not lab then ShowNotification(src, {description = "Lab not found.", type = 'error'}); return end
    if lab.owner_identifier ~= playerIdentifier and not (table.find(lab.keys or {}, playerIdentifier)) then ShowNotification(src, {description = Strings['not_owner_or_keyholder'], type = 'error'}); return end
    if not Config.DrugTypes[lab.type] or Config.DrugTypes[lab.type].raw_item ~= itemName then ShowNotification(src, {description = "Incorrect drug type.", type = 'error'}); return end

    if exports.ox_inventory:Search(src, 'count', itemName) >= itemCount then
        if exports.ox_inventory:RemoveItem(src, itemName, itemCount) then
            lab.stock_raw = lab.stock_raw + itemCount
            MySQL.Async.execute('UPDATE drug_labs SET stock_raw = @stock WHERE id = @labId',
                { ['@stock'] = lab.stock_raw, ['@labId'] = labId },
                function(affectedRows)
                    if affectedRows > 0 then
                        ShowNotification(src, {description = Strings['added_to_stash']:format(itemCount, itemName), type = 'success'})
                        UpdateAndBroadcastLabChange(labId)
                        CheckAndAutoProcess(labId)
                    else
                        exports.ox_inventory:AddItem(src, itemName, itemCount)
                        lab.stock_raw = lab.stock_raw - itemCount
                        ShowNotification(src, {description = "Database error.", type = 'error'})
                    end
                end)
        else
            ShowNotification(src, {description = "Failed to remove item from inventory.", type = 'error'})
        end
    else
        ShowNotification(src, {description = "You don't have enough of that item.", type = 'error'})
    end
end)

RegisterNetEvent('drug_labs:server:takePackagedFromStash', function(labId, itemName, itemCount)
    local src = source
    itemCount = tonumber(itemCount)
    if not itemCount or itemCount <= 0 then ShowNotification(src, {description = Strings['invalid_input'], type = 'error'}); return end

    local playerIdentifier = GetPlayerIdentifier(src)
    if not playerIdentifier then return end
    local lab = _G.ActiveDrugLabs[labId]

    if not lab then ShowNotification(src, {description = "Lab not found.", type = 'error'}); return end
    if lab.owner_identifier ~= playerIdentifier and not (table.find(lab.keys or {}, playerIdentifier)) then ShowNotification(src, {description = Strings['not_owner_or_keyholder'], type = 'error'}); return end
    if not Config.DrugTypes[lab.type] or Config.DrugTypes[lab.type].packaged_item ~= itemName then ShowNotification(src, {description = "Incorrect drug type.", type = 'error'}); return end
    if lab.stock_packaged < itemCount then ShowNotification(src, {description = "Not enough packaged drugs in stash.", type = 'error'}); return end

    if exports.ox_inventory:CanCarryItem(src, itemName, itemCount) then
        if exports.ox_inventory:AddItem(src, itemName, itemCount) then
            lab.stock_packaged = lab.stock_packaged - itemCount
            MySQL.Async.execute('UPDATE drug_labs SET stock_packaged = @stock WHERE id = @labId',
                { ['@stock'] = lab.stock_packaged, ['@labId'] = labId },
                function(affectedRows)
                    if affectedRows > 0 then
                        ShowNotification(src, {description = Strings['removed_from_stash']:format(itemCount, itemName), type = 'success'})
                        UpdateAndBroadcastLabChange(labId)
                    else
                        exports.ox_inventory:RemoveItem(src, itemName, itemCount, nil, true)
                        lab.stock_packaged = lab.stock_packaged + itemCount
                        ShowNotification(src, {description = "Database error.", type = 'error'})
                    end
                end)
        else
            ShowNotification(src, {description = Strings['inventory_full'] .. " (AddItem failed)", type = 'error'})
        end
    else
        ShowNotification(src, {description = Strings['inventory_full'] .. " (CanCarryItem failed)", type = 'error'})
    end
end)

RegisterNetEvent('drug_labs:server:manualProcess', function(labId)
    local src = source
    local playerIdentifier = GetPlayerIdentifier(src)
    if not playerIdentifier then TriggerClientEvent('drug_labs:client:processFinished', src, false); return end
    local lab = _G.ActiveDrugLabs[labId]

    if not lab then ShowNotification(src, {description = "Lab not found.", type = 'error'}); TriggerClientEvent('drug_labs:client:processFinished', src, false); return end
    if lab.owner_identifier ~= playerIdentifier and not (table.find(lab.keys or {}, playerIdentifier)) then ShowNotification(src, {description = Strings['not_owner_or_keyholder'], type = 'error'}); TriggerClientEvent('drug_labs:client:processFinished', src, false); return end
    
    if lab.stock_raw < Config.RawPerPackage then 
        ShowNotification(src, {description = Strings['not_enough_raw'], type = 'error'}); 
        TriggerClientEvent('drug_labs:client:processFinished', src, false); 
        return 
    end
    
    if lab.stock_raw >= Config.AutoProcessThreshold then 
        ShowNotification(src, {description = "System will auto-process.", type = 'inform'}); 
        TriggerClientEvent('drug_labs:client:processFinished', src, false); 
        return 
    end

    local drugInfo = Config.DrugTypes[lab.type]
    if not drugInfo then ShowNotification(src, {description = "Lab type config error.", type = 'error'}); TriggerClientEvent('drug_labs:client:processFinished', src, false); return end

    local packagesCreated = 1
    local rawConsumed = Config.RawPerPackage

    if lab.stock_raw >= rawConsumed then
        local originalRaw = lab.stock_raw
        local originalPackaged = lab.stock_packaged
        lab.stock_raw = lab.stock_raw - rawConsumed
        lab.stock_packaged = lab.stock_packaged + packagesCreated

        MySQL.Async.execute('UPDATE drug_labs SET stock_raw = @raw, stock_packaged = @packaged WHERE id = @labId',
            { ['@raw'] = lab.stock_raw, ['@packaged'] = lab.stock_packaged, ['@labId'] = labId },
            function(affectedRows)
                if affectedRows > 0 then
                    ShowNotification(src, {description = Strings['drugs_processed']:format(rawConsumed, drugInfo.raw_item, packagesCreated, drugInfo.packaged_item), type = 'success'})
                    UpdateAndBroadcastLabChange(labId)
                    TriggerClientEvent('drug_labs:client:processFinished', src, true)
                    
                    CheckAndAutoProcess(labId)
                else
                    lab.stock_raw = originalRaw
                    lab.stock_packaged = originalPackaged
                    ShowNotification(src, {description = Strings['failed_to_process'], type = 'error'})
                    TriggerClientEvent('drug_labs:client:processFinished', src, false)
                end
            end)
    else
        ShowNotification(src, {description = Strings['not_enough_raw'], type = 'error'})
        TriggerClientEvent('drug_labs:client:processFinished', src, false)
    end
end)

function CheckAndAutoProcess(labId)
    local lab = _G.ActiveDrugLabs[labId]
    if not lab or lab.stock_raw < Config.AutoProcessThreshold then return end

    local drugInfo = Config.DrugTypes[lab.type]
    if not drugInfo then print(("[DrugLabs] AutoProcess Error: Missing drugInfo for type '%s'"):format(lab.type)); return end

    local packagesCreated = math.floor(lab.stock_raw / Config.RawPerPackage)
    local rawConsumed = packagesCreated * Config.RawPerPackage

    if packagesCreated > 0 then
        local originalRaw = lab.stock_raw
        local originalPackaged = lab.stock_packaged
        lab.stock_raw = lab.stock_raw - rawConsumed
        lab.stock_packaged = lab.stock_packaged + packagesCreated

        MySQL.Async.execute('UPDATE drug_labs SET stock_raw = @raw, stock_packaged = @packaged WHERE id = @labId',
            { ['@raw'] = lab.stock_raw, ['@packaged'] = lab.stock_packaged, ['@labId'] = labId },
            function(affectedRows)
                if affectedRows > 0 then
                    print(('[DrugLabs] Auto-processed lab ID %s: %s %s -> %s %s'):format(labId, rawConsumed, drugInfo.raw_item, packagesCreated, drugInfo.packaged_item))
                    local ownerPlayer = lab.owner_identifier and GetPlayerByIdentifier(lab.owner_identifier)
                    if ownerPlayer then
                         local ownerSource = ownerPlayer.source or (ownerPlayer.PlayerData and ownerPlayer.PlayerData.source)
                         if ownerSource then
                            ShowNotification(ownerSource, {description = Strings['auto_processed']:format(rawConsumed, drugInfo.raw_item, packagesCreated, drugInfo.packaged_item), type = 'inform'})
                         end
                    end
                    UpdateAndBroadcastLabChange(labId)
                else
                    lab.stock_raw = originalRaw
                    lab.stock_packaged = originalPackaged
                    print(('[DrugLabs] ERROR: Auto-process DB update failed for lab ID %s'):format(labId))
                end
            end)
    end
end

-- POLICE RAID
function HandlePoliceRaid(labId)
    local lab = _G.ActiveDrugLabs[labId]
    if not lab then print(("[DrugLabs] Raid Error: Lab ID %s not found."):format(labId)); return end

    print(("[DrugLabs] Lab ID %s is being raided by police."):format(labId))

    local ownerIdentifier = lab.owner_identifier
    local labTypeLabel = Config.DrugTypes[lab.type] and Config.DrugTypes[lab.type].label or "Unknown"

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
                ShowNotification(nil, {
                    title = "Police Raid",
                    description = Strings['lab_raided_admin_notify']:format(labId, labTypeLabel),
                    type = 'warning',
                    persist = true
                })
                if ownerIdentifier then
                    local ownerPlayer = GetPlayerByIdentifier(ownerIdentifier)
                    if ownerPlayer then
                        local ownerSource = ownerPlayer.source or (ownerPlayer.PlayerData and ownerPlayer.PlayerData.source)
                        if ownerSource then
                           ShowNotification(ownerSource, {description = Strings['lab_raided_owner_notify']:format(labTypeLabel, labId), type = 'error', duration = 10000})
                        end
                    end
                end
                UpdateAndBroadcastLabChange(labId)
                print(("[DrugLabs] Lab ID %s successfully reset after police raid."):format(labId))
            else
                print(("[DrugLabs] Raid Error: Database update failed for lab ID %s after raid."):format(labId))
            end
        end
    )
end
exports('TriggerPoliceRaidOnLab', HandlePoliceRaid)

if not table.find then
    function table.find(tbl, val)
        for i, v in ipairs(tbl) do
            if v == val then return i end
        end
        return nil
    end
end

if not table.Count then 
    function table.Count(tbl)
        local count = 0
        for _ in pairs(tbl) do count = count + 1 end
        return count
    end
end
-- ADMIN FUNCTIONS
function GetAdminSourceIfAny()
    if Config.Framework == "ESX" then
        local xPlayers = ESX.GetPlayers()
        for i=1, #xPlayers do
            local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
            if xPlayer and (xPlayer.getGroup() == Config.AdminPermission or xPlayer.getGroup() == "superadmin") then
                return xPlayer.source 
            end
        end
    elseif Config.Framework == "QB" then
        local players = QBCore.Functions.GetPlayers()
        for _, playerId in ipairs(players) do
            if QBCore.Functions.HasPermission(playerId, Config.AdminPermission) then
                return playerId 
            end
        end
    end
    return nil
end

RegisterCommand(Config.AdminCommand, function(source, args, rawCommand)
    if HasAdminPermission(source) then
        TriggerClientEvent('drug_labs:client:openAdminMenu', source, _G.ActiveDrugLabs)
    else
        ShowNotification(source, {description = Strings['admin_must_be_admin'], type = 'error'})
    end
end, false)

function HasAdminPermission(source)
    if Config.Framework == "ESX" then
        local xPlayer = ESX.GetPlayerFromId(source)
        return xPlayer and (xPlayer.getGroup() == Config.AdminPermission or xPlayer.getGroup() == "superadmin")
    elseif Config.Framework == "QB" then
        return QBCore.Functions.HasPermission(source, Config.AdminPermission)
    end
    return false
end

function ShowNotification(source, data)
    if type(data) == 'string' then
        data = { title = 'Drug Lab', description = data, type = 'inform', duration = 5000 }
    end
    data.duration = data.duration or 5000
    TriggerClientEvent('ox_lib:notify', source, data)
end
