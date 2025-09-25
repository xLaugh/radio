ESX = exports['es_extended']:getSharedObject()

local PlayerData = {}
local playerInventory = {} -- Cache de l'inventaire

Citizen.CreateThread(function()
	while ESX.GetPlayerData().job == nil do
		Citizen.Wait(10)
    end
    PlayerData = ESX.GetPlayerData()
    playerInventory = PlayerData.inventory -- Initialiser le cache
end)

SetFieldValueFromNameEncode = function(stringName, data)
	SetResourceKvp(stringName, json.encode(data))
end

GetFieldValueFromName = function(stringName)
	local data = GetResourceKvpString(stringName)
	return data and json.decode(data) or {}
end

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
  PlayerData = xPlayer
  playerInventory = xPlayer.inventory -- Mettre à jour le cache
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
  PlayerData.job = job
end)

-- Mettre à jour le cache d'inventaire
RegisterNetEvent('esx:setInventoryItem')
AddEventHandler('esx:setInventoryItem', function(item, count)
    for k, v in pairs(playerInventory) do
        if v.name == item then
            v.count = count
            break
        end
    end
end)

local radioOpen = false
local currentVolume = 75
local radioFreq = 0
local radioActif = false
local RadioActived = false
local RadioMute = false
local keyCheckThread = nil -- Thread pour les contrôles clavier

local FrequenceJob = {
    {job = "police", freq = 1},
    {job = "police", freq = 2},
    {job = "police", freq = 3},
    {job = "police", freq = 4},
    {job = "police", freq = 5},
    {job = "ems", freq = 6},
    {job = "ems", freq = 7},
    {job = "ems", freq = 8},
    {job = "ems", freq = 9},
    {job = "ems", freq = 10}
}

function updateRadioIcon()
    if not RadioActived then
        SendNUIMessage({
            type = 'changeRadioIcon',
            icon = 'none'
        })
    else
        if RadioMute then
            SendNUIMessage({
                type = 'changeRadioIcon',
                icon = './img/6.png'
            })
        else
            SendNUIMessage({
                type = 'changeRadioIcon',
                icon = './img/5.png'
            })
        end
    end
    
    if RadioActived then
        SendNUIMessage({
            type = 'IconRadio',
            toggle = false
        })
    else
        SendNUIMessage({
            type = 'IconRadio',
            toggle = true
        })
    end
end

Citizen.CreateThread(function()
    Wait(1000)
    exports["pma-voice"]:setRadioVolume(currentVolume)
    exports["pma-voice"]:setVoiceProperty("micClicks", true)
    
    SendNUIMessage({
        type = 'IconRadio',
        toggle = true
    })
    
    if json.encode(GetFieldValueFromName("zroleplayFreqRadio")) ~= "[]" then
        local freq = GetFieldValueFromName("zroleplayFreqRadio")
        updateRadioIcon()
    end
end)

-- Fonction optimisée pour vérifier si le joueur possède une radio
function hasRadio()
    for k, v in pairs(playerInventory) do
        if v.name == "radio" and v.count > 0 then
            return true
        end
    end
    return false
end
exports("hasRadio", hasRadio)

-- Fonction pour désactiver complètement la radio
function disableRadioCompletely()
    exports["pma-voice"]:setVoiceProperty("radioEnabled", false)
    exports["pma-voice"]:SetRadioChannel(0)
    radioFreq = 0
    radioActif = false
    RadioActived = false
    RadioMute = false
    IconeRadioMute()
    closeRadio()
    SetKeepInputMode(false)
    ESX.ShowNotification("~r~Vous n'avez plus de radio.")
end

-- Thread optimisé pour vérifier périodiquement si le joueur possède toujours une radio
-- Ne se lance que si la radio est activée
local radioCheckThread = nil
function startRadioCheck()
    if radioCheckThread then return end
    
    radioCheckThread = Citizen.CreateThread(function()
        while RadioActived or radioActif do
            Citizen.Wait(5000) -- Vérifier toutes les 5 secondes
            if not hasRadio() then
                disableRadioCompletely()
                break
            end
        end
        radioCheckThread = nil
    end)
end

function loadAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Citizen.Wait(10)
    end
end

function playRadioAnim()
    local ped = PlayerPedId()
    loadAnimDict("random@arrests")
    TaskPlayAnim(ped, "random@arrests", "generic_radio_chatter", 8.0, 2.0, -1, 49, 0, false, false, false)
end

