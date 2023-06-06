#!/bin/bash -e

# default settings
LOGSDIRH="${LOGSDIRH:-$(pwd)}"
KUBERNETES_CONFIG_M4="${KUBERNETES_CONFIG_M4:-$SOURCEROOT/kubernetes-config.yaml.m4}"
KUBERNETES_CONFIG_J2="${KUBERNETES_CONFIG_M4:-$SOURCEROOT/kubernetes-config.yaml.j2}"
KUBERNETES_CONFIG="${KUBERNETES_CONFIG:-$LOGSDIRH/kubernetes-config.yaml}"
HELM_CONFIG="${HELM_CONFIG:-$SOURCEROOT/helm}"
CLUSTER_CONFIG_M4="${CLUSTER_CONFIG_M4:-$SOURCEROOT/cluster-config.yaml.m4}"
CLUSTER_CONFIG_J2="${CLUSTER_CONFIG_J2:-$SOURCEROOT/cluster-config.yaml.j2}"
CLUSTER_CONFIG="${CLUSTER_CONFIG:-$LOGSDIRH/cluster-config.yaml}"
JOB_FILTER="${JOB_FILTER:-job-name=benchmark}"
EXPORT_LOGS="${EXPORT_LOGS:-/export-logs}"
HELM_OPTIONS="${HELM_OPTIONS:-${RECONFIG_OPTIONS//-D/--set }}"
J2_OPTIONS="${J2_OPTIONS:-${RECONFIG_OPTIONS//-D/-e }}"

# OWNER and NAMESPACE
eval "options=\"\$${BACKEND^^}_OPTIONS\""
if [[ "$options $CTESTSH_OPTIONS" = *--owner=* ]]; then
    export OWNER="$(echo "x$options $CTESTSH_OPTIONS" | sed 's|.*--owner=\([^ ]*\).*|\1|' | tr 'A-Z' 'a-z' | tr -c -d 'a-z0-9-')"
else
    export OWNER="$( (git config user.name || id -un) 2> /dev/null | tr 'A-Z' 'a-z' | tr -c -d 'a-z0-9-')"
fi
if [ "$OWNER" = "root" ] || [ -z "$OWNER" ]; then
    echo "Please run as a regular user or specify --owner=<user> in ${BACKEND^^}_OPTIONS"
    exit 3
fi
NAMESPACE="${NAMESPACE:-$(echo $OWNER | sed 's|^\(.\{12\}\).*$|\1|')-$(cut -f5 -d- /proc/sys/kernel/random/uuid)}"

# args: image or Dockerfile
image_name () {
    if [ "$IMAGEARCH" = "linux/amd64" ]; then
        arch=""
    else
        arch="-${IMAGEARCH/*\//}"
    fi
    if [ -e "$1" ]; then
        echo $REGISTRY$(head -n 2 "$1" | grep '^# ' | tail -n 1 | cut -d' ' -f2)$arch$RELEASE
    elif [ -e "$SOURCEROOT/$1" ]; then
        echo $REGISTRY$(head -n 2 "$SOURCEROOT/$1" | grep '^# ' | tail -n 1 | cut -d' ' -f2)$arch$RELEASE
    else
        echo $REGISTRY$1$arch$RELEASE
    fi
}

# args: yaml
rebuild_config () {
    (
        cd "$SOURCEROOT" && \
        m4 -Itemplate -I"$PROJECTROOT/template" \
            -DNAMESPACE=$NAMESPACE \
            -DTESTCASE=$TESTCASE \
            -DPLATFORM=$PLATFORM \
            -DIMAGEARCH=$IMAGEARCH \
            -DWORKLOAD=$WORKLOAD \
            -DBACKEND=$BACKEND \
            -DREGISTRY=$REGISTRY \
            -DRELEASE=$RELEASE \
            -DEXPORT_LOGS=$EXPORT_LOGS \
            $RECONFIG_OPTIONS \
            "$1" > "$2"
    )
}

