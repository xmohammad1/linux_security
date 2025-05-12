#!/bin/bash
# Ensure the script is run as root
if [[ "$EUID" -ne 0 ]]; then
    echo "Please run as root."
    exit 1
fi
NEW_SSH_PORT="64999"
block_ICMP() {
    # Remove any existing line with 'net.ipv4.icmp_echo_ignore_all'
    sed -i '/net.ipv4.icmp_echo_ignore_all/d' /etc/sysctl.conf
    sed -i '/net.ipv4.icmp_echo_ignore_broadcasts/d' /etc/sysctl.conf
    # Add the new line to block ICMP (ping) requests
    echo "net.ipv4.icmp_echo_ignore_all = 1" >> /etc/sysctl.conf
    echo "net.ipv4.icmp_echo_ignore_broadcasts = 1" >> /etc/sysctl.conf
    sysctl -p
}
change_ssh_port_and_firewall() {
    local target_port="$1"
    SSHD_CONFIG_FILE="/etc/ssh/sshd_config"
    local current_port_config

    echo "Changing SSH port to $target_port..."

    # دریافت پورت فعلی پیکربندی‌شده برای حذف قانون UFW آن در صورت نیاز
    current_port_config=$(grep -E "^[[:space:]]*Port[[:space:]]+[0-9]+" "$SSHD_CONFIG_FILE" | awk '{print $2}' | tail -n 1)

    # تغییر یا افزودن خط پورت در sshd_config
    if grep -qE '^#?[[:space:]]*Port[[:space:]]*[0-9]+' "$SSHD_CONFIG_FILE"; then
        sed -i -E "s/^#?[[:space:]]*Port[[:space:]]*[0-9]+/Port $target_port/" "$SSHD_CONFIG_FILE"
    else
        echo -e "\nPort $target_port" >> "$SSHD_CONFIG_FILE" # افزودن خط جدید اگر وجود نداشته باشد
    fi

    echo "Attempting to restart SSH service..."
    if systemctl restart ssh.service; then
        echo "SSH service restarted successfully (using ssh.service)."
    elif systemctl restart sshd.service; then
        echo "SSH service restarted successfully (using sshd.service)." # به عنوان پشتیبان
    else
        echo "ERROR: Failed to restart SSH service. Please check 'systemctl status ssh' or 'systemctl status sshd' and restart it manually."
        echo "The SSH port was changed in $SSHD_CONFIG_FILE to $target_port, but the service may not have applied the new config."
        # در اینجا می‌توانید اجرای اسکریپت را متوقف کنید یا یک کد خطا برگردانید
    fi

    echo "Updating UFW firewall rules..."
    # حذف قانون قدیمی اگر پورت قبلی مشخص و متفاوت از پورت جدید و پورت 22 بود
    if [[ -n "$current_port_config" && "$current_port_config" != "22" && "$current_port_config" != "$target_port" ]]; then
        echo "Removing old UFW rule for port $current_port_config/tcp (if it exists)."
        ufw delete allow "$current_port_config/tcp"
    fi
    ufw allow "$target_port"
    ufw reload # اعمال تغییرات UFW
    echo "SSH port has been updated to Port $target_port and firewall configured."
}

remove_configurations() {
    # Unblock ICMP (ping)
    sed -i '/net.ipv4.icmp_echo_ignore_all/d' /etc/sysctl.conf
    sed -i '/net.ipv4.icmp_echo_ignore_broadcasts/d' /etc/sysctl.conf
    echo "net.ipv4.icmp_echo_ignore_all = 0" >> /etc/sysctl.conf
    echo "net.ipv4.icmp_echo_ignore_broadcasts = 0" >> /etc/sysctl.conf
    sysctl -p
    echo "ICMP echo requests are no longer blocked."
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
        echo "1) configure Anti DDoS script [Block ICMP && Private Ranges]"
        echo "2) remove all configurations"
        echo "3) white list a ip address/range"
        echo "4) IP Blocker Manager"
        echo "9) Exit"
        read -p "Enter your choice: " choice
        case $choice in
        1)
            echo "Starting configuration process..."
            change_ssh_port_and_firewall "$NEW_SSH_PORT"
            block_ICMP
            block_ip_ranges
            echo ""
            echo "All configurations applied successfully."
            echo "IMPORTANT: SSH port has been changed to $NEW_SSH_PORT."
            exit 0
            ;;
        2) remove_configurations; exit 1;;
        3) white_list_ip; exit 1;;
        4) ip_manager_script;;
        9) exit;;
        *) echo "Invalid option. Please try again.";;
    esac
done
}
menu
