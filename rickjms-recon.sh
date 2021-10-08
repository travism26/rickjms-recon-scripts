#!/bin/bash

# GLOBALS
SCRIPT=$(echo $0 | awk -F "/" '{print $NF}')
CUR_DATE=$(date +"%Y%m%d")
UUIDSHORT=$(uuidgen | cut -d\- -f1)
CURRENT_DIR=$(pwd)
BASEDIR=$(dirname $0)

## USER INPUT ##
USER_TARGET=""
USER_FILE="" # User input we need to clean this
OUTPUT_DIR="$CURRENT_DIR" # Default current directory

## USER INPUT FLAGS ##
DRYRUN="false"
FILE_PASSED="false"
TARGET_PASSED="false"
SILENT_MODE=""
ENABLE_DEBUG=""
PORTS_TO_SCAN="443,80,4443,8443,8080,8081"
LIGHT_SCAN=""
INSCOPE_PASSED=""
SKIPWAYBACK=""


###### PHASE ONE RECON ######
# Recon output This will hold all my amass, haktrails, assetfinder stuff...
# FOLDERS
# scans/amass.out,scans/assetfinder.out,scans/haktrails.out,...etc
# Code Execution.
# 1) Fastest tools for finding subdomains: assetfinder, haktrails, maybe crt.sh (tomnomnom/hakluke stuff)
# 2) Use amass last its fucking slow
# 3) 

###### PHASE TWO RECON ######
# We need to enum on these found urls using two approaches
# 1) httprobe them, find alive websites
# 2) dnsmasscan find open ports.
# 3) anything else? 

# FOLDERS
# post_scans
# alive_urls/httprobe.out
# dnsmasscan/ip_service.out

# Execute dry run
function isDryRun() {
	[ "$DRYRUN" = "true" ]
}

function filePassed() {
	[ "$FILE_PASSED" = "true" ]
}

function targetPassed() {
	[ "$TARGET_PASSED" = "true" ]
}

function isLightScan() {
	[ "$LIGHT_SCAN" = "true" ]
}

function isMissingUserInput() {
	targetPassed && filePassed
}

function inscopePassed() {
	[ $INSCOPE_PASSED = "true" ]
}

function skipWaybackUrl(){
	[ "$SKIPWAYBACK" = "true" ]
}

# TARGETS + user_FILE gets handled here...
function consolidateTargets() {
	info "Take user targets and combine them to one target list"
	if filePassed; then
		if isDryRun; then
			info "User passed file:$USER_FILE"
			echo "cat $USER_FILE | sort -u >> $tmp_target_list"
			cat $USER_FILE | sort -u >> $tmp_target_list
		else
			info "User passed file handle here file:$USER_FILE"
			cat $USER_FILE | sort -u >> $tmp_target_list
		fi
	fi

	if targetPassed; then
		if isDryRun; then
			echo "cat $USER_TARGET | sort -u >> $tmp_target_list"
			echo $USER_TARGET >> $tmp_target_list
		else
			info "User passed target url:$USER_TARGET"
			for t in $USER_TARGET; do
				echo "$t" >> $tmp_target_list
			done
		fi
	fi

	if ! filePassed && ! targetPassed ; then
		error "Must pass in target to scan -t DOMAIN.com OR -f FILENAME" 243
	fi
	if isDryRun; then
		echo "cat $tmp_target_list | sort -u >> $FINAL_TARGETS"
		cat $tmp_target_list | sort -u >> $FINAL_TARGETS
	else
		cat $tmp_target_list | sort -u >> $FINAL_TARGETS
	fi
}

# USE THIS FOR LOGGING
function info(){
	MSG="$1"
	if test -z $SILENT_MODE; then
		echo "[INFO]  $MSG"
	fi
}

function warn() {
	MSG="$1"
	if test -z $SILENT_MODE; then
		echo "[WARN] $MSG"
	fi
}

# USE FOR DEBUGGING
function debug(){
	MSG="$1"
	if ! test -z $ENABLE_DEBUG; then
		echo "[DEBUG] $MSG"
	fi
}

# USE THIS FOR ERROR Exit
function error(){
	MSG="$1"
	EXIT_CODE="$2"
	echo "[ERROR] $MSG"
	exit $EXIT_CODE
}

