# rapid-iperf

Script to run iperf3 tests. Currently WIP

## Features
- Automatically downloads iperf3 public servers
- Latency-based iperf3 server selection

## Usage
```bash
./iperf.sh           

./iperf.sh --help            Display help
./iperf.sh --fetch           Fetch newest iperf3 servers 
```

## Todo
- Region selection
- Automatic install of dependencies

## Dependencies
- iperf3
- jq
- fping
- curl
