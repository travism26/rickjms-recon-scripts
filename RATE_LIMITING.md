# Rate Limiting Configuration for Bug Bounty Programs

This document outlines the rate limiting configurations implemented to ensure responsible scanning during bug bounty testing. These settings are designed to prevent overwhelming target servers and avoid triggering security alerts or denial of service conditions.

## Global Settings Modified

The following global settings have been adjusted in `config/settings.sh`:

```bash
# Reduced concurrent connections
HTTPROBE_CONCURRENT=30         # Reduced from 60
SUBFINDER_THREADS=50           # Reduced from 100
SUBJACK_THREADS=50             # Reduced from 100
FFF_DEPTH=50                   # Reduced from 100
```

## Nmap Scan Configuration

Nmap scan settings in `src/scanners/active/nmap.sh` have been modified to use more conservative timing:

1. Changed timing template from T4 to T3 (more conservative)
2. Reduced scan rate:
   - Fast scan: `--min-rate=500` (reduced from 1000)
   - Detailed scan: Added `--max-rate=300` and reduced version intensity

## HTTP Probing Configuration

HTTP probing settings in `src/scanners/active/http_probe.sh` have been adjusted:

1. httpx:

   - Reduced threads from 50 to 25
   - Reduced rate limit from 150 to 50 requests per second

2. httprobe:
   - Added timeout parameter `-t 10000` (10 seconds)
   - Using reduced concurrent connections from global settings

## Web Crawling Configuration

Web crawling settings in `src/scanners/active/crawler.sh` have been modified:

1. hakrawler:
   - Reduced crawl depth from 3 to 2
   - Added thread limiting `-t 10` to control concurrent requests

## API Rate Limits

API rate limits in `src/scanners/api/rate_limiting.sh` have been updated:

| API/Service    | Rate Limit (requests/minute) | Notes                    |
| -------------- | ---------------------------- | ------------------------ |
| tls_bufferover | 30                           | Reduced from 60          |
| crtsh          | 30                           | Reduced from 60          |
| wayback        | 50                           | Reduced from 100         |
| httpx          | 50                           | New limit                |
| httprobe       | 30                           | New limit                |
| hakrawler      | 20                           | New limit                |
| subfinder      | 30                           | New limit                |
| assetfinder    | 30                           | New limit                |
| amass          | 20                           | New limit                |
| google         | 10                           | Removed - see note below |

> **Note about Google Dorks**: Rate limiting for Google dorks has been removed since the script doesn't actually make HTTP requests to Google. It only generates search URLs for manual investigation, so rate limiting was unnecessary.

## Running with Additional Rate Limiting

For even more conservative scanning, you can:

1. Use the light scan mode:

   ```bash
   ./rickjms-recon.sh -f shopify.scope -o shopify_recon -l
   ```

2. Skip wayback URL lookups (which can be intensive):

   ```bash
   ./rickjms-recon.sh -f shopify.scope -o shopify_recon -w
   ```

3. Run in debug mode to see rate limiting in action:
   ```bash
   ./rickjms-recon.sh -f shopify.scope -o shopify_recon -d
   ```

## Further Customization

You can further adjust rate limits by modifying:

1. `src/scanners/api/rate_limiting.sh` - API-specific rate limits
2. `config/settings.sh` - Global concurrency settings
3. Individual scanner files for tool-specific parameters

Remember that responsible scanning is essential for bug bounty programs. Always prioritize being a good citizen over speed of reconnaissance.
