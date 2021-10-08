# rickjms-recon-scripts


# Execute the recon script
- Hard requirements are the tools used and the `.scope` file within the root directory OR parent directory this is a "SAFTY NET" protects you from going outside of client scope!
- For more information please see the [github page](https://github.com/tomnomnom/hacks/tree/master/inscope)
	- https://github.com/tomnomnom/hacks/tree/master/inscope
```
cat .scope
yahoo.com
.*\.example.*\.com
!*.\.yahoo.tx
!*.\.yahoo.cn
```

## Help menu
```bash
~$ rickjms-recon.sh -h
Usage:
	-h 				Display help menu
	-f FILENAME 		Run recon with file of target domains
	-n 			Execute a dry run listing all the commands executed and tools used
	-o PATH/TO/OUTPUT 	Change the output directoy default is current directory
	-t USER_TARGET 		Run recon against single domain
	-s 			Silent Mode do not post output
	-d 			Enable Debugging mode
	-l 			LIGHT SCAN Mode Only run the quick scans (assetfinder, crt.sh, tls.bufferover.run)
	-w 			Skip the waybackurl lookup.
```
## Run script on file of domain names
- This script will run a search on each new line within the file, do NOT use wild cards it does it for you.
```
~$ cat targets.txt 
yahoo.com
example.com
testing.com
...
~$ rickjms-recon.sh -f targets.txt -o yahoo.com-automation
```

## Want to do a dry run
- Dry run is the concept of wanting to see what commands will get executed this will echo all the commands to be ran during my scanning process.
```bash
rickjms-recon.sh -f targets.txt -o yahoo.com-automation2 -n
[INFO]  Creating directory structure for recon files
[INFO]  TOPFOLDERS = yahoo.com-automation2/scans yahoo.com-automation2/post-scanning yahoo.com-automation2/maybe-out-scope
mkdir -p yahoo.com-automation2/scans
mkdir -p yahoo.com-automation2/post-scanning
mkdir -p yahoo.com-automation2/maybe-out-scope
mkdir -p yahoo.com-automation2/post-scanning/alive-urls
mkdir -p yahoo.com-automation2/post-scanning/dnmasscan
mkdir -p yahoo.com-automation2/post-scanning/haktrails
mkdir -p yahoo.com-automation2/post-scanning/website-crawling
mkdir -p yahoo.com-automation2/post-scanning/waybackurls
[INFO]  Take user targets and combine them to one target list
[INFO]  User passed file:targets.txt
cat targets.txt | sort -u >> /tmp/rickjms-recon.eNA8Yq
cat /tmp/rickjms-recon.eNA8Yq | sort -u >> yahoo.com-automation2/13159829-USERTARGETS.txt
[INFO]  Run all the top level scanners
assetfinder yahoo.com >> yahoo.com-automation2/scans/assetfinder.host.out
curl -s https://crt.sh/?Identity=%.yahoo.com | grep "\>\*.yahoo.com" | sed 's/<[/]*[TB][DR]>/\n/g' | grep -vE "<|^[\*]*[\.]*yahoo.com" | sort -u | awk 'NF' >> yahoo.com-automation2/scans/crtsh.host.out
curl tls.bufferover.run/dns?q=yahoo.com 2>/dev/null | jq .Results >> yahoo.com-automation2/scans/tls_bufferover.out
subfinder -dL yahoo.com-automation2/13159829-USERTARGETS.txt -t 100 -o yahoo.com-automation2/scans/subfinder.host.out -nW
python3 ~/tools/recon/Sublist3r/sublist3r.py -d yahoo.com
[WARN] Please ensure you have .scope file to ensure youre within scope
[INFO]  Running 'inscope' to ensure targets are inscope
[INFO]  Saving output to yahoo.com-automation2/scans/webaddress_scan_data.host.out
[INFO]  Running httprobe This might take awhile please be patient...
cat yahoo.com-automation2/scans/webaddress_scan_data.host.out | httprobe -c 60 | sed 's/https\?:\/\///' | tr -d ':443' >> yahoo.com-automation2/post-scanning/alive-urls/a.txt
sort -u yahoo.com-automation2/post-scanning/alive-urls/a.txt > yahoo.com-automation2/post-scanning/alive-urls/httprobe.out
cat yahoo.com-automation2/post-scanning/alive-urls/clean-httprobe.out | hakrawler -plain -forms >> yahoo.com-automation2/post-scanning/website-crawling/hakcrawler_forms.out
cat yahoo.com-automation2/post-scanning/alive-urls/clean-httprobe.out | hakrawler -plain -all >> yahoo.com-automation2/post-scanning/website-crawling/hakcrawler_all.out
cat yahoo.com-automation2/post-scanning/alive-urls/clean-httprobe.out | haktrails subdomains
[INFO]  Running waybackurls this might take up space depending on that program...
cat yahoo.com-automation2/post-scanning/alive-urls/clean-httprobe.out | waybackurls >> yahoo.com-automation2/post-scanning/waybackurls/wayback.out
subjack -w yahoo.com-automation2/post-scanning/alive-urls/clean-httprobe.out -t 100 -timeout 30 -ssl -c ~/wordlists/fingerprints.json -v 3 -o yahoo.com-automation2/post-scanning/potential-takeovers.out
nmap -iL yahoo.com-automation2/post-scanning/alive-urls/clean-httprobe.out -T4 -oA yahoo.com-automation2/post-scanning/nmap.out
cat yahoo.com-automation2/post-scanning/alive-urls/httprobe.out | fff -d 100 -S -o yahoo.com-automation2/post-scanning/fff-output
[INFO]  amass will only be executed on -t passed value since it takes for god damn ever to run...
[INFO]  To get a complete run on this script please run amass below adjust the 
amass enum -max-dns-queries 2 -o amass.out -src -ip -df yahoo.com-automation2/13159829-USERTARGETS.txt -brute -config ~/.config/amass/config.ini -active
sudo dnmasscan yahoo.com-automation2/scans/webaddress_scan_data.host.out yahoo.com-automation2/post-scanning/dnmasscan/dnmasscan.out -p443,80,4443,8443,8080,8081 -oG yahoo.com-automation2/post-scanning/dnmasscan/masscan.out
```

# Requirements
I make use of a lot of command line tools Ill do my best to list them all, also I made a symlink to each of them so they are access to my terminal directly. Visit [my blog](https://www.travisallister.com/post/bugbounty-recon-script-rickjms-recon-sh) for more information on this script.

# Installation
- Not 100% working I am using ubuntu and not supporting anyother OS ATM message me and I can try to help.
- [Install golang](https://golang.org/doc/install) (https://golang.org/doc/install)
- Run the install script to install dependencies, again this is not 100% create an issue if you have problems installing it ill fix it ASAP.
```bash
~$ chmod +x install-rickjms-tools.sh 
~$ ./install-rickjms-tools.sh 
```

## Links to tools used 
Majority of the tools are built in golang so a simple `go get ...` will work. Other python scripts will require symlink to `/bin/` or add it to your PATH (personally I prefer symlink)
1. [waybackurls](https://github.com/tomnomnom/waybackurls)
2. [httprobe](https://github.com/tomnomnom/httprobe) (build lastest version it has `-prefer-https` flag is useful but not required YET)
3. [hakrawler](https://github.com/hakluke/hakrawler)
4. [haktrails](https://github.com/hakluke/haktrails) (This code is commented out since it eats your api key up quickly)
5. [subjack](https://github.com/haccer/subjack)
6. [nmap](https://nmap.org/)
7. [fff](https://github.com/tomnomnom/fff)
8. [assetfinder](https://github.com/tomnomnom/assetfinder)
9. [subfinder](https://github.com/projectdiscovery/subfinder)
10. [sublist3r](https://github.com/aboul3la/Sublist3r)
11. [anew](https://github.com/tomnomnom/anew)
12. [inscope](https://github.com/tomnomnom/hacks/tree/master/inscope) <-- Needs to be build manually and symliked

## Create symlink
- Example on how to create a symlink for sublist3r.
`sudo ln -s ~/path/to/Sublist3r/sublist3r.py /bin/sublist3`

# My personal recon approach
- I am going to try and put down a good "Recon" workflow this will be from subdomain enumeration -> content discovery.
- Credit: https://m0chan.github.io/2019/12/17/Bug-Bounty-Cheetsheet.html

## Steps
1. Identify IPS and main top level domains (TLDS)
2. Subdomain Enumeration (This tool)
3. Domain Bruteforcing
4. Port Scanning, web-application port scanning (httprobe)
5. Run a screenshotting tool (aquatone, eyewitness)
6. Content Discovery

### Identifiy IPs and TLDS
- ASNs
	- https://bgp.he.net/
- Reverse whois
	- https://www.whoxy.com/
- Acquistions
	- https://www.crunchbase.com/home
- Google-fu
	- Use google to find shit few examples.
		- `url: tesla.com intitle:admin`
		- `url: tesla.com inurl:'src-img'`

### Subdomain Enum (This script will cover this mostly minus amass)
- rickjms-recon.sh
- amass <-- This tools is OVER POWERED, run this with as much info as possible and you wont be disappointed. (all api keys + using asn values)
	- Example:`amass enum -o amass/amass.enum-2.out -src -ip -df targets.txt -brute -config ~/.config/amass/config.ini -active -rf ~/resolvers/july30.21.txt -cidr x.x.x.x/x -asn ####,###`
- subfinder (included in rickjms-recon.sh)

#### Only have CIDR? hakrevdns is your answer
- https://github.com/hakluke/hakrevdns
```bash
prips xx.xx.xx.xx/xx | hakrevdns
...
```

### (sub)Domain Bruteforcing
- Generate permutations with dnsgen
`cat domains.txt | dnsgen - | massdns -r /path/to/resolvers.txt -t A -o J -w dnsgenoutput.txt --flush 2>/dev/null`
- `dnsrecon -d apple.com -D all.txt -t brt`
	- all.txt -> jhaddix yuge bruteforce list, see below.
- `python $Tools/subbrute/subbrute.py paypal.com paypal.co.uk -t all.txt`
- `gobuster dns -d apple.com -w all.txt`

#### Tools required
- https://github.com/blechschmidt/massdns
```bash 
git clone https://github.com/blechschmidt/massdns.git
cd massdns
make
cd bin
sudo ln -s PATH/TO/massdns/bin/massdns /bin/massdns
```
- https://github.com/ProjectAnte/dnsgen
```bash
git clone https://github.com/ProjectAnte/dnsgen
cd dnsgen
pip3 install -r requirements.txt
python3 setup.py install
```
- https://gist.github.com/jhaddix/86a06c5dc309d08580a018c66354a056

- https://github.com/TheRook/subbrute
- https://github.com/OJ/gobuster.git
