# Installation Guide for rickjms-recon

This guide provides step-by-step instructions for installing the rickjms-recon reconnaissance tool on macOS and Linux systems.

## Table of Contents

- [Prerequisites](#prerequisites)
- [macOS Installation](#macos-installation)
- [Linux Installation](#linux-installation)
- [Installing Wordlists](#installing-wordlists)
- [Installing Additional Git Tools](#installing-additional-git-tools)
- [Verifying Installation](#verifying-installation)
- [Troubleshooting](#troubleshooting)

## Prerequisites

Before installing rickjms-recon, ensure you have:

- Administrative privileges on your system
- Internet connection
- Basic familiarity with terminal commands
- Git installed

## macOS Installation

### 1. Install Homebrew (if not already installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Install Required System Dependencies

```bash
brew install openssl jq ruby python3 git nmap masscan
```

### 3. Install Go

```bash
brew install go
```

### 4. Set Up Go Environment

Add the following to your `~/.zshrc` or `~/.bash_profile`:

```bash
echo 'export GOPATH=$HOME/go' >> ~/.zshrc
echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.zshrc
source ~/.zshrc
```

### 5. Install Go Tools

You can install the required tools using either Go or Homebrew. Choose the method that works best for you.

#### Option A: Using Go (recommended for latest versions)

```bash
# Core reconnaissance tools
go install github.com/tomnomnom/assetfinder@latest
go install github.com/tomnomnom/httprobe@latest
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/hakluke/hakrawler@latest
go install github.com/tomnomnom/waybackurls@latest
go install github.com/haccer/subjack@latest
go install github.com/tomnomnom/fff@latest
go install github.com/OWASP/amass/v3/...@latest
go install github.com/tomnomnom/anew@latest

# Directory enumeration and fuzzing
go install github.com/OJ/gobuster/v3@latest
go install github.com/ffuf/ffuf@latest

# Parameter discovery
go install github.com/projectdiscovery/dnsx/cmd/dnsx@latest
go install github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest

# Additional useful tools
go install github.com/lc/gau/v2/cmd/gau@latest
go install github.com/d3mondev/puredns/v2@latest
go install github.com/tomnomnom/hacks/inscope@latest
```

#### Option B: Using Homebrew (if available)

Many of these tools are also available via Homebrew. If you prefer using Homebrew, you can install the available tools with:

```bash
# Check if tools are available in Homebrew
brew install amass subfinder httpx nuclei ffuf gobuster dnsx

# For tools not available in Homebrew, you can still use Go:
go install github.com/tomnomnom/assetfinder@latest
go install github.com/tomnomnom/httprobe@latest
go install github.com/tomnomnom/waybackurls@latest
go install github.com/haccer/subjack@latest
go install github.com/tomnomnom/fff@latest
go install github.com/tomnomnom/anew@latest
go install github.com/lc/gau/v2/cmd/gau@latest
go install github.com/d3mondev/puredns/v2@latest
go install github.com/hakluke/hakrawler@latest
go install github.com/tomnomnom/hacks/inscope@latest
```

Note: The availability of tools in Homebrew may change over time. You can check if a tool is available by running `brew search [tool-name]`. If a tool is not available via Homebrew, you can install it using Go as shown in Option A.

### 6. Install Python Dependencies

```bash
# Create and activate a virtual environment (optional but recommended)
python3 -m venv ~/recon-env
source ~/recon-env/bin/activate

# Install required Python packages
pip3 install requests bs4 dnspython

# Install SubDomainizer
pip3 install git+https://github.com/nsonaniya2010/SubDomainizer.git

# Install Arjun for parameter discovery
pip3 install arjun

# Install LinkFinder for JavaScript analysis
git clone https://github.com/GerbenJavado/LinkFinder.git ~/LinkFinder
cd ~/LinkFinder
pip3 install -r requirements.txt
python3 setup.py install
```

### 7. Clone the Repository

```bash
git clone https://github.com/rickjms/rickjms-recon-scripts.git
cd rickjms-recon-scripts
chmod +x *.sh
```

## Linux Installation

### Option 1: Using the Automated Install Script (Recommended)

```bash
# Clone the repository
git clone https://github.com/rickjms/rickjms-recon-scripts.git
cd rickjms-recon-scripts

# Make the install script executable
chmod +x install-rickjms-tools.sh

# Run the install script
./install-rickjms-tools.sh
```

### Option 2: Manual Installation

If you prefer to install components manually:

#### 1. Install System Dependencies

```bash
sudo apt-get update
sudo apt-get install -y libcurl4-openssl-dev libssl-dev jq ruby-full \
  libxml2 libxml2-dev libxslt1-dev ruby-dev build-essential \
  libgmp-dev zlib1g-dev libldns-dev python3-pip python3-venv git rename nmap \
  masscan uuid-runtime
```

#### 2. Install Go

```bash
# Download and install the latest version of Go
wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz
rm go1.22.0.linux-amd64.tar.gz

# Add Go to your PATH
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
source ~/.bashrc
```

#### 3. Install Go Tools

```bash
# Core reconnaissance tools
go install github.com/tomnomnom/assetfinder@latest
go install github.com/tomnomnom/httprobe@latest
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/hakluke/hakrawler@latest
go install github.com/tomnomnom/waybackurls@latest
go install github.com/haccer/subjack@latest
go install github.com/tomnomnom/fff@latest
go install github.com/tomnomnom/anew@latest

# Directory enumeration and fuzzing
go install github.com/OJ/gobuster/v3@latest
go install github.com/ffuf/ffuf@latest

# Parameter discovery and vulnerability scanning
go install github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest

# OWASP Amass
go install github.com/OWASP/Amass/v3/...@latest
```

#### 4. Set Up Python Environment and Install Tools

```bash
# Create and activate a virtual environment
python3 -m venv ~/recon-env
source ~/recon-env/bin/activate

# Install required Python packages
pip3 install requests bs4 dnspython

# Install SubDomainizer
pip3 install git+https://github.com/nsonaniya2010/SubDomainizer.git

# Install Arjun for parameter discovery
pip3 install arjun

# Install Sublist3r
git clone https://github.com/aboul3la/Sublist3r.git ~/Sublist3r
pip3 install -r ~/Sublist3r/requirements.txt
sudo ln -s ~/Sublist3r/sublist3r.py /usr/local/bin/sublist3r

# Install LinkFinder for JavaScript analysis
git clone https://github.com/GerbenJavado/LinkFinder.git ~/LinkFinder
cd ~/LinkFinder
pip3 install -r requirements.txt
python3 setup.py install
```

#### 5. Install dnmasscan

```bash
# Clone the repository
git clone https://github.com/rastating/dnmasscan.git ~/dnmasscan
sudo ln -s ~/dnmasscan/dnmasscan /usr/local/bin/dnmasscan
```

## Installing Wordlists

The repository includes a script to download common wordlists used for reconnaissance and penetration testing:

```bash
# Make the script executable
chmod +x rickjms-get-all-wordlists.sh

# Run the script
./rickjms-get-all-wordlists.sh
```

This will download and install the following wordlists to `~/wordlists/`:

- FuzzDB
- Dirsearch wordlists
- SecLists
- PayloadsAllTheThings

## Installing Additional Git Tools

The repository includes a script to download additional security tools from GitHub:

```bash
# Make the script executable
chmod +x rickjms-get-all-git-tools.sh

# Run the script
./rickjms-get-all-git-tools.sh
```

This will download and install various security tools to `~/rickjms/github-tools/`, including:

- JavaScript enumeration tools
- DNS enumeration tools
- GitHub reconnaissance tools
- Visual reconnaissance tools
- Web application firewall identification tools
- Virtual host enumeration tools
- Port scanners
- Fuzzing tools
- Subdomain enumeration tools
- Web attack tools

## Verifying Installation

To verify that all required tools are installed correctly:

```bash
# Make the script executable if you haven't already
chmod +x rickjms-recon.sh

# Run a simple test
./rickjms-recon.sh -h
```

You should see the help menu displayed. If any tools are missing, the script will notify you.

You can also check for individual tools:

```bash
# Check if required tools are in your PATH
for tool in assetfinder amass subfinder httpx httprobe hakrawler nmap ffuf nuclei jq; do
  which $tool &>/dev/null && echo "✅ $tool installed" || echo "❌ $tool NOT installed"
done
```

## Troubleshooting

### Common Issues

1. **Tool not found errors**: Ensure all tools are properly installed and in your PATH.

   ```bash
   # Check if a tool is in your PATH
   which assetfinder
   which subfinder
   # etc.

   # If a Go tool is not found, try reinstalling it
   go install github.com/tomnomnom/assetfinder@latest
   ```

2. **Permission denied**: Make sure the script is executable.

   ```bash
   chmod +x rickjms-recon.sh
   ```

3. **Python module not found**: Ensure you've activated your virtual environment.

   ```bash
   source ~/recon-env/bin/activate
   ```

4. **Go module issues**: Make sure your Go environment is properly set up.

   ```bash
   go version
   echo $GOPATH
   echo $PATH | grep go

   # If Go is not in your PATH, add it
   echo 'export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin' >> ~/.bashrc
   source ~/.bashrc
   ```

5. **Missing dependencies**: Some tools may require additional dependencies.

   ```bash
   # For Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install -y libpcap-dev

   # For macOS
   brew install libpcap
   ```

6. **Outdated Go version**: Some tools require a newer version of Go.

   ```bash
   # Check your Go version
   go version

   # For Ubuntu/Debian, update Go
   wget https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
   sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz

   # For macOS
   brew upgrade go
   ```

### Getting Help

If you encounter issues not covered in this guide, please:

1. Check the project's GitHub repository for open issues
2. Consult the documentation for individual tools
3. Run the tool with the `-d` flag to enable debug mode for more detailed error messages
4. Reach out to the community for support

---

This installation guide provides comprehensive steps to get rickjms-recon up and running on your system. The tool is designed to be modular, so even if some components fail to install, you can still use the core functionality.
