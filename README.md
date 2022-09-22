# HashiCorp Boundary on Kubernetes
Deploy HashiCorp Boundary to a Kubernetes cluster.

> Note: I am pulling my images from my personal Dockerhub since I am running this on a RaspberryPi cluster and need an arm64 image.

## Requirements:
  - A Kubernetes cluster
  - A HashiCorp Vault cluster with a Transit key (for Boundary KMS)

## Set Up HashiCorp Vault
The following steps will enable the Transit secrets engine and create an encryption key. After that, a policy and token are created that will be used by Boundary.
```bash
# Enable the Transit secrets engine
$ vault secrets enable transit

# Create an encryption key for Boundary
$ vault write -f transit/keys/boundary

# Create a policy for Boundary
$ vault policy write boundary - <<EOF
path "transit/encrypt/boundary" {
  capabilities = ["update"]
}

path "transit/decrypt/boundary" {
  capabilities = ["update"]
}
EOF

# Create a periodic token for Boundary
$ vault token create -period=24h -policy=boundary 
Key                  Value
---                  -----
token                s.ewrhgvmoqINeQDavuJqkHIXh
token_accessor       WKM0BXNslYuo6jPvNVg0Vw4L
token_duration       24h
token_renewable      true
token_policies       ["boundary" "default"]
identity_policies    []
policies             ["boundary" "default"]
```
## Deployment Instructions
The following steps will deploy Boundary. Before proceeding, review the two DaemonSets and ConfigMaps to ensure all values are configured appropriately.

```bash
# Create a namespace for Boundary
$ kubectl create ns boundary
namespace/boundary created

# Create a secret that will hold the signed certificate for Boundary's API
$ kubectl -n boundary create secret tls tls \
  --cert=tls.crt \
  --key=tls.key

# Create a secret that will hold the Vault token generated above
$ kubectl -n boundary create secret generic \
  token --from-literal=token=s.ewrhgvmoqINeQDavuJqkHIXh
secret/token created

# Create opaque secret containing PostgreSQL credentials
$ kubectl -n boundary create secret generic psql-creds \
  --from-literal=username=postgres \
  --from-literal=password=postgres \
  --from-literal=database=boundary
secret/psql-creds created

# Create the dedicated service account for Boundary
$ kubectl -n boundary apply \
  -f boundary-serviceaccount.yaml
serviceaccount/boundary-sa created

# Deploy PostgreSQL
$ kubectl -n boundary apply \
  -f manifests/postgresql-statefulset.yaml \
  -f manifests/postgresql-service.yaml
statefulset.apps/postgresql created
service/postgresql created

# Deploy Configmaps for Boundary Controller and Worker
$ kubectl -n boundary apply \
  -f manifests/controller-config-configmap.yaml \
  -f manifests/worker-config-configmap.yaml
configmap/controller-config created
configmap/worker-config created

# Deploy the Kubernetes job to initalize the PostgreSQL database
$ kubectl -n boundary apply \
  -f manifests/database-init-job.yaml
job.batch/database-init created

# Deploy Boundary Controller daemonset and services
$ kubectl -n boundary apply \
  -f manifests/controller-daemonset.yaml \
  -f manifests/controller-api-service.yaml \
  -f manifests/controller-cluster-service.yaml
daemonset.apps/boundary-controller created
service/controller-api created
service/controller-cluster created

# Deploy Boundary Worker daemonset and services
$ kubectl -n boundary apply \
  -f manifests/worker-daemonset.yaml \
  -f manifests/worker-proxy-service.yaml
daemonset.apps/boundary-worker created
service/worker-proxy created

# Verify all pods and services are up and running
$ kubectl -n boundary get pods,svc
NAME                            READY   STATUS      RESTARTS   AGE
pod/boundary-controller-nn669   1/1     Running     0          67s
pod/boundary-worker-dzwqq       1/1     Running     0          56s
pod/database-init-58nnr         0/1     Completed   0          77s
pod/postgresql-0                1/1     Running     0          94s

NAME                         TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)          AGE
service/controller-api       LoadBalancer   10.116.8.179   192.168.1.119    9200:30011/TCP   67s
service/controller-cluster   ClusterIP      10.116.4.164   <none>           9201/TCP         67s
service/postgresql           ClusterIP      10.116.7.183   <none>           5432/TCP         93s
service/worker-proxy         ClusterIP      None           <none>           9202/TCP         56s
```
