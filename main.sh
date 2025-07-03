#!/bin/bash
if [[ "$EUID" -ne 0 ]]; then
    echo -e "\033[1;31mError:\033[0m This script requires root privileges. Please run with 'sudo' or as root user."
    exit 1
fi

NEW_SSH_PORT="64999"

block_ICMP() {
    sed -i '/net.ipv4.icmp_echo_ignore_all/d' /etc/sysctl.conf
    sed -i '/net.ipv4.icmp_echo_ignore_broadcasts/d' /etc/sysctl.conf
    echo "net.ipv4.icmp_echo_ignore_all = 1" >> /etc/sysctl.conf
    echo "net.ipv4.icmp_echo_ignore_broadcasts = 1" >> /etc/sysctl.conf
    sysctl -p >/dev/null
}

change_ssh_port_and_firewall() {
    local target_port="$1"
    SSHD_CONFIG_FILE="/etc/ssh/sshd_config"

    echo -e "\n\033[1;34m=== SSH Port Configuration ===\033[0m"
    echo -e "Updating SSH port to \033[1;33m$target_port\033[0m..."

    # Check if system is using systemd socket activation
    if systemctl is-active ssh.socket >/dev/null 2>&1; then
        echo -e "Detected systemd socket activation for SSH. Configuring socket..."
        mkdir -p /etc/systemd/system/ssh.socket.d/
        OVERRIDE_FILE="/etc/systemd/system/ssh.socket.d/override.conf"
        {
            echo "[Socket]"
            echo "ListenStream="
            echo "ListenStream=$target_port"
        } > "$OVERRIDE_FILE"
        systemctl daemon-reload
        systemctl restart ssh.socket
        echo -e "\033[1;32m✔ Success:\033[0m SSH socket reconfigured to listen on port $target_port."

        # Comment out Port in sshd_config if present
        if grep -qE '^[[:space:]]*Port[[:space:]]+[0-9]+' "$SSHD_CONFIG_FILE"; then
            sed -i -E 's/^([[:space:]]*Port[[:space:]]+[0-9]+)/# \1/' "$SSHD_CONFIG_FILE"
            echo -e "\033[1;33m⚠ Notice:\033[0m Commented out Port directive in $SSHD_CONFIG_FILE."
        fi
    else
        # Modify sshd_config for non-systemd systems
        if grep -qE '^#?[[:space:]]*Port[[:space:]]*[0-9]+' "$SSHD_CONFIG_FILE"; then
            sed -i -E "s/^#?[[:space:]]*Port[[:space:]]*[0-9]+/Port $target_port/" "$SSHD_CONFIG_FILE"
        else
            echo -e "\nPort $target_port" >> "$SSHD_CONFIG_FILE"
        fi

        # Restart SSH service
        echo -e "\n\033[1;34m=== Service Restart ===\033[0m"
        if systemctl restart ssh.service; then
            echo -e "\033[1;32m✔ Success:\033[0m SSH service restarted (using ssh.service)"
        elif systemctl restart sshd.service; then
            echo -e "\033[1;32m✔ Success:\033[0m SSH service restarted (using sshd.service)"
        else
            echo -e "\033[1;31m✖ Critical Error:\033[0m Failed to restart SSH service!"
            echo -e "  - The SSH port was changed to $target_port in configuration"
            echo -e "  - Manual intervention required: Check service status with:"
            echo -e "    'systemctl status ssh' or 'systemctl status sshd'"
        fi
    fi

    ufw allow "$target_port/tcp"
    ufw reload
    echo -e "\033[1;32m✔ Complete:\033[0m Firewall updated for new SSH port \033[1;33m$target_port\033[0m"
}

remove_configurations() {
    sed -i '/net.ipv4.icmp_echo_ignore_all/d' /etc/sysctl.conf
    sed -i '/net.ipv4.icmp_echo_ignore_broadcasts/d' /etc/sysctl.conf
    echo "net.ipv4.icmp_echo_ignore_all = 0" >> /etc/sysctl.conf
    echo "net.ipv4.icmp_echo_ignore_broadcasts = 0" >> /etc/sysctl.conf
    sysctl -p >/dev/null
    echo -e "\033[1;32m✔ ICMP Settings:\033[0m Echo requests are now allowed"
}

block_ip_ranges() {
    bash <(curl -LS https://raw.githubusercontent.com/xmohammad1/linux_security/refs/heads/main/ip.sh) 1
}

white_list_ip() {
    bash <(curl -LS https://raw.githubusercontent.com/xmohammad1/linux_security/refs/heads/main/ip.sh) 2
}

ip_manager_script() {
    bash <(curl -LS https://raw.githubusercontent.com/xmohammad1/linux_security/refs/heads/main/ip.sh)
}

menu() {
    while true; do
        echo -e "\n\033[1;36m==========[ Security Configuration Menu ]==========\033[0m"
        echo -e "  \033[1;37m1)\033[0m Apply Security Hardening (ICMP & IP Ranges)"
        echo -e "  \033[1;37m2)\033[0m Restore Default Configurations"
        echo -e "  \033[1;37m3)\033[0m Whitelist IP Address/Range"
        echo -e "  \033[1;37m4)\033[0m IP Blocking Rules Manager"
        echo -e "  \033[1;37m9)\033[0m Exit"
        echo -e "\033[1;36m==================================================\033[0m"
        
        read -p "  Enter menu option [1-9]: " choice
        
        case $choice in
            1)
                echo -e "\n\033[1;35m=== Applying System Hardening ===\033[0m"
                read -p "do you want to change ssh port? [y/N] " answer1
                case "$answer1" in
                  [Yy]* )
                    change_ssh_port_and_firewall "$NEW_SSH_PORT"
                    ;;
                  * )
                    echo "Aborted."
                    ;;
                esac
                read -p "do you want to run block_ICMP? [y/N] " answer
                
                case "$answer" in
                  [Yy]* )
                    echo "Blocking ICMP…"
                    block_ICMP
                    ;;
                  * )
                    echo "Aborted."
                    ;;
                esac
                block_ip_ranges
                echo -e "\n\033[1;32m=== Hardening Complete ===\033[0m"
                echo -e "All security configurations applied successfully"
                echo -e "\033[1;33mImportant Notice:\033[0m New SSH port is \033[1;33m$NEW_SSH_PORT\033[0m"
                echo -e "  - Ensure you use this port for future SSH connections"
                exit 0
                ;;
            2)
                remove_configurations
                echo -e "\033[1;32m✔ Defaults Restored:\033[0m Security configurations removed"
                exit 1
                ;;
            3)
                white_list_ip
                exit 1
                ;;
            4)
                ip_manager_script
                ;;
            9)
                echo -e "\nExiting configuration menu..."
                exit 0
                ;;
            *)
                echo -e "\033[1;31m✖ Invalid Input:\033[0m Please select a valid menu option (1-9)"
                ;;
        esac
    done
}

menu
