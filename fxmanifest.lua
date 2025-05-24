fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'xResul Albania'
description 'Advanced Drug Lab System with Admin Menu and Position Editing'
version '2.1.0'
discord 'https://discord.gg/CAyUh9su2s'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server/main_sv.lua',
    'server/admin_sv.lua'
}

client_scripts {
    'client/main_cl.lua',
    'client/admin_cl.lua'
}

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
    --'qb-core',
    'es_extended'
}
