#!/bin/bash
# Usage: get_project_var <project> <var>
# Example: get_project_var askappy-base image_name
# Requires yq (https://github.com/mikefarah/yq)

get_project_var() {
    local project="$1"
    local var="$2"
    yq e ".projects.\"$project\".$var" "$(dirname "$0")/../projects.yml"
}

# If sourced, export the function
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    export -f get_project_var
fi
