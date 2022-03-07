#!/bin/bash

# GLOBALS

## These are just helper variables
SCRIPT=$(echo $0 | awk -F "/" '{print $NF}')
CUR_DATE=$(date +"%Y%m%d")
UUIDSHORT=$(uuidgen | cut -d\- -f1)
CURRENT_DIR=$(pwd)
BASEDIR=$(dirname $0)
SILENT_MODE="false"

# Default output script logging to current directory / scriptname.log
LOGFILE="$CURRENT_DIR/$SCRIPT.log"

########################################################################
######################## LIST OF ALL GIT TOOLS #########################
########################################################################
######################## RECON AND CONTENT DISCOVERY ###################
### Javascript Enumeration ###
declare -A JS_ENUM
JS_ENUM[JSParser]="https://github.com/nahamsec/JSParser.git"
JS_ENUM[LinkFinder]="https://github.com/GerbenJavado/LinkFinder.git"
JS_ENUM[getJS]="https://github.com/003random/getJS.git"
JS_ENUM[InputScanner]="https://github.com/zseano/InputScanner.git"
# THIS TOOLS INSTALLS A BUNCH OF OTHER TOOLS #
JS_ENUM[JSFScan]="https://github.com/KathanP19/JSFScan.sh.git"

### Recursive DNS Enum ###
declare -A DNS_ENUM
DNS_ENUM[Syborg]="https://github.com/MilindPurswani/Syborg.git"
DNS_ENUM[dnsgen]="https://github.com/ProjectAnte/dnsgen.git"
DNS_ENUM[masscan]="https://github.com/robertdavidgraham/masscan.git" # USED In addition to dnsgen
DNS_ENUM[dnsrecon]="https://github.com/darkoperator/dnsrecon.git"

### Github Recon ###
declare -A GIT_ENUM
GIT_ENUM[gitrob]="https://github.com/michenriksen/gitrob.git"
GIT_ENUM[githound]="https://github.com/tillson/git-hound.git"
GIT_ENUM[truffleHog]="https://github.com/trufflesecurity/truffleHog.git"
GIT_ENUM[gitAllSecrets]="https://github.com/anshumanbh/git-all-secrets.git"
GIT_ENUM[gitGraber]="https://github.com/hisxo/gitGraber.git"

### Visual Recon (Screenshot tools) ###
declare -A VISUAL_RECON
VISUAL_RECON[aquatone]="https://github.com/michenriksen/aquatone.git"
VISUAL_RECON[webscreenshot]="https://github.com/maaaaz/webscreenshot.git"
VISUAL_RECON[EyeWitness]="https://github.com/FortyNorthSecurity/EyeWitness.git"


### Web App Wirewall indentification ###
declare -A WAF_CHK
WAF_CHK[wafw00f]="https://github.com/EnableSecurity/wafw00f.git"


### Virtual Hosts ### 
declare -A VIRTUAL_ENUM
VIRTUAL_ENUM[VHostScan]="https://github.com/codingo/VHostScan.git"
VIRTUAL_ENUM[virtualHostDiscovery]="https://github.com/jobertabma/virtual-host-discovery.git"


### Port Scanner ###
declare -A PORT_SCANNERS
PORT_SCANNERS[massscan]="https://github.com/robertdavidgraham/masscan.git"
PORT_SCANNERS[nmap]="https://github.com/nmap/nmap.git"
PORT_SCANNERS[naabu]="https://github.com/projectdiscovery/naabu.git"

### Fuzzing ###
declare -A FUZZERS
FUZZERS[wfuzz]="https://github.com/xmendez/wfuzz.git"
FUZZERS[ffuf]="https://github.com/ffuf/ffuf.git"
FUZZERS[gobuster]="https://github.com/OJ/gobuster.git"

### Sub-domain Enumeration ###
declare -A SUBDOMAIN_ENUM
SUBDOMAIN_ENUM[rickjms_recon]="https://github.com/travism26/rickjms-recon-scripts.git"
SUBDOMAIN_ENUM[amass]="https://github.com/OWASP/Amass.git"
SUBDOMAIN_ENUM[subfinder]="https://github.com/projectdiscovery/subfinder.git"
SUBDOMAIN_ENUM[knock]="https://github.com/guelfoweb/knock.git"
SUBDOMAIN_ENUM[sublister]="https://github.com/aboul3la/Sublist3r.git"

