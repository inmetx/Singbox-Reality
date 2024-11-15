#!/bin/bash

# 检查是否安装了 jq，如果没有，则安装
if ! command -v jq &> /dev/null; then
    echo "jq 未安装。安装..."
    if [ -n "$(command -v apt)" ]; then
        apt update > /dev/null 2>&1
        apt install -y jq > /dev/null 2>&1
    elif [ -n "$(command -v yum)" ]; then
        yum install -y epel-release
        yum install -y jq
    elif [ -n "$(command -v dnf)" ]; then
        dnf install -y jq
    else
        echo "无法安装 jq。请手动安装 jq 并重新运行脚本."
        exit 1
    fi
fi

# 检查 reality.json、sing-box 和 sing-box.service 是否已存在
if [ -f "/root/reality.json" ] && [ -f "/root/sing-box" ] && [ -f "/root/public.key.b64" ] && [ -f "/etc/systemd/system/sing-box.service" ]; then

    echo "文件已存在."
    echo ""
    echo "请选择选项:"
    echo ""
    echo "1. 重新安装"
    echo "2. 更改配置"
    echo "3. 显示当前链接"
    echo "4. 选择版本（稳定版/测试版）"
    echo "5. 卸载"
    echo ""
    read -p "输入选择 (1-5): " choice

    case $choice in
        1)
	            	echo "重新安装..."
	            	# 卸载之前的安装
	            	systemctl stop sing-box
	            	systemctl disable sing-box > /dev/null 2>&1
	           	rm /etc/systemd/system/sing-box.service
	            	rm /root/reality.json
	            	rm /root/sing-box
	
	            	# 继续安装
	            	;;
        2)
            		echo "更改配置..."
			# 获取当前监听端口
			current_listen_port=$(jq -r '.inbounds[0].listen_port' /root/reality.json)

			# 请求监听端口
			read -p "Enter desired listen port (Current port is $current_listen_port): " listen_port
			listen_port=${listen_port:-$current_listen_port}

			# 获取当前服务器名称
			current_server_name=$(jq -r '.inbounds[0].tls.server_name' /root/reality.json)

			# 输入服务器名称 (sni)
			read -p "Enter server name/SNI (Current value is $current_server_name): " server_name
			server_name=${server_name:-$current_server_name}

			# 使用新设置修改 reality.json
			jq --arg listen_port "$listen_port" --arg server_name "$server_name" '.inbounds[0].listen_port = ($listen_port | tonumber) | .inbounds[0].tls.server_name = $server_name | .inbounds[0].tls.reality.handshake.server = $server_name' /root/reality.json > /root/reality_modified.json
			mv /root/reality_modified.json /root/reality.json

			# 重启sing-box
			systemctl restart sing-box
			echo ""
			echo ""
			echo "订阅链接:"
			echo ""
			echo ""
			# 获取当前监听端口
			current_listen_port=$(jq -r '.inbounds[0].listen_port' /root/reality.json)

			# 获取当前服务器名
			current_server_name=$(jq -r '.inbounds[0].tls.server_name' /root/reality.json)

			# 获取 UUID
			uuid=$(jq -r '.inbounds[0].users[0].uuid' /root/reality.json)

			# 从文件中获取公钥，并对其进行 base64 解码
			public_key=$(base64 --decode /root/public.key.b64)
			
			# 获取短 ID
			short_id=$(jq -r '.inbounds[0].tls.reality.short_id[0]' /root/reality.json)
			
			# 获取服务器 IP 地址
			server_ip=$(curl -s https://api.ipify.org)
			
			# 生成链接
			server_link="vless://$uuid@$server_ip:$current_listen_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$current_server_name&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#SING-BOX-TCP"
			
			echo "$server_link"
			echo ""
			echo ""
			exit 0
            		;;
	3)
			echo "显示当前链接..."
			
			# 获取当前监听端口
			current_listen_port=$(jq -r '.inbounds[0].listen_port' /root/reality.json)

			# 获取当前服务器名
			current_server_name=$(jq -r '.inbounds[0].tls.server_name' /root/reality.json)

			# 获取UUID
			uuid=$(jq -r '.inbounds[0].users[0].uuid' /root/reality.json)

			# 从文件中获取公钥，并对其进行 base64 解码
			public_key=$(base64 --decode /root/public.key.b64)
			
			# 获取短 ID
			short_id=$(jq -r '.inbounds[0].tls.reality.short_id[0]' /root/reality.json)
			
			# 获取服务器 IP
			server_ip=$(curl -s https://api.ipify.org)
			
			# 生成链接
			server_link="vless://$uuid@$server_ip:$current_listen_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$current_server_name&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#SING-BOX-TCP"
			echo ""
			echo ""
			echo "$服务器链接"
			echo ""
			echo ""
			exit 0
			;;
		4)
			echo ""
   			echo "切换版本..."
			echo ""
			# 提取当前版本
			current_version_tag=$(/root/sing-box version | grep 'sing-box version' | awk '{print $3}')

			# 获取最新的稳定版和测试版
			latest_stable_version=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" | jq -r '[.[] | select(.prerelease==false)][0].tag_name')
			latest_alpha_version=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" | jq -r '[.[] | select(.prerelease==true)][0].tag_name')

			# 确定当前版本类型（稳定版或 测试版）
			if [[ $current_version_tag == *"-alpha"* ]]; then
				echo "目前处于测试版.切换到稳定版..."
				echo ""
				new_version_tag=$latest_stable_version
			else
				echo "目前处于稳定版.切换到测试版..."
				echo ""
				new_version_tag=$latest_alpha_version
			fi

			# 更新前停止服务
			systemctl stop sing-box

			# 下载并替换二进制文件
			arch=$(uname -m)
			case $arch in
				x86_64) arch="amd64" ;;
				aarch64) arch="arm64" ;;
				armv7l) arch="armv7" ;;
			esac

			package_name="sing-box-${new_version_tag#v}-linux-${arch}"
			url="https://github.com/SagerNet/sing-box/releases/download/${new_version_tag}/${package_name}.tar.gz"

			curl -sLo "/root/${package_name}.tar.gz" "$url"
			tar -xzf "/root/${package_name}.tar.gz" -C /root
			mv "/root/${package_name}/sing-box" /root/sing-box

			# 清理软件包
			rm -r "/root/${package_name}.tar.gz" "/root/${package_name}"

			# 权限设置
			chown root:root /root/sing-box
			chmod +x /root/sing-box

			# 使用新二进制文件重启服务
			systemctl daemon-reload
			systemctl start sing-box

			echo "切换版本并使用新的二进制文件重启服务."
			echo ""
			exit 0
			;;

    5)
	            	echo "卸载..."
	            	# 停止并禁用sing-box
	            	systemctl stop sing-box
	            	systemctl disable sing-box > /dev/null 2>&1
	
	            	# 删除文件
	            	rm /etc/systemd/system/sing-box.service
	            	rm /root/reality.json
	            	rm /root/sing-box
			rm /root/public.key.b64
		    	echo "完成!"
	            	exit 0
	            	;;
	        	*)
	            	echo "选择无效。退出."
	            	exit 1
	            	;;
	    esac
	fi

		echo ""
  		echo "请选择安装版本:"
  		echo ""
		echo "1. 稳定版"
		echo "2. 测试版"
  		echo ""
		read -p "Enter your choice (1-2, default: 1): " version_choice
  		echo ""
		version_choice=${version_choice:-1}

		# 根据用户选择设置标签
		if [ "$version_choice" -eq 2 ]; then
			echo "安装测试版..."
   			echo ""
			latest_version_tag=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" | jq -r '[.[] | select(.prerelease==true)][0].tag_name')
		else
			echo "安装稳定版..."
   			echo ""
			latest_version_tag=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases" | jq -r '[.[] | select(.prerelease==false)][0].tag_name')
		fi

		# 无需再次获取最新版本，它已根据用户选择进行了设置
		latest_version=${latest_version_tag#v}  # Remove 'v' prefix from version number
		echo "最新版本: $latest_version"
  		echo ""

		# 检测服务器架构
		arch=$(uname -m)
		echo "Architecture: $arch"
  		echo ""

		# 地图架构名称
		case ${arch} in
			x86_64)
				arch="amd64"
				;;
			aarch64)
				arch="arm64"
				;;
			armv7l)
				arch="armv7"
				;;
		esac