function stopRadioAnim()
    local ped = PlayerPedId()
    StopAnimTask(ped, "random@arrests", "generic_radio_chatter", -4.0)
end

AddEventHandler('pma-voice:radioActive', function(isActive)
    if RadioActived then
        if isActive and not RadioMute then
            playRadioAnim()
            SendNUIMessage({
                type = 'radioTalking',
                talking = true
            })
            
            SendNUIMessage({
                type = 'IconRadio',
                toggle = false
            })
            
            SendNUIMessage({
                type = 'changeRadioIcon',
                icon = './img/5.png'
            })
        else
            stopRadioAnim()
            SendNUIMessage({
                type = 'radioTalking',
                talking = false
            })
            
            if RadioActived and not RadioMute then
                SendNUIMessage({
                    type = 'changeRadioIcon',
                    icon = './img/5.png'
                })
            elseif RadioActived and RadioMute then
                SendNUIMessage({
                    type = 'changeRadioIcon',
                    icon = './img/6.png'
                })
            end
        end
    else
        stopRadioAnim()
        SendNUIMessage({
            type = 'IconRadio',
            toggle = true
        })
        
        SendNUIMessage({
            type = 'changeRadioIcon',
            icon = 'none'
        })
    end
end)

RegisterNetEvent('esx:removeInventoryItem')
AddEventHandler('esx:removeInventoryItem', function(item, count)
	if item == "radio" then
        -- Mettre à jour le cache d'inventaire
        for k, v in pairs(playerInventory) do
            if v.name == "radio" then
                v.count = v.count - count
                break
            end
        end
        
        if not hasRadio() then
            disableRadioCompletely()
        end
	end
end)

RegisterNetEvent('esx:addInventoryItem')
AddEventHandler('esx:addInventoryItem', function(item, count)
	if item == "radio" then
        -- Mettre à jour le cache d'inventaire
        for k, v in pairs(playerInventory) do
            if v.name == "radio" then
                v.count = v.count + count
                return
            end
        end
        -- Si l'item n'existe pas dans le cache, l'ajouter
        table.insert(playerInventory, {name = "radio", count = count})
	end
end)

function toggleRadio()
    if not hasRadio() then
        ESX.ShowNotification("~r~Vous n'avez pas de radio.")
        return
    end
    
    radioOpen = not radioOpen
    SendNUIMessage({
        type = 'showradio',
        toggle = radioOpen
    })
    
    if radioOpen then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)
        SetKeepInputMode(true)
        startKeyCheckThread() -- Démarrer le thread de vérification des touches
    else
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        SetKeepInputMode(false)
        stopKeyCheckThread() -- Arrêter le thread de vérification des touches
    end
end

function closeRadio()
    radioOpen = false
    SendNUIMessage({
        type = 'showradio',
        toggle = false
    })
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SetKeepInputMode(false)
    stopKeyCheckThread() -- Arrêter le thread de vérification des touches
end

RegisterNetEvent('setActiveRadio')
AddEventHandler('setActiveRadio', function()
    if radioOpen then
        closeRadio()
    else
        toggleRadio()
    end
end)

RegisterKeyMapping("volumeUp", "Augmenter le volume de la radio de 10%", "keyboard", "PAGEUP")
RegisterCommand("volumeUp", function()
    if not hasRadio() then return end
    
    if radioFreq == 1 and radioActif and currentVolume >= 0 and currentVolume < 100 then
        currentVolume = currentVolume + 5
        exports['pma-voice']:setRadioVolume(currentVolume)
        ESX.DrawMissionText("Volume de la radio à "..math.floor(currentVolume).."%", 2000)
    end
end)

RegisterKeyMapping("volumeDown", "Réduire le volume de la radio de 10%", "keyboard", "PAGEDOWN")
RegisterCommand("volumeDown", function()
    if not hasRadio() then return end
    
    if radioFreq == 1 and radioActif and currentVolume > 0 then
        currentVolume = currentVolume - 5
        exports['pma-voice']:setRadioVolume(currentVolume)
        ESX.DrawMissionText("Volume de la radio à "..math.floor(currentVolume).."%", 2000)
    end
end)

RegisterNetEvent('IconeMuteRadio')
AddEventHandler('IconeMuteRadio', function(status)
    RadioMute = status
    updateRadioIcon()
    
    SendNUIMessage({
        type = 'showMuteIcon',
        toggle = status
    })
    SendNUIMessage({
        type = 'IconRadio',
        toggle = status
    })
    SendNUIMessage({
        type = 'IconMicro',
        toggle = status
    })
end)

