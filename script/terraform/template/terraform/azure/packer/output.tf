#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

output "packer" {
  value = {
    region: azurerm_resource_group.default.location
    zone: var.zone
    availability_zone: local.availability_zone
    subscription_id: data.azurerm_subscription.current.subscription_id
    network_id: azurerm_virtual_network.default.id
    network_name: reverse(split("/", azurerm_virtual_network.default.id))[0]
    subnet_id: azurerm_subnet.default.id
    subnet_name: reverse(split("/", azurerm_subnet.default.id))[0]
    network_resource_group_id: azurerm_resource_group.default.id
    network_resource_group_name: azurerm_resource_group.default.name
  }
}