# 准备软件包名称
package_name="sing-box-${latest_version}-linux-${arch}"

# 准备下载 URL
url="https://github.com/SagerNet/sing-box/releases/download/${latest_version_tag}/${package_name}.tar.gz"

# 下载最新版本软件包(.tar.gz) from GitHub
curl -sLo "/root/${package_name}.tar.gz" "$url"


# 解压缩软件包并将二进制文件移至 /root
tar -xzf "/root/${package_name}.tar.gz" -C /root
mv "/root/${package_name}/sing-box" /root/

# 清理软件包
rm -r "/root/${package_name}.tar.gz" "/root/${package_name}"

# 权限设置
chown root:root /root/sing-box
chmod +x /root/sing-box


# 生成配对密钥
echo "生成配对密钥..."
echo ""
key_pair=$(/root/sing-box generate reality-keypair)
echo "密钥对生成完成."
echo ""

# 提取私钥和公钥
private_key=$(echo "$key_pair" | awk '/PrivateKey/ {print $2}' | tr -d '"')
public_key=$(echo "$key_pair" | awk '/PublicKey/ {print $2}' | tr -d '"')

# 使用 base64 编码将公钥保存在文件中
echo "$public_key" | base64 > /root/public.key.b64

# 生成必要值
uuid=$(/root/sing-box generate uuid)
short_id=$(/root/sing-box generate rand --hex 8)

