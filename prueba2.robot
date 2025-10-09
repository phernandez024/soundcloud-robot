*** Settings ***
Documentation     SoundCloud downloader – usa el perfil por defecto de Edge (último usado) para aprovechar la sesión iniciada.
Library           SeleniumLibrary
Library           OperatingSystem
Library           String
Library           Process
Resource          ./browser_keywords.resource      # <-- aquí está Open Edge With Default Windows Profile
Resource          ./hypeddit.resource         # <-- aquí está Run Hypeddit Flow
Suite Setup       Open Edge With Default Windows Profile
Suite Teardown    Close All Browsers

*** Variables ***
${BASE_TIMEOUT}           15 s
${PLAYLIST_URL}           https://soundcloud.com/doncucho/sets/schranz-3
${TRACK_NUM}              3
${DOWNLOAD_DIR}      ${OUTPUT DIR}${/}downloads
${META_DIR}          ${OUTPUT DIR}${/}meta
${COVERS_DIR}        ${OUTPUT DIR}${/}portadas
${DOWNLOAD_TIMEOUT}       2 min

*** Keywords ***
Open Edge With Default Windows Profile
    [Documentation]    Abre Edge con el perfil por defecto del usuario (último usado). Cierra Edge y elimina locks antes.
    Create Directory    ${DOWNLOAD_DIR}
    Create Directory    ${META_DIR}
    Create Directory    ${COVERS_DIR}

    ${LOCALAPPDATA}=         Get Environment Variable    LOCALAPPDATA
    ${USER_DATA}=            Set Variable    ${LOCALAPPDATA}${/}Microsoft${/}Edge${/}User Data
    Directory Should Exist   ${USER_DATA}    No se encuentra User Data de Edge: ${USER_DATA}
    ${LOCAL_STATE}=          Set Variable    ${USER_DATA}${/}Local State

    ${exists}=    Evaluate    __import__('os').path.exists(r"""${LOCAL_STATE}""")
    IF    ${exists}
        ${LAST_USED}=    Evaluate    __import__('json').load(open(r"""${LOCAL_STATE}""","r",encoding="utf-8")).get("profile",{}).get("last_used","Default")
    ELSE
        ${LAST_USED}=    Set Variable    Default
    END

    ${PROFILE_PATH}=         Set Variable    ${USER_DATA}${/}${LAST_USED}
    Directory Should Exist   ${PROFILE_PATH}    El perfil detectado no existe: ${PROFILE_PATH}
    Log To Console           🔎 Perfil Edge detectado: ${LAST_USED} → ${PROFILE_PATH}

    Run Keyword And Ignore Error    Run Process    taskkill    /F    /IM    msedge.exe    shell=True
    Sleep    0.5 s
    ${locks}=    List Files In Directory    ${PROFILE_PATH}    pattern=Singleton*
    FOR    ${f}    IN    @{locks}
        Run Keyword And Ignore Error    Remove File    ${f}
    END
    Run Keyword And Ignore Error    Remove File    ${PROFILE_PATH}${/}LOCK

    ${opt}=    Evaluate    __import__('selenium.webdriver.edge.options', fromlist=['Options']).Options()

    ${arg_user}=        Set Variable    --user-data-dir=${USER_DATA}
    ${arg_prof}=        Set Variable    --profile-directory=${LAST_USED}
    ${arg_max}=         Set Variable    --start-maximized
    ${arg_devshm}=      Set Variable    --disable-dev-shm-usage
    ${arg_no_first}=    Set Variable    --no-first-run
    ${arg_no_default}=  Set Variable    --no-default-browser-check

    Call Method    ${opt}    add_argument    ${arg_user}
    Call Method    ${opt}    add_argument    ${arg_prof}
    Call Method    ${opt}    add_argument    ${arg_max}
    Call Method    ${opt}    add_argument    ${arg_devshm}
    Call Method    ${opt}    add_argument    ${arg_no_first}
    Call Method    ${opt}    add_argument    ${arg_no_default}

    &{prefs}=    Create Dictionary
    ...    download.default_directory=${DOWNLOAD_DIR}
    ...    download.prompt_for_download=${False}
    ...    download.directory_upgrade=${True}
    ...    safebrowsing.enabled=${True}
    Call Method   ${opt}    add_experimental_option    prefs    ${prefs}

    Create WebDriver    Edge    options=${opt}
    Set Selenium Timeout    ${BASE_TIMEOUT}
    Log To Console    ✅ Edge con perfil real: ${PROFILE_PATH} — Descargas: ${DOWNLOAD_DIR}

