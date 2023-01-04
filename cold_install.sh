#!/bin/bash

# 字体相关
red() {
	echo -e "\033[31m\033[01m$1\033[0m"
}

green() {
	echo -e "\033[32m\033[01m$1\033[0m"
}

yellow() {
	echo -e "\033[33m\033[01m$1\033[0m"
}

[[ $EUID -ne 0 ]] && red "请在root用户下运行脚本" && exit 1

CMD=(
	"$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)"
	"$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)"
	"$(lsb_release -sd 2>/dev/null)"
	"$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)"
	"$(grep . /etc/redhat-release 2>/dev/null)"
	"$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')"
)

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN="\033[0m"

REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove")

for i in "${CMD[@]}"; do
	SYS="$i" && [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
	[[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
done

[[ -z $SYSTEM ]] && red "不支持当前VPS系统，请使用主流的操作系统" && exit 1
[[ -z $(type -P curl) ]] && ${PACKAGE_UPDATE[int]} && ${PACKAGE_INSTALL[int]} curl

# 模块索引(line: 50)
# (好的，现在这个索引也有些发臭了。)
# 我的代码太混乱了，为了可读性，我把各个协议相关的模块放在这里，方便检索、维护。
# 这代码迟早会成屎坑，希望那天我还在维护这个屎坑。
# 如果你这个大冤种想来维护，那就想着吧。
################################# R . I . P ###########################################
# nginx: nginx_forward_http install_nginx uninstall_nginx nginx_menu                  #
# tuic: uninstall_tuic start_tuic tuic_menu install_tuic                              #
# shadowsocks: ss_menu start_ss uninstall_ss shadowshare install_ss                   #
# naiveproxy: naive_link down_naive install_naive uninstall_naive naive_menu          #
# trojan: trojan_share uninstall_trojan start_trojan trojan_menu                      #
# shadow-tls: uninstall_shadow_tls start_shadow_tls install_shadow_tls shadowtls_menu #
# 其他项: install_base client_config install_go method_speed get_cert                  #
#######################################################################################
# 给自己留的原则:相关代码块放一起

# nginx
nginx_forward_http() {
    yellow "请注意: "
    yellow "1. 会删除原先的nginx配置"
    yellow "2. 将反向代理一个https网站"
    yellow "3. nginx只提供http服务"
    echo ""
    read -p "输入任意内容继续，按ctrl + c 退出: " rubbish
    echo ""
    read -p "请输入nginx监听端口(默认80): " http_port
    [[ -z "$http_port" ]] && http_port=80
    yellow "当前nginx监听: $http_port"
    echo ""
    yellow "示例: https://www.bing.com"
    read -p "请输入反代网站(必须为https!): " forward_link
    [[ -z "$forward_link" ]] && forward_link="https://www.bing.com"
    yellow "当前反代网站: $forward_link "
    echo ""

    red "即将配置nginx，3秒后删除原先配置文件！"
    sleep 3

    rm /etc/nginx/nginx.conf
    cat >/etc/nginx/nginx.conf <<-EOF
user root;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    gzip on;

    server {
        listen [::]:$http_port;
        listen 0.0.0.0:$http_port;

        location / {
            proxy_pass $forward_link;
            proxy_redirect off;
            proxy_ssl_server_name on;
            sub_filter_once off;
            sub_filter "$forward_link" \$server_name;
            proxy_set_header Host "$forward_link";
            proxy_set_header Referer \$http_referer;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header User-Agent \$http_user_agent;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header Accept-Encoding "";
            proxy_set_header Accept-Language "zh-CN";
        }
    }
}
		EOF
    systemctl stop nginx
    systemctl start nginx

    yellow "装完了？"
}

install_nginx() {
    ${PACKAGE_INSTALL[int]} nginx
}

uninstall_nginx() {
    ${PACKAGE_UNINSTALL[int]} nginx
}

nginx_menu() {
    green "nginx"
    echo ""
    yellow "1. 安装nginx"
    yellow "2. 卸载nginx"
    yellow "3. 配置nginx: 反代一个https网站为http服务"
    read -p "请选择: " answer
    case $answer in
        1) install_nginx ;;
        2) uninstall_nginx ;;
        3) nginx_forward_http ;;
        *) exit 1 ;;
    esac
}

# shadow-tls
uninstall_shadow_tls() {
    rm -rf /etc/shadow-tls
    red "卸载成功!"
    yellow "提示：你的后端节点并未被卸载。"
}

start_shadow_tls() {
    ufw allow ${port}
    ufw reload
    joker /etc/shadow-tls/shadow-tls server --listen ${listen}:${port} --server ${forward} --tls ${fake_link}:${fake_port} --password ${password}
    jinbe joker /etc/shadow-tls/shadow-tls server --listen ${listen}:${port} --server ${forward} --tls ${fake_link}:${fake_port} --password ${password}
}

