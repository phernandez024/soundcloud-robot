*** Settings ***
Documentation     Hypeddit flow – Download gate (SC connect + IG follow) y descarga final.
Resource          ./browser_keywords.resource
Library           SeleniumLibrary
Library           OperatingSystem
Library           Process
Suite Setup       Open Edge With Default Windows Profile
Suite Teardown    Close All Browsers

*** Variables ***
${HYPEDDIT_URL}          https://hypeddit.com/azzik/thecardigansmyfavouritegameazzikschranzedit
${COMMENT_TEXT}          fire
${BASE_TIMEOUT}          15 s
${PAGE_WAIT}             15 s
${POPUP_TIMEOUT}         12 s
${SHORT_PAUSE}           0.7 s
${AFTER_SWITCH_PAUSE}    1 s
${POPUP_AUTOCLOSE_WAIT}    1.2 s 
${POPUP_AUTOCLOSE_TIMEOUT}      6 s  
${DOWNLOAD_DIR}          ${OUTPUT DIR}${/}downloads

*** Keywords ***
Open Hypeddit
    [Documentation]    Abre la URL de Hypeddit y espera al botón Download principal.
    Create Directory    ${DOWNLOAD_DIR}
    Go To    ${HYPEDDIT_URL}
    Wait Until Page Contains Element    css=#downloadProcess    ${PAGE_WAIT}
    Sleep    ${SHORT_PAUSE}

Click Download And Fill Comment
    [Documentation]    Click en "Download", escribe el comentario y prepara el login a SoundCloud.
    Scroll Element Into View    css=#downloadProcess
    Sleep    ${SHORT_PAUSE}
    Click Element    css=#downloadProcess
    Sleep    ${SHORT_PAUSE}
    Wait Until Page Contains Element    css=#sc_comment_text    ${PAGE_WAIT}
    Input Text    css=#sc_comment_text    ${COMMENT_TEXT}
    Sleep    ${SHORT_PAUSE}

Wait For New Window And Switch
    [Arguments]    @{before_handles}
    ${attempts}=    Set Variable    5
    ${new}=         Set Variable    ${EMPTY}
    FOR    ${i}    IN RANGE    ${attempts}
        ${after}=    Get Window Handles
        ${new}=      Set Variable    ${EMPTY}
        FOR    ${h}    IN    @{after}
            ${seen}=    Run Keyword And Return Status    List Should Contain Value    ${before_handles}    ${h}
            IF    not ${seen}
                ${new}=    Set Variable    ${h}
                BREAK
            END
        END
        IF    '${new}'!=''
            ${ok}=    Run Keyword And Return Status    Switch Window    handle=${new}
            IF    ${ok}
                Sleep    ${AFTER_SWITCH_PAUSE}
                RETURN    ${new}
            END
        END
        Sleep    0.3 s
    END
    Log To Console    ⚠️ No apareció popup (o se cerró demasiado rápido); seguimos en la ventana actual
    RETURN    None

Wait Until Windows Equal
    [Arguments]    ${target_count}    ${timeout}=5 s
    Wait Until Keyword Succeeds    ${timeout}    0.25 s    Number Of Windows Should Be    ${target_count}



New Window Should Have Opened
    [Arguments]    @{before}
    ${now}=    Get Window Handles
    ${n1}=     Get Length    ${before}
    ${n2}=     Get Length    ${now}
    Should Be True    ${n2} > ${n1}

Wait For Windows To Close Back
    [Arguments]    ${target_count}
    [Documentation]    Espera a que el número de ventanas vuelva a ${target_count}.
    Wait Until Keyword Succeeds    20x    0.5 s    Number Of Windows Should Be    ${target_count}
    Sleep    ${AFTER_SWITCH_PAUSE}

Number Of Windows Should Be
    [Arguments]    ${expected}
    ${now}=    Get Window Handles
    ${n}=      Get Length    ${now}
    Should Be Equal As Integers    ${n}    ${expected}

