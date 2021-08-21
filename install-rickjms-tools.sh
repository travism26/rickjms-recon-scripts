#!/bin/bash


CURRENT_PATH=$(pwd)

function log_title(){
	local msg="$1"
	echo -e "\e[0;34m [+] $msg \e[0m"
}

function log_message(){
	local msg="$1"
	echo -e "\e[0;35m  - $msg \e[0m"
}

function install_packages(){
	# Required for silencing the apt-get output
	DEBIAN_FRONTEND=noninteractive
	log_title "Installing required apt depedencies"
	log_message "openssl-dev"
	sudo apt-get install -qq libcurl4-openssl-dev < /dev/null > /dev/null
	sudo apt-get install -qq libssl-dev < /dev/null > /dev/null
	log_message "jq"
	sudo apt-get install -qq jq < /dev/null > /dev/null
	log_message "ruby"
	sudo apt-get install -qq ruby-full < /dev/null > /dev/null
	log_message "libs"
	sudo apt-get install -qq libcurl4-openssl-dev libxml2 libxml2-dev libxslt1-dev ruby-dev build-essential libgmp-dev zlib1g-dev < /dev/null > /dev/null
	log_message "build"
	sudo apt-get install -qq build-essential libssl-dev libffi-dev python-dev < /dev/null > /dev/null
	log_message "libdns"
	sudo apt-get install -qq libldns-dev < /dev/null > /dev/null
	log_message "python3 pip"
	sudo apt-get install -qq python3-pip < /dev/null > /dev/null
	log_message "python3 venv"
	sudo apt-get install -qq python3-venv < /dev/null > /dev/null
	log_message "git"
	sudo apt-get install -qq git < /dev/null > /dev/null
	log_message "rename"
	sudo apt-get install -qq rename < /dev/null > /dev/null
	# Removing as not in ubuntu repos, is installed by default
	#info "xargs"
	#sudo apt-get install -qq xargs < /dev/null > /dev/null
}

BASHRC_FILE=~/.bashrc
GO_VERSION="go1.16.5.linux-amd64.tar.gz"
GO_LINK="https://golang.org/dl/$GO_VERSION"

function install_go(){
	log_title "Installing go"
	wget -q $GO_LINK
	log_message "Uninstalling previous golang installation (if installed) and reinstalling."
	sudo rm -rf /usr/local/go && tar -C /usr/local -xzf $GO_VERSION
	sudo rm -f $GO_VERSION
	# Check if go path has been added
	if grep -Fxq "export PATH=$PATH:/usr/local/go/bin" $BASHRC_FILE
	then
		# export found
		log_message "Go path alredy in bashrc"
	else
		# export not found
		echo 'export PATH=$PATH:/usr/local/go/bin' >> $BASHRC_FILE
		# Set the export for future functions in this script
		export PATH=$PATH:/usr/local/go/bin
	fi
	
	if grep -Fxq "export GOPATH=$HOME/go" $BASHRC_FILE
	then
		# export found
		log_message "Go home alredy in bashrc"
	else
		# export not found
		echo 'export GOPATH=$HOME/go' >> $BASHRC_FILE 
		# Set the export for future functions in this script
		export GOPATH=$HOME/go
	fi
	
	if grep -Fxq "export PATH=$PATH:$GOPATH/bin" $BASHRC_FILE
	then
		# export found
		log_message "Go bin path alredy in bashrc"
	else
		# export not found
		echo 'export PATH=$PATH:$GOPATH/bin' >> $BASHRC_FILE 
		# Set the export for future functions in this script
		export PATH=$PATH:$GOPATH/bin
	fi

}

function install_go_tools(){
	log_title "Installing go tools"
	log_message "assetfinder"
	go get -u  github.com/tomnomnom/assetfinder
	log_message "httprobe"
	go get -u github.com/tomnomnom/httprobe
	log_message "subfinder"
	GO111MODULE=on go get -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder
	log_message "hakrawler"
	go get github.com/hakluke/hakrawler
	log_message "waybackurls"
	go get github.com/tomnomnom/waybackurls
	log_message "subjack"
	go get github.com/haccer/subjack
	log_message "fff"
	go get -u github.com/tomnomnom/fff
	log_message "anew"
	go get -u github.com/tomnomnom/anew
	log_message "gobuster"
	go install github.com/OJ/gobuster/v3@latest
	log_message "go dirsearch"
	go get github.com/evilsocket/dirsearch
}


# This is not 100% might need to get reworked!
function install_git_tools() {
	log_title "Cloning github repos"
	GITHUB_DIR="$CURRENT_PATH/github_repos"
	if [ -d "$GITHUB_DIR" ]; then
		log_message "Not creating github repo dir already exists"
	else
		log_message "Creating $GITHUB_DIR"
		mkdir $GITHUB_DIR
	fi
	
	log_message "sublister"
	if [ -d $GITHUB_DIR/sublister ]; then
		git pull $GITHUB_DIR/sublister --allow-unrelated-histories
	else
		git clone https://github.com/aboul3la/Sublist3r.git $GITHUB_DIR/sublister
	fi
	pip3 install -qr $GITHUB_DIR/sublister/requirements.txt
	# Install sublister
	if [[ ! -L /bin/sublist3r ]]; then
		sudo ln -s $GITHUB_DIR/sublister/sublist3r.py /bin/sublist3r
	fi

	log_message "tomnomnom hacks"
	if [ -d $GITHUB_DIR/hacks ]; then
		git pull $GITHUB_DIR/hacks --allow-unrelated-histories
	else
		git clone https://github.com/tomnomnom/hacks.git $GITHUB_DIR/hacks
	fi

	# Install inscope
	log_title "Installing inscope"
	cd $GITHUB_DIR/hacks/inscope
	go mod init inscope
	go mod tidy
	go build

	cd $CURRENT_PATH
	if [[ ! -L /bin/inscope ]]; then
		sudo ln -s $GITHUB_DIR/hacks/inscope/inscope /bin/inscope
	fi
}

function setup_python_venv() {
	python3 -m venv $CURRENT_PATH
	source $CURRENT_PATH/bin/activate
}

# You need to pass absolute path and no reletive path!
function create_symlink() {
	SCRIPT="$1"
	SYMLINK_LOCATION="/bin/$SCRIPT"
	ln -s $SCRIPT $SYMLINK_LOCATION
}

##### MAIN METHOD #####
# install_go
install_packages
install_go
install_go_tools
setup_python_venv
install_git_tools