install_shadow_tls() {
    yellow "请确定: "
    yellow "1. 已使用脚本101选项安装依赖"
    yellow "2. 已经搭好一个节点，这个节点只能是普通的tcp模式，不要有ws、tls之类的拓展。可以使用脚本选项2:shadowsocks-rust"
    red "3. 知道客户端如何使用！！！"
    read -p "输入任意内容继续，按ctrl + c退出: " rubbish
    #CPU
    bit=`uname -m`
    if [[ $bit = x86_64 ]]; then
        package_name=shadow-tls-x86_64-unknown-linux-musl
    elif [[ $bit = aarch64 ]]; then
        package_name=shadow-tls-aarch64-unknown-linux-musl
    elif [[ $bit = arm ]]; then
        package_name=shadow-tls-arm-unknown-linux-musleabi
    elif [[ $bit = armv8 ]]; then
        package_name=shadow-tls-arm-unknown-linux-musleabi
    else
        red "不支持的CPU，即将使用x86_64架构的内核"
        package_name=shadow-tls-x86_64-unknown-linux-musl
    fi
    echo ""
    read -p "请输入shadow-tls监听端口(默认443): " port
    [[ -z "$port" ]] && port=443
    yellow "当前shadow-tls监听端口: $port"
    echo ""
    yellow "shadow-tls 监听地址: "
    yellow "监听ipv4请输入 0.0.0.0(默认)"
    yellow "监听ipv6请输入 ::"
    yellow "不要输多个ip！不懂别输别的"
    read -p "请输入: " listen
    [[ -z "$listen" ]] && listen="0.0.0.0"
    yellow "当前监听: $listen"
    echo ""
    yellow  "请输入后端节点地址，示例: 127.0.0.1:8388  "
    yellow "要求： "
    yellow "1. 最好为shadowsocks/VMess，用VLESS、socks5相当于裸奔"
    yellow "2. 不要有其他传输层配置！！！不要有什么ws、tls，不要是UDP的协议！！！"
    read -p "请输入: " forward
    [[ -z "$forward" ]] && red "请输入已经搭好的节点端口！" && exit 1
    yellow "当前后端节点地址: $forward"
    echo ""
    read -p "请输入shadow-tls密码(默认随机): " password
    [[ -z "$password" ]] && password=$(openssl rand -base64 6)
    yellow "当前密码: $password"
    echo ""
    yellow "请输入伪装的网址，示例: www.bing.com"
    yellow "要求: "
    yellow "1. 不带https"
    yellow "2. 必须是https网站"
    yellow "3. 别填端口"
    read -p "请输入: " fake_link
    [[ -z "$fake_link" ]] && fake_link="www.bing.com"
    yellow "当前伪装地址: $fake_link"
    echo ""
    read -p "请输入伪装网址的端口(默认443): " fake_port
    [[ -z "$fake_port" ]] && fake_port=443
    yellow "当前伪装网址的端口: $fake_port"
    echo ""
    yellow "开始下载shadow-tls"
    mkdir /etc/shadow-tls
    cd /etc/shadow-tls
    curl -k -O -L https://github.com/ihciah/shadow-tls/releases/latest/download/${package_name}
    echo ""
    sleep 3
    mv ${package_name} shadow-tls
    chmod +x shadow-tls
    start_shadow_tls
    yellow "装完了？"
    echo ""
    ip=$(curl ip.sb)
    yellow "地址: $ip"
    yellow "端口: $port"
    yellow "sni: $fake_link"
    yellow "密码: $password"
    echo ""
    red "客户端使用命令: "
    red "./shadow-tls client --listen 127.0.0.1:1080 --server [${ip}]:$port --sni ${fake_link} --password ${password}"
    yellow "将先搭好的节点的ip改为127.0.0.1端口改为1080就能连接了。"
    yellow "注: ipv4请去掉"--server"后的中括号"
}

shadowtls_menu() {
    yellow "shadow-tls"
    echo "1. 安装shadow-tls"
    echo "2. 卸载shadow-tls"
    read -p "请选择: " answer
    case $answer in
        1) install_shadow_tls ;;
        2) uninstall_shadow_tls ;;
        *) exit 1 ;;
    esac
}

# trojan部分
trojan_share() {
    yellow "协议: trojan"
    yellow "地址: $domain 或服务器ip"
    yellow "端口: $port"
    yellow "密码: $password"
    yellow "sni: $domain"
    echo ""
    yellow "分享链接(推荐第一个): "
    echo "trojan://${password}@${domain}:${port}?sni=${domain}#trojan"
    echo "trojan://${password}@${domain}:${port}"
    # trojan://123@127.0.0.1:1080?sni=asd&security=tls&type=tcp#asd
    red "注意： 原版trojan不支持多路复用，请勿开启！"
}

