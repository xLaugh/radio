let resourceName = 'radio'

$(function(){
    let radioOpen = false
    window.addEventListener('message', (event) => {
        if (event.data.type == 'showradio'){
            radioOpen = !radioOpen
            if (event.data.toggle === true) {
                $('.radioUI').show()
            } else {
                $('.radioUI').hide()
            }
        } else if (event.data.type === 'setFrequence'){
            $('.radioState').html(event.data.data)
        } else if (event.data.type === 'showIconsRadioOn') {
            $('#radioHZ').show()
            $('#radioNetwork').show()
        } else if (event.data.type === 'showMuteIcon'){
            if (event.data.toggle) {
                $('#radioMute').show()
                $('#radioRec').hide()
            } else {
                $('#radioRec').show()
                $('#radioMute').hide()
            }
        } else if (event.data.type === 'radioTalking') {
            if (event.data.talking) {
                // Effet visuel quand on parle dans la radio
                $('#radioRec').css('opacity', '1')
                $('#radioNetwork').css('opacity', '1')
                // Animation de pulsation
                animateRadioTalking()
            } else {
                // Retour à la normale
                $('#radioRec').css('opacity', '0.7')
                $('#radioNetwork').css('opacity', '0.7')
                // Arrêter l'animation
                stopRadioTalkingAnimation()
            }
        }
    });

    window.addEventListener('keydown', (e) => {
        // Touche P (80) pour fermer la radio
        if (e.keyCode == 80) {
            $.post('https://radio/closeRadio')
        }
        
        // Touche Échap (27) pour fermer la radio
        if (e.keyCode == 27) {
            $.post('https://radio/closeRadio')
        }
        
        // Touche DEL/Retour (8) pour fermer la radio
        if (e.keyCode == 8) {
            $.post('https://radio/closeRadio')
        }
    })

});

$('#radioManual').click(() => {
    $.post(`https://${resourceName}/requestFreq`)
})

$('#radioButtonMute').click(() => {
    $.post(`https://${resourceName}/muteRadio`)
})

$("#radioToggle").click(() => {
    $('.radioState').html('')
    $('#radioRec').hide()
    $('#radioMute').hide()
    $('#radioHZ').hide()
    $('#radioNetwork').hide()
    $.post(`https://${resourceName}/offRadio`)
})

$('#radioUP').click(() => {
    $.post(`https://${resourceName}/volumeUp`)
})

$('#radioDown').click(() => {
    $.post(`https://${resourceName}/volumeDown`)
})

window.addEventListener('message', function(e) {
    $("#container").stop(false, true);
    if (e.data.type == 'IconRadio'){
        if (e.data.toggle === true) {
            $("#container").css('display', 'none');
        } else {
            $("#container").css('display', 'flex');
        }
    } else if (e.data.type == 'changeRadioIcon') {
        $("header img").attr('src', e.data.icon);
    } else if (e.data.sound) {
        // Jouer les sons de clic de micro
        let audioElement = document.createElement('audio');
        audioElement.setAttribute('src', `./sounds/${e.data.sound}.ogg`);
        audioElement.volume = e.data.volume || 0.1;
        audioElement.play();
    }
});

// Fonction pour animer l'effet de pulsation quand on parle dans la radio
function animateRadioTalking() {
    // Arrêter toute animation en cours
    stopRadioTalkingAnimation()
    
    // Créer une animation de pulsation
    $('#radioRec').addClass('pulsating')
    $('#radioNetwork').addClass('pulsating')
}

// Fonction pour arrêter l'animation
function stopRadioTalkingAnimation() {
    $('#radioRec').removeClass('pulsating')
    $('#radioNetwork').removeClass('pulsating')
}