function IconeRadioMute()
    SendNUIMessage({
        type = 'showMuteIcon',
        toggle = true
    })
    SendNUIMessage({
        type = 'IconRadio',
        toggle = true
    })
    SendNUIMessage({
        type = 'IconMicro',
        toggle = true
    })
    SendNUIMessage({
        type = 'setFrequence',
        data = ""
    })
end
 
RegisterNUICallback('requestFreq', function(data, cb)
    if not hasRadio() then
        ESX.ShowNotification("~r~Vous n'avez pas de radio.")
        closeRadio()
        cb('ok')
        return
    end
    
    if RadioActived then
        SetNuiFocus(false, false)
        local frequence = ESX.KeyboardInput("Fréquence", 5)

        for k, v in pairs(FrequenceJob) do           
            if tonumber(frequence) == v.freq and PlayerData.job.name ~= v.job then
                SetNuiFocus(true, true)
                ESX.ShowNotification("~r~Impossible de se connecter à une fréquence privée.")
                return
            end
        end

        if frequence ~= '' and tonumber(frequence) and frequence ~= nil then
            SendNUIMessage({
                type = 'setFrequence',
                data = frequence
            })
            ESX.ShowNotification("Vous avez ~g~connecté~s~ votre ~g~radio~s~ à la fréquence ~g~"..frequence.."Hz")
            exports["pma-voice"]:setVoiceProperty("radioEnabled", true)
            exports["pma-voice"]:SetRadioChannel(tonumber(frequence))
            SetFieldValueFromNameEncode("zroleplayFreqRadio", frequence)
            radioFreq = 1
            
            RadioMute = false
            
            updateRadioIcon()
            
            SetNuiFocus(true, true)
            TriggerEvent("CallRadioDefault")
        else
            SetNuiFocus(true, true)
        end
    end
    cb('ok')
end)

RegisterNUICallback('closeRadio', function()
    closeRadio()
end)

RegisterNUICallback('muteRadio', function()
    if not hasRadio() then
        ESX.ShowNotification("~r~Vous n'avez pas de radio.")
        closeRadio()
        return
    end
    
    if RadioActived then
        PlayRadioClickSound(not RadioMute)
        
        ExecuteCommand('-muteradio')
    end
end)

RegisterNUICallback('offRadio', function()
    if not hasRadio() then
        ESX.ShowNotification("~r~Vous n'avez pas de radio.")
        closeRadio()
        return
    end
    
    if RadioActived then
        PlayRadioClickSound(false)
        
        TriggerEvent('radio:disableRadioAnimationPermanently')
        ExecuteCommand('me éteint sa radio')
        exports["pma-voice"]:setVoiceProperty("radioEnabled", false)
        exports["pma-voice"]:SetRadioChannel(0)
        ESX.ShowNotification("Vous avez ~r~désactivé~s~ la radio.")
        radioFreq = 0
        RadioActived = false
        RadioMute = false
        radioActif = false
        
        updateRadioIcon()
        
        SendNUIMessage({
            type = 'IconRadio',
            toggle = true
        })
        
        SendNUIMessage({
            type = 'setFrequence',
            data = ""
        })
        
        SendNUIMessage({
            type = 'showMuteIcon',
            toggle = true
        })
        SendNUIMessage({
            type = 'radioTalking',
            talking = false
        })
    else
        PlayRadioClickSound(true)
        
        ExecuteCommand('me allume sa radio')
        
        ESX.ShowNotification("Vous avez ~g~activé~s~ la radio.")
        RadioActived = true
        radioActif = true
        RadioMute = false
        
        startRadioCheck() -- Démarrer la vérification de la radio
        
        SendNUIMessage({
            type = "showIconsRadioOn"
        })
        
        SendNUIMessage({
            type = 'changeRadioIcon',
            icon = './img/5.png'
        })
        
        SendNUIMessage({
            type = 'IconRadio',
            toggle = false
        })
        
        if json.encode(GetFieldValueFromName("zroleplayFreqRadio")) ~= "[]" then
            local freq = GetFieldValueFromName("zroleplayFreqRadio")

            for k, v in pairs(FrequenceJob) do           
                if tonumber(freq) == v.freq and PlayerData.job.name ~= v.job then
                    SetNuiFocus(true, true)
                    return
                end
            end

            SendNUIMessage({
                type = 'setFrequence',
                data = freq
            })
            ESX.ShowNotification("Vous avez ~g~connecté~s~ votre ~g~radio~s~ à la fréquence ~g~"..freq.."Hz")
            exports["pma-voice"]:setVoiceProperty("radioEnabled", true)
            exports["pma-voice"]:SetRadioChannel(tonumber(freq))
            SetFieldValueFromNameEncode("zroleplayFreqRadio", freq)
            radioFreq = 1
            RadioMute = false
            
            updateRadioIcon()
            
            SetNuiFocus(true, true)
            TriggerEvent("CallRadioDefault")
        end
    end
end)

