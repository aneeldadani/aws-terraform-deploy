# AWS Demo (Terraform)

## Overview

This Terraform project provisions a demo AWS environment that deploys an application behind an Application Load Balancer (ALB) with HTTPS enabled via Route 53 and ACM.

It is intended for **demo / lab use only**, not production.

---

## What This Project Creates

* VPC with public and private subnets
* Application Load Balancer (ALB)
* Target group + listener (HTTP → HTTPS redirect)
* EC2 instance running the demo application
* Security groups
* Route 53 DNS record
* ACM certificate (for HTTPS)

---

## Prerequisites

Before using this project, make sure you have:

### 1. AWS Account

* A valid AWS account
* Permissions to create:

  * EC2
  * VPC
  * IAM (if extended later)
  * Route 53
  * ACM

### 2. AWS Authentication

This project **does NOT hardcode credentials**. It uses standard AWS authentication via environment variables or profiles.

You must configure ONE of the following:

#### Option A: AWS Profile (Recommended)

```bash
aws configure sso
# or
aws configure
```

Then export:

```bash
export AWS_PROFILE=your-profile-name
```

#### Option B: Environment Variables

```bash
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_SESSION_TOKEN=your_session_token  # if using temporary credentials
```

---

### 3. Terraform

* Terraform >= 1.5 recommended

Check version:

```bash
terraform version
```

---

### 4. Route 53 Hosted Zone

You must already have a **public hosted zone** in Route 53.

Example:

```
example.com
```

---

## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/aneeldadani/aws-terraform-deploy.git
cd aws-terraform-deploy 
```

---

### 2. Create Your Variables File

Copy the example file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
name        = "salt-demo"
aws_region  = "us-west-2"

domain_name = "example.com"
record_name = "demo"

allowed_ingress_cidrs = ["YOUR_PUBLIC_IP/32"]

app_port = 80
```

---

## Important Variables

| Variable                | Description                                    |
| ----------------------- | ---------------------------------------------- |
| `domain_name`           | Your Route 53 hosted zone (e.g. `example.com`) |
| `record_name`           | Subdomain to create (e.g. `demo`)              |
| `allowed_ingress_cidrs` | CIDR blocks allowed to access the ALB          |
| `app_port`              | Port your application listens on               |

---

## Deploying the Infrastructure

### Initialize Terraform

```bash
terraform init
```

### Review Plan

```bash
terraform plan
```

### Apply Changes

```bash
terraform apply
```

Type `yes` when prompted.

---

## Accessing the Application

Once deployment completes, you can access the app at:

```
https://<record_name>.<domain_name>
```

Example:

```
https://demo.example.com
```

---

## Important Notes

### Private Subnet (No Direct SSH)

The EC2 instance is deployed in a **private subnet**, meaning:

* No direct SSH access from the internet
* You would need:

  * AWS SSM Session Manager (recommended), or
  * A bastion host / VPN

---

### Security Considerations

* Do NOT use `0.0.0.0/0` unless necessary
* Restrict `allowed_ingress_cidrs` to your IP
* This project is **not hardened for production**

---

### Demo-Only Warning

This project may deploy:

* intentionally vulnerable/demo applications
* simplified networking and security configurations

**Do not use in production environments.**

---

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

---

## Project Structure

```
.
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── terraform.tfvars.example
├── user_data.sh.tpl
├── .gitignore
└── README.md
```

---

## Future Improvements (Optional)

* Add SSM IAM role for EC2 access
* Enable IMDSv2 enforcement
* Add WAF in front of ALB
* Expand tagging strategy
* Add CI/CD (GitHub Actions)

---

## License

MIT

---

## Author

Aneel Dadani