### SCANNING TOOLS ### 
function run_tls_bufferover() {
	local USERIN="$1"
	debug "run_tls_bufferover($USERIN)"
	local TLSOUT="tls_bufferover.out"
	if isDryRun; then
		echo "curl tls.bufferover.run/dns?q="$USERIN" 2>/dev/null | jq .Results >> $SCAN_FOLDER/$TLSOUT"
	else
		info "Executing search tls.bufferover.run $USERIN"
		curl tls.bufferover.run/dns?q="$USERIN" 2>/dev/null | jq .Results >> $SCAN_FOLDER/$TLSOUT
	fi
}

function run_tls_bufferover_with_file() {
	local FILEIN="$1"
	debug "run_tls_bufferover_with_file($FILEIN)"
	if ! test -f $FILEIN; then
		error "Please enter a correct file, you entered an incorrect file:$FILEIN" 254
	fi
	while IFS= read -r line
	do
		run_tls_bufferover "$line"
	done < "$FILEIN"
}


function run_crtsh() {
	local USERIN="$1"
	debug "run_crtsh($USERIN)"
	local CRTOUT="crtsh.host.out"
	# curl -s https://crt.sh/?Identity=%.$1 |
	# grep ">*.$1" | sed 's/<[/]*[TB][DR]>/\n/g' | grep -vE "<|^[\*]*[\.]*$1" | sort -u | awk 'NF'
	if isDryRun; then
		echo "curl -s https://crt.sh/?Identity=%.$USERIN | grep \"\>\*.$USERIN\" | \
sed 's/<[/]*[TB][DR]>/\n/g' | grep -vE \"<|^[\*]*[\.]*$USERIN\" | sort -u | awk 'NF' >> $SCAN_FOLDER/$CRTOUT"	
	else
		info "Executing search crt.sh/?...$USERIN"
		curl -s https://crt.sh/?Identity=%.$USERIN | grep ">*.$USERIN" | sed 's/<[/]*[TB][DR]>/\n/g' \
| grep -vE "<|^[\*]*[\.]*$USERIN" | sort -u | awk 'NF' >> $SCAN_FOLDER/$CRTOUT
		sleep 1 # Adding a sleep here to so we dont pass the RATE of 60 requests per minute.
	fi
}

## This will run crtsh with file input just a wrapper function...
## crtsh $URL
## Can abstract this but that will be future code release...
function run_crtsh_with_file() {
	local FILEIN="$1"
	debug "run_crtsh_with_file($FILEIN)"
	if ! test -f $FILEIN; then
		error "Please enter a correct file, you entered an incorrect file:$FILEIN" 254
	fi
	while IFS= read -r line
	do
		debug "run_crtsh_with_file->run_crtsh($line)"
		run_crtsh "$line"
	done < "$FILEIN"
}

## subdomain finder ## 
function run_assetfinder() {
	local URL_INPUT="$1"
	local ASSETFINDEROUT="assetfinder.host.out"
	debug "run_assetfinder($URL_INPUT)"
	if isDryRun; then
		echo "assetfinder $URL_INPUT >> $SCAN_FOLDER/$ASSETFINDEROUT"
	else
		info "Executing assetfinder $URL_INPUT"
		assetfinder $URL_INPUT >> $SCAN_FOLDER/$ASSETFINDEROUT
	fi
}

## This will run assetfinder with file input just a wrapper function...
## assetfinder $URL
function run_assetfinder_with_file() {
	local FILEIN="$1"
	debug "run_assetfinder_with_file($FILEIN)"
	if ! test -f $FILEIN; then
		error "Please enter a correct file, you entered an incorrect file:$FILEIN" 254
	fi
	while IFS= read -r line
	do
		debug "run_assetfinder_with_file->run_assetfinder($line)"
		run_assetfinder "$line"
	done < "$FILEIN"
}

function run_subfinder() {
	local USERIN="$1"
	local SUBFINDEROUT="subfinder.host.out"
	debug "run_subfinder($USERIN)"
	if isDryRun; then
		echo "subfinder -dL $USERIN -t 100 -o $SCAN_FOLDER/$SUBFINDEROUT -nW"
	else
		info "Executing subfinder $USERIN"
		subfinder -dL $USERIN -t 100 -o $SCAN_FOLDER/$SUBFINDEROUT -nW
	# Add subfinder
	# -o 	File to write output to (optional) 	subfinder -o output.txt
	# -nW 	Remove Wildcard & Dead Subdomains from output 	subfinder -nW
	# -dL 	File containing list of domains to enumerate 	subfinder -dL hackerone-hosts.txt
	# -t 	Number of concurrent goroutines for resolving (default 10) 	subfinder -t 100
	# subfinder -dL domain-list.txt -t 100 -o $WORKSPACE/subdomain/$OUTPUT-subfinder.txt -nW
	fi
}

