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

# Save Certs and Key
cat <<EOF > /etc/kubernetes/ssl/ca.pem
${ca_pem}
EOF
cat <<EOF > /etc/kubernetes/ssl/key.pem
${key_pem}
EOF
chmod 600 /etc/kubernetes/ssl/key.pem
cat <<EOF > /etc/kubernetes/ssl/cert.pem
${cert_pem}
EOF

mkdir -p /opt/bin
cd /opt/bin
wget https://storage.googleapis.com/kubernetes-release/release/${version}/bin/linux/amd64/kubectl
chmod +x kubectl

cat > /etc/systemd/system/kubelet.service <<EOF
[Service]
Environment=KUBELET_IMAGE_TAG=${version}_coreos.0
Environment="RKT_RUN_ARGS=--uuid-file-save=/var/run/kubelet-pod.uuid \
  --volume var-log,kind=host,source=/var/log \
  --mount volume=var-log,target=/var/log \
  --volume dns,kind=host,source=/etc/resolv.conf \
  --mount volume=dns,target=/etc/resolv.conf"
ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests
ExecStartPre=/usr/bin/mkdir -p /var/log/containers
ExecStartPre=-/usr/bin/rkt rm --uuid-file=/var/run/kubelet-pod.uuid
ExecStart=/usr/lib/coreos/kubelet-wrapper \
  --allow-privileged=true \
  --api-servers=http://127.0.0.1:8080 \
  --cloud-provider=aws \
  --cluster-dns=10.0.0.10 \
  --cluster_domain=cluster.local \
  --container-runtime=docker \
  --hostname-override=$FQDN \
  --network-plugin=kubenet \
  --non-masquerade-cidr=10.10.0.0/16 \
  --pod-manifest-path=/etc/kubernetes/manifests \
  --register-schedulable=${master_register_schedulable}
ExecStop=-/usr/bin/rkt stop --uuid-file=/var/run/kubelet-pod.uuid
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/kubernetes/manifests/kube-apiserver.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-apiserver
    image: gcr.io/google_containers/hyperkube-amd64:${version}
    command:
    - /hyperkube
    - apiserver
    - --admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota
    - --advertise-address=$INTERNAL_IP
    - --allow-privileged=true
    - --apiserver-count=1
    - --bind-address=0.0.0.0
    - --client-ca-file=/etc/kubernetes/ssl/ca.pem
    - --cloud-provider=aws
    - --insecure-bind-address=127.0.0.1
    - --etcd-cafile=/etc/kubernetes/ssl/ca.pem
    - --etcd-certfile=/etc/kubernetes/ssl/cert.pem
    - --etcd-keyfile=/etc/kubernetes/ssl/key.pem
    - --etcd-servers=${etcd_url}
    - --etcd-prefix=/registry/${cluster_name}
    - --service-account-key-file=/etc/kubernetes/ssl/key.pem
    - --service-cluster-ip-range=10.0.0.0/16
    - --service-node-port-range=${service_node_port_range}
    - --runtime-config=extensions/v1beta1/networkpolicies=true
    - --tls-cert-file=/etc/kubernetes/ssl/cert.pem
    - --tls-private-key-file=/etc/kubernetes/ssl/key.pem
    - --v=2
    livenessProbe:
      httpGet:
        host: 127.0.0.1
        port: 8080
        path: /healthz
      initialDelaySeconds: 15
      timeoutSeconds: 15
    ports:
    - containerPort: 6443
      hostPort: 6443
      name: https
    - containerPort: 8080
      hostPort: 8080
      name: local
    volumeMounts:
    - mountPath: /etc/kubernetes/ssl
      name: ssl-certs-kubernetes
      readOnly: true
    - mountPath: /etc/ssl/certs
      name: ssl-certs-host
      readOnly: true
  volumes:
  - hostPath:
      path: /etc/kubernetes/ssl
    name: ssl-certs-kubernetes
  - hostPath:
      path: /usr/share/ca-certificates
    name: ssl-certs-host
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
    - --logtostderr=true
    - --master=http://127.0.0.1:8080
    - --masquerade-all=true
    - -v=2
    securityContext:
      privileged: true
    volumeMounts:
    - mountPath: /etc/ssl/certs
      name: ssl-certs-host
      readOnly: true
  volumes:
  - hostPath:
      path: /usr/share/ca-certificates
    name: ssl-certs-host
EOF

cat > /etc/kubernetes/manifests/kube-controller-manager.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: kube-controller-manager
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-controller-manager
    image: gcr.io/google_containers/hyperkube-amd64:${version}
    command:
    - /hyperkube
    - controller-manager
    - --allocate-node-cidrs=true
    - --cloud-provider=aws
    - --cluster-cidr=10.10.0.0/16
    - --cluster-name=${cluster_name}
    - --leader-elect=true
    - --master=http://127.0.0.1:8080
    - --root-ca-file=/etc/kubernetes/ssl/ca.pem
    - --service-account-private-key-file=/etc/kubernetes/ssl/key.pem
    - --service-cluster-ip-range=10.0.0.0/16
    resources:
      requests:
        cpu: 200m
    livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: 10252
      initialDelaySeconds: 15
      timeoutSeconds: 15
    volumeMounts:
    - mountPath: /etc/kubernetes/ssl
      name: ssl-certs-kubernetes
      readOnly: true
    - mountPath: /etc/ssl/certs
      name: ssl-certs-host
      readOnly: true
  volumes:
  - hostPath:
      path: /etc/kubernetes/ssl
    name: ssl-certs-kubernetes
  - hostPath:
      path: /usr/share/ca-certificates
    name: ssl-certs-host
EOF

cat > /etc/kubernetes/manifests/kube-scheduler.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: kube-scheduler
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-scheduler
    image: gcr.io/google_containers/hyperkube-amd64:${version}
    command:
    - /hyperkube
    - scheduler
    - --master=http://127.0.0.1:8080
    - --leader-elect=true
    resources:
      requests:
        cpu: 100m
    livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: 10251
      initialDelaySeconds: 15
      timeoutSeconds: 15
EOF

systemctl daemon-reload
systemctl enable kubelet
systemctl start kubelet

sleep 360 

# Deploy kube-dns
curl https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/dns/kubedns-cm.yaml | /opt/bin/kubectl apply -f -
curl https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/dns/kubedns-sa.yaml | /opt/bin/kubectl apply -f -
curl https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/dns/kubedns-controller.yaml.sed | sed 's/$DNS_DOMAIN/cluster.local/g' | /opt/bin/kubectl apply -f - 
curl https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/dns/kubedns-svc.yaml.sed | sed 's/$DNS_SERVER_IP/10.0.0.10/g' | /opt/bin/kubectl apply -f - 
# Deploy Kubernetes dashboard
/opt/bin/kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/kubernetes-dashboard.yaml
