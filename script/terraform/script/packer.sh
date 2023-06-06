#!/bin/bash -e

DIR="$(dirname "$0")"

if [[ $1 = *=* ]]; then
    PROJECT_NAME=main
else
    PROJECT_NAME=$1
    shift
fi

cd /opt/workspace

extract_string () {
    value="$(sed -n "/^\s*variable\s*\"$1\"\s*{/,/^\s*}/{/^\s*$2\s*=\s*\"/{s/^\s*$2\s*=\s*\"\(.*\)\"\s*$/\1/;p}}" terraform-config.tf)"
    echo "$3=${value:-null}"
    eval "$3=\"${value:-null}\""
}

extract_number () {
    value="$(sed -n "/^\s*variable\s*\"$1\"\s*{/,/^\s*}/{/^\s*$2\s*=/{s/^\s*$2\s*=\s*\([0-9.]*\).*$/\1/;p}}" terraform-config.tf)"
    echo "$3=${value:-0}"
    eval "$3=\"${value:-0}\""
}

extract_bool () {
    value="$(sed -n "/^\s*variable\s*\"$1\"\s*{/,/^\s*}/{/^\s*$2\s*=/{s/^\s*$2\s*=\s*\([truefals]*\).*$/\1/;p}}" terraform-config.tf)"
    echo "$3=${value:-false}"
    eval "$3=\"${value:-false}\""
}

extract_host_string () {
    value="$(sed -n "/^\s*variable\s*\"$1\"\s*{/,/^\s*}/{/^\s*\"$2\"\s*:\s*{/,/^\s*}/{/^\s*\"$3\"\s*:/{s/^\s*\"$3\"\s*:\s*\"\(.*\)\"\s*,*\s*$/\1/;p}}}" terraform-config.tf)"
    echo "$4=${value:-null}"
    eval "$4=\"${value:-null}\""
}

extract_host_number () {
    value="$(sed -n "/^\s*variable\s*\"$1\"\s*{/,/^\s*}/{/^\s*\"$2\"\s*:\s*{/,/^\s*}/{/^\s*\"$3\"\s*:/{s/^\s*\"$3\"\s*:\s*\([0-9.]*\).*$/\1/;p}}}" terraform-config.tf)"
    echo "$4=${value:-0}"
    eval "$4=\"${value:-0}\""
}

CSP="$(grep -E '^\s*csp\s*=' terraform-config.tf | cut -f2 -d'"' | tail -n1)"
CSP=${CSP:-static}
echo "CSP=$CSP"
OWNER=${OWNER:-$(env | grep _OPTIONS= | tr ' ' '\n' | grep -F owner= | sed 's/.*--owner=\([^ ]*\)/\1/')}
echo "OWNER=$OWNER"

extract_string worker_profile instance_type INSTANCE_TYPE
extract_number worker_profile memory_size MEMORY_SIZE
extract_number worker_profile cpu_core_count CPU_CORE_COUNT
extract_string worker_profile min_cpu_platform MIN_CPU_PLATFORM
extract_string zone default ZONE
extract_string compartment default COMPARTMENT
extract_bool   spot_instance default SPOT_INSTANCE
extract_string worker_profile os_type OS_TYPE
extract_string worker_profile os_disk_type OS_DISK_TYPE
extract_number worker_profile os_disk_size OS_DISK_SIZE
extract_string worker_profile os_image OS_IMAGE
extract_host_string worker_profile worker-0 user_name USER_NAME
extract_host_string worker_profile worker-0 public_ip PUBLIC_IP
extract_host_string worker_profile worker-0 private_ip PRIVATE_IP
extract_host_number worker_profile worker-0 ssh_port SSH_PORT
extract_string kvm_hosts host KVM_HOST
extract_string kvm_hosts user KVM_HOST_USER
extract_number kvm_hosts port KVM_HOST_PORT
extract_string kvm_hosts pool KVM_HOST_POOL


case "$PLATFORM" in
ARMv*)
    ARCHITECTURE="arm64";;
ROME|MILAN|GENOA)
    ARCHITECTURE="amd64";;
*)
    ARCHITECTURE="x86_64";;
esac
echo "ARCHITECTURE=$ARCHITECTURE"

