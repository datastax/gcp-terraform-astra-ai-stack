## DataStax AI stack (GCP) with a custom domain

## Table of contents

1. [Overview](#1-overview)
2. [Installation and Prerequisites](#2-installation-and-prerequisites)
3. [Setup](#3-setup)
4. [Deployment](#4-deployment)
5. [Cleanup](#5-cleanup)

## 1. Overview

### 1.1 - About this module

Terraform module which helps you quickly deploy an opinionated AI/RAG stack to your cloud provider of choice, provided by DataStax.

It offers multiple easy-to-deploy components, including:
 - Langflow
 - Astra Assistants API
 - Astra Vector Databases

### 1.2 - About this example

This example uses the GCP variant of the module, and allows you to deploy langflow/assistants easily using Cloud Run, using a custom domain.

There are a few ways to go about this:
- The more managed way, where we create a CloudDNS manged zone for you, and all you have to do is add the nameserver records to your DNS, or
- A slighty less managed way, where you can pass in the ID of an exisiting CloudDNS zone, or
- The least managed way, where you need to configure your DNS to point to the output `load_balancer_ip` yourself manually

This example will follow the first method.

## 2. Installation and Prerequisites

### 2.1 - Terraform installation

You will need to install the Terraform CLI to use Terraform. Follow the steps below to install it, if you still need to.

- ✅ `2.1.a` Visit the Terraform installation page to install the Terraform CLI

https://developer.hashicorp.com/terraform/install

- ✅ `2.1.b` After the installation completes, verify that Terraform is installed correctly by checking its version:

```sh
terraform -v
```

### 2.2 - Astra token w/ sufficient perms

Additionally, you'll need a DataStax AstraDB token to enable creation and management of any vector databases.

The token must have the sufficient perms to manage DBs, as shown in the steps below.

- ✅ `2.2.a` Connect to [https://astra.datastax.com](https://astra.datastax.com)

![https://raw.githubusercontent.com/datastax/terraform-astra-ai-stack/main/assets/astra/login.png](https://raw.githubusercontent.com/datastax/terraform-astra-ai-stack/main/assets/astra/login.png)

- ✅ `2.2.b` Navigate to token and generate a token with `Organization Administrator` permissions and copy the token starting by `AstraCS:...`

![https://raw.githubusercontent.com/datastax/terraform-astra-ai-stack/main/assets/astra/token.png](https://raw.githubusercontent.com/datastax/terraform-astra-ai-stack/main/assets/astra/token.png)

Keep the token secure, as you won't be able to access it again!

### 2.3 - Obtaining your GCP billing account

You can provide your own project ID if you want to plug the components into an exisitng project, but for the purposes of
this example, the module will create one for you. All you need to provide is a billing account ID.

Below is a short guide on how to obtain them, but you can find more detail over at the official 
[GCP documentation](https://cloud.google.com/billing/docs/how-to/find-billing-account-id).

- ✅ `2.3.a` - Access the Billing Management console in GCP

https://console.cloud.google.com/billing/manage

- ✅ `2.3.b` - Select the billing account you'd like to use here (if you have multiple)

![https://raw.githubusercontent.com/datastax/terraform-astra-ai-stack/main/assets/gcp/billing-account-selection.png](https://raw.githubusercontent.com/datastax/terraform-astra-ai-stack/main/assets/gcp/billing-account-selection.png)

- ✅ `2.3.c` - You can find the billing account ID near the top-right corner of the page

![https://raw.githubusercontent.com/datastax/terraform-astra-ai-stack/main/assets/gcp/billing-account-id.png](https://raw.githubusercontent.com/datastax/terraform-astra-ai-stack/main/assets/gcp/billing-account-id.png)

Again, keep this secure!

## 3. Setup

### 3.1 - Cloning the sample project

- ✅ `3.1.a` - Clone the same project through the following git command:

```sh
git clone https://github.com/datastax/terraform-gcp-astra-ai-stack.git
```

- ✅ `3.1.b` - Then, find your way to the correct diectory:

```sh
cd terraform-gcp-astra-ai-stack/examples/gcp-no-custom-domain
```

### 3.2 - Initialize Terraform

- ✅ `3.2.a` - In this specific example directory, simply run `terraform init`, and wait as it downloads all of the necessary dependencies.

```sh
terraform init
```

## 4. Deployment

### 4.1 - Actually deploying

- ✅ `4.1.a` - Run the following command to list out the components to be created. The `dns_name` will be the apex domain you'd like to use
for the services (e.g. `gcp.enterprise-ai-stack.com`). Remember that this must be a domain which you own/have control over.

```sh
terraform plan -var="astra_token=<your_astra_token>" -var="billing_account=<account_id>" -var="dns_name=<apex_domain>"
```

- ✅ `4.1.b` - Once you're ready to commit to the deployment, run the following command, and type `yes` after double-checking that it all looks okay

```sh
terraform apply -var="astra_token=<your_astra_token>" -var="billing_account=<account_id>" -var="dns_name=<apex_domain>"
```

- ✅ `4.1.c` - Simply wait for it to finish deploying everything—it may take a hot minute!

### 4.2 - Accessing your deployments

- ✅ `4.2.a` - Run the following command to access the variables output from deploying the infrastructure

```sh
terraform output datastax-ai-stack-gcp
```

- ✅ `4.2.b` - Access Langflow

In your browser, go to the URL given by the output `service_uris.langflow` to access Langflow.

Note that it may take the SSL cert some time to properly work, and you may get 'unsupported protocol' errors for a bit.

- ✅ `4.2.c` - Access Astra Assistants API

You can access the Astra Assistants API through the URL given by the output `service_uris.assistants` through your HTTP client of choice. e.g:

```sh
curl datastax-assistants-alb-1234567890.some-region.elb.amazonaws.com/metrics
```

Note that it may take the SSL cert some time to properly work, and you may get 'unsupported protocol' errors for a bit.

- ✅ `4.2.d` - Access your Astra Vector DB

You can connect to your Astra DB instance through your method of choice, using `astra_vector_dbs.<db_id>.endpoint`.

The [Data API clients](https://docs.datastax.com/en/astra-db-serverless/api-reference/overview.html) are heavily recommended for this.

## 5. Cleanup

### 5.1 - Destruction

- ✅ `5.1.a` - When you're done, you can easily tear everything down with the following command:

```sh
terraform destroy -var="astra_token=<your_astra_token>" -var="billing_account=<account_id>" -var="dns_name=<apex_domain>"
```
