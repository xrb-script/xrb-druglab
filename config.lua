Config = {}

Config.Framework = "ESX" -- "ESX" or "QB"

Config.RawPerPackage = 10
Config.AutoProcessThreshold = 500
Config.ManualProcessTime = 5000 -- ms
Config.MaxKeysPerLab = 5
Config.SellBackPercentage = 0.7

Config.BlipSprite = 474
Config.BlipColorOwned = 2
Config.BlipColorUnowned = 1
Config.BlipColorKeyed = 38
Config.BlipScale = 0.8

Config.TargetDistance = 2.0
Config.TargetIcon = 'fas fa-bong'
Config.TargetBoxZoneSize = vec3(1.5, 1.5, 2.0)

Config.AdminCommand = "adminlab"
Config.AdminPermission = "admin"

Config.DrugTypes = {
    ['coke'] = {
        label = "Coke Lab",
        raw_item = "cokepowder",
        packaged_item = "ouncofcoke",
        process_text = "Process Cocaine",
        target_icon = "fas fa-prescription-bottle-alt"
    },
    ['meth'] = {
        label = "Meth Lab",
        raw_item = "methgel",
        packaged_item = "ouncofmeth",
        process_text = "Cook Meth",
        target_icon = "fas fa-flask"
    },
    ['weed'] = {
        label = "Weed Lab",
        raw_item = "skunk",
        packaged_item = "bagofskunk",
        process_text = "Process Skunk",
        target_icon = "fas fa-leaf"
    },
}

