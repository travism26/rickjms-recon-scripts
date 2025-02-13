# rickjms-recon-scripts

A collection of advanced reconnaissance scripts for security research and bug bounty hunting.

## Main Features

- Modular architecture with separate components for different scanning functionalities
- Comprehensive passive and active reconnaissance capabilities
- Rate limiting and error handling for API interactions
- Detailed reporting with Markdown and HTML output
- Progress monitoring and statistics for long-running scans
- Configurable scan intensity (light vs full scan modes)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/rickjms/rickjms-recon-scripts.git
cd rickjms-recon-scripts
```

2. Install required tools:
```bash
./install-rickjms-tools.sh
```

## Required Tools

The following tools are required for full functionality:

- assetfinder
- amass
- subfinder
- httpx
- httprobe
- hakrawler
- SubDomainizer
- dnmasscan
- waybackurls
- subjack
- nmap
- fff
- linkfinder
- pandoc (optional, for HTML report generation)

## Usage

```bash
./rickjms-recon.sh [options]

Options:
  -h                    Display help menu
  -f FILENAME          Run recon with file of target domains
  -n                   Execute a dry run listing all commands executed
  -o PATH/TO/OUTPUT    Change the output directory (default: current directory)
  -t USER_TARGET       Run recon against single domain
  -s                   Silent Mode (suppress output)
  -d                   Enable Debugging mode
  -l                   Light scan mode (quick scans only)
  -w                   Skip waybackurl lookup
```

## Examples

1. Scan a single domain:
```bash
./rickjms-recon.sh -t example.com
```

2. Scan multiple domains from a file:
```bash
./rickjms-recon.sh -f domains.txt
```

3. Run a light scan with custom output directory:
```bash
./rickjms-recon.sh -t example.com -l -o /path/to/output
```

## Output Structure

The script creates the following directory structure for scan results:

```
output_dir/
├── scans/                    # Raw scan outputs
├── post-scanning/            # Post-processing results
│   ├── subdomains/          # Discovered subdomains
│   ├── dnmasscan/           # DNS/port scanning results
│   ├── haktrails/           # Hakrawler results
│   ├── website-crawling/    # Web crawling data
│   ├── waybackurls/         # Wayback Machine data
│   └── js-endpoint-discovery/ # JavaScript analysis
└── maybe-out-scope/         # Potentially out-of-scope targets
```

## Features

### Passive Reconnaissance
- Certificate Transparency scanning (crt.sh)
- TLS Bufferover data collection
- Wayback Machine URL discovery
- Rate-limited API interactions

### Active Reconnaissance
- Port scanning with Nmap (adaptive scan based on target count)
- HTTP service detection with httpx and httprobe
- Web crawling with hakrawler
- JavaScript analysis with SubDomainizer

### Reporting
- Comprehensive Markdown reports
- Optional HTML report generation
- Detailed statistics and findings
- Security concern highlighting

## Architecture

The script is organized into modular components:

```
.
├── config/                 # Configuration files
│   └── settings.sh        # Global settings and variables
├── src/
│   ├── core/              # Core functionality
│   │   ├── logging.sh     # Logging functions
│   │   ├── validation.sh  # Input validation
│   │   └── utils.sh       # Utility functions
│   ├── scanners/          # Scanner modules
│   │   ├── active/        # Active reconnaissance
│   │   ├── passive/       # Passive reconnaissance
│   │   └── api/           # API interaction
│   └── reporting/         # Report generation
└── rickjms-recon.sh       # Main script
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Thanks to all the creators of the tools used in this script
- Inspired by various reconnaissance methodologies and tools in the security community
