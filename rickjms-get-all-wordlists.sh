#!/bin/bash

# GLOBALS

## These are just helper variables
SCRIPT=$(echo $0 | awk -F "/" '{print $NF}')
CUR_DATE=$(date +"%Y%m%d")
UUIDSHORT=$(uuidgen | cut -d\- -f1)
CURRENT_DIR=$(pwd)
BASEDIR=$(dirname $0)
SILENT_MODE=""


## INSTALLATION LOCATION ~/wordlist/*
INSTALL_LOCATION="$HOME/wordlists"


# LIST OF ALL THE GITHUB WORDLISTS
declare -A WORDLIST
WORDLIST[fuzzdb]="https://github.com/fuzzdb-project/fuzzdb.git"
WORDLIST[dirsearch]="https://github.com/maurosoria/dirsearch.git"
WORDLIST[secLists]="https://github.com/danielmiessler/SecLists.git"
WORDLIST[payloadsAllTheThings]="https://github.com/swisskyrepo/PayloadsAllTheThings.git"
# WORDLIST[]=""

# Default output script logging to current directory / scriptname.log
LOGFILE="$CURRENT_DIR/$SCRIPT.log"

# LOGGING STUFF
function log() {
    echo "$CUR_DATE [$SCRIPT] $@" >> $LOGFILE
}

function info() {
  if test -z $SILENT_MODE; then
      echo "[$SCRIPT] [INFO] $@"
  fi
  # Save to log file
  log "[INFO] $@"
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

# h  => flag
# f: => flag + input: For example -f ~/rickjms/awesome/file.txt
# n  => flag
  while getopts "hf:ns" flag
    do
      case $flag in
        h)
          Usage
          exit 255
          ;;
        f)
          USER_FILE="$OPTARG" # Note you need to use $OPTARG for this to work.
          FILE_PASSED="true"  # I use this as a helper to easily check if file is passed in.
          ;;
        n)
          USER_FLAG="true"
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
  echo -e "\t-f FILENAME \t\tUser passes in a file!"
  echo -e "\t-n \t\t\tUser passes in just a flag"
  echo -e "\t-s \t\t\tSilent Mode do not post output"
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

##### Script Functions #####

function updateWordlist() {
  # Lets say the lists are already installed instead lets update them
  # git pull origin main / master
  WORDLIST_DIRECTORY_TO_UPDATE="$1"
  info "Changing to Directory:$WORDLIST_DIRECTORY_TO_UPDATE"
  cd $WORDLIST_DIRECTORY_TO_UPDATE
  info "pulling updates from github"
  git pull origin master
  info "Change back to top Directory: $CURRENT_DIR"
  cd $CURRENT_DIR
  info "Finished updating wordlist"
}

function fetchGitRepo() {
  # This one is simple we just need to pull the repo
  local REPO_LOCATION="$1"
  local DIR_NAME="$2"
  info "Running command:"
  info "git clone $REPO_LOCATION $INSTALL_LOCATION/$DIR_NAME"
  git clone $REPO_LOCATION $INSTALL_LOCATION/$DIR_NAME
}

function downloadWordlists() {
  for key in "${!WORDLIST[@]}"
  do
    echo "Key: $key"
    echo "Val: ${WORDLIST[$key]}"
    local WORDLIST_LOCATION="$INSTALL_LOCATION/$key"
    echo "$WORDLIST_LOCATION"
    if test -d "$WORDLIST_LOCATION"; then
      echo "Directory Exists run updater"
      updateWordlist "$WORDLIST_LOCATION"
    else
      info "Missing wordlist I will download and save: $WORDLIST_LOCATION"
      fetchGitRepo "${WORDLIST[$key]}" "$key"
    fi
  done
}
###This part you add your code here
# YOUR SCRIPT CODE GOES HERE
####


##### MAIN FUNCTION #####
userInput $@
init

downloadWordlists
# add your code here for what you want the script to do.
# Example code what I done: https://github.com/travism26/rickjms-recon-scripts/blob/master/rickjms-recon.sh