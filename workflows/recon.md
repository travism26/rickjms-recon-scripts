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

## Shodan Scan

```bash
shodan search --csv $1 > shodan.csv
```

### Nmap Scan

```bash
nmap -iL unique_subdomains.txt -p- -sV --top-ports 1000 --open -oN nmap.txt
```