install_trojan() {
    yellow "1. 请准备自己的证书及域名"
    red  "2. 请有一个用于回落的http服务，可以在本机，也可以在别的地方，可使用本脚本106安装的nginx服务。"
    yellow "3. 请使用脚本101选项安装依赖"
    read -p "输入任意内容继续，按ctrl +c 退出  " rubbish
    echo ""
    read -p "请输入自己的证书路径(请不要以"~"开头)： " cert
    [[ -z "$cert" ]] && red "请输入证书！！！"
    yellow "当前证书: $cert"
    echo ""
    read -p "请输入自己的私钥路径(请不要以"~"开头):  " key
    [[ -z "$key" ]] && red "请输入私钥！！！"
    yellow "当前私钥: $key"
    echo ""
    read -p "请输入自己的域名: " domain
    yellow "当前域名: $domain"
    echo ""
    yellow "trojan监听地址: "
    yellow "监听ipv4请输入 0.0.0.0(默认)"
    yellow "监听ipv6请输入 ::"
    yellow "不要输多个ip！不懂别输别的"
    read -p "" listen
    [[ -z "$listen" ]] && listen="0.0.0.0"
    yellow "当前监听: $listen"
    echo ""
    read -p "请输入trojan监听端口(默认443): " port
    [[ -z "$port" ]] && port="443"
    yellow "当前端口: $port"
    echo ""
    read -p "请输入trojan密码(默认随机): " password
    [[ -z "${password}" ]] && password=$(openssl rand -base64 16)
    yellow "当前密码: $password"
    echo ""
    yellow "请输入回落端口(用于防止主动探测，默认80。): " fallback_port
    [[ -z "$fallback_port" ]] && fallback_port=80
    yellow "当前回落端口: $fallback_port"
    echo ""
    yellow "请输入回落地址(默认127.0.0.1): " fallback_add
    [[ -z "$fallback_add" ]] && fallback_add="127.0.0.1"
    yellow "当前回落地址: $fallback_add"
    echo ""
    sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/trojan-gfw/trojan-quickstart/master/trojan-quickstart.sh)"
    sleep 5
    cp $key /usr/local/bin/key.key
    cp $cert /usr/local/bin/cert.crt
    yellow "正在写入trojan配置......"
    cat >/usr/local/bin/config.json <<-EOF
{
    "run_type": "server",
    "local_addr": "${listen}",
    "local_port": ${port},
    "remote_addr": "127.0.0.1",
    "remote_port": ${http_port},
    "password": [
        "${password}"
        ],
    "ssl": {
        "cert": "/usr/local/bin/cert.crt",
        "key": "/usr/local/bin/key.key",
        "alpn": [
            "h2",
            "http/1.1"
        ]
    }
}
EOF
    ufw allow ${port}
    ufw reload
    start_trojan
    echo ""
    yellow "装完了？"
    trojan_share
}

uninstall_trojan() {
    rm /usr/local/bin/trojan
    rm /usr/local/bin/config.json
}

start_trojan() {
    joker /usr/local/bin/trojan -c /usr/local/bin/config.json
    jinbe joker /usr/local/bin/trojan -c /usr/local/bin/config.json
}

trojan_menu() {
    yellow "trojan-GFW安装"
    echo "1. 安装trojan-GFW"
    echo "2. 删除trojan-GFW"
    echo "3. 启动trojan"
    read -p "请选择: " answer
    case $answer in
        1) install_trojan ;;
        2) uninstall_trojan ;;
        3) start_trojan ;;
        *) exit 1
    esac
}

#naiveproxy部分
# naiveproxy链接
naive_link() {
    yellow "分享链接(qv2ray的标准，非官方！): "
    naive_httpslink="naive+https://${username}:${password}@${domain}:${port}?padding=false#记得把sni改为${domain}"
    green "$naive_httpslink"
    echo ""
    yellow "测试链接: 使用quic传输，更快，但隐蔽性未知。"
    naive_quiclink="naive+quic://${username}:${password}@${domain}:${port}?padding=false#记得把sni改为${domain}"
    green "$naive_quiclink"
}

#安装naiveproxy
down_naive() {
    echo ""
    echo "区别: "
    yellow "1. 直接安装: 仅适用于ubuntu amd64系统，优点：快"
    yellow "2. 编译安装: 需要 v1.14 以上版本的go语言，适合几乎任何系统。但是比较慢。当前不完善！！！"
    read -p "请选择: " install_type
    yellow "当前选择: $install_type"
    yellow "如果填错自动编译安装！"
    mkdir /etc/caddy2
    cd /etc/caddy2
    if [[ "$install_type" == "1" ]]; then
        echo ""
        yellow "直接安装"
        curl -O -k -L https://github.com/klzgrad/forwardproxy/releases/latest/download/caddy-forwardproxy-naive.tar.xz
        sleep 3
        tar -xf caddy-forwardproxy-naive.tar.xz
        mv /etc/caddy2/caddy-forwardproxy-naive/caddy /etc/caddy2/caddy
        rm -rf /etc/caddy2/caddy-forwardproxy-naive
        rm /etc/caddy2/caddy-forwardproxy-naive.tar.xz
    else
    # 不完善
        red "即将开始 编译 安装，可能耗时非常久(取决于cpu)，尽量不要中途退出！！！"
        red "中途会卡住，别在意。"
        go mod tidy
        go env -w GO111MODULE=on
        go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
        ~/go/bin/xcaddy build --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive
        rm -rf /root/go
    fi
}