## Bruteforce tools maybe not use it? ##
function run_ffuf() {
	# ffuf -w /path/to/wordlist.txt -ac -t 50 -u https://paypal.com/username/FUZZ
	local USERIN="$1"
	debug "run_ffuf($USERIN)"
	if isDryRun; then
		echo "ffuf -w /path/to/wordlist.txt -ac -t 50 -u $USERIN/FUZZ"
	else
		echo "ffuf -w /path/to/wordlist.txt -ac -t 50 -u $USERIN/FUZZ"
	fi
}

# This is slow as fuck so do this last and maybe only do it on something thats super interesting.
# Typical execution Jeff Foley does is
# :: amass enum -src -ip -brute -d owaps.org
# You can also pass in a file not super recommended by you can like so
# :: amass enum -src -ip -brute -df domains.txt
function run_amass() {
	local USERIN="$1" # This is a file dont use as output!
	local AMASS_IP_OUT="ips-amass.out"
	local AMASS_HOST_OUT="hosts-amass.host.out"
	local AMASS_RAW="amass-raw.out"

	local DOMAIN_FLAG="-d $(head -n 1 $USERIN)" # -d is default
	# local ARG_PASSED=$(head -n 1 $USERIN)
	local FILECOUNT=$(cat $USERIN | wc -l)
	if [[ $FILECOUNT -le 10 ]]; then
		DOMAIN_FLAG="-df $USERIN" # EXECUTE THE FILE
		info "Expermental Feature enabled if domains passed is < 10 we will use -df <TARGETS.txt> in amass"
	fi
	debug "run_amass($USERIN)"
	if isDryRun; then
		echo "amass enum -o $SCAN_FOLDER/$AMASS_RAW -src -ip $DOMAIN_FLAG -brute -config ~/.config/amass/config.ini -active"
		echo "cat $SCAN_FOLDER/$AMASS_RAW | cut -d']' -f2 | awk '{print \$1}' \
| sort -u >> $SCAN_FOLDER/$AMASS_HOST_OUT"
		echo "cat $SCAN_FOLDER/$AMASS_RAW | cut -d']' -f2 | awk '{print \$2}' \
| tr ',' '\n' | sort -u >> $SCAN_FOLDER/$AMASS_IP_OUT"
	else
		# Two execution attempts 
		# 1) head -n 1 $USERIN (pull the first domain off the file)
		# 2) use -df on amass to execute a scan on the entire file?
		info "Executing Amass this might take awhile..."
		amass enum -o $SCAN_FOLDER/$AMASS_RAW -src -ip $DOMAIN_FLAG -brute -config ~/.config/amass/config.ini -active
		info "Parsing out the hostnames to: $SCAN_FOLDER/$AMASS_HOST_OUT"
		cat $SCAN_FOLDER/$AMASS_RAW | cut -d']' -f2 | awk '{print $1}' | sort -u >> $SCAN_FOLDER/$AMASS_HOST_OUT
		info "Parsing out the ip address to: $SCAN_FOLDER/$AMASS_IP_OUT"
		cat $SCAN_FOLDER/$AMASS_RAW | cut -d']' -f2 | awk '{print $2}' | tr ',' '\n' | sort -u >> $SCAN_FOLDER/$AMASS_IP_OUT
	fi

	# amass enum -o amass.out -src -ip -d paypal.com -brute -config ~/.config/amass/config.ini -active
}

# Expermental function do not relie on yet?
# This will be a post scan option
function run_httpx(){
	local USERIN="$1"
	local HTTPXOUT="httpx.out"
	debug "run_httpx($USERIN)"
	if isDryRun; then
		echo "cat $USERIN | httpx -cname -ports $PORTS_TO_SCAN -threads 75 -title -o $POST_SCAN_ENUM/$HTTPXOUT"
	else
		cat $USERIN | httpx -cname -ports "$PORTS_TO_SCAN" -threads 75 -title -o $POST_SCAN_ENUM/$HTTPXOUT
	fi
}

