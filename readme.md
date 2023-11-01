aws eks --region us-east-1 update-kubeconfig --name my-eks-cluster


Installations:
You must have kubectl install on your local machines
You must install the helm in your local machine where you are running the terraform code machine

EBS CSI install:

Attch the ebs policy to the eks nodes roles add permissions and atatch the policy.

# Deploy EBS CSI Driver
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"

# Verify ebs-csi pods running
kubectl get pods -n kube-system

