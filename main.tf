# see https://github.com/hashicorp/terraform
terraform {
  required_version = "1.0.11"
  required_providers {
    # see https://github.com/hashicorp/terraform-provider-random
    # see https://registry.terraform.io/providers/hashicorp/random
    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }
    # see https://github.com/terraform-providers/terraform-provider-azurerm
    # see https://registry.terraform.io/providers/hashicorp/azurerm
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.88.1"
    }
  }
}

provider "azurerm" {
  features {}
}

# NB you can test the relative speed from you browser to a location using https://azurespeedtest.azurewebsites.net/
# get the available locations with: az account list-locations --output table
variable "location" {
  default = "France Central" # see https://azure.microsoft.com/en-us/global-infrastructure/france/
}

# NB this name must be unique within the Azure subscription.
#    all the other names must be unique within this resource group.
variable "resource_group_name" {
  default = "rgl-terraform-container-instances-example"
}

data "azurerm_client_config" "current" {
}

# NB this name must be unique within the given azure region/location.
#    it will be used as the container public FQDN as {dns_name_label}.{location}.azurecontainer.io.
# NB this FQDN length is limited to Let's Encrypt Certicate CN maximum length of 64 characters.
locals {
  # NB this results in a 32 character string. e.g. f64e997403f65d32aa7fb0a482c49e1b.
  dns_name_label = replace(uuidv5("url", "https://azurecontainer.io/${data.azurerm_client_config.current.subscription_id}/${var.resource_group_name}/example"), "/\\-/", "")
}

output "ip_address" {
  value = azurerm_container_group.example.ip_address
}

output "fqdn" {
  value = azurerm_container_group.example.fqdn
}

output "url" {
  value = "https://${azurerm_container_group.example.fqdn}"
}

# NB this generates a random number for the storage account.
# NB this must be at most 12 bytes.
resource "random_id" "example" {
  keepers = {
    resource_group = azurerm_resource_group.example.name
  }
  byte_length = 12
}

resource "azurerm_resource_group" "example" {
  name     = var.resource_group_name # NB this name must be unique within the Azure subscription.
  location = var.location
}

resource "azurerm_storage_account" "example" {
  # NB this name must be globally unique as all the azure storage accounts share the same namespace.
  # NB this name must be at most 24 characters long.
  name                     = random_id.example.hex
  location                 = azurerm_resource_group.example.location
  resource_group_name      = azurerm_resource_group.example.name
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "example" {
  name                 = "example-caddy-data"
  storage_account_name = azurerm_storage_account.example.name
  quota                = 1
}

resource "azurerm_container_group" "example" {
  name                = "example"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  ip_address_type     = "Public"
  dns_name_label      = local.dns_name_label
  os_type             = "Linux"

  container {
    name   = "caddy"
    image  = "caddy:2"
    cpu    = "0.5"
    memory = "0.2"

    volume {
      name = "config"
      read_only = true
      mount_path = "/etc/caddy"
      secret = {
        "Caddyfile" = base64encode(<<-EOF
          ${local.dns_name_label}.${replace(lower(azurerm_resource_group.example.location), "/ /", "")}.azurecontainer.io {
            log
            #respond "Hello, World!"
            reverse_proxy localhost:8080
          }
          EOF
        ),
      }
    }

    # see https://caddyserver.com/docs/conventions#data-directory
    # see https://github.com/caddyserver/caddy-docker
    volume {
      name = "data"
      mount_path = "/data"
      share_name = azurerm_storage_share.example.name
      storage_account_name = azurerm_storage_account.example.name
      storage_account_key = azurerm_storage_account.example.primary_access_key
    }

    ports {
      port     = 80
      protocol = "TCP"
    }

    ports {
      port     = 443
      protocol = "TCP"
    }
  }

  container {
    name     = "app"
    image    = "ruilopes/example-docker-buildx-go:v1.4.0"
    cpu      = "0.5"
    memory   = "0.2"
    commands = ["/app/example-docker-buildx-go", "-listen", "localhost:8080"]
  }
}
