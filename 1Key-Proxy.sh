#!/bin/bash

# 检查root权限，免得安装麻烦

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"

green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "———————————————————————————————"
        red "错误：检测到无root权限，请使用root账户运行此脚本。"
        echo "———————————————————————————————"
        exit 1
    fi
}

# 检查curl命令是否存在，curl必须有
check_curl() {
    if ! command -v curl &> /dev/null; then
        echo "———————————————————————————————"
        red "错误：未找到curl，请先安装curl。"
        echo "———————————————————————————————"
        exit 1
    fi
}

hy2(){
    echo "1Key-Proxy正在安装和配置hysteria2，请耐心等待，以下操作均来自于官方文档"
    curl -fsSL https://get.hy2.sh/ -o hy2.sh
    chmod +x hy2.sh
    ./hy2.sh
    echo "———————————————————————————————"
    yellow "hysteria2安装完成，现在进行配置"
    echo "———————————————————————————————"
    local FLAG=0
    while [ "$FLAG" == 0 ]; do #防止在等待安装的时候输入回车，导致配置文件全空
        read -p "请输入yes开始配置：" key
        if [ "$key" == "yes" ]; then
            FLAG=1
            read -p "现在进行acme证书配置，请输入解析到此服务器的域名：" DOMAIN
            read -p "请输入您的邮箱地址：" EMAIL
            read -p "请输入您的hy2密码：" PASSWORD
            read -p "请输入您用于反向代理的网址，如www.baidu.com：" PROXYURL
            
        else
            FLAG=0
        fi
    done
    hy2_config $DOMAIN $EMAIL $PASSWORD $PROXYURL
    return 0
}

hy2_config(){
    config_file="/etc/hysteria/config.yaml"
        cat <<EOF >"$config_file"
# listen: :443

acme:
  domains:
    - $1
  email: $2

auth:
  type: password
  password: $3

masquerade:
  type: proxy
  proxy:
    url: https://$4/
    rewriteHost: true

EOF

    systemctl start hysteria-server.service
    systemctl enable hysteria-server.service
    echo "———————————————————————————————"
    echo "您的hysteria2服务器地址为：$1，密码为：$3，请牢记"
    echo "hysteria2配置完成，请自行寻找使用方法"
    echo "———————————————————————————————"
    return 0
}

hy2_installed() {
    if [ -x "$(command -v hysteria)" ]; then
        echo "———————————————————————————————"
        echo "Hysteria2 已经安装，跳过安装过程。"
        echo "———————————————————————————————"
        return 1
    else
        hy2
        return 0
    fi
}

naive_installed() {
    if [ -x "./caddy" ]; then
        echo "———————————————————————————————"
        echo "Caddy with naive plugin已经安装，跳过安装过程。"
        echo "———————————————————————————————"
        return 1
    else
        naive
        return 0
    fi
}

naive(){
    echo "———————————————————————————————"
    yellow "正在安装和配置naiveproxy，请耐心等待，安装时间取决于网络环境及系统配置"
    echo "———————————————————————————————"
    apt-get install software-properties-common
    add-apt-repository ppa:longsleep/golang-backports 
    apt-get update 
    apt-get install golang-go
    go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
    ~/go/bin/xcaddy build --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive
    local FLAG=0
    while [ "$FLAG" == 0 ]; do #防止在等待安装的时候输入回车，导致配置文件全空
        read -p "请输入yes开始配置：" key
        if [ "$key" == "yes" ]; then
            read -p "现在进行acme证书配置，请输入解析到此服务器的域名：" DOMAIN
            read -p "请输入您的邮箱地址：" EMAIL
            read -p "请输入您的naive用户名：" USER
            read -p "请输入您的naive密码：" PASSWORD
            read -p "请输入您用于反向代理的网址，如www.baidu.com：" PROXYURL
            FLAG=1
        else
            FLAG=0
        fi
    done
    na_config $DOMAIN $EMAIL $USER $PASSWORD $PROXYURL
    return 0
}

na_config(){
    config_file="/root/Caddyfile"
        cat <<EOF >"$config_file"
{
 order forward_proxy before file_server
   servers {
    protocols h1 h2
  }
}
:443, $1
tls $2
route {
 forward_proxy {
   basic_auth $3 $4
   hide_ip
   hide_via
   probe_resistance
  }
 reverse_proxy  $5  {
   header_up  Host  {upstream_hostport}
   header_up  X-Forwarded-Host  {host}
  }
}
EOF

    ./caddy start
    echo "———————————————————————————————"
    echo "您的naiveproxy服务器地址为：$1，用户名为：$3，密码为：$4，请牢记"
    echo "naiveproxy配置完成，请自行寻找使用方法"
    echo "———————————————————————————————"
    return 0
}

print_script_info() {
    echo "===================================================="
    echo "欢迎使用 1Key-Proxy.sh 脚本"
    echo "----------------------------------------------------"
    echo "提示: 脚本运行时需要 root 权限，请使用 sudo 命令运行或以 root 身份运行"
    echo "适用系统: Ubuntu 22.04"
    echo "用途: 快速搭建代理服务器"
    echo "注意: 本脚本并非一键脚本，适用于有一定基础的用户"
    echo "----------------------------------------------------"
    echo "自动安装和配置：naiveproxy 和 hysteria2"
    echo "所有步骤均来自官方文档，请放心使用"
    echo "小白请按0请高明：www.cfri.edu.cn"
    echo "===================================================="
}

unhy2(){
    yellow "正在卸载hysteria"
    bash <(curl -fsSL https://get.hy2.sh/) --remove
    rm -rf /etc/hysteria
    userdel -r hysteria
    rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server.service
    rm -f /etc/systemd/system/multi-user.target.wants/hysteria-server@*.service
    systemctl daemon-reload
    yellow "hysteria卸载完成"
}

unnaive(){
    yellow "正在卸载naive"
    ./caddy stop
    rm -f /root/Caddyfile /root/caddy
    yellow "naive卸载完成"
}


print_script_info
read -p "如果您不同意脚本以root权限运行，请输入no退出，输入yes继续：" YES
if [ ${YES,,} = "yes" ]; then
    check_root
    check_curl
else    
    echo "您选择了退出"
    exit 1
fi

echo "请选择功能："
echo "1.安装naive"
echo "2.安装hysteria"
echo "3.卸载naive"
echo "4.卸载hysteria"

read -p "请输入数字：" FUNCTION
if [ ${FUNCTION,,} = 1 ]; then
    naive_installed
    yellow "hysteria2已安装，相关命令如下："
    yellow "===================================================="
    echo "naive已安装，相关命令："
    echo "启动服务(前台运行)./caddy run"
    echo "启动服务(后台运行)：./caddy start"
    yellow "===================================================="
elif [ ${FUNCTION,,} = 2 ]; then
    hy2_installed
    yellow "===================================================="
    echo "hy2相关命令："
    echo "服务器配置文件：/etc/hysteria/config.yaml"
    echo "启动hysteria服务：systemctl start hysteria-server.service"
    echo "开机自启动hysteria服务：systemctl enable hysteria-server.service"
    yellow "===================================================="
elif [ ${FUNCTION,,} = 3 ]; then
    unnaive
elif [ ${FUNCTION,,} = 4 ]; then
    unhy2
fi



