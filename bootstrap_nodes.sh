#!/bin/bash

###
# Variables
##

LOG_FILE=/var/log/bootstrap.log
INTERNAL_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
FQDN=$(curl http://169.254.169.254/latest/meta-data/hostname)

###
# Redirecting STDOUT and STDERR to LOG_FILE
##

# Close STDOUT file descriptor
exec 1<&-
# Close STDERR FD
exec 2<&-
# Open STDOUT as $LOG_FILE file for read and write.
exec 1<>$LOG_FILE
# Redirect STDERR to STDOUT
exec 2>&1

###
# Start Bootstrap process
##
 
# Create directories
mkdir -p /etc/kubernetes/{manifests,ssl}
mkdir -p /var/lib/kubelet

# Save Certs and Key
cat <<EOF > /etc/kubernetes/ssl/ca.pem
${ca_pem}
EOF
cat <<EOF > /etc/kubernetes/ssl/ca-key.pem
${ca_key_pem}
EOF
chmod 600 /etc/kubernetes/ssl/ca-key.pem

mkdir -p /opt/bin && cd /opt/bin
wget https://storage.googleapis.com/kubernetes-release/release/${version}/bin/linux/amd64/kubectl
curl -s -L -o cfssl https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
curl -s -L -o cfssljson https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
chmod +x cfssl cfssljson
chmod +x kubectl

cat > /etc/kubernetes/ssl/ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > /etc/kubernetes/ssl/kubelet-csr.json <<EOF
{
  "CN": "system:node:$FQDN",
  "hosts": [
    "127.0.0.1",
    "$FQDN",
    "$INTERNAL_IP"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Cluster",
      "ST": "Oregon"
    }
  ]
}
EOF

cd /etc/kubernetes/ssl/
/opt/bin/cfssl gencert \
  -ca=/etc/kubernetes/ssl/ca.pem \
  -ca-key=/etc/kubernetes/ssl/ca-key.pem \
  -config=/etc/kubernetes/ssl/ca-config.json \
  -profile=kubernetes \
  kubelet-csr.json | /opt/bin/cfssljson -bare kubelet

/opt/bin/kubectl config set-cluster ${cluster_name} \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --server=${api_url} \
  --kubeconfig=/var/lib/kubelet/kubeconfig

/opt/bin/kubectl config set-credentials kubelet \
  --client-certificate=/etc/kubernetes/ssl/kubelet.pem \
  --client-key=/etc/kubernetes/ssl/kubelet-key.pem \
  --kubeconfig=/var/lib/kubelet/kubeconfig

/opt/bin/kubectl config set-context default \
  --cluster=${cluster_name} \
  --user=kubelet \
  --kubeconfig=/var/lib/kubelet/kubeconfig

/opt/bin/kubectl config use-context default --kubeconfig=/var/lib/kubelet/kubeconfig

sleep 180

cat > /etc/systemd/system/kubelet.service <<EOF
[Service]
Environment=KUBELET_IMAGE_TAG=${version}_coreos.0
Environment="RKT_RUN_ARGS=--uuid-file-save=/var/run/kubelet-pod.uuid \
  --volume dns,kind=host,source=/etc/resolv.conf \
  --mount volume=dns,target=/etc/resolv.conf \
  --volume var-log,kind=host,source=/var/log \
  --mount volume=var-log,target=/var/log"
ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests
ExecStartPre=/usr/bin/mkdir -p /var/log/containers
ExecStartPre=-/usr/bin/rkt rm --uuid-file=/var/run/kubelet-pod.uuid
ExecStart=/usr/lib/coreos/kubelet-wrapper \
  --allow-privileged=true \
  --api-servers=${api_url} \
  --cloud-provider=aws \
  --cluster_dns=10.0.0.10 \
  --cluster_domain=cluster.local \
  --container-runtime=docker \
  --hostname-override=$FQDN \
  --kubeconfig /var/lib/kubelet/kubeconfig \
  --network-plugin=kubenet \
  --non-masquerade-cidr=10.10.0.0/16 \
  --pod-manifest-path=/etc/kubernetes/manifests \
  --register-node=true \
  --tls-cert-file=/etc/kubernetes/ssl/kubelet.pem \
  --tls-private-key-file=/etc/kubernetes/ssl/kubelet-key.pem
ExecStop=-/usr/bin/rkt stop --uuid-file=/var/run/kubelet-pod.uuid
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

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
    image: gcr.io/google_containers/hyperkube-amd64:${version}
    command:
    - /hyperkube
    - proxy
    - --cluster-cidr=10.10.0.0/16
    - --kubeconfig=/var/lib/kubelet/kubeconfig
    - --logtostderr=true
    - --masquerade-all=true
    - -v=2
    securityContext:
      privileged: true
    volumeMounts:
    - mountPath: /etc/ssl/certs
      name: "ssl-certs"
    - mountPath: /var/lib/kubelet/kubeconfig
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
      path: "/var/lib/kubelet/kubeconfig"
  - name: "etc-kube-ssl"
    hostPath:
      path: "/etc/kubernetes/ssl"
EOF

systemctl daemon-reload
systemctl enable kubelet
systemctl start kubelet