function run_httprobe() {
	local USERIN="$1"
	HTTPROBEOUT="httprobe.out"
	CLEANHTTPROBE="clean-httprobe.out"
	debug "run_httprobe($USERIN)"
	if isDryRun; then
		echo "cat $USERIN | httprobe -c 60 | sed 's/https\?:\/\///' | tr -d ':443' >> $ALIVE/a.txt"
		echo "sort -u $ALIVE/a.txt > $ALIVE/$HTTPROBEOUT"
	else
		info "Executing httprobe on targets:$USERIN saving:$ALIVE/$HTTPROBEOUT"
		cat $USERIN | httprobe -c 60 >> $ALIVE/$HTTPROBEOUT
		info "Combine httprobe output: $ALIVE/$HTTPROBEOUT"
		cat $ALIVE/$HTTPROBEOUT | xargs -n1 -I{} sh -c "echo {} | sed 's/https\?:\/\///'" | anew -q $ALIVE/$CLEANHTTPROBE
		# sort -u $ALIVE/a.txt > $ALIVE/$HTTPROBEOUT
		# rm $ALIVE/a.txt
	fi
}

function break_httprobe_up() {
	local FILE_PREFIX="$1"
	local ALL_HOSTS="$2"
	TEMP_PREFIX_DATA="$ALIVE/split-data"
	# split -C 10k --numeric-suffixes all_hosts.txt hosts
	# We need to break the files into smaller parts
	split -C 10k --numeric-suffixes $ALL_HOSTS $TEMP_PREFIX_DATA/$FILE_PREFIX
	# We loop through that list and run httprobe...
	warn "You are Attempting to run httprobe on $(cat $ALL_HOSTS | wc -l) hosts this might take a while"
	# for (( i=0; i<=$(find  -type f -name "$FILE_PREFIX*" | wc -l); i++ ))
	# do
	# 	echo 

}

function run_hakrawler() {
	local USERIN="$1"
	local HAKRAWLER_ALL="hakcrawler_all.out"
	local HAKRAWLER_FORMS="hakcrawler_forms.out"
	debug "run_hakrawler($USERIN)"
	if isDryRun; then
		echo "cat $USERIN | hakrawler >> $CRAWLING/$HAKRAWLER_ALL"
	else
		info "Pulling all the forms from target"
		cat $USERIN | hakrawler >> $CRAWLING/$HAKRAWLER_ALL
		# info "Crawling target for information"
		# cat $USERIN | hakrawler -plain -all >> $CRAWLING/$HAKRAWLER_ALL
	fi	
}

function run_subdomainizer() {
	local USERIN="$1"
	local DOMAINIZER="subdomainizer.out"
	debug "run_subdomainizer($USERIN)"
	if isDryRun; then
		echo "SubDomainizer -l $USERIN -o $CRAWLING/$DOMAINIZER"
	else
		info "Executing SubDomainizer $USERIN"
		SubDomainizer -l $USERIN -o $CRAWLING/$DOMAINIZER
	fi
}

# This will be a post scan option
# SUDO required for masscan!!
function run_dnmasscan() {
	local USERIN="$1"
	debug "run_dnmasscan($USERIN)"
	local DNMASSCAN="dns-dnmasscan.log"
	local MASSCAN="masscan.log"
	if isDryRun; then
		echo "dnmasscan $USERIN $DNSCAN/$DNMASSCAN -p$PORTS_TO_SCAN -oG $DNSCAN/$MASSCAN"
	else
		info "Executing post scan enum dnmasscan $USERIN -> $DNSCAN"
		FILESIZE=$(cat $USERIN | wc -l)
		if [[ $FILESIZE -ge 1000 ]]; then
			warn "Large hosts file passed breaking up dnmasscan into parts..."
			split_up_dnmasscan "$UUIDSHORT" $USERIN
		else
			sudo dnmasscan $USERIN $DNSCAN/$DNMASSCAN -p$PORTS_TO_SCAN -oG $DNSCAN/$MASSCAN
		fi
	fi
}

function run_waybackurls() {
	local USERIN="$1"
	local WAYBACKOUT="wayback.out"
	debug "run_waybackurls($USERIN)"
	if isDryRun; then
		echo "cat $USERIN | waybackurls >> $WAYBACKURL/$WAYBACKOUT"
	else
		info "Executing waybackurls on targets"
		cat $USERIN | waybackurls >> $WAYBACKURL/$WAYBACKOUT
	fi
}

