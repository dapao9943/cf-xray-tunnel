#!/bin/bash

# 更新系统
apt update && apt install -y curl unzip wget sudo

# 安装 Xray-Core
mkdir -p /etc/xray
cd /etc/xray || exit
wget https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip Xray-linux-64.zip && chmod +x xray

# 生成配置文件
UUID="a7fc2d51-cd74-4ffe-a460-83fad655465d"
cat > /etc/xray/config.json <<EOF
{
  "inbounds": [
    {
      "port": 8001,
      "protocol": "vmess",
      "settings": {
        "clients": [{ "id": "$UUID" }]
      }
    },
    {
      "port": 8002,
      "protocol": "trojan",
      "settings": {
        "clients": [{ "password": "$UUID" }]
      }
    }
  ],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

# 创建 systemd 启动服务
cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
ExecStart=/etc/xray/xray -config /etc/xray/config.json
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl enable xray
systemctl restart xray

# 安装 Cloudflare Tunnel
echo "安装 cloudflared 中..."
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared

# 用户交互设置 Tunnel
read -p "请输入 Cloudflare Tunnel token（格式 eyJhIj...）: " CF_TOKEN
read -p "请输入你绑定的固定隧道域名（如 cf.example.com）: " CF_DOMAIN

mkdir -p /root/.cloudflared
echo "$CF_TOKEN" > /root/.cloudflared/cert.json

# 启动隧道到本地 8001
nohup cloudflared tunnel --url http://localhost:8001 --hostname "$CF_DOMAIN" --origincert /root/.cloudflared/cert.json >/dev/null 2>&1 &

echo -e "\n部署完成！"
echo "------------------------------------"
echo "VMess UUID: $UUID"
echo "端口: 8001"
echo "协议: vmess"
echo "固定隧道地址: https://$CF_DOMAIN"
echo "（trojan节点端口为8002，密码与UUID相同）"
echo "建议设置保活：定时访问 https://$CF_DOMAIN/ping"
echo "------------------------------------"
