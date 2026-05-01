#!/usr/bin/env bash

set -euo pipefail

fzf_header=$(cat << EOU
rapid-iperf
Bash script tool for running iperf3 network tests with automatic server selection based on latency

EOU
)

declare regions=("Russia" "Europe" "Asia" "North America" "South America" "Oceania" "Africa")
declare menu_options=("Run test (select region)" "Test favourite servers" "Fetch newest iperf lists" "Quit")

function detect_os {
    if [[ -f /etc/debian-release ]]; then
        echo "debian"
    elif [[ -f /etc/redhat-release || -f /etc/centos-release ]]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

function check_requirements {
        local required_packages=("fzf" "jq" "yq" "fping" "iperf3" "curl")
        local missing_packages=()

        os_type=$(detect_os)

        for cmd in "${required_packages[@]}"; do
            if ! command -v "$cmd" &> /dev/null; then
                missing_packages+=("$cmd")
            fi
        done
        if ((${#missing_packages[@]})); then
            case "$os_type" in
            debian)
                sudo apt install "${missing_packages[@]}" -y && menu || exit 1
                ;;
            rhel)
                sudo dnf install -y "${missing_packages[@]}" && menu || exit 1
                ;;
            *)
                echo "Failed to install: Unknown OS. Install requirements manually" || exit 1
                ;;            
            esac  
        fi
}

function run_test {
    host=$1
    port=$2
    if iperf3 -c "$host" -p "$port" -P1; then
        found=false
        while IFS='|' read -r fav_host; do
            if [[ "$fav_host" == "$host" ]]; then
                found=true
                break
            fi
        done < iperf/favourite.txt
        if ! $found; then
            read -r -p "Save this server to favourites? [y/N]: " answer
            if [[ "$answer" =~ ^[Yy] ]]; then
                echo "$best_server" >> iperf/favourite.txt
                return
            else
                menu
            fi
        fi
    else 
        echo "Failed to start iperf3 test."
    fi
    read -n 1 -s -r -p "Press any key to continue ..."
    menu

}

function select_favourite {
    choose=$({ while IFS='|' read -r host port city country isp; do
        echo "$host $port $isp ($city, $country)"
    done < iperf/favourite.txt
    echo "Back";  } | fzf --header "$fzf_header" --layout=reverse) || menu
    if [[ $choose == "Back" ]]; then
        menu
    fi
    host=$(printf "%s\n" "$choose" | awk -F ' ' '{print $1}')
    port=$(printf "%s\n" "$choose" | awk -F ' ' '{print $2}')
    
    run_test "$host" "$port"

}

function fetch_iperf {
    mkdir -p iperf
    if curl https://export.iperf3serverlist.net/listed_iperf3_servers.json -o iperf/new_iperf_servers.json; then
        mv iperf/new_iperf_servers.json iperf/iperf_servers.json
    else
        echo "Failed to reach https://export.iperf3serverlist.net/listed_iperf3_servers.json"
        read -n 1 -s -r -p "Press any key to continue ..."
    fi
    if curl https://raw.githubusercontent.com/itdoginfo/russian-iperf3-servers/refs/heads/main/list.yml -o iperf/new_ru_iperf.yml; then
        mv iperf/new_ru_iperf.yml iperf/ru_iperf.yaml
    else
        echo "Failed to reach https://raw.githubusercontent.com/itdoginfo/russian-iperf3-servers/refs/heads/main/list.yml"
        read -n 1 -s -r -p "Press any key to continue ..."
    fi
    menu
}

function find_best_server  {
    cmd=$1
    servers=$(echo "$cmd" | cut -d'|' -f1)
    total=$(echo "$servers" | wc -l)
    echo "$total servers fetched. testing ..." 
    best_ip=$(
        (echo "$servers" | xargs -r fping -e -q -C 1 -r 0 -B 1 -4 -t 300 2>&1 || true) \
        | awk '$3 > 0 {print $1, int($3)}' \
        | sort -k2 -n \
        | head -1)
    formatted_ip=$(awk '{print $1}' <<< "$best_ip")
    ping=$(awk '{print $2}' <<< "$best_ip")
    best_server=$(grep "^${formatted_ip}|" <<< "$cmd")    
    IFS='|' read -r host port city country isp <<< "$best_server"
    echo "Best server: $host $ping ms $isp ($city, $country)"
    echo "Starting iperf test ..."

    run_test "$host" "$port"
}

function choose_region {
    choose=$(printf "%s\n" "${regions[@]}" | fzf --header "$fzf_header" --layout=reverse ) || menu
    if [[ $choose == "Russia" ]]; then
        if cmd=$(yq '.[] | "\(.address)|\(.port)|\(.City)|RU|\(.Name)"' iperf/ru_iperf.yaml); then
            find_best_server "$cmd"
        else
            read -n 1 -s -r -p "Fetch servers first. Press any key to continue ..."
            menu
        fi

    else
        if cmd=$(cat iperf/iperf_servers.json | jq -r --arg choose "$choose" \
        '.[] | select(.CONTINENT == $choose)."IP/HOST"+"|"+."PORT"+"|"+."SITE"+"|"+."COUNTRY"+"|"+."PROVIDER"'); then
            find_best_server "$cmd"
        else
            read -n 1 -s -r -p "Fetch servers first. Press any key to continue ..."
            menu 
        fi
    fi
}

function menu {
    choose=$(printf "%s\n" "${menu_options[@]}" | fzf --header "$fzf_header" --layout=reverse)
    case $choose in
        "Run test (select region)")
            choose_region
            ;;
        "Test favourite servers")
            select_favourite
            ;;
        "Fetch newest iperf lists")
            fetch_iperf
            ;;
        "Quit")
            exit 1
            ;;
        *)
            ;;
    esac
}

check_requirements && menu