# Inputs:
# 1) file prefix to be used in the slit
# 2) file we are splitting ie: all_hosts.txt
# OUTPUT:
# 1) Creates dns-masscan.log
# 2) Creates masscan.log
# SUDO requred for masscan!!
function split_up_dnmasscan() {
	local FILE_PREFIX="$1"
	local ALL_HOSTS="$2"
	debug "split_up_dnmasscan($FILE_PREFIX, $ALL_HOSTS)"
	local TEMP_PREFIX_DATA="$ALIVE_HOSTS/split-data"
	local FILE_ARRAY=()
	info "Splitting up the scan target to smaller chunks so dnmasscan doesn't get mad"
	# split -C 10k --numeric-suffixes all_hosts.txt hosts
	# We need to break the files into smaller parts
	if isDryRun; then
		echo "mkdir -p $TEMP_PREFIX_DATA"
		echo "split -C 10k --numeric-suffixes $ALL_HOSTS $TEMP_PREFIX_DATA/$FILE_PREFIX"
		echo "# Split up $ALL_HOSTS into 10k bytes and run dnmasscan on each file"
		echo "# Combine all the results into one file and post in $DNSCAN folder"
	else
		mkdir -p $TEMP_PREFIX_DATA
		split -C 10k --numeric-suffixes $ALL_HOSTS $TEMP_PREFIX_DATA/$FILE_PREFIX
		
		while IFS= read -r -d $'\0'; do
			FILE_ARRAY+=("$REPLY")
		done < <(find $TEMP_PREFIX_DATA -type f -name "$FILE_PREFIX*")
		
		warn "About to run dnmasscan on $(find $TEMP_PREFIX_DATA -type f -name "$FILE_PREFIX*" | wc -l) files"
		# Temp names for each log file.
		local DNS_TEMP_LOG="dns-dnmasscan"
		local MASSCAN_TEMP_LOG="masscan"

		# We now loop through the array of "Temp prefix" files running the scan saving to temp names above
		for dnfile in $FILE_ARRAY; do
			info "|----Broke up dnmasscan into parts running file:$dnfile"
			sudo dnmasscan $dnfile "$DNS_TEMP_LOG-$dnfile" -p$PORTS_TO_SCAN -oG "$MASSCAN_TEMP_LOG-$dnfile"
		done
		info "|"
		info "-->Finished dnmasscan" 
	fi


	# Scan complete we now need to combine all the results into two files
	# 1) dns-masscan.log
	# 2) masscan.log
	
}

# Paid resouces
function run_haktrails() {
	local USERIN="$1"
	debug "run_haktrails($USERIN)"
	if isDryRun; then
		echo "cat $USERIN | haktrails subdomains"
	else
		# This can eat your api usage... careful!
		info "WARNING This might eat up your api usage!!"
		info "cat $USERIN | haktrails subdomains"
	fi
}

function run_subjack() {
	local USERIN="$1"
	local TAKEOVEROUT="potential-takeovers.out"
	debug "run_subjack($USERIN)"
	if isDryRun; then
		echo "subjack -w $USERIN -t 100 -timeout 30 -ssl -c ~/wordlists/fingerprints.json -v 3 -o $POST_SCAN_ENUM/$TAKEOVEROUT"
	else
		info "Checking for subdomain takeovers with subjack"
		subjack -w $USERIN -t 100 -timeout 30  \
-ssl -c ~/wordlists/fingerprints.json -v 3 -o $POST_SCAN_ENUM/$TAKEOVEROUT
	fi
}

function run_nmap() {
	local USERIN="$1"
	local NMAPOUT="nmap.out"
	debug "run_nmap($USERIN)"
	if isDryRun; then
		echo "nmap -iL $USERIN -T4 -oA $POST_SCAN_ENUM/$NMAPOUT"
	else
		info "Running nmap on $USERIN"
		nmap -iL $USERIN -T4 -oA $POST_SCAN_ENUM/$NMAPOUT
		info "Finished nmap file saved:$POST_SCAN_ENUM/$NMAPOUT"
	fi
}

function run_fff() {
	local USERIN="$1"
	local FFFOUT="fff-output"
	debug "run_fff($USERIN)"
	if isDryRun; then
		echo "cat $USERIN | fff -d 100 -S -o $POST_SCAN_ENUM/$FFFOUT"
	else
		info "Running fff saving to:$POST_SCAN_ENUM/$FFFOUT"
		cat $USERIN | inscope | fff -d 100 -S -o $POST_SCAN_ENUM/$FFFOUT
	fi
}

