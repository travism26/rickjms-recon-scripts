#!/bin/bash


CURRENT_PATH=$(pwd)

function log_h1(){
	local msg="$1"
	echo -e "[+] $msg"
}

function log_h2(){
	local msg="$1"
	echo -e "[-] $msg"
}

function install_packages(){
	# Required for silencing the apt-get output
	DEBIAN_FRONTEND=noninteractive
	log_h1 "Installing required apt depedencies"
	log_h2 "openssl-dev"
	sudo apt-get install -qq libcurl4-openssl-dev < /dev/null > /dev/null
	sudo apt-get install -qq libssl-dev < /dev/null > /dev/null
	log_h2 "jq"
	sudo apt-get install -qq jq < /dev/null > /dev/null
	log_h2 "ruby"
	sudo apt-get install -qq ruby-full < /dev/null > /dev/null
	log_h2 "libs"
	sudo apt-get install -qq libcurl4-openssl-dev libxml2 libxml2-dev libxslt1-dev ruby-dev build-essential libgmp-dev zlib1g-dev < /dev/null > /dev/null
	log_h2 "build"
	sudo apt-get install -qq build-essential libssl-dev libffi-dev python-dev < /dev/null > /dev/null
	log_h2 "libdns"
	sudo apt-get install -qq libldns-dev < /dev/null > /dev/null
	log_h2 "python3 pip"
	sudo apt-get install -qq python3-pip < /dev/null > /dev/null
	log_h2 "python3 venv"
	sudo apt-get install -qq python3-venv < /dev/null > /dev/null
	log_h2 "git"
	sudo apt-get install -qq git < /dev/null > /dev/null
	log_h2 "rename"
	sudo apt-get install -qq rename < /dev/null > /dev/null
	# Removing as not in ubuntu repos, is installed by default
	#info "xargs"
	#sudo apt-get install -qq xargs < /dev/null > /dev/null
}

BASHRC_FILE=~/.bashrc
GO_VERSION="go1.16.5.linux-amd64.tar.gz"
GO_LINK="https://golang.org/dl/$GO_VERSION"

function install_go(){
	log_h1 "Installing go"
	wget -q $GO_LINK
	log_h2 "Uninstalling previous golang installation (if installed) and reinstalling."
	sudo rm -rf /usr/local/go && tar -C /usr/local -xzf $GO_VERSION
	sudo rm -f $GO_VERSION
	# Check if go path has been added
	if grep -Fxq "export PATH=$PATH:/usr/local/go/bin" $BASHRC_FILE
	then
		# export found
		log_h2 "Go path alredy in bashrc"
	else
		# export not found
		log_h2 'export PATH=$PATH:/usr/local/go/bin' >> $BASHRC_FILE
		# Set the export for future functions in this script
		export PATH=$PATH:/usr/local/go/bin
	fi
}

function update_bashrc(){
	##### THIS IS FOR GOLANG SETUP #####
	# https://github.com/tomnomnom/hacks.git
	# Setting gopath to allow external packages to be used
	# Ie: go get -u github.com/tomnomnom/assetfinder
	echo '##### SETTING UP GO PATH #####' >> $BASHRC_FILE
	echo 'export GOPATH=$HOME/go' >> $BASHRC_FILE 
	echo 'export PATH=$PATH:$GOPATH/bin' >> $BASHRC_FILE
}


# export GOROOT=/usr/local/go
# export GOPATH=$HOME/go
# export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
# echo 'export GOROOT=/usr/local/go' >> ~/.bash_profile
# echo 'export GOPATH=$HOME/go'   >> ~/.bash_profile
# echo 'export PATH=$GOPATH/bin:$GOROOT/bin:$PATH' >> ~/.bash_profile
# source ~/.bash_profile


function install_go_tools(){
	log_h1 "Installing go tools"
	log_h2 "assetfinder"
	go get -u  github.com/tomnomnom/assetfinder
	log_h2 "httprobe"
	go get -u github.com/tomnomnom/httprobe
	log_h2 "subfinder"
	GO111MODULE=on go get -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder
	log_h2 "hakrawler"
	go get github.com/hakluke/hakrawler
	log_h2 "waybackurls"
	go get github.com/tomnomnom/waybackurls
	log_h2 "subjack"
	go get github.com/haccer/subjack
	log_h2 "fff"
	go get -u github.com/tomnomnom/fff
	log_h2 "anew"
	go get -u github.com/tomnomnom/anew
	log_h2 "gobuster"
	go install github.com/OJ/gobuster/v3@latest
	log_h2 "go dirsearch"
	go get github.com/evilsocket/dirsearch
}


# This is not 100% might need to get reworked!
function install_git_tools() {
	log_h1 "Cloning github repos"
	GITHUB_DIR="$CURRENT_PATH/github_repos"
	if [ -d "$GITHUB_DIR" ]; then
		echo "Not creating github repo dir already exists"
	else
		echo "Creating $GITHUB_DIR"
		mkdir $GITHUB_DIR
	fi
	
	log_h2 "sublister"
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

	log_h2 "tomnomnom hacks"
	if [ -d $GITHUB_DIR/hacks ]; then
		git pull $GITHUB_DIR/hacks --allow-unrelated-histories
	else
		git clone https://github.com/tomnomnom/hacks.git $GITHUB_DIR/hacks
	fi

	# Install inscope
	log_h1 "Installing inscope"
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
