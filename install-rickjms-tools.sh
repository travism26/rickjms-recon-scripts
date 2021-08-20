#!/bin/bash


CURRENT_PATH=$(pwd)

function info(){
	local msg="$1"
	echo -e "[+] Installing $msg"
}

function install_packages(){
	info "Installing required apt depedencies"
	info "openssl-dev"
	sudo apt install -y -qq libcurl4-openssl-dev
	sudo apt install -y -qq libssl-dev
	info "jq"
	sudo apt install -y -qq jq
	info "ruby"
	sudo apt install -y -qq ruby-full
	info "libs"
	sudo apt install -y -qq libcurl4-openssl-dev libxml2 libxml2-dev libxslt1-dev ruby-dev build-essential libgmp-dev zlib1g-dev
	info "build"
	sudo apt install -y -qq build-essential libssl-dev libffi-dev python-dev
	info "libdns"
	sudo apt install -y -qq libldns-dev
	info "python3 pip"
	sudo apt install -y -qq python3-pip
	info "python3 venv"
	sudo apt install -y -qq python3-venv
	info "git"
	sudo apt install -y -qq git
	info "rename"
	sudo apt install -y -qq rename
	info "xargs"
	sudo apt install -y -qq xargs
}

BASHRC_FILE="~/.bashrc"
GO_VERSION="go1.16.5.linux-amd64.tar.gz"
GO_LINK="https://golang.org/dl/$GO_VERSION"

function install_go(){
	wget $GO_LINK
	echo -e "Uninstalling previous golang installation (if installed) and reinstalling."
	sudo rm -rf /usr/local/go && tar -C /usr/local -xzf $GO_VERSION
	echo 'export PATH=$PATH:/usr/local/go/bin' >> $BASHRC_FILE
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
	info "assetfinder"
	go get -u  github.com/tomnomnom/assetfinder
	info "httprobe"
	go get -u github.com/tomnomnom/httprobe
	info "subfinder"
	GO111MODULE=on go get -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder
	info "hakrawler"
	go get github.com/hakluke/hakrawler
	info "waybackurls"
	go get github.com/tomnomnom/waybackurls
	info "subjack"
	go get github.com/haccer/subjack
	info "fff"
	go get -u github.com/tomnomnom/fff
	info "anew"
	go get -u github.com/tomnomnom/anew
	info "gobuster"
	go install github.com/OJ/gobuster/v3@latest
	info "go dirsearch"
	go get github.com/evilsocket/dirsearch
}


# This is not 100% might need to get reworked!
CURRENT_PATH=$(pwd)
function install_git_tools() {
	GITHUB_DIR="$CURRENT_PATH/github_repos"
	if [ -d "$GITHUB_DIR" ]; then
		"Not creating github repo dir already exists"
	else
		echo "Creating $GITHUB_DIR"
		mkdir $GITHUB_DIR
	fi
	info "github repos"
	git clone https://github.com/aboul3la/Sublist3r.git $GITHUB_DIR/sublister
	pip3 install -r $GITHUB_DIR/sublister/requirements.txt

	git clone https://github.com/tomnomnom/hacks.git $GITHUB_DIR/hacks

	# Install sublister
	sudo ln -s $GITHUB_DIR/sublister/sublist3r.py /bin/sublist3r
	# Install inscope
	cd $GITHUB_DIR/hacks/inscope
	go mod init inscope
	go mod tidy
	go build
	cd $CURRENT_PATH
	sudo ln -s $GITHUB_DIR/hacks/inscope/inscope /bin/inscope
}

function setup_python_venv() {
	python3 -m venv rickjms-tools
	source rickjms-tools/bin/activate
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
install_go_tools
setup_python_venv
install_git_tools