# This needs to be reworked to handle multiple domains IE: pass in a files
# Similar to above commands: run_asserfinder_with_file()
function run_sublister() {
	local USERIN="$1"
	local SUBLISTEROUT="sublist3r.$USERIN.out"
	local SUBLIST_OUT="sublister.host.out"
	debug "run_sublister($USERIN)"
	# python3 ~/tools/recon/Sublist3r/sublist3r.py -d netflix.com
	if isDryRun; then
		echo "sublist3r -d $USERIN -o $SCAN_FOLDER/$SUBLISTEROUT"
	else
		info "Running sublist3r -d $USERIN -o $SCAN_FOLDER/$SUBLISTEROUT"
		# python3 ~/tools/recon/Sublist3r/
		sublist3r -d $USERIN -o $SCAN_FOLDER/$SUBLISTEROUT
		info "cat $SCAN_FOLDER/$SUBLISTEROUT | anew $SCAN_FOLDER/$SUBLIST_OUT"
		cat $SCAN_FOLDER/$SUBLISTEROUT | anew $SCAN_FOLDER/$SUBLIST_OUT
	fi
}

## This will run assetfinder with file input just a wrapper function...
## assetfinder $URL
function run_sublister_with_file() {
	local FILEIN="$1"
	debug "run_sublister_with_file($FILEIN)"
	if ! test -f $FILEIN; then
		error "Please enter a correct file, you entered an incorrect file:$FILEIN" 254
	fi
	while IFS= read -r line
	do
		debug "run_sublister_with_file->run_sublister($line)"
		run_sublister "$line"
	done < "$FILEIN"
}

## JS linkfinder 
## RUN on alive hosts so this will need httprobe output.
function run_linkfinder() {
	local USERIN="$1"
	temp="${USERIN#*//}" 	# This removes the http(s)://
	temp="${temp%/}" 		# This removes the trailing /
	local LINKFINDEROUT="$temp.html"
	debug "run_linkfinder($USERIN)"
	if isDryRun; then 
		echo "linkfinder -i $USERIN -d -o $LINKFINDEROUT"
	else
		info "Running linkfinder -i $USERIN -d -o $LINKFINDEROUT"
		linkfinder -i $USERIN -d -o $JS_SCANNING/$LINKFINDEROUT
	fi
}

function run_linkfinder_with_file() {
	local FILEIN="$1"
	debug "run_linkfinder_with_file($FILE)"
	if !test -f $FILEIN; then
		error "Please enter a correct file, you entered an incorrect file:$FILEIN" 254
	fi
	while IFS= read -r line 
	do
		debug "run_linkfinder_with_file($line)"
		run_linkfinder $line
	done < "$FILEIN"
}

function generate_folders() {
	# Top level directories
	SCAN_FOLDER="$OUTPUT_DIR/scans"
	POST_SCAN_ENUM="$OUTPUT_DIR/post-scanning"
	POSSIBLE_OOS_TARGETS="$OUTPUT_DIR/maybe-out-scope"
	TOPFOLDERS="$SCAN_FOLDER $POST_SCAN_ENUM $POSSIBLE_OOS_TARGETS"

	# Sub directories POST SCANNING? / subdomain enum
	ALIVE="$POST_SCAN_ENUM/alive-urls"
	DNSCAN="$POST_SCAN_ENUM/dnmasscan"
	HAKTRAILS="$POST_SCAN_ENUM/haktrails"
	CRAWLING="$POST_SCAN_ENUM/website-crawling"
	WAYBACKURL="$POST_SCAN_ENUM/waybackurls"
	JS_SCANNING="$POST_SCAN_ENUM/js-endpoint-discovery"
	SUBFOLDERS="$ALIVE $DNSCAN $HAKTRAILS $CRAWLING $WAYBACKURL"


	## SCRIPT FILES ##
	tmp_target_list=$(mktemp /tmp/rickjms-recon.XXXXXX)
	# If user passes in both target + user_file we need to combine them and clean them
	TARGET_LIST="$SCAN_FOLDER/temp_target_list.txt" 
	FINAL_TARGETS="$OUTPUT_DIR/$UUIDSHORT-USERTARGETS.txt" # Cleaned target_list file (cleaned with sort -u)

	info "Creating directory structure for recon files"
	# debug "Base directory:$OUTPUT_DIR"
	info "TOPFOLDERS = $TOPFOLDERS"
	for top_path in $TOPFOLDERS; do
		debug "Attempting to create folder:$top_path"
		if test -d "$top_path"; then
			error "Path:$top_path already exists..." 255
		fi
		if isDryRun; then
				echo "mkdir -p $top_path"
				mkdir -p $top_path
		else
			mkdir -p $top_path
			debug "Created directory:$top_path"
		fi
	done

	for sub_folder in $SUBFOLDERS; do
		debug "Attempting to create folder:$sub_folder"
		if test -d "$sub_folder"; then
			error "Path:$sub_folder already exists"
		fi

		if isDryRun; then
			echo "mkdir -p $sub_folder"
		else
			mkdir -p $sub_folder
			debug "Create directory:$sub_folder"
		fi
	done


}

