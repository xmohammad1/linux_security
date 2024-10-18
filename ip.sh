#!/bin/bash

# Script to block specified IP ranges and optionally whitelist a single IP or range.
# Provides a professional menu interface with coloring and robust error handling.
# Automatically installs or upgrades required packages.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# List of IP ranges to block
IP_RANGES=(
    "10.0.0.0/8"
    "100.64.0.0/10"
    "169.254.0.0/16"
    "172.16.0.0/12"
    "192.0.0.0/24"
    "192.0.2.0/24"
    "192.88.99.0/24"
    "192.168.0.0/16"
    "198.18.0.0/15"
    "198.51.100.0/24"
    "203.0.113.0/24"
    "240.0.0.0/24"
    "224.0.0.0/4"
    "233.252.0.0/24"
    "102.0.0.0/8"
    "185.235.86.0/24"
    "185.235.87.0/24"
    "114.208.187.0/24"
    "216.218.185.0/24"
    "206.191.152.0/24"
    "45.14.174.0/24"
    "195.137.167.0/24"
    "103.58.50.1/24"
    "25.11.10.0/24"
)

# Function to check and install required packages
check_requirements() {
    REQUIRED_PKG="iptables"

    if ! command -v iptables &>/dev/null; then
        echo -e "${YELLOW}iptables is not installed. Installing...${NC}"
        if [ -x "$(command -v apt-get)" ]; then
            sudo apt-get update
            sudo apt-get install -y iptables
        elif [ -x "$(command -v yum)" ]; then
            sudo yum install -y iptables
        else
            echo -e "${RED}Package manager not found. Please install iptables manually.${NC}"
            exit 1
        fi
        echo -e "${GREEN}iptables installed successfully.${NC}"
    else
        echo -e "${GREEN}iptables is already installed.${NC}"
    fi
}

# Function to validate IP address or CIDR notation
validate_ip_range() {
    local ip_range="$1"
    if [[ $ip_range =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(/([0-9]|[1-2][0-9]|3[0-2]))?$ ]]; then
        # Split IP and prefix length
        IFS='/' read -r ip prefix <<< "$ip_range"
        # Validate each octet
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if ((octet < 0 || octet > 255)); then
                echo -e "${RED}Invalid IP address: $ip_range${NC}"
                return 1
            fi
        done
        return 0
    else
        echo -e "${RED}Invalid IP address or CIDR notation: $ip_range${NC}"
        return 1
    fi
}

# Function to block an IP range
block_ip_range() {
    local ip_range="$1"

    # Validate IP range
    if ! validate_ip_range "$ip_range"; then
        return 1
    fi

    # Block incoming traffic
    if ! iptables -C INPUT -s "$ip_range" -j DROP &>/dev/null; then
        iptables -I INPUT -s "$ip_range" -j DROP
        echo -e "${GREEN}Blocked incoming traffic from $ip_range${NC}"
    else
        echo -e "${YELLOW}Incoming traffic from $ip_range is already blocked.${NC}"
    fi

    # Block forwarded traffic
    if ! iptables -C FORWARD -s "$ip_range" -j DROP &>/dev/null; then
        iptables -I FORWARD -s "$ip_range" -j DROP
        echo -e "${GREEN}Blocked forwarded traffic from $ip_range${NC}"
    else
        echo -e "${YELLOW}Forwarded traffic from $ip_range is already blocked.${NC}"
    fi

    # Block outgoing traffic
    if ! iptables -C OUTPUT -d "$ip_range" -j DROP &>/dev/null; then
        iptables -I OUTPUT -d "$ip_range" -j DROP
        echo -e "${GREEN}Blocked outgoing traffic to $ip_range${NC}"
    else
        echo -e "${YELLOW}Outgoing traffic to $ip_range is already blocked.${NC}"
    fi
}

# Function to whitelist an IP or IP range
whitelist_ip_range() {
    local ip_range="$1"

    # Validate IP range
    if ! validate_ip_range "$ip_range"; then
        return 1
    fi

    # Allow incoming traffic
    if ! iptables -C INPUT -s "$ip_range" -j ACCEPT &>/dev/null; then
        iptables -I INPUT -s "$ip_range" -j ACCEPT
        echo -e "${GREEN}Whitelisted incoming traffic from $ip_range${NC}"
    else
        echo -e "${YELLOW}Incoming traffic from $ip_range is already whitelisted.${NC}"
    fi

    # Allow forwarded traffic
    if ! iptables -C FORWARD -s "$ip_range" -j ACCEPT &>/dev/null; then
        iptables -I FORWARD -s "$ip_range" -j ACCEPT
        echo -e "${GREEN}Whitelisted forwarded traffic from $ip_range${NC}"
    else
        echo -e "${YELLOW}Forwarded traffic from $ip_range is already whitelisted.${NC}"
    fi

    # Allow outgoing traffic
    if ! iptables -C OUTPUT -d "$ip_range" -j ACCEPT &>/dev/null; then
        iptables -I OUTPUT -d "$ip_range" -j ACCEPT
        echo -e "${GREEN}Whitelisted outgoing traffic to $ip_range${NC}"
    else
        echo -e "${YELLOW}Outgoing traffic to $ip_range is already whitelisted.${NC}"
    fi
}

# Function to display the menu
show_menu() {
    clear
    echo -e "${CYAN}"
    echo "======================================="
    echo "          IP Blocker Firewall          "
    echo "======================================="
    echo -e "${NC}"
    echo -e "${GREEN}1.${NC} Block predefined IP ranges"
    echo -e "${GREEN}2.${NC} Whitelist an IP or range"
    echo -e "${GREEN}3.${NC} View current iptables rules"
    echo -e "${GREEN}4.${NC} Exit"
    echo
}

# Function to handle menu selection
handle_menu_choice() {
    local choice="$1"
    case $choice in
        1)
            echo -e "${BLUE}Blocking predefined IP ranges...${NC}"
            for ip_range in "${IP_RANGES[@]}"; do
                block_ip_range "$ip_range" || continue
            done
            echo -e "${GREEN}All predefined IP ranges have been blocked.${NC}"
            ;;
        2)
            while true; do
                read -rp "Enter the IP or IP range to whitelist (e.g., 192.168.1.0/24): " whitelist_ip
                if [ -z "$whitelist_ip" ]; then
                    echo -e "${RED}No IP address or range entered. Please try again.${NC}"
                else
                    if whitelist_ip_range "$whitelist_ip"; then
                        break
                    else
                        echo -e "${YELLOW}Please enter a valid IP address or CIDR notation.${NC}"
                    fi
                fi
            done
            ;;
        3)
            echo -e "${BLUE}Current iptables rules:${NC}"
            iptables -L -n -v --line-numbers | less
            ;;
        4)
            echo -e "${BLUE}Exiting the script.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please select a number between 1 and 4.${NC}"
            ;;
    esac
    echo -e "${YELLOW}Press Enter to return to the menu...${NC}"
    read -r
}

# Check for superuser privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run the script as root or use sudo.${NC}"
    exit 1
fi

# Main script execution
check_requirements

if [ -n "$1" ]; then
    choice="$1"
    clear
    handle_menu_choice "$choice"
else
    while true; do
        show_menu
        read -rp "Please choose an option [1-4]: " choice
        echo
        handle_menu_choice "$choice"
    done
fi