Connect SoundCloud Popup And Return
    [Documentation]    Click en “Connect” → manejar popup de SoundCloud → “Conectar y continuar” → volver.
    ${parent_title}=    Get Title
    ${before}=          Get Window Handles
    Wait Until Element Is Visible    css=#login_to_sc    ${PAGE_WAIT}
    Sleep    ${SHORT_PAUSE}
    Click Element    css=#login_to_sc
    Log To Console      🛎️ Botón clickado

    # Cambiar a la popup de SoundCloud
    Wait For New Window And Switch    @{before}
    Sleep    ${AFTER_SWITCH_PAUSE}
    Wait Until Page Contains Element    css=#submit_approval    ${POPUP_TIMEOUT}
    Sleep    ${SHORT_PAUSE}
    Click Button    css=#submit_approval


Do Instagram Step (open/close) And Next
    [Documentation]    Abre popup de IG, espera ~1s y cierra. Luego pulsa "Next".
    ${parent_title}=    Get Title
    ${before}=          Get Window Handles

    ${ig}=       Set Variable    //a[contains(@class,'button-instagram')]
    ${present}=  Run Keyword And Return Status    Page Should Contain Element    xpath=${ig}
    IF    ${present}
        Sleep    ${SHORT_PAUSE}
        Click Element    xpath=${ig}
        ${ig_popup}=    Wait For New Window And Switch    @{before}
        IF    '${ig_popup}'!='None'
            Sleep    1.0 s
            Close Window
            Sleep    ${SHORT_PAUSE}
        ELSE
            Log To Console    🔎 IG no abrió popup (o se cerró muy rápido)
        END
        Switch Window    title=${parent_title}
        Sleep    ${AFTER_SWITCH_PAUSE}
    ELSE
        Log To Console    🔎 Botón de Instagram no presente (gate puede omitirlo)
    END

    Wait Until Element Is Visible    css=#skipper_ig_channel    ${PAGE_WAIT}
    Sleep    ${SHORT_PAUSE}
    Click Button    css=#skipper_ig_channel
    Sleep    ${AFTER_SWITCH_PAUSE}

Disable Connect Auto Trigger (optional)
    ${js}=    Catenate    SEPARATOR=
    ...    (function(){
    ...      var a=document.querySelector('#login_to_sc');
    ...      if(!a) return;
    ...      a.onclick=null;
    ...      a.removeAttribute('data-onclick');
    ...      a.setAttribute('data-onclick-disabled','1');
    ...      a.removeAttribute('target');
    ...    })();
    Execute Javascript    ${js}
    Sleep    ${SHORT_PAUSE}

Is Hypeddit Connect Step Complete
    ${has_ig}=       Run Keyword And Return Status    Page Should Contain Element    xpath=//a[contains(@class,'button-instagram')]
    ${has_next}=     Run Keyword And Return Status    Page Should Contain Element    css=#skipper_ig_channel
    ${has_dl}=       Run Keyword And Return Status    Page Should Contain Element    css=#gateDownloadButton
    ${has_connect}=  Run Keyword And Return Status    Page Should Contain Element    css=#login_to_sc
    ${done}=         Evaluate    ${has_ig} or ${has_next} or ${has_dl} or (not ${has_connect})
    RETURN    ${done}

Final Gate Download
    [Documentation]    Pulsa el botón final "Download".
    Wait Until Element Is Visible    css=#gateDownloadButton    ${PAGE_WAIT}
    Sleep    ${SHORT_PAUSE}
    Click Element    css=#gateDownloadButton
    # (Opcional) aquí podrías esperar al archivo en ${DOWNLOAD_DIR}

*** Test Cases ***
Hypeddit – flujo de prueba (SC connect + IG + download)
    Open Hypeddit
    Click Download And Fill Comment
    Connect SoundCloud Popup And Return
    Do Instagram Step (open/close) And Next
    Final Gate Download