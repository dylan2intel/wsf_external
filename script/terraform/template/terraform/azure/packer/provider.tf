terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "= 3.53.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}
