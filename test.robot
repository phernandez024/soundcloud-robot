*** Settings ***
Documentation     SoundCloud downloader – dos modos de abrir el menú (click en pista vs hover en playlist) y descargar si está disponible.
Library           SeleniumLibrary
Library           OperatingSystem
Suite Setup       Open Edge With My Profile
Suite Teardown    Close All Browsers

*** Variables ***
${BASE_TIMEOUT}           15 s
${EDGE_USER_DATA_DIR}     C:/Users/USER/AppData/Local/Microsoft/Edge/User Data
${EDGE_PROFILE_DIR}       Default
${PLAYLIST_URL}           https://soundcloud.com/doncucho/sets/schranz-3
${TRACK_NUM}              5
${OPEN_METHOD}            click          # click = abrir página de la pista (opción A). hover = menú dentro de la playlist (opción B)
${DOWNLOAD_DIR}           ${OUTPUT DIR}${/}downloads
${DOWNLOAD_TIMEOUT}       2 min

*** Keywords ***
Open Edge With My Profile
    [Documentation]    Abre Edge con tu perfil y fija la carpeta de descargas sin diálogos.
    Create Directory    ${DOWNLOAD_DIR}
    ${opt}=    Evaluate    __import__('selenium.webdriver.edge.options', fromlist=['Options']).Options()

    # Flags del navegador (posicionales)
    ${arg_user}=        Set Variable    --user-data-dir=${EDGE_USER_DATA_DIR}
    ${arg_prof}=        Set Variable    --profile-directory=${EDGE_PROFILE_DIR}
    ${arg_max}=         Set Variable    --start-maximized
    ${arg_devshm}=      Set Variable    --disable-dev-shm-usage
    ${arg_no_first}=    Set Variable    --no-first-run
    ${arg_no_default}=  Set Variable    --no-default-browser-check
    ${arg_allow}=       Set Variable    --remote-allow-origins=*
    # ${arg_no_ext}=      Set Variable    --disable-extensions

    Call Method    ${opt}    add_argument    ${arg_user}
    Call Method    ${opt}    add_argument    ${arg_prof}
    Call Method    ${opt}    add_argument    ${arg_max}
    Call Method    ${opt}    add_argument    ${arg_devshm}
    Call Method    ${opt}    add_argument    ${arg_no_first}
    Call Method    ${opt}    add_argument    ${arg_no_default}
    Call Method    ${opt}    add_argument    ${arg_allow}
    # Call Method    ${opt}    add_argument    ${arg_no_ext}

    # Preferencias de descarga (silenciosa)
    ${prefs}=    Evaluate    {"download.default_directory": r"""${DOWNLOAD_DIR}""", "download.prompt_for_download": False, "download.directory_upgrade": True, "safebrowsing.enabled": True}
    Call Method   ${opt}    add_experimental_option    prefs    ${prefs}

    Create WebDriver    Edge    options=${opt}
    Set Selenium Timeout    ${BASE_TIMEOUT}
    Log To Console    ✅ Edge abierto con perfil: ${EDGE_PROFILE_DIR} — Descargas en: ${DOWNLOAD_DIR}

Open Playlist
    Go To    ${PLAYLIST_URL}

