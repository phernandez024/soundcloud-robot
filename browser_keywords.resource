*** Keywords ***
Open Edge With Default Windows Profile
    [Documentation]    Abre Edge con el perfil por defecto (último usado). Cierra Edge y elimina locks antes.
    ${DOWNLOAD_DIR}=    Set Variable    ${OUTPUT DIR}${/}downloads
    Create Directory    ${DOWNLOAD_DIR}

    ${LOCALAPPDATA}=         Get Environment Variable    LOCALAPPDATA
    ${USER_DATA}=            Set Variable    ${LOCALAPPDATA}${/}Microsoft${/}Edge${/}User Data
    Directory Should Exist   ${USER_DATA}
    ${LOCAL_STATE}=          Set Variable    ${USER_DATA}${/}Local State

    ${exists}=    Evaluate    __import__('os').path.exists(r"""${LOCAL_STATE}""")
    IF    ${exists}
        ${LAST_USED}=    Evaluate    __import__('json').load(open(r"""${LOCAL_STATE}""","r",encoding="utf-8")).get("profile",{}).get("last_used","Default")
    ELSE
        ${LAST_USED}=    Set Variable    Default
    END

    ${PROFILE_PATH}=         Set Variable    ${USER_DATA}${/}${LAST_USED}
    Directory Should Exist   ${PROFILE_PATH}
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
    Set Selenium Timeout    15 s
    Log To Console    ✅ Edge con perfil real: ${PROFILE_PATH} — Descargas: ${DOWNLOAD_DIR}