install_naive() {
#安装大体过程
    yellow "注意事项: "
    yellow "1. 请准备好域名并解析到对应ip"
    yellow "2. 请使用101选项安装依赖"
    yellow "3, 有 80 端口的控制权限且 80 端口无占用。"
    port_used=$(lsof -i:80)
    red "当前80端口占用: "
    red "$port_used"
    echo ""
    read -p "按任意键继续，按ctrl + c退出 " rubbish
    echo ""
    read -p "请输入 naiveproxy 监听端口(默认443): " port
    [[ -z "${port}" ]] && port="443"
    if [[ "${port:0:1}" == "0" ]]; then
        red "端口不能以0开头"
        port="443"
    fi
    yellow "当前端口: $port"
    echo ""
    read -p "请输入用户名(默认随机): " username
    [[ -z "${username}" ]] && username=$(openssl rand -base64 6)
    yellow "当前用户名: $username"
    echo ""
    read -p "请输入密码(默认随机): " password
    [[ -z "${password}" ]] && password=$(openssl rand -base64 16)
    yellow "当前密码: $password"

    echo ""
    read -p "请输入域名: " domain
    [[ -z "${domain}" ]] && red "请输入域名！" && exit 1
    echo ""
    read -p "请输入邮箱(申请证书用)(默认随机):  " email
    if [[ -z "${email}" ]]; then
        automail=$(date +%s%N | md5sum | cut -c 1-16)
        email=${automail}@gmail.com
    fi
    yellow "当前邮箱: $email"

    echo ""
    echo "请输入反向代理网址: "
    read -p "尽量使用https网址...... " forward_link
    [[ -z "$forward_link" ]] && forward_link="https://www.bing.com"
    yellow "当前反代地址: $forward_link"

    down_naive

    echo ""
    yellow "写入配置文件......"
    cat >/etc/caddy2/Caddyfile <<-EOF
:${port}, ${domain}:${port}
tls ${email}
route {
    forward_proxy {
        basic_auth ${username} ${password}
        hide_ip
        hide_via
        probe_resistance
    }
    reverse_proxy ${forward_link} {
        header_up  Host  {upstream_hostport}
        header_up  X-Forwarded-Host  {host}
        }
}
EOF

    ufw allow 80
    ufw allow ${port}
    ufw reload
    start_naive

    echo ""
    yellow "应该装完了吧......"

    echo ""
    green "地址: $domain 或你的服务器ip"
    green "sni: $domain"
    green "用户名: $username"
    green "密码: $password"

    naive_link
}

uninstall_naive() {
    rm -rf /etc/caddy2
    red "naiveproxy卸载完毕！"
}

start_naive() {
    cd /etc/caddy2/
    joker ./caddy run
    jinbe joker ./caddy run
}

naive_menu() {
    yellow "naiveproxy管理"
    echo "1. 安装 naiveproxy"
    echo "2. 卸载 naiveproxy"
    echo "3. 启动naiveproxy"
    read -p "请选择:" answer
    case $answer in
        1) install_naive ;;
        2) uninstall_naive ;;
        3) start_naive ;;
        *) exit 1 ;;
    esac
}