# args: yaml
rebuild_config_j2 () {
    (
        cd "$SOURCEROOT" && \
        ansible all -i "localhost," -c local -m template \
            -a "src=\"$1\" dest=\"$2\"" \
            -e NAMESPACE=$NAMESPACE \
            -e TESTCASE=$TESTCASE \
            -e PLATFORM=$PLATFORM \
            -e IMAGEARCH=$IMAGEARCH \
            -e WORKLOAD=$WORKLOAD \
            -e BACKEND=$BACKEND \
            -e REGISTRY=$REGISTRY \
            -e RELEASE=$RELEASE \
            -e EXPORT_LOGS=$EXPORT_LOGS \
            $J2_OPTIONS
    )
}

# args: none
test_pass_fail () {
  local ret=0
  for status_path in "$LOGSDIRH"/*/*/status "$LOGSDIRH"/*/status "$LOGSDIRH"/status
  do
    [ ! -e $status_path ] && continue
    
    local value=$(< $status_path)
    if [ "$value" != "0" ]; then
      echo "Failure reported in: $status_path"
      ret=1
    fi
  done
  return $ret
}

rebuild_kubernetes_config () {
    if [ -r "${KUBERNETES_CONFIG_M4%.m4}" ]; then
        cp -f "${KUBERNETES_CONFIG_M4%.m4}" "$KUBERENTES_CONFIG"
        return 0
    elif [ -r "$KUBERNETES_CONFIG_M4" ]; then
        rebuild_config "$KUBERNETES_CONFIG_M4" "$KUBERNETES_CONFIG"
        return 0
    elif [ -r "$KUBERNETES_CONFIG_J2" ]; then
        rebuild_config_j2 "$KUBERNETES_CONFIG_J2" "$KUBERNETES_CONFIG"
        return 0
    elif [ -d "$HELM_CONFIG" ]; then
        local options="-n $NAMESPACE \
            --set NAMESPACE=$NAMESPACE \
            --set TESTCASE=$TESTCASE \
            --set PLATFORM=$PLATFORM \
            --set IMAGEARCH=$IMAGEARCH \
            --set WORKLOAD=$WORKLOAD \
            --set BACKEND=$BACKEND \
            --set REGISTRY=$REGISTRY \
            --set RELEASE=$RELEASE \
            --set EXPORT_LOGS=$EXPORT_LOGS \
            $HELM_OPTIONS"
        local chart_list=$(find "$HELM_CONFIG" -name "Chart.yaml")
        if helm version &>/dev/null; then
            while read chart_path; do
                local appdir="$(dirname $chart_path)"
                local appname="$(basename "$appdir")"
                helm template "$appname" "$appdir" $options
            done <<< "$chart_list" > "$KUBERNETES_CONFIG"
        else
            while read chart_path; do
                local appdir="$(dirname $chart_path)"
                local appname="$(basename "$appdir")"
                docker run --rm -v "$appdir":/apps:ro alpine/helm:3.7.1 template "$appname" /apps $options
            done <<< "$chart_list" > "$KUBERNETES_CONFIG"
        fi
        return 0
    fi
    return 1
}

dataset_images () {
    if [ ${#DOCKER_DATASET[@]} -gt 0 ]; then
        for ds in "${DOCKER_DATASET[@]}"; do
            image_name "$ds"
        done
    elif [ -n "$DOCKER_DATASET" ]; then
        image_name "$DOCKER_DATASET"
    fi
}

# convert arrays to strings
convert_workload_params () {
    WORKLOAD_PARAMS="$(for kv in "${WORKLOAD_PARAMS[@]}"; do
                           eval "kv=\"$kv:\${$kv}\""
                           echo "$kv"
                       done | tr '\n' ';'
                      )"
    WORKLOAD_PARAMS="${WORKLOAD_PARAMS%;}"
    [ "${CTESTSH_EVENT_TRACE_PARAMS-undefined}" = "undefined" ] ||  EVENT_TRACE_PARAMS="$CTESTSH_EVENT_TRACE_PARAMS"
}

save_script_args () {
    echo "script_args: \"$SCRIPT_ARGS\"" >> "$LOGSDIRH/workload-config.yaml"
}

save_workload_params () {
    echo "tunables: \"$WORKLOAD_PARAMS;testcase:$TESTCASE$TESTCASE_CUSTOMIZED\"" >> "$LOGSDIRH/workload-config.yaml"
    echo "bom: \"$WORKLOAD_BOM\"" >> "$LOGSDIRH/workload-config.yaml"
    eval "bk_opts=\"\$${BACKEND^^}_OPTIONS\""
    eval "bk_sut=\"\$${BACKEND^^}_SUT\""
    echo "cmake_cmdline: \"cmake -DPLATFORM=$PLATFORM -DREGISTRY=$REGISTRY -DREGISTRY_AUTH=$REGISTRY_AUTH -DRELEASE=$RELEASE -DTIMEOUT=$TIMEOUT -DBENCHMARK='$BENCHMARK' -DBACKEND=$BACKEND -D${BACKEND^^}_OPTIONS='$bk_opts' -D${BACKEND^^}_SUT='$bk_sut' -DSPOT_INSTANCE=$SPOT_INSTANCE\"" >> "$LOGSDIRH/workload-config.yaml"
}

save_kpish () {
    if [ -e "$SOURCEROOT/kpi.sh" ]; then
        cp -f "$SOURCEROOT/kpi.sh" "$LOGSDIRH"
        chmod a+rx "$LOGSDIRH/kpi.sh"
    fi
}

save_git_history () {
    eval "bk_opts=\"\$${BACKEND^^}_OPTIONS\""
    if [[ "$bk_opts$CTESTSH_OPTIONS" != *"--dry-run"* ]]; then
        mkdir -p "$LOGSDIRH/git-history"
        git show HEAD | sed  '/^diff/{q}' > "$LOGSDIRH/git-history/HEAD" || true
        git diff HEAD > "$LOGSDIRH/git-history/DIFF" || true
    fi
}

print_workload_configurations () {
    echo ""
    if [ -r "$CLUSTER_CONFIG" ]; then
      echo "Workload Labels:"
      grep -F 'HAS-SETUP-' "$CLUSTER_CONFIG" | awk '{a[$0]=1}END{if(length(a)) for(x in a)print x;else print "N/A"}' | sed 's|^\s*||'
      echo ""
      echo "Workload VM Groups:"
      grep -F 'vm_group:' "$CLUSTER_CONFIG" | awk '{a[$2]=1}END{if(length(a)) for(x in a)print x;else print "worker"}' | sed 's|^\s*||'
      echo ""
    fi
    echo "Workload Configuration:"
    echo "$WORKLOAD_PARAMS" | sed 's/;/\n/g' | sed 's/:/=/'
    echo ""
    echo "EVENT_TRACE_PARAMS=$EVENT_TRACE_PARAMS"
}

if [ -z "$CTESTSH_OPTIONS" ]; then
    echo -e "\033[31m=====================================================\033[0m" 1>&2
    echo -e "\033[31mInvoking testcases via ctest directly is discouraged.\033[0m" 1>&2
    echo -e "\033[31mPlease use ./ctest.sh to invoke WSF testcases.       \033[0m" 1>&2
    echo -e "\033[31m=====================================================\033[0m" 1>&2
    exit 3
fi

WORKLOAD_BOM="$("$SOURCEROOT"/build.sh --bom | grep -E '^ARG' | sed 's/^ARG //' | tr '=\n' ':;' | sed 's/;$//')"
if [ -r "$PROJECTROOT/script/${BACKEND}/validate.sh" ]; then
    save_kpish
    save_script_args
    convert_workload_params
    save_workload_params
    save_git_history
    if [ -r "$CLUSTER_CONFIG_M4" ]; then
        rebuild_config "$CLUSTER_CONFIG_M4" "$CLUSTER_CONFIG"
    elif [ -r "$CLUSTER_CONFIG_J2" ]; then
        rebuild_config_j2 "$CLUSTER_CONFIG_J2" "$CLUSTER_CONFIG"
    fi
    print_workload_configurations
    . "$PROJECTROOT/script/${BACKEND}/validate.sh"
    test_pass_fail
else
    echo "$BACKEND not supported"
    exit 3
fi
