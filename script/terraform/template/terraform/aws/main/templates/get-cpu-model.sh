#!/bin/bash

while true; do
  cpu_model="$(ssh $@ cat /proc/cpuinfo | sed -n -E '/^model\s*(name|)\s*:/{s/.*:\s*//;p}' | head -n2 | tr '\n' ':')"
  [ -z "$cpu_model" ] || break
done

cat <<EOF
{
  "cpu_model": ":$cpu_model"
}
EOF