#shadowsocks部分
install_ss() {
    #CPU
    bit=`uname -m`
    if [[ $bit = x86_64 ]]; then
        cpu=x86_64
    elif [[ $bit = aarch64 ]]; then
        cpu=aarch64
    else
        cpu="$bit"
        red "VPS的CPU架构为$bit，可能安装失败!"
    fi

    yellow "注意: "
    yellow "1. 请先使用 101 选项  安装依赖。"
    yellow "2. 使用带TLS的插件时，需要自备证书。"
    yellow "3. 使用 qtun 插件时，要确保本机 9000 端口未被占用"
    yellow "回想一下有什么没做。"
    echo ""
    read -p "按任意键继续，按ctrl + c退出" rubbish

    read -p "请输入shadowsocks监听端口(100-65535): " port
    [[ -z "${port}" ]] && port=$(shuf -i200-65000 -n1)
    if [[ "${port:0:1}" == "0" ]]; then
        red "端口不能以0开头"
        exit 1
    fi
    yellow "当前监听端口: $port"

    echo ""
    yellow "shadowsocks 监听地址: "
    yellow "监听ipv4请输入 0.0.0.0(默认)"
    yellow "监听ipv6请输入 ::"
    yellow "不要输多个ip！不懂别输别的"
    read -p "请输入: " listen
    [[ -z "$listen" ]] && listen="0.0.0.0"
    yellow "当前监听: $listen"

    yellow "加密方式: "
    echo "注：带有2022字样的为shadowsocks-2022的加密方式，支持的客户端较少！"
    echo "已剔除不安全的加密方式！"
    red "1. 2022-blake3-chacha8-poly1305"
    red "2. 2022-blake3-chacha20-poly1305"
    red "3. 2022-blake3-aes-256-gcm"
    red "4. 2022-blake3-aes-128-gcm"
    green "5. chacha20-ietf-poly1305(默认)"
    yellow "6. aes-256-gcm"
    yellow "7. aes-128-gcm(推荐)"
    red "8. plain或none (无加密！)"
    read -p "请选择加密方式: " answer
    case $answer in
        1) method="2022-blake3-chacha8-poly1305" ;;
        2) method="2022-blake3-chacha20-poly1305" ;;
        3) method="2022-blake3-aes-256-gcm" ;;
        4) method="2022-blake3-aes-128-gcm" ;;
        5) method="chacha20-ietf-poly1305" ;;
        6) method="aes-256-gcm" ;;
        7) method="aes-128-gcm" ;;
        8) method="none" ;;
        *) method="chacha20-ietf-poly1305" ;;
    esac
    yellow "当前加密方式: $method"

    green "16位密码:"
    openssl rand -base64 16
    yellow "注意： 不填将会使用32位密码"
    yellow "注意：除2022-blake3-aes-128-gcm使用16位密码外，其他2022系加密方式需要使用32位密码！其他随意"
    read -p "请输入密码(默认随机): " password
    [[ -z "${password}" ]] && password=$(openssl rand -base64 32)
    yellow "当前密码： ${password}"

    yellow "插件选择: "
    yellow "0. 无插件(默认)"
    yellow "1. *Ray-lpugin"
    yellow "2. qtun"
    read -p "清选择: " choose_plugin
    case $choose_plugin in
        1) plugin="v2Ray-plugin" ;;
        2) plugin="qtun" ;;
        *) plugin="none" ;;
    esac
    yellow "当前选择: $plugin"

    # 设置插件
    if [[ "$plugin" == "v2Ray-plugin" ]]; then
        tls="false"
        echo ""
        yellow "传输模式: "
        yellow "1. http模式(默认)"
        yellow "2. websocket(ws)"
        yellow "3. QUIC(强制开启TLS)"
        green "4. gRPC(xray-plugin)"
        red "注: 想用TLS请自备证书！"
        echo ""
        read -p "清选择: " answer
        case $answer in
            1) transport=http ;;
            2) transport=ws ;;
            3) transport=quic && tls="true" ;;
            4) transport=gRPC ;;
            *) transport=http ;;
        esac
        echo ""
        if [[ "$transport" == "ws" ]]; then
            read -p "是否开启TLS?(Y/n)" answer
            if [[ "$answer" == "n" ]]; then
                tls="false"
                echo ""
                read -p "请输入ws host(可用来免流，默认 a.189.cn): " domain
                [[ -z "$domain" ]] && domain="a.189.cn"
                yellow "当前ws host: $domain"
            else
                tls="true"
            fi
            echo ""
            read -p "请输入ws路径(以/开头，不懂直接回车): " wspath
            while true; do
                if [[ -z "${wspath}" ]]; then
                    tmp=$(openssl rand -hex 6)
                    wspath="/$tmp"
                    break
                elif [[ "${wspath:0:1}" != "/" ]]; then
                    red "伪装路径必须以/开头！"
                else
                    break
                fi
            done
            yellow "当前ws路径: $wspath"
        fi
        if [[ "$transport" == "gRPC" ]]; then
            read -p "是否开启TLS(Y/n)?" answer
            if [[ "$answer" == "n" ]]; then
               tls="false"
               read -p "请输入您的域名(默认: a.189.cn): " domain
               [[ -z "$domain" ]] && domain="a.189.cn"
            else
               tls="true"
            fi
        fi
        yellow "TLS开启情况: $tls"
        echo ""
        if [[ "$tls" == "true" ]]; then
            read -p "请输入证书路径(请不要以"~"开头！): " cert
            yellow "当前证书：$cert"
            read -p "请输入密钥路径(请不要以"~"开头！): " key
            yellow "当前密钥: $key"
            read -p "请输入你的域名: " domain
            yellow "当前域名: $domain"
        fi

        if [[ "$transport" == "http" ]]; then
            plugin_opts=""
            semicolon=""
        elif [[ "$transport" == "ws" ]]; then
            semicolon=";"
            if [[ "$tls" == "true" ]]; then
                plugin_opts="tls;host=${domain};cert=/etc/shadowsocks-rust/cert.crt;key=/etc/shadowsocks-rust/key.key;path=${wspath}"
            elif [[ "$tls" == "false" ]]; then
                plugin_opts="host=${domain};path=${wspath}"
            fi
        elif [[ "$transport" == "quic" ]]; then
            semicolon=";"
            plugin_opts="mode=quic;host=${domain};cert=/etc/shadowsocks-rust/cert.crt;key=/etc/shadowsocks-rust/key.key"
        elif [[ "$transport" == "gRPC" ]]; then
            semicolon=";"
            if [[ "$tls" == "true" ]]; then
                plugin_opts="mode=grpc;tls;host=${domain};cert=/etc/shadowsocks-rust/cert.crt;key=/etc/shadowsocks-rust/key.key"
            elif [[ "$tls" == "false" ]]; then
                plugin_opts="mode=grpc;host=${domain}"
            fi
        fi
    fi

    if [[ "$plugin" == "qtun" ]]; then
        read -p "请输入证书路径(完整，不要包含"~"): " cert
        yellow "当前证书: $cert"
        read -p "请输入私钥路径(完整，不要包含"~"): " key
        yellow "当前私钥: $key" 
        read -p "请输入您的域名(默认: a.189.cn): " domain
        yellow "当前域名: $domain"
        sleep 1
    fi

    # 安装
    ss_version=$(curl -k https://raw.githubusercontent.com/tdjnodj/cold_install/api/shadowsocks-rust)
    mkdir /etc/shadowsocks-rust
    cd /etc/shadowsocks-rust
    curl -O -L -k https://github.com/shadowsocks/shadowsocks-rust/releases/download/v${ss_version}/shadowsocks-v${ss_version}.${cpu}-unknown-linux-gnu.tar.xz
    tar xvf shadowsocks-v${ss_version}.${cpu}-unknown-linux-gnu.tar.xz
    rm shadowsocks-*.tar.xz

    if [[ "$plugin" == "none" ]]; then
        yellow "正在写入配置......"
        cat >/etc/shadowsocks-rust/config.json <<-EOF
{
    "server": "${listen}",
    "server_port": $port,
    "password": "$password",
    "method": "$method"
}   
EOF
    elif [[ "$plugin" == "v2Ray-plugin" ]]; then
        bit=`uname -m`
        if [[ $bit = x86_64 ]]; then
            cpu=amd64
        elif [[ $bit = amd ]]; then
            cpu=amd64
        elif [[ $bit = amd64 ]]; then
            cpu=amd64
        elif [[ $bit = arm ]]; then
            cpu=arm64
        elif [[ $bit = armv7 ]]; then
            cpu=arm64
        elif [[ $bit = aarch64 ]]; then
            cpu=arm64
        else
            cpu="$bit"
            red "VPS的CPU架构为$bit，可能安装失败!"
        fi
        cd /etc/shadowsocks-rust
        yellow "开始下载 $plugin "
        read -p "是否改用xray插件(如果用gRPC则必选xray)(Y/n)？" v2orx
        if [[ "$v2orx" == "n" ]]; then
            if [[ "$transport" == "gRPC" ]]; then
                ray_plugin="x"
                red "由于你选择了 gRPC 作为传输模式，强制使用xray-plugin!"
            else
                ray_plugin="v"
                echo ""
                green "当前插件: v2Ray-plugin"
            fi
        else 
            ray_plugin="x"
            echo ""
            yellow "当前插件: xray-plugin"
        fi
        echo ""
        if [[ "$ray_plugin" == "v" ]]; then
            v2Ray_plugin_version=$(curl -k https://raw.githubusercontent.com/tdjnodj/cold_install/api/v2Ray-plugin)
            curl -L -k -O https://github.com/shadowsocks/v2ray-plugin/releases/download/v${v2Ray_plugin_version}/v2ray-plugin-linux-${cpu}-v${v2Ray_plugin_version}.tar.gz
            tar xvf *.tar.gz
            rm *.tar.gz
            mv v2ray-plugin_linux* v2Ray-plugin
        elif [[ "$ray_plugin" == "x" ]]; then
            xray_plugin_version=$(curl -k https://raw.githubusercontent.com/tdjnodj/cold_install/api/xray-plugin)
            curl -L -k -O https://github.com/teddysun/xray-plugin/releases/download/v${xray_plugin_version}/xray-plugin-linux-${cpu}-v${xray_plugin_version}.tar.gz
            tar xvf *.tar.gz
            rm *.tar.gz
            mv xray-plugin_linux* v2Ray-plugin
        fi
        if [[ "$tls" == "true" ]]; then
            cp $cert /etc/shadowsocks-rust/cert.crt
            cp $key /etc/shadowsocks-rust/key.key
        fi
        cat >/etc/shadowsocks-rust/config.json <<-EOF
{
    "server": "${listen}",
    "server_port": $port,
    "password": "$password",
    "method": "$method",
    "plugin": "/etc/shadowsocks-rust/v2Ray-plugin",
    "plugin_opts": "server${semicolon}${plugin_opts}"
}
EOF
    elif [[ "$plugin" == "qtun" ]]; then
        if [[ $bit = x86_64 ]]; then
            cpu=x86_64
        elif [[ $bit = amd ]]; then
            cpu=x86_64
        elif [[ $bit = amd64 ]]; then
            cpu=x86_64
        elif [[ $bit = arm ]]; then
            cpu=aarch64
        elif [[ $bit = armv7 ]]; then
            cpu=aarch64
        elif [[ $bit = aarch64 ]]; then
            cpu=aarch64
        else
            cpu=x86_64
            red "VPS的CPU架构为$bit，可能安装失败!"
        fi
        qtun_version=$(curl -k https://raw.githubusercontent.com/tdjnodj/cold_install/api/qtun)
        yellow "检测到的最新版本: $qtun_version"
        read -p "请填写qtun版本(可直接回车): " qtun_version
        [[ -z "$qtun_version" ]] && qtun_version=$(curl -k https://raw.githubusercontent.com/tdjnodj/cold_install/api/qtun)
        cd /etc/shadowsocks-rust
        curl -L -O -k https://github.com/shadowsocks/qtun/releases/download/v${qtun_version}/qtun-v${qtun_version}.${cpu}-unknown-linux-musl.tar.xz
        tar xvf qtun*
        rm qtun*.tar.xz
        rm qtun-client
        cp $cert /etc/shadowsocks-rust/cert.crt
        cp $key /etc/shadowsocks-rust/key.key
        cat >/etc/shadowsocks-rust/config.json <<-EOF
{
    "server": "${listen}",
    "server_port": $port,
    "password": "$password",
    "method": "$method",
    "mode":"tcp_only",
    "plugin": "/etc/shadowsocks-rust/qtun-server",
    "plugin_opts": "cert=/etc/shadowsocks-rust/cert.crt;key=/etc/shadowsocks-rust/key.key"
}
EOF
        ufw allow 9000
    fi
    
    ufw allow ${port}
    ufw reload
    start_ss
    yellow "装完了？"
    shadowshare
}

shadowshare() {
    if [[ "$plugin" == "none" ]]; then
        ip=$(curl ip.sb)
        green "地址: $ip"
        green "端口: $port"
        green "加密方式: $method"
        green "密码: $password"
    elif [[ "$plugin" == "v2Ray-plugin" ]]; then
        ip=$(curl ip.sb)
        green "地址: $ip"
        green "端口: $port"
        green "加密方式: $method"
        green "密码: $password"
        green "插件: v2Ray/xray"
        echo ""
        if [[ "$transport" == "http" ]]; then
            client_opts="不填！"
        elif [[ "$transport" == "ws" ]]; then
            if [[ "$tls" == "true" ]]; then
                client_opts="tls;host=${domain};path=${wspath}"
            elif [[ "$tls" == "false" ]]; then
                client_opts="host=${domain};path=${wspath}"
            fi
        elif [[ "$transport" == "quic" ]]; then
            client_opts="mode=quic;host=${domain}"
        elif [[ "$transport" == "gRPC" ]]; then
            if [[ "$tls" == "true" ]]; then
                client_opts="tls;host=${domain};mode=grpc"
            elif [[ "$tls" == "false" ]]; then
                client_opts="host=${domain};mode=grpc"
            fi
        fi
        green "插件参数: $client_opts"
    elif [[ "$plugin" == "qtun" ]]; then
        ip=$(curl ip.sb)
        green "地址: $ip"
        green "端口: $port"
        green "加密方式: $method"
        green "密码: $password"
        green "插件: qtun-client"
        echo ""
        green "插件参数: host=${domain}"
    fi

    echo ""
    yellow "分享链接(如果使用插件则不能使用！): "
    /etc/shadowsocks-rust/ssurl -e /etc/shadowsocks-rust/config.json
    red "请将ip地址改成自己的！"
}

uninstall_ss() {
    rm -rf /etc/shadowsocks-rust
}

start_ss() {
    joker /etc/shadowsocks-rust/ssserver -c /etc/shadowsocks-rust/config.json
    jinbe joker /etc/shadowsocks-rust/ssserver -c /etc/shadowsocks-rust/config.json
}

ss_menu() {
    answer="0"
    echo "shadowsocks-rust"
    yellow "1. 安装 shadowsocks-rust"
    yellow "2. 卸载 shadowsocks-rust"
    yellow "3. 启动 shadowsocks-rust"
    read -p "请选择: " answer
    case $answer in
        1) install_ss ;;
        2) uninstall_ss ;;
        3) start_ss ;;
        *) exit 1 ;;
    esac
}

