#!/bin/bash


# ファイアウォール停止(すべてのルールをクリア)
/etc/rc.d/init.d/iptables stop

# デフォルトルール(以降のルールにマッチしなかった場合に適用するルール)設定
iptables -P INPUT   DROP   # 受信はすべて破棄
iptables -P OUTPUT  ACCEPT # 送信はすべて許可
iptables -P FORWARD DROP   # 通過はすべて破棄

# 自ホストからのアクセスをすべて許可
iptables -A INPUT -i lo -j ACCEPT

# 内部からのアクセスをすべて許可
iptables -A INPUT -s $LOCALNET -j ACCEPT

# 内部から行ったアクセスに対する外部からの返答アクセスを許可
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT


# ブロードキャストアドレス宛pingには応答しない
# ※Smurf攻撃対策
sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=1 > /dev/null
sed -i '/net.ipv4.icmp_echo_ignore_broadcasts/d' /etc/sysctl.conf
echo "net.ipv4.icmp_echo_ignore_broadcasts=1" >> /etc/sysctl.conf

# ICMP Redirectパケットは拒否
sed -i '/net.ipv4.conf.*.accept_redirects/d' /etc/sysctl.conf
for dev in `ls /proc/sys/net/ipv4/conf/`
do
    sysctl -w net.ipv4.conf.$dev.accept_redirects=0 > /dev/null
    echo "net.ipv4.conf.$dev.accept_redirects=0" >> /etc/sysctl.conf
done

# Source Routedパケットは拒否
sed -i '/net.ipv4.conf.*.accept_source_route/d' /etc/sysctl.conf
for dev in `ls /proc/sys/net/ipv4/conf/`
do
    sysctl -w net.ipv4.conf.$dev.accept_source_route=0 > /dev/null
    echo "net.ipv4.conf.$dev.accept_source_route=0" >> /etc/sysctl.conf
done

# フラグメント化されたパケットはログを記録して破棄
iptables -A INPUT -f -j LOG --log-prefix '[IPTABLES FRAGMENT] : '
iptables -A INPUT -f -j DROP

# 外部とのNetBIOS関連のアクセスはログを記録せずに破棄
# ※不要ログ記録防止
iptables -A INPUT ! -s $LOCALNET -p tcp -m multiport --dports 135,137,138,139,445 -j DROP
iptables -A INPUT ! -s $LOCALNET -p udp -m multiport --dports 135,137,138,139,445 -j DROP
iptables -A OUTPUT ! -d $LOCALNET -p tcp -m multiport --sports 135,137,138,139,445 -j DROP
iptables -A OUTPUT ! -d $LOCALNET -p udp -m multiport --sports 135,137,138,139,445 -j DROP

# 1秒間に4回を超えるpingはログを記録して破棄
# ※Ping of Death攻撃対策
iptables -N LOG_PINGDEATH
iptables -A LOG_PINGDEATH -m limit --limit 1/s --limit-burst 4 -j ACCEPT
iptables -A LOG_PINGDEATH -j LOG --log-prefix '[IPTABLES PINGDEATH] : '
iptables -A LOG_PINGDEATH -j DROP
iptables -A INPUT -p icmp --icmp-type echo-request -j LOG_PINGDEATH

# 全ホスト(ブロードキャストアドレス、マルチキャストアドレス)宛パケットはログを記録せずに破棄
# ※不要ログ記録防止
iptables -A INPUT -d 255.255.255.255 -j DROP
iptables -A INPUT -d 224.0.0.1 -j DROP

# 113番ポート(IDENT)へのアクセスには拒否応答
# ※メールサーバ等のレスポンス低下防止
iptables -A INPUT -p tcp --dport 113 -j REJECT --reject-with tcp-reset


#----------------------------------------------------------#
# 各種サービスを公開する場合の設定(ここから)               #
#----------------------------------------------------------#

# 外部からのTCP22番ポート(SSH)へのアクセスを日本からのみ許可
# ※SSHサーバーを公開する場合のみ
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# 外部からのTCP80番ポート(HTTP)へのアクセスを許可
# ※Webサーバーを公開する場合のみ
iptables -A INPUT -p tcp --dport 80 -j ACCEPT

# 外部からのTCP443番ポート(HTTPS)へのアクセスを許可
# ※Webサーバーを公開する場合のみ
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# 外部からのTCP21番ポート(FTP)へのアクセスを日本からのみ許可
# ※FTPサーバーを公開する場合のみ
iptables -A INPUT -p tcp --dport 21 -j ACCEPT

# 外部からのPASV用ポート(FTP-DATA)へのアクセスを日本からのみ許可
# ※FTPサーバーを公開する場合のみ
# ※PASV用ポート60000:60030は当サイトの設定例
iptables -A INPUT -p tcp --dport 60000:60030 -j ACCEPT

# 外部からのTCP25番ポート(SMTP)へのアクセスを許可
# ※SMTPサーバーを公開する場合のみ
iptables -A INPUT -p tcp --dport 25 -j ACCEPT


# 外部からのUDP1194番ポート(OpenVPN)へのアクセスを日本からのみ許可
# ※OpenVPNサーバーを公開する場合のみ
iptables -A INPUT -p tcp --dport 4949 -j ACCEPT
iptables -A INPUT -p udp --dport 4949 -j ACCEPT
iptables -A INPUT -p tcp --dport 10050 -j ACCEPT
iptables -A INPUT -p udp --dport 10050 -j ACCEPT

#----------------------------------------------------------#
# 各種サービスを公開する場合の設定(ここまで)               #
#----------------------------------------------------------#


# サーバー再起動時にも上記設定が有効となるようにルールを保存
/etc/rc.d/init.d/iptables save

# iptables 1.4.3.1バグ対処
iptables -V|grep 1.4.3.1 > /dev/null 2>&1
if [ $? -eq 0 ]; then
    sed -i s/"-s \!"/"\! -s"/g /etc/sysconfig/iptables
    sed -i s/"-d \!"/"\! -d"/g /etc/sysconfig/iptables
fi

# ファイアウォール起動
/etc/rc.d/init.d/iptables start