### INSTALLATION OF GO TOOLS ###
declare -A INSTALL_GO_TOOLS
INSTALL_GO_TOOLS[gobuster]="go install github.com/OJ/gobuster/v3@latest"
INSTALL_GO_TOOLS[ffuf]="go install github.com/ffuf/ffuf@latest"
INSTALL_GO_TOOLS[gau]="go install github.com/lc/gau/v2/cmd/gau@latest"
INSTALL_GO_TOOLS[amass]="go install -v github.com/OWASP/Amass/v3/...@master"

######################## ATTACKING THE TARGET ########################

### Web attacks ###
declare -A WEB_ATTACKS
WEB_ATTACKS[SSRFmap]="https://github.com/swisskyrepo/SSRFmap.git"
WEB_ATTACKS[CORScanner]="https://github.com/chenjj/CORScanner.git"
WEB_ATTACKS[Corsy]="https://github.com/s0md3v/Corsy.git"
WEB_ATTACKS[Blazy]="https://github.com/s0md3v/Blazy.git"
WEB_ATTACKS[Bolt]="https://github.com/s0md3v/Bolt.git"
WEB_ATTACKS[xsscrapy]="https://github.com/DanMcInerney/xsscrapy.git"
WEB_ATTACKS[XSStrike]="https://github.com/s0md3v/XSStrike.git"
WEB_ATTACKS[commix]="https://github.com/commixproject/commix.git"


######################## LOGGING DATA ########################
function log() {
    echo "$CUR_DATE [$SCRIPT] $@" >> $LOGFILE
}

function info() {
  if enableLogging; then
      echo "[$SCRIPT] [INFO] $@"
  fi
  # Save to log file
  # log "[INFO] $@"
}

function error() {
  if test -z $SILENT_MODE; then
      echo "[$SCRIPT] [ERROR] $@"
  fi
  # Save to log file
  log "[ERROR] $@"
}

# Reading user input / flags
function userInput() {
  # People like to use --help I just add this as a catch all type of thing
  if [[ $@ =~ --help ]]; then
    Usage
    exit 255
  fi

  while getopts "hf:ns" flag
    do
      case $flag in
        h)
          Usage
          exit 255
          ;;
        s)
          SILENT_MODE="true" # Turns off logging to the terminal
          ;;
        \?)
          Usage
          exit 255
          ;;
      esac
    done
}

# This is self explanatory display help menu
function Usage() {
  echo "Usage:"
  echo -e "\t-h \t\t\t\tDisplay help menu"
  echo -e "\t-s \t\t\tEnable logging to screen (STDout)"
}

function init() {
    # Generally this is a startup function when we start our program if we need
    # To initialize anything this is where we do it.
    info "Initialize Something Here"
}

# User Flag Helper functions
## This part i try to add helper function to easily check if flags are passed.

# This returns a boolean super helpful if you want to wrap this in an if statement
## Example: if filePassed; then ...
function filePassed() {
  [ "$FILE_PASSED" = "true" ]
}

function enableLogging() {
  [ "$SILENT_MODE" = "true" ]
}
##### Script Functions #####


## Fetch the git repo ##
# 1) GIT Repo URL (Ex: https://github.com/travism26/rickjms-recon-scripts.git)
# 2) Download Location of git repo (Ex: ~/tools/github-repos/amass)
function fetchGitRepo() {
  # This one is simple we just need to pull the repo
  local GIT_REPOSITORY="$1"
  local SAVE_LOCATION="$2"
  info "git clone $GIT_REPOSITORY $SAVE_LOCATION"
  git clone $GIT_REPOSITORY $SAVE_LOCATION
}

function updateGitRepo() {
  # Lets say the lists are already installed instead lets update them
  # git pull origin main / master
  local REPO_LOCATION="$1"
  info "Change to repo location:$REPO_LOCATION"
  cd $REPO_LOCATION
  
  info "pulling updates from github check for master if fail pull from main"
  git pull origin master || git pull origin main
  info "Change back to top Directory: $CURRENT_DIR"
  cd $CURRENT_DIR
  info "Finished updating git repositories..."
}

# Abstracted function to wrap all common calls
function checkAndDownloadRepo() {
  local INSTALL_LOCATION="$1"
  local REPO="$2"
  if test -d "$INSTALL_LOCATION"; then
    updateGitRepo "$INSTALL_LOCATION"
  else
    fetchGitRepo "$REPO" "$INSTALL_LOCATION"
  fi
}

## DOWNLOAD REPOS ## 

function get_js(){
  local INSTALL_LOCATION_INPUT="$1"
  for key in "${!JS_ENUM[@]}"
  do
    local INSTALL_LOCATION="$INSTALL_LOCATION_INPUT/$key"
    local REPO="${JS_ENUM[$key]}"
    checkAndDownloadRepo "$INSTALL_LOCATION" "$REPO"
  done
}