function Usage() {
	echo "Usage:"
	echo -e "\t-h \t\t\t\tDisplay help menu"
	echo -e "\t-f FILENAME \t\tRun recon with file of target domains"
	echo -e "\t-n \t\t\tExecute a dry run listing all the commands executed and tools used"
	echo -e "\t-o PATH/TO/OUTPUT \tChange the output directoy default is current directory"
	echo -e "\t-t USER_TARGET \t\tRun recon against single domain"
	echo -e "\t-s \t\t\tSilent Mode do not post output"
	echo -e "\t-d \t\t\tEnable Debugging mode"
	echo -e "\t-l \t\t\tLIGHT SCAN Mode Only run the quick scans (assetfinder, crt.sh, tls.bufferover.run)"
	echo -e "\t-w \t\t\tSkip the waybackurl lookup."
}

function userInput() {

	if [[ $@ =~ --help ]]; then
		Usage
	fi

	while getopts "hf:no:dt:slw" flag
	do
		case $flag in
			h) 
				Usage
				exit 255;;
			f) 
				USER_FILE="$OPTARG"
				FILE_PASSED="true";;
			n) 
				DRYRUN="true";;
			o)
				OUTPUT_DIR="$OPTARG";;
			t)
				USER_TARGET="$OPTARG"
				info "USER TARGET:$USER_TARGET"
				TARGET_PASSED="true";;
			d)
				ENABLE_DEBUG="true";;
			s)
				SILENT_MODE="true";;
			l) 
				LIGHT_SCAN="true";;
			S)
				INSCOPE_PASSED="true";;
			w)
				SKIPWAYBACK="true";;
			\?)
				Usage
				exit 255;;
		esac
	done
}

# function assetFinderScan() {
# 	local target_url="$1"
# 	info "[+] Harvesting subdomains with assetfinder..."
# 	assetfinder $target_url >> $target_url/recon/assets.txt
# 	info "[-->] Cleaning up assetfinder results with only save results with name:$target_url"
# 	cat $target_url/recon/assets.txt | grep $target_url >> $target_url/recon/final.txt
# 	rm $target_url/recon/assets.txt
# }

# function probAliveDomains() {
# 	local domains_found="$1"
# 	echo "[+] Probing for alive domains..."
# 	cat $domains_found | sort -u | httprobe -s -p https:443 | sed 's/https\?:\/\///' | 
# tr -d ':443' >> $url/recon/httprobe/a.txt
# 	sort -u $url/recon/httprobe/a.txt > $url/recon/httprobe/alive.txt
# 	rm $url/recon/httprobe/a.txt

# }

function init() {
	# Generate folders
	generate_folders
	# Parse user input and get all targets into one file.
	consolidateTargets
}

