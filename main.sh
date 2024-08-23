#!/bin/bash
# Ensure the script is run as root
if [[ "$EUID" -ne 0 ]]; then
    echo "Please run as root."
    exit 1
fi
block_ICMP() {
    # Remove any existing line with 'net.ipv4.icmp_echo_ignore_all'
    sed -i '/net.ipv4.icmp_echo_ignore_all/d' /etc/sysctl.conf
    sed -i '/net.ipv4.icmp_echo_ignore_broadcasts/d' /etc/sysctl.conf
    # Add the new line to block ICMP (ping) requests
    echo "net.ipv4.icmp_echo_ignore_all = 1" >> /etc/sysctl.conf
    echo "net.ipv4.icmp_echo_ignore_broadcasts = 1" >> /etc/sysctl.conf
    sysctl -p
}
change_ssh_port() {
    SSHD_CONFIG_FILE="/etc/ssh/sshd_config"

    # Try to replace an existing Port line, if it exists
    if grep -qE '^#?[[:space:]]*Port[[:space:]]*[0-9]+' "$SSHD_CONFIG_FILE"; then
        sed -i -E 's/^#?[[:space:]]*Port[[:space:]]*[0-9]+/Port 64999/' "$SSHD_CONFIG_FILE"
    else
        # If no Port line exists, append a new Port line
        echo "Port 64999" >> "$SSHD_CONFIG_FILE"
    fi
    systemctl restart sshd
    ufw allow 64999
    echo "SSH Port has been updated to Port 64999"
}
fail2ban() {
    apt-get install -y fail2ban
    # Configure SSH protection
    cat <<EOT > /etc/fail2ban/jail.local
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOT

    # Restart Fail2Ban to apply configurations
    systemctl restart fail2ban
    systemctl enable fail2ban
}

remove_configurations() {
    # Remove the Fail2Ban package and its configurations
    systemctl stop fail2ban
    systemctl disable fail2ban
    apt-get remove --purge -y fail2ban
    rm -f /etc/fail2ban/jail.local
    echo "Fail2Ban and its configurations have been removed."

    # Remove UDP block rule
    iptables -D INPUT -p udp -j DROP
    iptables-save > /etc/iptables/rules.v4

    # Unblock ICMP (ping)
    sed -i '/net.ipv4.icmp_echo_ignore_all/d' /etc/sysctl.conf
    sed -i '/net.ipv4.icmp_echo_ignore_broadcasts/d' /etc/sysctl.conf
    echo "net.ipv4.icmp_echo_ignore_all = 0" >> /etc/sysctl.conf
    echo "net.ipv4.icmp_echo_ignore_broadcasts = 0" >> /etc/sysctl.conf
    sysctl -p
    echo "ICMP echo requests are no longer blocked."
}

menu() {
    while true; do
        echo "1) configure Anti DDoS script (Fail2ban , Block ICMP)"
        echo "2) remove all configurations"
        echo "9) Exit"
        read -p "Enter your choice: " choice
        case $choice in
        1) fail2ban; block_ICMP; change_ssh_port; echo " All configurations activated"; exit 1;;
        2) remove_configurations; exit 1;;
        9) exit;;
        *) echo "Invalid option. Please try again.";;
    esac
done
}
menu
