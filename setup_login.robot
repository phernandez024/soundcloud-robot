*** Settings ***
Library    Browser

*** Variables ***
${STATE_FILE}    storage/state.json
${TIMEOUT}       10 s

*** Keywords ***
Handle Cookies If Any
    # Intenta detectar consentimiento en iframe o en la página
    ${has_iframe}=    Run Keyword And Return Status    Get Element Count    xpath=//iframe[contains(@src,'consent') or contains(@id,'sp_message_iframe')]
    IF    ${has_iframe}
        Select Frame    xpath=//iframe[contains(@src,'consent') or contains(@id,'sp_message_iframe')]
        ${btns}=    Get Element Count    xpath=//button[.//text()[contains(.,'Accept') or contains(.,'Aceptar') or contains(.,'Agree')]]
        IF    ${btns} > 0
            Click    xpath=(//button[.//text()[contains(.,'Accept') or contains(.,'Aceptar') or contains(.,'Agree')]])[1]
        END
        Unselect Frame
    END
    ${btns2}=    Get Element Count    xpath=//button[.//text()[contains(.,'Accept') or contains(.,'Aceptar') or contains(.,'Agree')]]
    IF    ${btns2} > 0
        Click    xpath=(//button[.//text()[contains(.,'Accept') or contains(.,'Aceptar') or contains(.,'Agree')]])[1]
    END

Logged In?
    # Consideramos login correcto si aparece enlace a "You" o "Upload"
    ${c}=    Get Element Count    xpath=//a[contains(@href,'/you')] | //a[contains(@href,'/upload')]
    Should Be True    ${c} > 0

*** Test Cases ***
Login manual y guardar sesión
    New Browser    chromium    headless=False
    New Context
    New Page    https://soundcloud.com/signin
    Handle Cookies If Any
    Log To Console    >>> Inicia sesión MANUALMENTE ahora (usuario/contraseña/2FA si aplica)...
    # Reintenta durante ~3 minutos (60*3s) hasta detectar que estás logueado
    Wait Until Keyword Succeeds    60x    3 s    Logged In?
    Log To Console    >>> Sesión detectada. Guardando estado...
    # Asegúrate de que existe la carpeta storage
    New Page    about:blank
    ${_}=    Run Keyword And Ignore Error    Create Directory    storage
    Save Storage State    ${STATE_FILE}
    Close Browser
