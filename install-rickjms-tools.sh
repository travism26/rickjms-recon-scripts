#!/bin/bash


CURRENT_PATH=$(pwd)

function info(){
	local msg="$1"
	echo -e "[+] Installing $msg"
}

function install_packages(){
	# Required for silencing the apt-get output
	DEBIAN_FRONTEND=noninteractive
	info "required apt depedencies"
	info "openssl-dev"
	sudo apt-get install -qq libcurl4-openssl-dev < /dev/null > /dev/null
	sudo apt-get install -qq libssl-dev < /dev/null > /dev/null
	info "jq"
	sudo apt-get install -qq jq < /dev/null > /dev/null
	info "ruby"
	sudo apt-get install -qq ruby-full < /dev/null > /dev/null
	info "libs"
	sudo apt-get install -qq libcurl4-openssl-dev libxml2 libxml2-dev libxslt1-dev ruby-dev build-essential libgmp-dev zlib1g-dev < /dev/null > /dev/null
	info "build"
	sudo apt-get install -qq build-essential libssl-dev libffi-dev python-dev < /dev/null > /dev/null
	info "libdns"
	sudo apt-get install -qq libldns-dev < /dev/null > /dev/null
	info "python3 pip"
	sudo apt-get install -qq python3-pip < /dev/null > /dev/null
	info "python3 venv"
	sudo apt-get install -qq python3-venv < /dev/null > /dev/null
	info "git"
	sudo apt-get install -qq git < /dev/null > /dev/null
	info "rename"
	sudo apt-get install -qq rename < /dev/null > /dev/null
	# Removing as not in ubuntu repos, is installed by default
	#info "xargs"
	#sudo apt-get install -qq xargs < /dev/null > /dev/null
}

BASHRC_FILE=~/.bashrc
GO_VERSION="go1.16.5.linux-amd64.tar.gz"
GO_LINK="https://golang.org/dl/$GO_VERSION"

function install_go(){
	info "go"
	wget -q $GO_LINK
	echo "Uninstalling previous golang installation (if installed) and reinstalling."
	sudo rm -rf /usr/local/go && tar -C /usr/local -xzf $GO_VERSION
	# Check if go path has been added
	echo 'export PATH=$PATH:/usr/local/go/bin' >> $BASHRC_FILE
	# Set the export for future functions in this script
	export PATH=$PATH:/usr/local/go/bin
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
	info "go tools"
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
