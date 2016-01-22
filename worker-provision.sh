#!/bin/bash

set -e

mkdir -p /etc/kubernetes/ssl/
mv /tmp/ca.pem /etc/kubernetes/ssl/ca.pem
mv /tmp/worker.pem /etc/kubernetes/ssl/worker.pem
mv /tmp/worker-key.pem /etc/kubernetes/ssl/worker-key.pem

chmod 0600 /etc/kubernetes/ssl/*-key.pem
chown root:root /etc/kubernetes/ssl/*-key.pem

mkdir -p /etc/systemd/system/flanneld.service.d/
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

mkdir -p /etc/kubernetes/manifests/
cat > /etc/kubernetes/manifests/kube-proxy.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: kube-proxy
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
    - name: kube-proxy
      image: gcr.io/google_containers/hyperkube:v1.1.2
      command:
        - /hyperkube
        - proxy
        - --master=https://192.168.50.100
        - --kubeconfig=/etc/kubernetes/worker-kubeconfig.yaml
        #- --proxy-mode=iptables
      securityContext:
        privileged: true
      volumeMounts:
        - mountPath: /etc/ssl/certs
          name: "ssl-certs"
        - mountPath: /etc/kubernetes/worker-kubeconfig.yaml
          name: "kubeconfig"
          readOnly: true
        - mountPath: /etc/kubernetes/ssl
          name: "etc-kube-ssl"
          readOnly: true
  volumes:
    - name: "ssl-certs"
      hostPath:
        path: "/usr/share/ca-certificates"
    - name: "kubeconfig"
      hostPath: 
        path: "/etc/kubernetes/worker-kubeconfig.yaml"
    - name: "etc-kube-ssl"
      hostPath:
        path: "/etc/kubernetes/ssl"
EOF

cat > /etc/kubernetes/worker-kubeconfig.yaml <<EOF
apiVersion: v1
kind: Config
clusters:
  - name: local
    cluster:
      certificate-authority: /etc/kubernetes/ssl/ca.pem
users:
  - name: kubelet
    user:
      client-certificate: /etc/kubernetes/ssl/worker.pem
      client-key: /etc/kubernetes/ssl/worker-key.pem
contexts:
  - context:
      cluster: local
      user: kubelet
    name: kubelet-context
current-context: kubelet-context
EOF

systemctl daemon-reload

systemctl start kubelet
systemctl enable kubelet