# TUIC部分

uninstall_tuic() {
    sudo rm  /etc/TUIC/tuic
    sudo rm /etc/TUIC/config.json
    red "卸载成功！证书保存在 /etc/TUIC "
    echo ""
    yellow "删除证书命令: "
    echo "rm /etc/TUIC/cert.crt"
    echo "rm /etc/TUIC/key.key"
}

start_tuic() {
    joker /etc/TUIC/tuic -c /etc/TUIC/config.json
    jinbe joker /etc/TUIC/tuic -c /etc/TUIC/config.json
    yellow "TUIC 启动成功(?)"
}

tuic_menu(){
    answer="0"
    yellow "管理TUIC"
    echo ""
    yellow "1. 安装TUIC"
    yellow "2. 卸载TUIC"
    yellow "3. 启动tuic"
    echo ""
    read -p "请选择操作: " answer
    case $answer in
        1) install_tuic ;;
        2) uninstall_tuic ;;
        3) start_tuic ;;
        *) echo "请输入正确的选项！" && exit 1
    esac
}

install_tuic() {
    # 判断CPU架构
    bit=`uname -m`
    if [[ $bit = x86_64 ]]; then
        cpu=x86_64
    elif [[ $bit = aarch64 ]]; then
        cpu=aarch64
    elif [[ $bit = arm ]]; then
        cpu=arm
    elif [[ $bit = armv7 ]]; then
        cpu=armv7
    elif [[ $bit = armv8 ]]; then
        cpu=arm
    else
        cpu="$bit"
        red "VPS的CPU架构为$bit，可能不支持！"
    fi


    yellow "请先确认安装条件"
    yellow "1. 已经准备好了自己的TLS证书和密钥"
    yellow "2. 确定你的运营商允许代理，以及允许大量UDP流量"
    yellow "3. 已经使用脚本的101选项安装了依赖"
    echo ""
    yellow "再回想一下自己还有什么忘做的吧"
    read -p "输入任意内容继续，按ctrl + c退出: " rubbish

    read -p "请输入tuic监听端口(100-65535): " port
    [[ -z "${port}" ]] && port=$(shuf -i200-65000 -n1)
    if [[ "${port:0:1}" == "0" ]]; then
        red "端口不能以0开头"
        exit 1
    fi
    yellow "当前监听端口: $port"

    echo ""
    yellow "TUIC 监听地址: "
    yellow "监听ipv4请输入 0.0.0.0"
    yellow "监听ipv6请输入 :: (默认)"
    yellow "不要输多个ip！不懂别输别的"
    read -p "" listen
    [[ -z "$listen" ]] && listen="::"
    yellow "当前监听: $listen"

    read -p "请输入密码(默认随机): " password
    [[ -z "$password" ]] && password=$(openssl rand -base64 8)
    yellow "当前密码: $password"

    read -p "请输入证书公钥路径(完整，请不要以"~"开头): " cert 
    [[ -z "$cert" ]] && red "请输入路径！" && exit 1
    read -p "请输入证书私钥路径(完整，请不要以"~"开头): " key
    [[ -z "$key" ]] && red "请输入路径！" && exit 1
    yellow "当前证书路径: $cert"
    yellow "当前私钥路径: $key"

    tuic_version=$(curl https://raw.githubusercontent.com/tdjnodj/cold_install/api/TUIC -k)
    yellow "当前TUIC版本: $tuic_version"
    yellow "开始下载"
    mkdir /etc/TUIC
    cd /etc/TUIC
    curl -O -k -L https://github.com/EAimTY/tuic/releases/download/${tuic_version}/tuic-server-${tuic_version}-${cpu}-linux-gnu
    mv tuic-server-${tuic_version}-${cpu}-linux-gnu tuic
    chmod +x tuic

    yellow "正在写入配置......"
    cp $cert /etc/TUIC/cert.crt
    cp $key /etc/TUIC/key.key
    touch /etc/TUIC/config.json

    cat >/etc/TUIC/config.json <<-EOF
{
    "ip": "${listen}",
    "port": $port,
    "token": [ "$password" ],
    "certificate": "/etc/TUIC/cert.crt",
    "private_key": "/etc/TUIC/key.key",

    "congestion_controller": "bbr"
}

EOF

    start_tuic

    red "大概安装完了吧......"
    echo ""

    ip=$(curl ip.sb)
    green  "客户端填写信息如下，请妥善保存。"
    yellow "server: 你的域名"
    yellow "port: $port"
    yellow "token: $password"
    yellow "ip: 你的域名或 $ip"
    yellow "alpn: 随意"

}

# 其他部分

install_base() {
    ${PACKAGE_UPDATE[int]}
    ${PACKAGE_INSTALL[int]} curl openssl python3 tar
    sleep 3
    yellow "剩余部分请输入以下命令手动安装(可同时复制两行): "
    echo "bash <(curl https://bash.ooo/nami.sh)"
    echo "nami install joker jinbe"
}

client_config() {
    yellow "提示： 请先安装python3"
    curl -k -O -L https://raw.githubusercontent.com/tdjnodj/science_config_maker/main/science_config_maker.py && python3 science_config_maker.py
}

install_go() {
    # CPU
    bit=`uname -m`
    if [[ $bit = x86_64 ]]; then
        cpu=amd64
    elif [[ $bit = amd64 ]]; then
        cpu=amd64
    elif [[ $bit = aarch64 ]]; then
        cpu=arm64
    elif [[ $bit = armv8 ]]; then
        cpu=arm64
    elif [[ $bit = armv7 ]]; then
        cpu=arm64
    else 
        cpu=$bit
        red "可能不支持该型号( $cpu )的CPU!"
    fi
    go_version=$(curl https://go.dev/VERSION?m=text)
    red "当前最新版本golang: $go_version"
    curl -O -k -L https://go.dev/dl/${go_version}.linux-${cpu}.tar.gz
    sleep 5
    tar -xf go*.linux-${cpu}.tar.gz -C /usr/local/
    sleep 3
    export PATH=\$PATH:/usr/local/go/bin
    rm go*.linux-${cpu}.tar.gz
    cat >/root/.bash_profile <<-EOF
export PATH=\$PATH:/usr/local/go/bin
EOF
    source /root/.bash_profile
    yellow "检查当前golang版本: "
    go version
    yellow "请手动输入: "
    red "export PATH=\$PATH:/usr/local/go/bin"
    red "source /root/.bash_profile"
    echo ""
    echo "常见错误原因: 未删除旧的go"
}

method_speed() {
    yellow "请确保此时VPS的CPU没被大量使用。"
    yellow "部分VPS不支持"
    openssl speed aes-128-gcm aes-256-gcm chacha20-poly1305
    sleep 5
    yellow "同一列，数字越大证明加密越快，优先选择这种加密方式。"
    yellow "如无法测速，推荐使用 aes-128-gcm"
}

get_cert() {
    curl -O -k https://raw.githubusercontent.com/tdjnodj/simple-acme/main/simple-acme.sh && bash simple-acme.sh
}

menu() {
    clear
    answer="0"
    echo "冷门协议安装一键脚本"
    echo "快捷命令: bash cold_install.sh"
    echo "-----------------------"
    echo "1. TUIC"
    echo "2. shadowsocks-rust"
    echo "3. naiveproxy"
    echo "4. trojan-gfw"
    echo "5. shadow-tls"
    echo "-----------------------"
    echo "101. 安装/升级本脚本必须依赖"
    echo ""
    echo "如果你之前没选择过101，请先选择！"
    echo ""
    echo "102. 生成客户端配置"
    echo "103. 安装最新版本的golang"
    echo "104. 各加密方式测速"
    echo "105. 申请TLS证书(http方式/自签)"
    green "106. nginx功能"
    echo "0. 退出"
    echo ""
    read -p "请选择操作: " answer
    case $answer in
        0) exit 1 ;;
        1) tuic_menu ;;
        2) ss_menu ;;
        3) naive_menu ;;
        4) trojan_menu ;;
        5) shadowtls_menu ;;
        101) install_base ;;
        102) client_config ;;
        103) install_go ;;
        104) method_speed ;;
        105) get_cert ;;
        106) nginx_menu ;;
        *) echo "请输入正确的选项！" && exit 1
    esac
}

action=$1
[[ -z $1 ]] && action=menu

# 偷来的，我也不理解......
case "$action" in
	menu | update | uninstall | start | restart | stop | showInfo | showLog) ${action} ;;
	*) echo " 参数错误" && echo " 用法: $(basename $0) [menu|update|uninstall|start|restart|stop|showInfo|showLog]" ;;
esac
