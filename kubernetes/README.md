# Kubernetes Deployment

### Prerequisites: 
- Kubernetes Cluster
- kubectl commandline

Note, i use longhorn block storage for persistant volume and nginx ingress controller. Kubernetes engine which i use is RKE (Rancher Kubernetes Engine). If you use different block storage and ingress maybe you need to change some configuration.

## deploy to kubernetes cluster

1. You need to change some line inside blockscout-configmap.yml file.

2. Apply Configmap with this command :

```bash
kubectl apply -f blockscout-configmap.yml
```

3. Deploy blockscout with :

```bash
kubectl apply -f explorer-blockscout.yml
```