
packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "= 1.4.2"
    }
  }
}

