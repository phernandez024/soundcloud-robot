*** Settings ***
Documentation     Verifica enlaces externos de SoundCloud y descarga si son Hypeddit
Library           SeleniumLibrary
Library           OperatingSystem
Library           String
Library           Collections
Resource          ./browser_keywords.resource
Resource          ./hypeddit.resource
Suite Setup       Setup Suite
Suite Teardown    Teardown Suite

*** Variables ***
${BASE_TIMEOUT}       15 s
${URLS_FILE}          temp/urls_for_robot.json
${OUTPUT_FILE}        temp/external_links.json
${DOWNLOAD_DIR}       downloads
${DELAY}              5    # Segundos de pausa entre tracks

*** Keywords ***
Setup Suite
    Open Edge With Default Windows Profile
    ${urls_json}=    Get File    ${URLS_FILE}    encoding=UTF-8
    ${urls_data}=    Evaluate    __import__('json').loads('''${urls_json}''')
    Set Suite Variable    ${URLS_DATA}    ${urls_data}
    ${results}=    Create List
    Set Suite Variable    ${RESULTS}    ${results}

Teardown Suite
    # Guardar resultados en JSON
    ${json_output}=    Evaluate    __import__('json').dumps(${RESULTS}, indent=2, ensure_ascii=False)
    Create File    ${OUTPUT_FILE}    ${json_output}    encoding=UTF-8
    Log To Console    \n✓ Resultados guardados en: ${OUTPUT_FILE}
    Close All Browsers

Open More Menu On Track Page
    [Documentation]    En la página de pista, abrir el menú de los tres puntitos
    ${more_xpath}=    Set Variable    //div[contains(@class,'listenEngagement') or contains(@class,'fullListen')]//button[contains(@class,'sc-button-more') and (@aria-label='Más' or @aria-label='More')]
    Wait Until Page Contains Element    xpath=${more_xpath}    ${BASE_TIMEOUT}
    Scroll Element Into View            xpath=${more_xpath}
    Wait Until Element Is Visible       xpath=${more_xpath}    ${BASE_TIMEOUT}
    Click Element                       xpath=${more_xpath}
    # Confirmar que se abrió el menú
    Wait Until Keyword Succeeds    10x    0.3 s    Page Should Contain Element
    ...    //div[contains(@class,'dropdown') or contains(@class,'moreActions') or @role='menu' or @role='listbox']

Download If Available
    [Documentation]    Intenta "Download". Si no existe, abre enlace externo SOLO si es Hypeddit
    
    # XPath único con uniones (botón Download o enlace /download)
    ${download_any}=    Set Variable
    ...    //button[contains(@class,'sc-button-download')]
    ...    | //button[.//span[normalize-space(.)='Download']]
    ...    | //a[(contains(@class,'sc-link') or contains(@class,'download')) and (contains(normalize-space(.),'Download') or contains(@href,'/download'))]

    # Verificar si existe botón de descarga
    ${present}=    Run Keyword And Return Status    Wait Until Page Contains Element    xpath=${download_any}    5 s

    IF    ${present}
        Log To Console    \n  ✓ Tiene botón Download interno (archivo original ya descargado por yt-dlp)
        Press Keys    NONE    ESC
        Sleep    0.3 s
        RETURN    internal_download
    ELSE
        # Fallback: intentar enlace externo sólo si es Hypeddit
        Press Keys    NONE    ESC
        Sleep    0.3 s
        ${opened}=    Click Purchase Link If Hypeddit
        RETURN    ${opened}
    END

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
    [Documentation]    Busca el botón externo en la página de pista y lo abre SÓLO si el destino es hypeddit.com
    ${purchase}=    Set Variable    //a[contains(@class,'soundActions__purchaseLink')]
    ${exists}=      Run Keyword And Return Status    Page Should Contain Element    xpath=${purchase}
    IF    not ${exists}
        Log To Console    \n  ℹ️  No hay botón de descarga externa
        RETURN    None
    END
    ${href}=        Get Element Attribute    xpath=${purchase}    href
    ${final_url}    ${domain}=    Resolve Link To Final Url And Domain    ${href}
    Log To Console    \n  🔗 Enlace externo detectado → ${domain}
    IF    'hypeddit.com' in '${domain}'
        ${before}=  Get Window Handles
        ${prev}=    Get Length    ${before}
        Click Element    xpath=${purchase}
        Wait Until Keyword Succeeds    20x    0.5 s    Window Count Should Be Greater    ${prev}
        Switch Window    NEW
        Log To Console    \n  ✅ Abierto Hypeddit en nueva pestaña: ${final_url}
        RETURN    ${final_url}
    ELSE
        Log To Console    \n  ⚠️  Enlace externo NO permitido: ${domain} (no se abre)
        RETURN    None
    END