Open Playlist
    Go To    ${PLAYLIST_URL}

Ensure Track Item Is Rendered
    [Arguments]    ${n}
    ${li}=    Set Variable    (//li[contains(@class,'trackList__item') or contains(@class,'soundList__item')])[${n}]
    FOR    ${i}    IN RANGE    0    40
        ${ok}=    Run Keyword And Return Status    Page Should Contain Element    xpath=${li}
        IF    ${ok}
            BREAK
        END
        Execute JavaScript    window.scrollBy(0, 800)
        Sleep    0.2 s
    END
    Wait Until Page Contains Element    xpath=${li}    ${BASE_TIMEOUT}
    Scroll Element Into View            xpath=${li}

Open Track Page By Index
    [Arguments]    ${n}
    [Documentation]    Abre la página de la pista (no comprobamos /tracks/ en la URL; SoundCloud usa /usuario/slug).
    Ensure Track Item Is Rendered    ${n}
    ${li}=      Set Variable    (//li[contains(@class,'trackList__item') or contains(@class,'soundList__item')])[${n}]
    ${link}=    Set Variable    ${li}//a[contains(@class,'trackItem__trackTitle') or contains(@class,'soundTitle__title') or contains(@href,'/tracks/') or contains(@href,'soundcloud.com/')]
    Wait Until Element Is Visible    xpath=${link}    ${BASE_TIMEOUT}
    Click Element                    xpath=${link}
    # En la vista de pista, el botón "Más/More" es estático → esperamos a ese botón como señal de carga
    Wait Until Page Contains Element    //div[contains(@class,'listenEngagement') or contains(@class,'fullListen')]//button[contains(@class,'sc-button-more')]    ${BASE_TIMEOUT}

Open More Menu On Track Page
    [Documentation]    En la página de pista, abrir el menú de los tres puntitos.
    ${more_xpath}=    Set Variable    //div[contains(@class,'listenEngagement') or contains(@class,'fullListen')]//button[contains(@class,'sc-button-more') and (@aria-label='Más' or @aria-label='More')]
    Wait Until Page Contains Element    xpath=${more_xpath}    ${BASE_TIMEOUT}
    Scroll Element Into View            xpath=${more_xpath}
    Wait Until Element Is Visible       xpath=${more_xpath}    ${BASE_TIMEOUT}
    Click Element                       xpath=${more_xpath}
    # Confirmar que se abrió el menú
    Wait Until Keyword Succeeds    10x    0.3 s    Page Should Contain Element
    ...    //div[contains(@class,'dropdown') or contains(@class,'moreActions') or @role='menu' or @role='listbox']

Open Track Page And Open More Menu
    [Arguments]    ${n}
    Open Track Page By Index    ${n}
    Open More Menu On Track Page

Get File Count In Dir
    ${files}=    List Files In Directory    ${DOWNLOAD_DIR}    absolute=True
    ${count}=    Get Length    ${files}
    RETURN    ${count}

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
    RETURN      ${latest}

Wait For New Download
    [Arguments]    ${old_count}
    [Documentation]    Espera a que aparezca un nuevo archivo y a que termine (desaparece .crdownload).
    Wait Until Keyword Succeeds    60x    2 s    File Count Should Increase    ${old_count}
    ${final_file}=    Wait Until Keyword Succeeds    60x    2 s    Get Most Recent Completed Download
    Log To Console    ✅ Descargado: ${final_file}

Download If Available
    [Documentation]    Intenta “Download”. Si no existe, abre enlace externo SOLO si es Hypeddit.
    ${before}=    Get File Count In Dir

    # XPath único con uniones (botón Download o enlace /download)
    ${download_any}=    Set Variable
    ...    //button[contains(@class,'sc-button-download')]
    ...    | //button[.//span[normalize-space(.)='Download']]
    ...    | //a[(contains(@class,'sc-link') or contains(@class,'download')) and (contains(normalize-space(.),'Download') or contains(@href,'/download'))]

    # No bloquee la ejecución si no está: check con timeout corto
    ${present}=    Run Keyword And Return Status    Wait Until Page Contains Element    xpath=${download_any}    5 s

    IF    ${present}
        Click Element    xpath=${download_any}
        # (Opcional) esperar archivo si esperas descarga directa
        # Wait For New Download    ${before}
        Log To Console    ✅ Click en “Download”
    ELSE
        # Fallback: intentar enlace externo sólo si es Hypeddit
        Press Keys    NONE    ESC
        Sleep    0.3 s
        ${opened}=    Click Purchase Link If Hypeddit
        RETURN    ${opened}
        IF    '${opened}'=='None'
            Log To Console    ❌ NO HAY DESCARGA ni enlace Hypeddit permitido
        END
    END


   # Wait For New Download    ${before}

_ensure_meta_csv_headers_exist
    ${t_csv}=    Set Variable    ${META_DIR}${/}titulos.csv
    ${a_csv}=    Set Variable    ${META_DIR}${/}artistas.csv
    ${t_exists}=    Run Keyword And Return Status    File Should Exist    ${t_csv}
    ${a_exists}=    Run Keyword And Return Status    File Should Exist    ${a_csv}
    IF    not ${t_exists}
        Create File    ${t_csv}    n,title\n    UTF-8
    END
    IF    not ${a_exists}
        Create File    ${a_csv}    n,artist\n    UTF-8
    END

_csv_escape
    [Arguments]    ${text}
    ${x}=    Replace String    ${text}    "    ""
    ${x}=    Replace String    ${x}    \n    ${EMPTY}
    ${x}=    Replace String    ${x}    \r    ${EMPTY}
    RETURN    ${x}

Extract And Save Track Metadata
    [Arguments]    ${n}
    [Documentation]    Desde la página de pista, extrae título, artista y portada, guarda CSVs y descarga la portada.
    Sleep    1
    Wait Until Page Contains Element    //h1[contains(@class,'soundTitle__title')]//span    ${BASE_TIMEOUT}
    ${title}=     Get Text    xpath=//h1[contains(@class,'soundTitle__title')]//span
    ${artist}=    Get Text    xpath=//h2[contains(@class,'soundTitle__username')]//a

    # 1) Portada: intenta style background-image, si no, og:image o <img>
    ${style_found}=    Run Keyword And Return Status    Page Should Contain Element
    ...    xpath=(//div[contains(@class,'listenEngagement') or contains(@class,'fullListen')]//span[contains(@class,'sc-artwork') and contains(@style,'background-image')])[1]
    IF    ${style_found}
        ${style}=    Get Element Attribute    xpath=(//div[contains(@class,'listenEngagement') or contains(@class,'fullListen')]//span[contains(@class,'sc-artwork') and contains(@style,'background-image')])[1]    style
        ${img_url}=  Evaluate    __import__('re').search(r'url\\([\"\\\']?(.*?)[\"\\\']?\\)', r"""${style}""").group(1)
    ELSE
        ${og_found}=    Run Keyword And Return Status    Page Should Contain Element    xpath=//meta[@property='og:image']
        IF    ${og_found}
            ${img_url}=    Get Element Attribute    xpath=//meta[@property='og:image']    content
        ELSE
            ${img_url}=    Get Element Attribute    xpath=(//img[contains(@class,'image__full')])[1]    src
        END
    END

    # 2) Guardar a CSVs (n,title) y (n,artist) con cabeceras
    _ensure_meta_csv_headers_exist
    ${t_csv}=    Set Variable    ${META_DIR}${/}titulos.csv
    ${a_csv}=    Set Variable    ${META_DIR}${/}artistas.csv
    ${title_q}=  _csv_escape    ${title}
    ${artist_q}=    _csv_escape    ${artist}
    Append To File    ${t_csv}    ${n},"${title_q}"\n    UTF-8
    Append To File    ${a_csv}    ${n},"${artist_q}"\n    UTF-8

    # 3) Descargar portada a portadas/n.ext (ext de la URL o .png)
    ${ext}=   Evaluate    (lambda u: (__import__('os').path.splitext(__import__('urllib.parse', fromlist=['urlparse']).urlparse(u).path)[1] or '.png'))(r"""${img_url}""")
    ${cover}=   Set Variable    ${COVERS_DIR}${/}${n}${ext}
    Evaluate    __import__('urllib.request', fromlist=['urlretrieve']).urlretrieve(r"""${img_url}""", r"""${cover}""")
    Log To Console    💾 Guardado meta en CSVs y portada: ${cover}
Resolve Link To Final Url And Domain
    [Arguments]    ${href}
    ${final_url}=    Evaluate    (lambda h:(lambda up:( up.unquote(up.parse_qs(up.urlparse(h).query).get('url',[''])[0]) if 'gate.sc' in up.urlparse(h).netloc else h ))(__import__('urllib.parse', fromlist=['urlparse','parse_qs','unquote'])))(r"""${href}""")
    ${domain}=       Evaluate    __import__('urllib.parse', fromlist=['urlparse']).urlparse(r"""${final_url}""").netloc.lower()
    RETURN    ${final_url}    ${domain}

Window Count Should Be Greater
    [Arguments]    ${prev}
    ${handles}=    Get Window Handles
    ${n}=          Get Length    ${handles}
    Should Be True    ${n} > ${prev}

Click Purchase Link If Hypeddit
    [Documentation]    Busca el botón externo en la página de pista y lo abre SÓLO si el destino es hypeddit.com.
    ${purchase}=    Set Variable    //a[contains(@class,'soundActions__purchaseLink')]
    ${exists}=      Run Keyword And Return Status    Page Should Contain Element    xpath=${purchase}
    IF    not ${exists}
        Log To Console    🔎 No hay botón de descarga externa en esta pista
        RETURN    None
    END
    ${href}=        Get Element Attribute    xpath=${purchase}    href
    ${final_url}    ${domain}=    Resolve Link To Final Url And Domain    ${href}
    Log To Console  🔗 Enlace externo detectado → ${domain}
    IF    'hypeddit.com' in '${domain}'
        ${before}=  Get Window Handles
        ${prev}=    Get Length    ${before}
        Click Element    xpath=${purchase}
        Wait Until Keyword Succeeds    20x    0.5 s    Window Count Should Be Greater    ${prev}
        Switch Window    NEW
        Log To Console    ✅ Abierto Hypeddit en nueva pestaña: ${final_url}

        RETURN    ${final_url}
    ELSE
        Log To Console    ⚠️ Enlace externo NO permitido: ${domain} (no se abre)
        RETURN    None
    END

*** Test Cases ***
Opcion A - Abrir página de pista y descargar si hay
    Open Playlist
    Open Track Page And Open More Menu    ${TRACK_NUM}
    Extract And Save Track Metadata    ${TRACK_NUM}
    ${hyp_url}=    Download If Available
    Run Keyword If    '${hyp_url}'!='None'    Run Hypeddit Flow    ${hyp_url}    fire
    #Switch Window By Url    ${PLAYLIST_URL}
    Sleep    20

