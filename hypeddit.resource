*** Settings ***
Library           SeleniumLibrary
Library           OperatingSystem
Library           Collections
Library           BuiltIn

*** Variables ***
${BASE_TIMEOUT}          15s
${PAGE_WAIT}             15s
${SHORT_PAUSE}           700ms
${AFTER_SWITCH_PAUSE}    1s

*** Keywords ***
Run Hypeddit Flow
    [Documentation]    Ejecuta el flujo completo de Hypeddit en ${hypeddit_url}.
    ...                1) Download -> comment -> login SC en popup y aprobar
    ...                2) Paso Instagram: abre popup, espera y cierra
    ...                3) Click Download final
    [Arguments]    ${hypeddit_url}    ${comment_text}=fire    ${download_dir}=${OUTPUT DIR}${/}downloads
    Create Directory    ${download_dir}

    # 0) Ir a la URL de Hypeddit
    #Go To    ${hypeddit_url}
    Wait Until Page Contains Element    css=#downloadProcess    ${PAGE_WAIT}
    Sleep    ${SHORT_PAUSE}

    # 1) Click en Download + comentar + abrir login SC
    Scroll Element Into View    css=#downloadProcess
    Click Element    css=#downloadProcess
    Sleep    ${SHORT_PAUSE}
    Wait Until Page Contains Element    css=#sc_comment_text    ${PAGE_WAIT}
    Input Text    css=#sc_comment_text    ${comment_text}
    Sleep    ${SHORT_PAUSE}
    Click Element    css=#login_to_sc
    Log To Console    Esperando popup de SoundCloud… ⌛

    # 1.1) Cambiar a la ventana nueva (robusto, sin "Wait Until Number Of Windows Is")
    ${handles_before}=    Get Window Handles
    Switch To Last Window
    Sleep    ${AFTER_SWITCH_PAUSE}

    # 1.2) Aprobar en el popup y volver
    # Ajusta el locator si tu botón difiere
    Wait Until Page Contains Element    css=#submit_approval    ${PAGE_WAIT}
    Click Button    css=#submit_approval
    Sleep    ${SHORT_PAUSE}
    Switch Window        url:${hypeddit_url}
    Log To Console    Fin Paso "Connect" 🧩

    # 2) Instagram: abrir popup, cerrarlo, y Next
    Wait Until Page Contains Element    css=#instagram_status    ${PAGE_WAIT}
    Click Element    css=#instagram_status
    Log To Console    Botón Instagram clickado
    Sleep    ${SHORT_PAUSE}
    Switch To Last Window
    Sleep    1s
    Close Window
    Log To Console    Popup de Instagram cerrado
    Sleep    ${SHORT_PAUSE}
    Switch Window        url:${hypeddit_url}

    # Click en el botón Next visible (algunos flujos muestran #skipper_ig_next, otros #skipper_ig_channel)
    Click Visible Next

    Log To Console    Fin Paso Instagram

    # 3) Download final
    Wait Until Element Is Visible    css=#gateDownloadButton    ${PAGE_WAIT}
    Sleep    ${SHORT_PAUSE}
    Click Element    css=#gateDownloadButton
    Sleep    3
    Close Window

# ------------------------
# Helpers reutilizables
# ------------------------

Wait For New Window
    [Arguments]    @{handles_before}    ${timeout}=10s    ${interval}=500ms
    Wait Until Keyword Succeeds    ${timeout}    ${interval}    New Window Should Exist    @{handles_before}

New Window Should Exist
    [Arguments]    @{handles_before}
    ${current}=       Get Window Handles
    ${before_len}=    Get Length    ${handles_before}
    ${now_len}=       Get Length    ${current}
    Should Be True    ${now_len} > ${before_len}

Switch To Last Window
    ${handles}=    Get Window Handles
    ${last}=       Evaluate    len($handles)-1
    Switch Window  ${handles}[${last}]

Switch Window By Url
    [Arguments]    ${url}
    # Intenta por URL; si falla, vuelve a la 1ª ventana como fallback
    ${status}    ${msg}=    Run Keyword And Ignore Error    Switch Window    url:${url}
    Run Keyword If    '${status}'=='PASS'        RETURN
    Switch Window    index=0

Click Visible Next
    # Elige el Next visible y clicable; si no, fuerza por JS en skipper_ig_channel
    ${next1}=    Run Keyword And Return Status    Element Should Be Visible    css=#skipper_ig_next
    IF    ${next1}
        Wait Until Element Is Enabled    css=#skipper_ig_next    ${BASE_TIMEOUT}
        Click Element                    css=#skipper_ig_next
        RETURN
    END
    ${next2}=    Run Keyword And Return Status    Element Should Be Visible    css=#skipper_ig_channel
    IF    ${next2}
        Wait Until Element Is Enabled    css=#skipper_ig_channel    ${BASE_TIMEOUT}
        # primero intenta click normal…
        ${ok}    ${_}=    Run Keyword And Ignore Error    Click Element    css=#skipper_ig_channel
        IF    '${ok}'=='PASS'
            RETURN
        END
        # …si no, fuerza el click por JS (evita ElementNotInteractable)
        Execute Javascript    document.getElementById('skipper_ig_channel')?.click()
        RETURN
    END
    Fail    No hay botón Next visible (ni #skipper_ig_next ni #skipper_ig_channel).
