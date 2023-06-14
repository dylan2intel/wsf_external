#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if [ $# = 0 ]; then
    echo "Usage: user@host ..."
    exit 3
fi

if [ ! -r ~/.ssh/id_rsa ]; then
    echo "Setup self-signed key file..."
    yes y | ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
fi

for login in "$@"; do
    echo "Setup passwordless ssh to $login..."
    ssh-copy-id "$login"

    echo "Setup passwordless sudo..."
    username="$(ssh "$login" id -un)"
    groupname="$(ssh "$login" id -gn)"
    if [[ "$username" = *" "* ]]; then
        echo "Unsupported: username contains whitespace!"
        continue
    fi

    sudoerline="$username ALL=(ALL:ALL) NOPASSWD: ALL"
    ssh -t "$login" sudo bash -c "'grep -q -F \"$sudoerline\" /etc/sudoers || echo \"$sudoerline\" | EDITOR=\"tee -a\" visudo'"
done

