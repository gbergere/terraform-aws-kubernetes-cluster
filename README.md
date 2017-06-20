# Kubernetes Cluster

Here is a kubernetes cluster module for terraform (to run on AWS).

## Requirements

* VPC
* S3 Endpoint (need one created to be retrieved via a terraform data).
* Route53 Host Zone (used as `cluster_dns`).
* Access to private subnet (VPN to reach instances in private subnets).
* Security group to allow you to reach the instances in SSH.

## How to use it

### Inputs

#### Required
* `cluster_name` Cluster name used by `KubernetesCluster` tags.
* `cluster_dns` Domain used to create DNS Records for the cluster (`etcd`, `api`).
* `vpc_id` VPC used to create subnets and route table for the cluster.
* `aws_az` Amazon AZ used to create subnets and route table for the cluster.
* `public_cidr_block` Block CIDR to use for public subnet (used by Kubernetes to create ELB).
* `private_cidr_block` Block CIDR to use for private subnet (where all instances are).
* `nat_internet_gateway` NAT Gateway to use for the private subnet as default gateway.
* `keypair` Keypair to use to create instances.

#### Optional
* `propagating_vgws`(array) Virtual Gateway to import routes in the route table.
* `whitelisted_ips` (array) Blocks CIDR to allow to reach kube-apiserver (default `0.0.0.0/0`).
* `additional_security_groups` (array) Additional security groups to apply to all instances.

### Example
```hcl
    provider "aws" {                         
      region = "eu-west-1"
    }
        
    module "k8s_cluster" {
      source = "github.com/gbergere/terraform-aws-kubernetes-cluster"
    
      # Cluster
      cluster_name = "my-cluster"
      cluster_dns  = "gbergeret.org"
    
      # VPC Networking
      vpc_id               = "vpc-xxxxxxxx"
      aws_az               = "eu-west-1a"
      public_cidr_block    = "192.168.0.0/24"
      private_cidr_block   = "192.168.1.0/24"
      nat_internet_gateway = "nat-xxxxxxxxxxxxxxxxx"
     
      # EC2
      keypair = "my-keypair"
    }
```

## References

In order to write the module I've been inspired by 
[Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) from 
[Kelsey Hightower](https://github.com/kelseyhightower) and 
[Kubernetes: Getting Started with CoreOS](https://coreos.com/kubernetes/docs/latest/getting-started.html)