Check Track For External Link
    [Arguments]    ${track_num}    ${url}    ${title}
    [Documentation]    Verifica si un track tiene enlace externo y lo procesa
    
    Log To Console    \n======================================================================
    Log To Console    [${track_num}] Verificando: ${title}
    Log To Console    ======================================================================
    
    # Ir directamente a la página del track
    Go To    ${url}
    
    # Esperar a que cargue la página de la pista (botón "Más/More")
    Wait Until Page Contains Element    //div[contains(@class,'listenEngagement') or contains(@class,'fullListen')]//button[contains(@class,'sc-button-more')]    ${BASE_TIMEOUT}
    Sleep    1
    
    # Abrir menú de opciones
    Open More Menu On Track Page
    Sleep    0.5
    
    # Verificar opciones de descarga
    ${download_result}=    Download If Available
    
    ${result}=    Create Dictionary    
    ...    num=${track_num}    
    ...    url=${url}    
    ...    title=${title}    
    ...    external_url=None
    ...    downloaded=${False}
    
    IF    '${download_result}' == 'internal_download'
        # Ya fue descargado por yt-dlp en la Fase 2
        Log To Console    \n  ℹ️  Archivo original ya descargado previamente
        Set To Dictionary    ${result}    downloaded=${True}    external_url=internal
        
    ELSE IF    '${download_result}' != 'None'
        # Es Hypeddit, procesarlo
        Set To Dictionary    ${result}    external_url=${download_result}
        
        TRY
            Run Hypeddit Flow    ${download_result}    fire
            Set To Dictionary    ${result}    downloaded=${True}
            Log To Console    \n  ✅ Descargado vía Hypeddit
        EXCEPT
            Log To Console    \n  ✗ Error al descargar de Hypeddit
            Set To Dictionary    ${result}    downloaded=${False}
        END
        
        # Cerrar pestaña de Hypeddit y volver a la principal
        Close Window
        Switch Window    MAIN
        
    ELSE
        # No tiene descarga externa
        Log To Console    \n  ℹ️  Sin enlace externo - se descargará con yt-dlp
        Set To Dictionary    ${result}    downloaded=${False}
    END
    
    Append To List    ${RESULTS}    ${result}

*** Test Cases ***
Process All Tracks From JSON
    [Documentation]    Procesa todos los tracks del archivo JSON
    
    ${track_count}=    Get Length    ${URLS_DATA}
    Log To Console    \n======================================================================
    Log To Console    🤖 Robot Framework: Procesando ${track_count} tracks
    Log To Console    ⚠️  Pausa de ${DELAY}s entre tracks para evitar rate limiting
    Log To Console    ======================================================================
    
    FOR    ${track}    IN    @{URLS_DATA}
        ${num}=      Get From Dictionary    ${track}    num
        ${url}=      Get From Dictionary    ${track}    url
        ${title}=    Get From Dictionary    ${track}    title
        
        Check Track For External Link    ${num}    ${url}    ${title}
        
        # Pausa configurable entre tracks
        Sleep    ${DELAY}s
    END
    
    Log To Console    \n======================================================================
    Log To Console    ✅ Robot Framework: Procesamiento completado
    Log To Console    ======================================================================