#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

variable "region" {
  type = string
  default = null
}

variable "zone" {
  type = string
  nullable = false
}

variable "subscription_id" {
  type = string
  default = null
}

variable "common_tags" {
  type    = map(string)
  default = {}
}

variable "owner" {
  type = string
  nullable = false
}

variable "create_resource" {
  type = bool
  nullable = false
}

