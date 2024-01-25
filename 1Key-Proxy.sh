#!/bin/bash

# 检查root权限，免得安装麻烦
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "———————————————————————————————"
        echo "错误：检测到无root权限，请使用root账户运行此脚本。"
        echo "———————————————————————————————"
        exit 1
    fi
}

# 检查curl命令是否存在，curl必须有
check_curl() {
    if ! command -v curl &> /dev/null; then
        echo "———————————————————————————————"
        echo "错误：未找到curl，请先安装curl。"
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
    echo "hysteria2安装完成，现在进行配置"
    echo "———————————————————————————————"
    read -p "现在进行acme证书配置，请输入解析到此服务器的域名：" DOMAIN
    read -p "请输入您的邮箱地址：" EMAIL
    read -p "请输入您的hy2密码：" PASSWORD
    read -p "请输入您用于反向代理的网址，如www.baidu.com：" PROXYURL
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
    if pgrep -x "hysteria" > /dev/null; then
        echo "———————————————————————————————"
        echo "Hysteria2 已经安装，跳过安装过程。"
        echo "———————————————————————————————"
        return 1
    else
        hy2
        return 0
    fi
}

naive(){
    echo "———————————————————————————————"
    echo "1Key-Proxy正在安装和配置naiveproxy，请耐心等待，时间取决于网络环境及系统配置"
    echo "———————————————————————————————"
    apt-get install software-properties-common
    add-apt-repository ppa:longsleep/golang-backports 
    apt-get update 
    apt-get install golang-go
    go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
    ~/go/bin/xcaddy build --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive
    read -p "现在进行acme证书配置，请输入解析到此服务器的域名：" DOMAIN
    read -p "请输入您的邮箱地址：" EMAIL
    read -p "请输入您的naive用户名：" USER
    read -p "请输入您的naive密码：" PASSWORD
    read -p "请输入您用于反向代理的网址，如www.baidu.com：" PROXYURL
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
:443, $1 #你的域名
tls $2 #你的邮箱
route {
 forward_proxy {
   basic_auth $3 $4 #用户名和密码
   hide_ip
   hide_via
   probe_resistance
  }
 reverse_proxy  $5  { #伪装网址
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

echo "———————————————————————————————"
echo "这里是1Key-Proxy.sh"
echo "脚本运行时需要root权限，请使用sudo命令运行或以root身份运行"
check_root
check_curl
echo "本脚本适用于Ubuntu 22.04，用于快速搭建代理服务器"
echo "自动安装和配置naiveproxy和hysteria2，所有安装步骤均来源于官方文档，请放心使用"
echo "本脚本并非一键脚本，仅用于快速搭建服务器，适用于有一定基础的用户，小白请按0请高明：www.cfri.edu.cn"
echo "———————————————————————————————"

read -p "如果您不同意脚本以root权限运行，请输入no退出，输入yes继续：" YES
if [ ${YES,,} = "no" ]; then
    echo "您选择了退出，脚本将不会继续运行"
    exit 1
fi

hy2_installed

naive