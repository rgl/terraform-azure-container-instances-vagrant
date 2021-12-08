# About

This shows how to create a [Azure Container Instances Container Group](https://docs.microsoft.com/en-us/azure/container-instances/container-instances-container-groups) with [Caddy (for Let's Encrypt TLS Certificate)](https://hub.docker.com/_/caddy) reverse proxy for an internal test container.

This is wrapped in a vagrant environment to make it easier to play with this stack without changing your local machine.

## Usage

If you are using Hyper-V, [configure Hyper-V in your local machine](https://github.com/rgl/windows-vagrant#hyper-v-usage).

If you are using libvirt, you should already known what to do.

Start the vagrant environment:

```bash
vagrant up --no-destroy-on-error
```

Enter the created vagrant environment and play with the example terraform project:

```bash
# enter the vagrant environment.
vagrant ssh

# login into azure.
az login

# list the subscriptions and select the current one
# if the default is not OK.
az account list --all
az account show
az account set --subscription <YOUR-SUBSCRIPTION-ID>

# provision the example infrastructure.
cd /vagrant
export CHECKPOINT_DISABLE=1
export TF_LOG=TRACE
export TF_LOG_PATH=terraform.log
terraform init
terraform plan -out=tfplan
time terraform apply tfplan

# use the app.
wget -qSO- "$(terraform output -raw url)"

# destroy the infrastructure.
terraform destroy
```

## Caveats

* [There is no support for initContainers (init containers) in the terraform provider](https://github.com/hashicorp/terraform-provider-azurerm/issues/8085).
* [There is no way to known the end-user client IP address](https://feedback.azure.com/d365community/idea/c81db3f3-0c25-ec11-b6e6-000d3a4f0858).
  * **NB** The ACI container is behind a load balancer that does not preserve the client IP address.

## Reference

* [azurerm_container_group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_group)
* [Container groups in Azure Container Instances](https://docs.microsoft.com/en-us/azure/container-instances/container-instances-container-groups)
* [YAML reference: Azure Container Instances](https://docs.microsoft.com/en-us/azure/container-instances/container-instances-reference-yaml)
* [Caddy](https://github.com/caddyserver/caddy)
* [Caddy Docker Image](https://github.com/caddyserver/caddy-docker)
