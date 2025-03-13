# Installation Guide for rickjms-recon

This guide provides step-by-step instructions for installing the rickjms-recon reconnaissance tool on macOS and Ubuntu systems.

## Table of Contents

- [Prerequisites](#prerequisites)
- [macOS Installation](#macos-installation)
- [Ubuntu Installation](#ubuntu-installation)
- [Verifying Installation](#verifying-installation)
- [Troubleshooting](#troubleshooting)

## Prerequisites

Before installing rickjms-recon, ensure you have:

- Administrative privileges on your system
- Internet connection
- Basic familiarity with terminal commands

## macOS Installation

### 1. Install Homebrew (if not already installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Install Required System Dependencies

```bash
brew install openssl jq ruby python3 git nmap
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

```bash
go install github.com/tomnomnom/assetfinder@latest
go install github.com/tomnomnom/httprobe@latest
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/hakluke/hakrawler@latest
go install github.com/tomnomnom/waybackurls@latest
go install github.com/haccer/subjack@latest
go install github.com/tomnomnom/fff@latest
go install github.com/OWASP/amass/v3/...@latest
```

### 6. Install Python Dependencies

```bash
# Create and activate a virtual environment (optional but recommended)
python3 -m venv ~/recon-env
source ~/recon-env/bin/activate

# Install SubDomainizer
pip3 install git+https://github.com/nsonaniya2010/SubDomainizer.git
```

### 7. Clone the Repository

```bash
git clone https://github.com/rickjms/rickjms-recon-scripts.git
cd rickjms-recon-scripts
```

## Ubuntu Installation

### Option 1: Using the Automated Install Script

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
  libgmp-dev zlib1g-dev libldns-dev python3-pip python3-venv git rename nmap
```

#### 2. Install Go

```bash
wget https://golang.org/dl/go1.16.5.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.16.5.linux-amd64.tar.gz
rm go1.16.5.linux-amd64.tar.gz

# Add Go to your PATH
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
source ~/.bashrc
```

#### 3. Install Go Tools

```bash
go install github.com/tomnomnom/assetfinder@latest
go install github.com/tomnomnom/httprobe@latest
GO111MODULE=on go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/hakluke/hakrawler@latest
go install github.com/tomnomnom/waybackurls@latest
go install github.com/haccer/subjack@latest
go install github.com/tomnomnom/fff@latest
go install github.com/tomnomnom/anew@latest
go install github.com/OJ/gobuster/v3@latest
go install github.com/OWASP/Amass/v3/...@latest
```

#### 4. Set Up Python Environment and Install Tools

```bash
# Create and activate a virtual environment
python3 -m venv ~/recon-env
source ~/recon-env/bin/activate

# Install SubDomainizer
pip3 install git+https://github.com/nsonaniya2010/SubDomainizer.git

# Install Sublist3r
git clone https://github.com/aboul3la/Sublist3r.git ~/Sublist3r
pip3 install -r ~/Sublist3r/requirements.txt
sudo ln -s ~/Sublist3r/sublist3r.py /usr/local/bin/sublist3r
```

## Verifying Installation

To verify that all required tools are installed correctly:

```bash
# Clone the repository if you haven't already
git clone https://github.com/rickjms/rickjms-recon-scripts.git
cd rickjms-recon-scripts

# Make the script executable
chmod +x rickjms-recon.sh

# Run a simple test
./rickjms-recon.sh -h
```

You should see the help menu displayed. If any tools are missing, the script will notify you.

## Troubleshooting

### Common Issues

1. **Tool not found errors**: Ensure all tools are properly installed and in your PATH.

   ```bash
   # Check if a tool is in your PATH
   which assetfinder
   which subfinder
   # etc.
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
   ```

### Getting Help

If you encounter issues not covered in this guide, please:

1. Check the project's GitHub repository for open issues
2. Consult the documentation for individual tools
3. Reach out to the community for support

---

This installation guide follows the KISS (Keep It Simple, Stupid) principle, providing straightforward steps to get rickjms-recon up and running on your system.