RegisterNUICallback('volumeUp', function()
    if not hasRadio() then
        ESX.ShowNotification("~r~Vous n'avez pas de radio.")
        closeRadio()
        return
    end
    
    if radioFreq and RadioActived and currentVolume >= 0 and currentVolume < 100 then
        currentVolume = currentVolume + 5
        exports['pma-voice']:setRadioVolume(currentVolume)
        ESX.DrawMissionText("Volume de la ~g~radio~s~ à "..math.floor(currentVolume).."%", 2000)
    end
end)

RegisterNUICallback('volumeDown', function()
    if not hasRadio() then
        ESX.ShowNotification("~r~Vous n'avez pas de radio.")
        closeRadio()
        return
    end
    
    if radioFreq and RadioActived and currentVolume > 0 then
        currentVolume = currentVolume - 5
        exports['pma-voice']:setRadioVolume(currentVolume)
        ESX.DrawMissionText("Volume de la ~g~radio~s~ à "..math.floor(currentVolume).."%", 2000)
    end
end)

local controlDisabled = {1, 2, 3, 4, 5, 6, 18, 24, 25, 37, 68, 69, 70, 91, 92, 182, 199, 200, 257}

function SetKeepInputMode(bool)
    if SetNuiFocusKeepInput then
        SetNuiFocusKeepInput(bool)
    end

    KEEP_FOCUS = bool

    if not threadCreated and bool then
        threadCreated = true

        Citizen.CreateThread(function()
            while KEEP_FOCUS do
                Wait(0)

                DisableControlAction(0, 1, true)
                DisableControlAction(0, 2, true)
                DisableControlAction(0, 3, true)
                DisableControlAction(0, 4, true)
                DisableControlAction(0, 5, true)
                DisableControlAction(0, 6, true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 37, true)
                
                EnableControlAction(0, 289, true)
                EnableControlAction(0, 311, true)
                EnableControlAction(0, 157, true)
                EnableControlAction(0, 158, true)
                EnableControlAction(0, 160, true)
                EnableControlAction(0, 164, true)
                EnableControlAction(0, 165, true)
                
                for i = 157, 165 do
                    EnableControlAction(0, i, true)
                end

                for i = 288, 289 do
                    EnableControlAction(0, i, true)
                end

                EnableControlAction(0, 303, true)
                EnableControlAction(0, 244, true)
            end

            threadCreated = false
        end)
    end
end

-- Thread optimisé pour la vérification des touches - ne se lance que quand la radio est ouverte
function startKeyCheckThread()
    if keyCheckThread then return end
    
    keyCheckThread = Citizen.CreateThread(function()
        while radioOpen do
            Wait(100) -- Optimisé de 1ms à 100ms
            
            if IsControlJustPressed(0, 177) then
                closeRadio()
                break
            end
            
            if IsControlJustPressed(0, 194) then
                closeRadio()
                break
            end
        end
        keyCheckThread = nil
    end)
end

function stopKeyCheckThread()
    keyCheckThread = nil
end

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
end)

RegisterNetEvent('pma-voice:muteStateChanged')
AddEventHandler('pma-voice:muteStateChanged', function(isMuted)
    RadioMute = isMuted
    updateRadioIcon()
end)

function PlayRadioClickSound(clickType)
    if clickType then
        PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
    else
        PlaySoundFrontend(-1, "NAV_LEFT_RIGHT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
    end
end

RegisterNetEvent('radio:disableRadioAnimationPermanently')
AddEventHandler('radio:disableRadioAnimationPermanently', function()
    TriggerEvent('pma-voice:disableRadioAnimation')
    
    exports["pma-voice"]:setVoiceProperty("enableRadioAnim", false)
end)

Citizen.CreateThread(function()
    Wait(2000)
    TriggerEvent('radio:disableRadioAnimationPermanently')
end)