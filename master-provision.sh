#!/bin/bash

mkdir -p /etc/kubernetes/ssl/
mv /tmp/*pem /etc/kubernetes/ssl/
chmod 0600 etc/kubernetes/ssl/*-key.pem
chown root:root etc/kubernetes/ssl/*-key.pem

# FLANNEL
mkdir -p /etc/flannel
cat > /etc/flannel/options.env << EOF
FLANNELD_IFACE=192.168.50.100
FLANNELD_ETCD_ENDPOINTS=http://192.168.50.101:2379/
EOF

mkdir -p etc/systemd/system/flanneld.service.d/
cat > /etc/systemd/system/flanneld.service.d/40-ExecStartPre-symlink.conf << EOF
[Service]
ExecStartPre=/usr/bin/ln -sf /etc/flannel/options.env /run/flannel/options.env
EOF

mkdir -p /etc/systemd/system/docker.service.d/
cat > /etc/systemd/system/docker.service.d/40-flannel.conf << EOF
[Unit]
Requires=flanneld.service
After=flanneld.service
EOF


# Kubelet
mkdir -p /etc/systemd/system/
cat > /etc/systemd/system/kubelet.service << EOF
[Service]
ExecStart=/usr/bin/kubelet \
	--api_servers=http://127.0.0.1:8080 \
	--register-node=false \
	--allow-privileged=true \
	--config=/etc/kubernetes/manifests \
	--hostname-override=192.168.50.100 \
	--cluster-dns=192.168.50.53 \
	--cluster-domain=cluster.local
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF

mkdir -p /etc/kubernetes/manifests/
mv /tmp/master-manifests/*yaml /etc/kubernetes/manifests/

systemctl daemon-reload

curl -s -X PUT -d "value={\"Network\":\"10.2.0.0/16\",\"Backend\":{\"Type\":\"vxlan\"}}" "http://192.168.50.101:2379/v2/keys/coreos.com/network/config"

systemctl start kubelet
systemctl enable kubelet