# 请求监听端口
read -p "Enter desired listen port (default: 443): " listen_port
listen_port=${listen_port:-443}
echo ""
# 输入优选域名 (sni)
read -p "Enter server name/SNI (默认: addons.mozilla.org): " server_name
echo ""
server_name=${server_name:-addons.mozilla.org}

# 获取IP 地址
server_ip=$(curl -s https://api.ipify.org)

# 使用 jq 创建 reality.json
jq -n --arg listen_port "$listen_port" --arg server_name "$server_name" --arg private_key "$private_key" --arg short_id "$short_id" --arg uuid "$uuid" --arg server_ip "$server_ip" '{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": ($listen_port | tonumber),
      "sniff": true,
      "sniff_override_destination": true,
      "domain_strategy": "ipv4_only",
      "users": [
        {
          "uuid": $uuid,
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": $server_name,
          "reality": {
          "enabled": true,
          "handshake": {
            "server": $server_name,
            "server_port": 443
          },
          "private_key": $private_key,
          "short_id": [$short_id]
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ]
}' > /root/reality.json

# 创建 sing-box
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/root/sing-box run -c /root/reality.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

# 检查配置并启动服务
if /root/sing-box check -c /root/reality.json; then
    echo "Configuration checked successfully. Starting sing-box service..."
    systemctl daemon-reload
    systemctl enable sing-box > /dev/null 2>&1
    systemctl start sing-box
    systemctl restart sing-box

# 生成链接

    server_link="vless://$uuid@$server_ip:$listen_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$server_name&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#SING-BOX-TCP"

    # 输出服务器详情
    echo
    echo "Server IP: $server_ip"
    echo "Listen Port: $listen_port"
    echo "Server Name: $server_name"
    echo "Public Key: $public_key"
    echo "Short ID: $short_id"
    echo "UUID: $uuid"
    echo ""
    echo ""
    echo "以下是 v2rayN 和 v2rayNG 的链接 :"
    echo ""
    echo ""
    echo "$订阅链接"
    echo ""
    echo ""
else
    echo "配置错误."
fi