Strings = {
    ['lab_unowned_prompt'] = "Buy %s",
    ['lab_manage_prompt'] = "Manage %s",
    ['lab_access_prompt'] = "Access %s",
    ['lab_stash_prompt'] = "Access Lab Stash",
    ['lab_process_prompt'] = "%s",
    ['not_enough_money'] = "You don't have enough money.",
    ['lab_purchased'] = "You purchased the %s for $%s.",
    ['lab_sold'] = "You sold the lab for $%s.",
    ['not_owner'] = "You are not the owner of this lab.",
    ['not_owner_or_keyholder'] = "You don't have access to this lab.",
    ['max_keys_reached'] = "Maximum number of keys reached.",
    ['player_not_found'] = "Player not found or not online.",
    ['player_already_has_key'] = "This player already has a key.",
    ['key_given'] = "Key given to player %s.",
    ['key_revoked'] = "Key revoked from %s.",
    ['no_one_to_revoke'] = "No keys to revoke.",
    ['invalid_input'] = "Invalid input.",
    ['not_enough_raw'] = "Not enough raw materials to process.",
    ['processing_drugs'] = "Processing drugs...",
    ['drugs_processed'] = "%s %s processed into %s %s.",
    ['auto_processed'] = "[AUTO] Lab processed %s %s into %s %s.",
    ['failed_to_process'] = "Failed to process drugs.",
    ['added_to_stash'] = "Added %s %s to stash.",
    ['removed_from_stash'] = "Took %s %s from stash.",
    ['inventory_full'] = "Your inventory is full or cannot carry that item.",
    ['confirm_purchase'] = "Confirm Purchase",
    ['confirm_sell'] = "Confirm Sale",
    ['target_id_prompt'] = "Target Player Server ID",
    ['amount_prompt'] = "Amount",
    ['keys_title'] = "Manage Keys",
    ['give_key_label'] = "Give Key",
    ['revoke_key_label'] = "Revoke Key",
    ['stash_title'] = "Lab Stash",
    ['deposit_raw_label'] = "Deposit Raw Material",
    ['withdraw_packaged_label'] = "Withdraw Packaged Product",
    ['lab_info'] = "Lab Information",
    ['raw_stock_info'] = "Raw Stock: %s",
    ['packaged_stock_info'] = "Packaged Stock: %s",
    ['owned_by_other'] = "Lab (Owned by %s)",
    ['lab_raided_owner_notify'] = "Your %s lab (ID: %s) has been raided by the police and is now defunct!",
    ['lab_raided_admin_notify'] = "Lab ID %s (%s) was raided and reset.",

    ['admin_menu_title'] = "Admin Drug Lab Panel",
    ['admin_create_lab'] = "Create New Lab",
    ['admin_view_labs'] = "View/Manage Active Labs",
    ['admin_lab_type_prompt'] = "Lab Type (e.g., coke, meth)",
    ['admin_lab_price_prompt'] = "Lab Price",
    ['admin_lab_created_success'] = "New %s lab created at your location with ID: %s.",
    ['admin_no_active_labs'] = "No active labs found.",
    ['admin_lab_details_title'] = "Lab Details - ID: %s",
    ['admin_lab_owner'] = "Owner: %s (%s)",
    ['admin_lab_unowned'] = "Owner: Unowned",
    ['admin_lab_keys_list'] = "Keyholders:",
    ['admin_lab_no_keys'] = "No keyholders.",
    ['admin_revoke_key_from'] = "Revoke key from %s",
    ['admin_delete_lab'] = "Reset Lab",
    ['admin_confirm_delete_lab'] = "Are you sure you want to reset Lab ID %s? This will make it unowned and clear its stock.",
    ['admin_lab_deleted'] = "Lab ID %s has been reset.",
    ['admin_must_be_admin'] = "You must be an admin to use this command.",
    ['admin_invalid_lab_type'] = "Invalid lab type. Valid types: %s",
    ['admin_error_creating_lab'] = "Error creating lab in database.",
    ['admin_edit_lab_positions'] = "Edit Lab Positions",
    ['admin_set_stash_pos'] = "Set Stash Position (Current Location)",
    ['admin_set_process_pos'] = "Set Process Position (Current Location)",
    ['admin_pos_updated_stash'] = "Stash position updated for Lab ID %s.",
    ['admin_pos_updated_process'] = "Process position updated for Lab ID %s.",
    ['admin_error_updating_pos'] = "Error updating position for Lab ID %s.",
    
 
    ['admin_set_mlo_pos'] = "Set MLO Position (Current Location)",
    ['admin_set_mlo_enter_pos'] = "Set Enter Lab Position (Inside MLO)",
    ['admin_set_mlo_exit_pos'] = "Set Exit Lab Position (Outside MLO)",
    ['admin_pos_updated_mlo'] = "MLO position updated for Lab ID %s.",
    ['admin_pos_updated_enter'] = "Enter position updated for Lab ID %s.",
    ['admin_pos_updated_exit'] = "Exit position updated for Lab ID %s.",
    ['admin_mlo_pos'] = "MLO Position: X:%.1f Y:%.1f Z:%.1f",
    ['admin_enter_pos'] = "Enter Position: X:%.1f Y:%.1f Z:%.1f",
    ['admin_exit_pos'] = "Exit Position: X:%.1f Y:%.1f Z:%.1f",
    ['admin_interior_not_set'] = "Interior not configured",
    
   
    ['entering_lab'] = "Entering lab...",
    ['exiting_lab'] = "Exiting lab...",
    ['lab_entered'] = "You entered the lab",
    ['lab_exited'] = "You exited the lab",
    ['lab_no_interior'] = "This lab has no interior setup",
    ['lab_enter_fail'] = "Failed to enter lab",
    ['lab_exit_fail'] = "Failed to exit lab",
    

    ['admin_permanent_delete'] = "Delete Lab Permanently",
    ['admin_confirm_permanent_delete'] = "Are you sure you want to permanently delete Lab ID %s? This cannot be undone!",
    ['admin_permanent_delete_success'] = "Lab ID %s has been permanently deleted.",
    ['admin_permanent_delete_fail'] = "Failed to delete lab",
    

    ['key_given_notification'] = "You gave a key for lab %s to player %s",
    ['key_received_notification'] = "You received a key for lab %s from %s"
}

function ShowNotification(source, data)
    if type(data) == 'string' then
        data = { title = 'Drug Lab', description = data, type = 'inform', duration = 5000 }
    end
    data.duration = data.duration or 5000
    if source then
        TriggerClientEvent('ox_lib:notify', source, data)
    else
        if exports.ox_lib and exports.ox_lib.notify then
            exports.ox_lib:notify(data)
        else
            print("[DrugLabs] ox_lib not available for notification: " .. (data.description or "Unknown error"))
        end
    end
end
