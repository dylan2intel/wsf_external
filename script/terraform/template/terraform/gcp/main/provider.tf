terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "= 4.63.1"
    }
  }
}

provider "google" {
  region = var.region!=null?var.region:replace(var.zone,"/([a-z0-9]+-[a-z0-9]+)-.*/","$1")
  zone = var.zone
  project = local.project_id
}