function get_dns(){
  local INSTALL_LOCATION_INPUT="$1"
  for key in "${!DNS_ENUM[@]}"
  do
    local INSTALL_LOCATION="$INSTALL_LOCATION_INPUT/$key"
    local REPO="${DNS_ENUM[$key]}"
    checkAndDownloadRepo "$INSTALL_LOCATION" "$REPO"
  done
}


function get_git(){
  local INSTALL_LOCATION_INPUT="$1"
  for key in "${!GIT_ENUM[@]}"
  do
    local INSTALL_LOCATION="$INSTALL_LOCATION_INPUT/$key"
    local REPO="${GIT_ENUM[$key]}"
    checkAndDownloadRepo "$INSTALL_LOCATION" "$REPO"
  done
}

function get_visual(){
  local INSTALL_LOCATION_INPUT="$1"
  for key in "${!VISUAL_RECON[@]}"
  do
    local INSTALL_LOCATION="$INSTALL_LOCATION_INPUT/$key"
    local REPO="${VISUAL_RECON[$key]}"
    checkAndDownloadRepo "$INSTALL_LOCATION" "$REPO"
  done
}

function get_waf(){
  local INSTALL_LOCATION_INPUT="$1"
  for key in "${!WAF_CHK[@]}"
  do
    local INSTALL_LOCATION="$INSTALL_LOCATION_INPUT/$key"
    local REPO="${WAF_CHK[$key]}"
    checkAndDownloadRepo "$INSTALL_LOCATION" "$REPO"
  done
}

function get_virtial(){
  local INSTALL_LOCATION_INPUT="$1"
  for key in "${!VIRTUAL_ENUM[@]}"
  do
    local INSTALL_LOCATION="$INSTALL_LOCATION_INPUT/$key"
    local REPO="${VIRTUAL_ENUM[$key]}"
    checkAndDownloadRepo "$INSTALL_LOCATION" "$REPO"
  done
}

function get_port_scanners(){
  local INSTALL_LOCATION_INPUT="$1"
  for key in "${!PORT_SCANNERS[@]}"
  do
    local INSTALL_LOCATION="$INSTALL_LOCATION_INPUT/$key"
    local REPO="${PORT_SCANNERS[$key]}"
    checkAndDownloadRepo "$INSTALL_LOCATION" "$REPO"
  done
}

function get_fuzzer(){
  local INSTALL_LOCATION_INPUT="$1"
  for key in "${!FUZZERS[@]}"
  do
    local INSTALL_LOCATION="$INSTALL_LOCATION_INPUT/$key"
    local REPO="${FUZZERS[$key]}"
    checkAndDownloadRepo "$INSTALL_LOCATION" "$REPO"
  done
}

function get_subdomain(){
  local INSTALL_LOCATION_INPUT="$1"
  for key in "${!SUBDOMAIN_ENUM[@]}"
  do
    local INSTALL_LOCATION="$INSTALL_LOCATION_INPUT/$key"
    local REPO="${SUBDOMAIN_ENUM[$key]}"
    checkAndDownloadRepo "$INSTALL_LOCATION" "$REPO"
  done
}

function get_web_attacks(){
  local INSTALL_LOCATION_INPUT="$1"
  for key in "${!WEB_ATTACKS[@]}"
  do
    local INSTALL_LOCATION="$INSTALL_LOCATION_INPUT/$key"
    local REPO="${WEB_ATTACKS[$key]}"
    checkAndDownloadRepo "$INSTALL_LOCATION" "$REPO"
  done
}

function downloadrepos() {
  local userLocation="$1"
  ## All the functions that collect the git repos
  local INSTALL_LOCATION="$HOME/rickjms/github-tools"
  if !test -d $INSTALL_LOCATION; then
    mkdir -p $INSTALL_LOCATION
  fi
  get_js "$INSTALL_LOCATION"
  get_dns "$INSTALL_LOCATION"
  get_git "$INSTALL_LOCATION"
  get_visual "$INSTALL_LOCATION"
  get_waf "$INSTALL_LOCATION"
  get_virtial "$INSTALL_LOCATION"
  get_port_scanners "$INSTALL_LOCATION"
  get_fuzzer "$INSTALL_LOCATION"
  get_subdomain "$INSTALL_LOCATION"
  get_web_attacks "$INSTALL_LOCATION"
  echo "Complete Saved all tools:$HOME/rickjms/github-tools/"
}

##### MAIN FUNCTION #####
userInput $@
init
downloadrepos
# add your code here for what you want the script to do.
# Example code what I done: https://github.com/travism26/rickjms-recon-scripts/blob/master/rickjms-recon.sh