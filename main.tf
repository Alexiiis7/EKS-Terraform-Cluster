terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.30.0"
    }
  }
}

provider "aws" {
  region = var.region
  access_key=var.AWS_ACCESS_KEY
  secret_key=var.AWS_SECRET_KEY
}

locals {
    zones = ["${var.region}a", "${var.region}b"]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"

  name = "terraform-vpc"
  cidr = "10.0.0.0/16"

  azs  = local.zones
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

}

module "eks-cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name    = "cluster-test"
  kubernetes_version = "1.33"

  #Disables EKS Auto Mode (it's enabled by default)
  compute_config = {
    enabled = false
  }

  addons = {
    coredns                = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy             = {}
    vpc-cni                = {
      before_compute = true
    }
    aws-ebs-csi-driver = {
      service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
    }
  }

  #Both are optional, the latter adds current caller identity as an administrator via cluster access entry
  endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  #Here we specify which VPC the cluster will make use of
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  #Node group definition
  eks_managed_node_groups = {
    one = {
      name = "node-group-1"

      instance_types = ["t3.small"]

      min_size     = 1
      max_size     = 2
      desired_size = 2
    }
  }
}

# https://aws.amazon.com/blogs/containers/amazon-ebs-csi-driver-is-now-generally-available-in-amazon-eks-add-ons/ 
data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.39.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}

provider "kubernetes" {
  config_path = "C:/Users/alexi/.kube/config"
}

resource "kubernetes_deployment_v1" "terraform-deployment" {
  metadata {
    name = "webpage-deployment"
    labels = {
      kind = "deployment"
    }
  }

  spec {
    replicas = 3
    selector {
      match_labels = {
        app = "website"
      }
    }
    template {
      metadata {
        labels = {
          app = "website"
        }
      }
      spec {
        init_container {
          name = "websetup"
          image = "nginx:stable"
          args = ["/bin/sh", "-c", "cp /mnt/config-map/index.html /webpage/index.html; cp /mnt/config-map/login.php /webpage/login.php; cp /mnt/config-map/default.conf /etc/nginx/conf.d/default.conf; cp /mnt/config-map/www.conf /etc/php/8.4/fpm/pool.d/www.conf; chmod 755 /webpage/index.html; chmod 755 /webpage/login.php"]
          port {
            container_port = 80
          }
          volume_mount {
            name = "webpage"
            mount_path = "/webpage/"
          }
          volume_mount {
            name = "configmapvolume"
            mount_path = "/mnt/config-map/"
          }
          volume_mount {
            name = "configvolume1"
            mount_path = "/etc/nginx/conf.d/"
          }
          volume_mount {
            name = "configvolume2"
            mount_path = "/etc/php/8.4/fpm/pool.d/"
          }
        }
        container {
          name = "webserver"
          image = "nginx:stable"
          liveness_probe {
            failure_threshold = 3
            http_get {
              path = "/"
              port = 80
              scheme = "HTTP"
            }
            initial_delay_seconds = 30
            period_seconds = 60
            success_threshold = 1
            timeout_seconds = 5
          }
          lifecycle {
            post_start {
              exec {
                command = ["/bin/sh", "-c", "apt update -y; apt install php8.4-fpm -y; apt install php8.4-mysql -y; service php8.4-fpm start; service nginx reload"]
              }
            }
          }
          port {
            container_port = 80
          }
          volume_mount {
            name = "webpage"
            mount_path = "/webpage/"
          }
          volume_mount {
            name = "configvolume1"
            mount_path = "/etc/nginx/conf.d/"
          }
          volume_mount {
            name = "configvolume2"
            mount_path = "/etc/php/8.4/fpm/pool.d/"
          }
        }
        volume {
          name = "webpage"
          empty_dir {}
        }
        volume {
          name = "configmapvolume"
          config_map {
            name = kubernetes_config_map_v1.webpage-configmap.metadata[0].name
          }
        }
        volume {
          name = "configvolume1"
          empty_dir {}
        }
        volume {
          name = "configvolume2"
          empty_dir {}
        }
      }
    }
  }
} 

resource "kubernetes_config_map_v1" "webpage-configmap" {
  metadata {
    name = "webpageconfigmap"
  }
  data = {
"index.html" = <<EOT
<html>
  <body>
    <form action="login.php" method="get">User: <input type="text" name="databaseUsername"><br>Password: <input type="password" name="databasePassword"><br><input type="submit"></form>
  </body>
</html>
EOT
"login.php" = <<EOT
<?php $databaseHost = "mariadb-ss-0.mariadb-service.default.svc.cluster.local";
$databaseName = "users";
$mysqli = mysqli_connect(
    $databaseHost,
    $_GET["databaseUsername"],
    $_GET["databasePassword"],
    $databaseName
);
if (mysqli_connect_errno()) {
    printf("Connect failed: %s\n", mysqli_connect_error());
    exit();
}
$sql = "SELECT * FROM userlist;";
if ($mysqli->multi_query($sql)) {
    do {
        if ($result = $mysqli->use_result()) {
            while ($row = $result->fetch_row()) {
                printf("%s\n", $row[0]);
            }
            $result->close();
        }
        if ($mysqli->more_results()) {
            printf("-\n");
        }
    } while ($mysqli->next_result());
}
$mysqli->close(); ?>
EOT
"default.conf" = <<EOT
server {
    listen       80;
    listen  [::]:80;
    server_name  localhost;

    location / {
        root   /webpage;
        index  index.html index.htm;
    }

      location ~ \.php$ {
          root           html;
          fastcgi_pass   unix:/var/run/php/php8.4-fpm.sock;
          fastcgi_index  index.php;
          fastcgi_param  SCRIPT_FILENAME  /webpage$fastcgi_script_name;
          include        fastcgi_params;
      }
}
EOT
"www.conf" = <<EOT
[www]
user = nginx
group = nginx
listen = /run/php/php8.4-fpm.sock
listen.owner = nginx
listen.group = nginx
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
EOT
  }
}

resource "kubernetes_service_v1" "webpage-load-balancer" {
  metadata {
    name = "web-loadbalancer"
  }
  spec {
    port {
      port = 80
      protocol = "TCP"
      target_port = 80
    }
    selector = {
        app = "website"
    }
    type = "LoadBalancer"
  }
}

data "kubernetes_service_v1" "webpage-load-balancer" {
  metadata {
    name = "web-loadbalancer"
  }
}

resource "kubernetes_manifest" "dbconfigmap" {
  manifest = yamldecode(file("yaml-files/dbconfigmap.yaml"))
}

resource "kubernetes_manifest" "dbsecret" {
  manifest = yamldecode(file("yaml-files/dbsecret.yaml"))
}

resource "kubernetes_manifest" "dbservice" {
  manifest = yamldecode(file("yaml-files/dbservice.yaml"))
}

resource "kubernetes_manifest" "dbstatefulset" {
  manifest = yamldecode(file("yaml-files/dbstatefulset.yaml"))
}

resource "kubernetes_manifest" "dbcreationjob" {
  manifest = yamldecode(file("yaml-files/dbcreationjob.yaml"))
}