Ensure Track Item Is Rendered
    [Arguments]    ${n}
    [Documentation]    Hace scroll hasta que el <li> de la pista n esté en el DOM/viewport.
    ${li}=    Set Variable    (//li[contains(@class,'trackList__item') or contains(@class,'soundList__item')])[${n}]
    :FOR    ${i}    IN RANGE    0    40
    \   ${ok}=    Run Keyword And Return Status    Page Should Contain Element    xpath=${li}
    \   Exit For Loop If    ${ok}
    \   Execute JavaScript    window.scrollBy(0, 800)
    \   Sleep    0.2 s
    Wait Until Page Contains Element    xpath=${li}    ${BASE_TIMEOUT}
    Scroll Element Into View            xpath=${li}

Open Track Page By Index
    [Arguments]    ${n}
    [Documentation]    Opción A: dentro de la playlist, clica el título para abrir la página de esa pista.
    Ensure Track Item Is Rendered    ${n}
    ${li}=      Set Variable    (//li[contains(@class,'trackList__item') or contains(@class,'soundList__item')])[${n}]
    ${link}=    Set Variable    ${li}//a[contains(@class,'trackItem__trackTitle') or contains(@class,'soundTitle__title') or contains(@href,'/tracks/')]
    Wait Until Element Is Visible    xpath=${link}    ${BASE_TIMEOUT}
    Click Element                    xpath=${link}
    # SPA: espera a que la URL sea de pista
    Wait Until Keyword Succeeds    60x    0.5 s    Location Should Contain    /tracks/
    # Y a que cargue el bloque principal de la vista de pista
    Wait Until Page Contains Element    //div[contains(@class,'listenEngagement') or contains(@class,'fullListen') or contains(@class,'playControls')]    ${BASE_TIMEOUT}

Open More Menu On Track Page
    [Documentation]    En la página de pista, abre el menú More/… (estático).
    ${more_xpath}=    Set Variable    //button[contains(@class,'sc-button-more') or @aria-label='More' or @aria-label='Más' or @title='More' or @title='Más' or .//span[normalize-space(.)='More'] or .//span[normalize-space(.)='Más']]
    Wait Until Page Contains Element    xpath=${more_xpath}    ${BASE_TIMEOUT}
    Scroll Element Into View            xpath=${more_xpath}
    Wait Until Element Is Visible       xpath=${more_xpath}    ${BASE_TIMEOUT}
    Click Element                       xpath=${more_xpath}

Open More Menu From Playlist By Hover
    [Arguments]    ${n}
    [Documentation]    Opción B: hace hover sobre el <li> de la pista en la playlist y abre el menú contextual.
    Ensure Track Item Is Rendered    ${n}
    ${li}=      Set Variable    (//li[contains(@class,'trackList__item') or contains(@class,'soundList__item')])[${n}]
    Mouse Over    xpath=${li}
    ${more_in_li}=    Set Variable    ${li}//button[contains(@class,'more') or contains(@class,'sc-button-more') or @aria-label='More' or @aria-label='Más']
    Wait Until Element Is Visible    xpath=${more_in_li}    ${BASE_TIMEOUT}
    Click Element                    xpath=${more_in_li}

Open More Menu (Any)
    [Arguments]    ${n}
    [Documentation]    Decide si abre por hover (playlist) o abriendo la página de pista y allí el menú.
    Run Keyword If    '${OPEN_METHOD}'=='hover'    Open More Menu From Playlist By Hover    ${n}
    ...    ELSE    Open Track Page By Index    ${n}
    Run Keyword If    '${OPEN_METHOD}'!='hover'    Open More Menu On Track Page

Get File Count In Dir
    ${files}=    List Files In Directory    ${DOWNLOAD_DIR}    absolute=True
    ${count}=    Get Length    ${files}
    [Return]     ${count}

File Count Should Increase
    [Arguments]    ${old_count}
    ${now}=    Get File Count In Dir
    Should Be True    ${now} > ${old_count}

Get Most Recent Completed Download
    [Documentation]    Devuelve el archivo más reciente que no sea .crdownload.
    ${paths}=    List Files In Directory    ${DOWNLOAD_DIR}    absolute=True
    Should Not Be Empty    ${paths}
    ${cands}=    Create List
    FOR    ${p}    IN    @{paths}
        ${is_tmp}=    Run Keyword And Return Status    Should End With    ${p}    .crdownload
        IF    not ${is_tmp}
            Append To List    ${cands}    ${p}
        END
    END
    Should Not Be Empty    ${cands}
    ${latest}=    Evaluate    sorted(${cands}, key=__import__("os").path.getmtime, reverse=True)[0]
    [Return]      ${latest}

Wait For New Download
    [Arguments]    ${old_count}
    [Documentation]    Espera a que aparezca un nuevo archivo y a que termine (desaparece .crdownload).
    Wait Until Keyword Succeeds    60x    2 s    File Count Should Increase    ${old_count}
    ${final_file}=    Wait Until Keyword Succeeds    60x    2 s    Get Most Recent Completed Download
    Log To Console    ✅ Descargado: ${final_file}

Download If Available
    [Documentation]    Abre el menú (según OPEN_METHOD), clica Download (si existe) y espera el archivo.
    ${before}=    Get File Count In Dir
    Open More Menu (Any)    ${TRACK_NUM}

    # Asegura que el menú está pintado
    Wait Until Keyword Succeeds    5x    1 s    Page Should Contain Element
    ...    //button[contains(@class,'sc-button-download')]
    ...    | //button[.//span[normalize-space(.)='Download']]
    ...    | //a[(contains(@class,'sc-link') or contains(@class,'download')) and (contains(.,'Download') or contains(@href,'/download'))]

    ${has_btn}=   Run Keyword And Return Status    Page Should Contain Element
    ...    //button[contains(@class,'sc-button-download')] | //button[.//span[normalize-space(.)='Download']]
    IF    ${has_btn}
        Click Element    //button[contains(@class,'sc-button-download')] | //button[.//span[normalize-space(.)='Download']]
    ELSE
        ${has_link}=   Run Keyword And Return Status    Page Should Contain Element
        ...    //a[(contains(@class,'sc-link') or contains(@class,'download')) and (contains(.,'Download') or contains(@href,'/download'))]
        IF    ${has_link}
            Click Element    xpath=//a[(contains(@class,'sc-link') or contains(@class,'download')) and (contains(.,'Download') or contains(@href,'/download'))]
        ELSE
            Log To Console    ❌ NO HAY DESCARGA
            [Return]    None
        END
    END
    Wait For New Download    ${before}

Check Download Availability
    [Documentation]    Conservado por compatibilidad: informa y, si existe, descarga.
    Open More Menu (Any)    ${TRACK_NUM}
    ${count}=    Get Element Count
    ...    //button[contains(@class,'sc-button-download') or .//span[contains(normalize-space(.),'Download')]]
    ...    | //a[(contains(@class,'sc-link') or contains(@class,'download')) and (contains(.,'Download') or contains(@href,'/download'))]
    IF    ${count} > 0
        Log To Console    ✅ DOWNLOAD DISPONIBLE
        # Cierra menú viejo y vuelve a abrir para evitar overlays
        Press Keys    NONE    ESC
        Sleep    0.3 s
        Download If Available
    ELSE
        Log To Console    ❌ NO HAY DESCARGA
    END

*** Test Cases ***
#Opcion A - Abrir página de pista y descargar si hay
#    [Documentation]    Usa OPEN_METHOD=click (recomendado).
#    Set Suite Variable    ${OPEN_METHOD}    click
#    Open Playlist
#    Download If Available
#    Capture Page Screenshot

Opcion B - Hover en playlist y descargar si hay
    [Documentation]    Usa OPEN_METHOD=hover (menú en la lista). El botón puede no ofrecer Download.
    Set Suite Variable    ${OPEN_METHOD}    hover
    Open Playlist
    Download If Available
    Capture Page Screenshot
