#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
apt update
apt install -y linux-tools-$(uname -r)

echo "Disable C6"
cpupower idle-set -d 2
cpupower idle-info

echo "Set CPU frequency governor"
cpupower frequency-set -g performance

echo "<<< preparing done"