function consolidateScanInformation() {
	local OUTPUT_FILE="$1"
	local tmp_consolidate_hosts=$(mktemp /tmp/rickjms-recon.XXXXXX)
	warn "Please ensure you have .scope file to ensure youre within scope"
	find $SCAN_FOLDER -iname  "*host.out" | xargs -n1 -I{} sh -c "cat {} | anew $tmp_consolidate_hosts"
	# if inscopePassed; then
	info "Running 'inscope' to ensure targets are inscope"
	info "Saving output to $OUTPUT_FILE"
	cat $tmp_consolidate_hosts | inscope >> $OUTPUT_FILE
	# else
	# 	warn "Its best to use the .scope file to makesure youre within hacker scope"
	# 	cat $tmp_consolidate_hosts >> $OUTPUT_FILE
	# fi
	# xargs -n1 -I{} sh -c 'echo {} | base64 -d
	# find scans/ -iname *.out | xargs -n1 -I{} sh -c 'cat {} >> scans/all.txt'
}
function run_scanners() {
	info "Run all the top level scanners"
	local TARGETS=$FINAL_TARGETS
	
	# LIGHT_SCAN (AKA This is a quick result scan!) 
	run_assetfinder_with_file $TARGETS
	run_crtsh_with_file $TARGETS
	run_tls_bufferover_with_file $TARGETS
	run_subfinder $TARGETS
	run_sublister_with_file $TARGETS

	# This file will be all the *.host.out files cat >> $ALL_HOST_DATA 
	# allowing us to run tools against this to find extra stuff
	# tools: httprobe(alive.out), dnmasscan(jason_haddix tip: pull ips and services then run `nmap IP`) 
	ALL_HOST_DATA="$SCAN_FOLDER/webaddress_scan_data.host.out"
	consolidateScanInformation "$ALL_HOST_DATA"
	
	if isLightScan; then
		if skipWaybackUrl; then
			info "Skipping waybackurls function call"
		else
			info "Running waybackurls this might take up space depending on that program..."
			run_waybackurls $TARGETS
		fi
		exit 0
	fi

	# POST SCANNING
	# We now need to enumerate all the scan_data
	# dnmasscan
	info "Running httprobe This might take awhile please be patient..."
	run_httprobe $ALL_HOST_DATA
	# run_dnmasscan $ALL_HOST_DATA

	# Run extra stuff on the 'alive data' that httprobe gives us.
	# Find forms and put in a seperate file for "TESTING input vulns manually"

	### TOOLS ###
	## hakrawler
	# cat FILE | hakrawler -plain -forms >> 
	# cat FILE | hakrawler -plain -plain -all >>
	## SubDomainizer.py
	# python3 SubDomainizer.py -u https://www.example.com -o output.txt
	# python3 SubDomainizer.py -l list.txt
	# 
	ALIVE_HOSTS="$ALIVE/$CLEANHTTPROBE"
	PROBOUTPUT="$ALIVE/$HTTPROBEOUT"
	
	# Subdomain script doesnt work well i am commenting it out!
	# run_subdomainizer $ALIVE_HOSTS
	run_hakrawler $ALIVE_HOSTS
	run_haktrails $ALIVE_HOSTS
	if skipWaybackUrl; then
		info "Skipping waybackurls function call"
	else
		info "Running waybackurls this might take up space depending on that program..."
		run_waybackurls $ALIVE_HOSTS
	fi
	run_subjack $ALIVE_HOSTS
	run_nmap $ALIVE_HOSTS
	run_fff $PROBOUTPUT
	info "RUNNING NEW FEATURES MIGHT BREAK!"
	run_linkfinder_with_file $PROBOUTPUT

	# FILES WE ARE DEALING WITH:
	# scans/assetfinder.out :: TOOLS: dnmasscan, httprobe, 
	# scans/crtsh.out :: TOOLS: dnmasscan, httprobe,
	# scans/tls_bufferover.out :: TOOLS: Clean Data and only show ip :: nmap, masscan?
	# scans/hosts-amass.out :: TOOLS: dnmasscan, httprobe
	# scans/ips-amass.out :: TOOLS: nmap

	##### FIND APIS in all the output for kiterunner #####
	# grep -i "api" -R $SCAN_FOLDER >> $ALIVE/alive-apis.out
	# Run kiterunner `kr scan api.example.com -w ~/tools/word_lists/routes-large.kite --delay 5s -x 10  
	# --ignore-length=34 | tee api.example.com-kr.output`

	if targetPassed; then
		info "Passed in -t running amass on $USER_TARGET"
		run_amass $USER_TARGET
	else
		info "amass will only be executed on -t passed value since it takes for god damn ever to run..."
	fi
	info "To get a complete run on this script please run amass below adjust the "
	echo "amass enum -max-dns-queries 2 -o amass.out -src -ip -df $FINAL_TARGETS -brute -config ~/.config/amass/config.ini -active"
	echo "sudo dnmasscan $ALL_HOST_DATA $DNSCAN/dnmasscan.out -p$PORTS_TO_SCAN -oG $DNSCAN/masscan.out"
} 

function activate_python_venv() {
	source $BASEDIR/bin/activate
}

## MAIN METHOD ##
activate_python_venv
userInput $@
init
run_scanners
## This will run all the scanner functions ##
