ESX = exports['es_extended']:getSharedObject()
ESX.RegisterUsableItem('radio', function(source)
    TriggerClientEvent('setActiveRadio', source)
end)