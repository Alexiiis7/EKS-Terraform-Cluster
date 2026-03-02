The purpose for this project is to practice different topics related to AWS, EKS, Terraform and Kubernetes in a semi-coherent infrastructure. There are the topics I've touched on this far:

- Kubernetes:
  - Deployment:
    - Created a Deployment for a webpage service:
      - InitContainer to make the initial configuration (changing the default webpage location to /webpage and changing the default configuration files for nginx to make use of PHP FastCGI Process Manager).
      - Container in which I installed the necessary packages for the webpage to properly make use of PHP files. 
  - StatefulSet:
    - Created a StatefulSet for a mariadb service:
      - InitContainer which depending on the pod's name it will make use of a different configuration, the first pod (mariadb-ss-0) will make use of a specific configuration file stored in a ConfigMap.
      - Container with files from ConfigMap.
      - Created a volumeClaimTemplate making use of the default StorageClass.
  - ConfigMap:
    - Set up configuration files for pods' initial configuration.
  - Service:
    - Service creation:
      - LoadBalancer so that web requests are distributed through the different webpage pods.
      - Headless service so that the database makes use of the DNS service by default.
  - Secret:
    - Created an opaque Secret to store the database password.
  - Job:
    - Created a Job to create the initial database setup (the idea for now is to make changes to the database through Jobs).
  - Volumes:
    - PVC 
    - PV  
    - StorageClass

---

- MariaDB:
  - Created a master-replica setup.

---

- EKS:
  - Self-managed EKS Cluster:
    - Creation and initial configuration:
      - Attached specific VPC.
      - Added a few addons (CoreDNS, eks-pod-identity-agent, kube-proxy, vpc-cni, aws-ebs-csi-driver).
  - Self-managed node-group

---

- AWS:
  - IAM:
      - Role creation.
      - Assign Role to Service Account ebs-csi-controller-sa.
  - VPC:
      - VPC creation.

---
   
- Terraform:
  - Variables
  - Outputs:
    - Output creation:
      - Created an Output using a value from the data set I created for a LoadBalancer.
  - Modules
  - Data
  - Resources
    - Created Resources with YAML files as "kubernetes_manifest" resources.
    - Instead of manually adding the name of a ConfigMap for a volume I specified the Terraform resource name (kubernetes_config_map_v1.webpage-configmap.metadata[0].name)
  - Locals
