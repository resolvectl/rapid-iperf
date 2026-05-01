# rapid-iperf

Bash script tool for running iperf3 network tests with automatic server selection based on latency 

## Features
- Automatically downloads iperf3 public servers
- Latency-based iperf3 server selection
- Interactive navigation using ```fzf```
- Favourite servers feature

## Available regions
- Russia
- Europe
- Asia
- North America
- South America
- Oceania
- Africa

## Usage
```bash
./iperf.sh           
```

## Todo
- [x] Region selection
- [x] Automatic install of dependencies
- [X] Favourite servers

## Dependencies
- iperf3
- fzf
- jq
- yq
- fping
- curl

## Notes

Still WIP