cp -r -L /opt/workload/* .
if [ ! -d template/packer/$CSP/$PROJECT_NAME ]; then
    if [ -d /opt/template/packer/$CSP/$PROJECT_NAME ]; then
        mkdir -p template/packer/$CSP/$PROJECT_NAME
        cp -r /opt/template/packer/$CSP/$PROJECT_NAME template/packer/$CSP
    else
        echo "Missing template/packer/$CSP/$PROJECT_NAME"
        exit 0
    fi
fi

# copy shared stack templates
if [ -d "$STACK_TEMPLATE_PATH" ]; then
    cp -r -f "${STACK_TEMPLATE_PATH}" /opt/workspace
fi

# Create SG white list
"$DIR"/get-ip-list.sh /opt/csp/etc/proxy-ip-list.txt > proxy-ip-list.txt

if [ -e /home/.ssh/config ]; then
    SSH_PROXY="$(grep ProxyCommand /home/.ssh/config | tr ' ' '\n' | grep -E ':[0-9]+$' | head -n1)"
    SSH_PROXY_HOST="${SSH_PROXY/:*/}"
    SSH_PROXY_PORT="${SSH_PROXY/*:/}"
fi

mkdir -p /opt/workspace/template/terraform/$CSP
if [ -d /opt/template/terraform/$CSP/packer-rg ]; then
    cp -rf /opt/template/terraform/$CSP/packer-rg /opt/workspace/template/terraform/$CSP
    cd /opt/workspace/template/terraform/$CSP/packer-rg

    cat > terraform.tfvars <<EOF
zone="$ZONE"
owner="$OWNER"
EOF
    (
        set -x
        terraform init -input=false -no-color
        terraform apply -input=false --auto-approve -no-color --var create_resource=false -parallelism=$(nproc) || terraform apply -input=false --auto-approve -no-color --var create_resource=true -parallelism=$(nproc)
    )
    eval "$(terraform show -json | "$DIR"/create-vars.py)"
fi

destroy () {
    trap - SIGINT SIGKILL ERR EXIT
    if [ -d /opt/workspace/template/terraform/$CSP/packer ]; then
        cd /opt/workspace/template/terraform/$CSP/packer
        echo "Cleanup resources..."
        TF_LOG=ERROR terraform destroy -auto-approve -input=false -no-color -parallelism=$(nproc) > ../../../../cleanup.logs 2>&1
    fi
    echo "exit with status: ${1:-3}"
    exit ${1:-3}
}

write_var () {
    if [ "$2" = "null" ]; then
        echo "$1=$2"
    elif [ "$2" = "true" ] || [ "$2" = "false" ]; then
        echo "$1=$2"
    elif [[ "$2" =~ ^[+-]?([0-9]+([.][0-9]*)?|\.[0-9]+)$ ]]; then
        echo "$1=$2"
    elif [[ "$2" = "["*"]" ]] || [[ "$2" = "{"*"}" ]]; then
        echo "$1=$2"
    else
        echo "$1=\"$2\""
    fi
}

if [ -d /opt/template/terraform/$CSP/packer ]; then
    cp -rf /opt/template/terraform/$CSP/packer /opt/workspace/template/terraform/$CSP
    cd /opt/workspace/template/terraform/$CSP/packer

    cat > terraform.tfvars <<EOF
zone="$ZONE"
owner="$OWNER"
proxy_ip_list="$(readlink -f ../../../../proxy-ip-list.txt)"
job_id="$NAMESPACE"
EOF
    vars="$(sed -n '/^\s*variable\s*"[^"]*"\s*{*\s*#*.*$/{s/.*"\(.*\)".*/\1/;p}' *.tf | tr '\n' ' ')"
    for var in compartment resource_group_id instance_type os_type os_image; do
        if [[ " $vars " = *" $var "* ]]; then
            eval "v=\"\$${var^^}\""
            write_var "$var" "$v" >> terraform.tfvars
        fi
    done
    (
        set -x
        terraform init -input=false -no-color
        terraform plan -input=false -out tfplan -no-color -parallelism=$(nproc)
    )

    trap destroy SIGINT SIGKILL ERR EXIT

    (
        set -x
        terraform apply -input=false --auto-approve -no-color -parallelism=$(nproc)
    )
    terraform show -json > ../../../../tfplan.json
    eval "$("$DIR"/create-vars.py < ../../../../tfplan.json)"
fi

cd /opt/workspace/template/packer/$CSP/$PROJECT_NAME
ssh-keygen -m PEM -q -f ssh_access.key -t rsa -N ''
packer init .

vars="$(sed -n '/^\s*variable\s*"[^"]*"\s*{*\s*#*.*$/{s/.*"\(.*\)".*/\1/;p}' *.pkr.hcl | tr '\n' ' ')"
for argv in $@; do
    if [[ "$argv" = *'='* ]]; then
        k="${argv/=*/}"
        if [[ " $vars " = *" $k "* ]]; then
            v="${argv/*=/}"
            [[ "$k" = *'$'* ]] && eval "k=$k"
            [[ "$v" = *'$'* ]] && eval "v=$v"
            write_var "$k" "$v" >> packer.auto.pkrvars.hcl
        fi
    fi
done

(
    set -x
    PACKER_LOG=1 PACKER_LOG_PATH=/opt/workspace/packer.logs packer build -force .
)

destroy 0
