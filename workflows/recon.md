# Recon Workflow (WIP)

## Initial Recon

### Subdomain Enumeration

```bash
./scripts/crt.sh $1 > subdomains.txt
subfinder -d $1 -silent -all >> subdomains.txt
# Sort and remove duplicates
cat subdomains.txt | rev | cut -d "." -f 1,2 | rev | sort -u > unique_subdomains.txt
subfinder -dL unique_subdomains.txt -silent -all >> subdomains.txt
```

## Shodan

Some examples of how to use shodan to find interesting things.

### Examples still need to decide on the best way to do this

```bash
shodan search "hostname:ibm.com port:8080" # search for port 8080
shodan search "hostname:ibm.com \!port:8080" # exclude port 8080
shodan search "hostname:ibm.com \!port:443,21,8080" # exclude common ports
shodan search "hostname:ibm.com product:nginx" # search for nginx
shodan search "hostname:ibm.com product:tomcat" # search for tomcat
shodan search "hostname:ibm.com product:jboss" # search for jboss
shodan search "hostname:ibm.com product:weblogic" # search for weblogic
shodan search "hostname:ibm.com product:websphere" # search for websphere
# Extract a field
shodan search "hostname:ibm.com product:nginx" --fields ip_str,isp,location,org,os,product,timestamp
```

## Httpx

### Examples still need to decide on the best way to do this

```bash
# nahamsec command?
httpx -l paypal-subdomains.txt -cl -sc -location -favicon -title -ip -tech-detect -ports 80,443,8080,8443,8000 -probe-all-ips -o paypal-httpx.txt -follow-redirects
httpx -l subdomains.txt -o httpx.txt
httpx -l subdomains.txt -o httpx.txt -status-code
httpx -l subdomains.txt -o httpx.txt -title
httpx -l subdomains.txt -o httpx.txt -status-code -title
httpx -l subdomains.txt -o httpx.txt -status-code -title -ip
httpx -l subdomains.txt -o httpx.txt -status-code -title -ip -content-length

```

### Nmap Scan

```bash
nmap -iL unique_subdomains.txt -p- -sV --top-ports 1000 --open -oN nmap.txt
```
