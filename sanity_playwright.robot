*** Settings ***
Library    SeleniumLibrary

*** Variables ***
${CHROME_USER_DATA_DIR}    C:/Users/USER/AppData/Local/Google/Chrome/User Data
${CHROME_PROFILE_DIR}      Default

*** Test Cases ***
Sanity abre mi Chrome real
    ${opt}=    Evaluate    __import__('selenium.webdriver.chrome.options', fromlist=['Options']).Options()
    ${a}=    Set Variable    --user-data-dir=${CHROME_USER_DATA_DIR}
    ${b}=    Set Variable    --profile-directory=${CHROME_PROFILE_DIR}
    Call Method    ${opt}    add_argument    ${a}
    Call Method    ${opt}    add_argument    ${b}
    Create WebDriver    Chrome    options=${opt}
    Go To    chrome://version
    Sleep    2 s
    Close Browser
