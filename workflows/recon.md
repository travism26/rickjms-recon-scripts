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
```

### Nmap Scan

```bash
nmap -iL unique_subdomains.txt -p- -sV --top-ports 1000 --open -oN nmap.txt
```
