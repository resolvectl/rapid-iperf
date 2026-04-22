#!/usr/bin/env bash

set -uo pipefail

FILENAME=$(basename "$0")

function usage()
{
    cat << EOU >&2
$FILENAME Usage:

$FILENAME --help            Display help
$FILENAME --fetch           Fetch newest iperf3 servers 
EOU
}

function check_requirements {
    for cmd in jq fping iperf3 curl; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Failed to start. '$cmd' required to executte script." >&2
        exit 1
    fi
done
}

function run_iperf_test {
    cmd=$(cat iperf/iperf_servers.json | jq -r '.[] | select(.CONTINENT=="Europe")."IP/HOST"+"|"+."PORT"+"|"+."SITE"+"|"+."COUNTRY"+"|"+."PROVIDER"')
    servers=$(echo "$cmd" | cut -d'|' -f1)
    total=$(echo "$servers" | wc -l)
    echo "$total servers saved. Running tests ..." 

    best_ip=$(fping -e -q -C 1 -r 0 -B 1 -4 -t 300 "$servers" 2>&1 \
        | awk '$3 > 0 {print $1, int($3)}' \
        | sort -k2 -n \
        | head -1 )
    formatted_ip=$(awk '{print $1}' <<< "$best_ip")
    ping=$(awk '{print $2}' <<< "$best_ip")
    best_server=$(grep "^${formatted_ip}|" <<< "$cmd")    
    IFS='|' read -r host port city country provider <<< "$best_server"

    echo "Best server: $host $ping ms $provider ($city, $country)"
    echo "Starting iperf test ..."
    iperf3 -c "$host" -p "$port" -P1
}

function fetch_iperf {
    echo "Obtaining newest iperf3 servers ..."
    curl https://export.iperf3serverlist.net/listed_iperf3_servers.json > iperf/new_iperf_servers.json \
    && mv iperf/new_iperf_servers.json iperf/iperf_servers.json \
    || echo "Failed to fetch newest iperf servers"

}

function execute {
    if [[ ! -d iperf ]]; then
        mkdir "iperf"
    fi
    if [[ -f iperf/iperf_servers.json ]]; then
        run_iperf_test
    else
        fetch_iperf && execute
    fi
}

while true
do
	case "${@}" in
		-h | --help)
			usage
			exit 0
			;;
        --fetch)
            fetch_iperf
            exit 0
            ;; 
		*)
            check_requirements && execute
            exit 0
			;;
	esac
done 
