#!/usr/bin/env bash

# Copyright 2021 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

KUBE_ROOT=$(dirname "${BASH_SOURCE[0]}")/../..
source "${KUBE_ROOT}/hack/lib/init.sh"
source "${KUBE_ROOT}/hack/lib/util.sh"

stability_check_setup() {
  kube::golang::verify_go_version
  kube::util::ensure-temp-dir
  cd "${KUBE_ROOT}"
  kube::golang::setup_env
}

find_files_to_check() {
  find . -not \( \
      \( \
        -wholename './output' \
        -o -wholename './_output' \
        -o -wholename './_gopath' \
        -o -wholename './release' \
        -o -wholename './target' \
        -o -wholename '*/third_party/*' \
        -o -wholename '*/vendor/*' \
        -o -wholename '*/hack/*' \
        -o -wholename '*_test.go' \
        -o -wholename './test/instrumentation/*.go' \
        \) -prune \
    \) \
    \( -wholename '**/*.go' \
  \)
}

find_test_files() {
  find './test/instrumentation' -wholename '**/*.go'
}

red=$(tput setaf 1)
green=$(tput setaf 2)
reset=$(tput sgr0)

kube::validate::stablemetrics() {
  stability_check_setup
  temp_file=$(mktemp)
  doValidate=$(find_files_to_check | grep -E ".*.go" | grep -v ".*_test.go" | grep -v ".git" | sort | KUBE_ROOT=${KUBE_ROOT} xargs -L 200 go run "test/instrumentation/main.go" "test/instrumentation/decode_metric.go" "test/instrumentation/find_stable_metric.go" "test/instrumentation/error.go" "test/instrumentation/metric.go" -- 1>"${temp_file}")

  if $doValidate; then
    echo -e "${green}Diffing test/instrumentation/testdata/stable-metrics-list.yaml\n${reset}"
    if diff -u "$KUBE_ROOT/test/instrumentation/testdata/stable-metrics-list.yaml" "$temp_file"; then
      echo -e "${green}\nPASS metrics stability verification ${reset}"
      return 0
    fi
  fi
  
  echo "${red}!!! Metrics Stability static analysis has failed!${reset}" >&2
  echo "${red}!!! Please run ./hack/update-generated-stable-metrics.sh to update the golden list.${reset}" >&2
  exit 1
}

kube::validate::test::stablemetrics() {
  stability_check_setup
  temp_file=$(mktemp)
  doValidate=$(find_test_files | grep -E ".*.go" | grep -v ".*_test.go" | grep -v ".git" | sort | KUBE_ROOT=${KUBE_ROOT} xargs -L 200 go run "test/instrumentation/main.go" "test/instrumentation/decode_metric.go" "test/instrumentation/find_stable_metric.go" "test/instrumentation/error.go" "test/instrumentation/metric.go" -- 1>"${temp_file}")

  if $doValidate; then
    echo -e "${green}Diffing test/instrumentation/testdata/test-stable-metrics-list.yaml\n${reset}"
    if diff -u "$KUBE_ROOT/test/instrumentation/testdata/test-stable-metrics-list.yaml" "$temp_file"; then
      echo -e "${green}\nPASS metrics stability verification ${reset}"
      return 0
    fi
  fi

  echo "${red}!!! Metrics stability static analysis test has failed!${reset}" >&2
  echo "${red}!!! Please run './test/instrumentation/test-update.sh' to update the golden list.${reset}" >&2
  exit 1
}

kube::update::stablemetrics() {
  stability_check_setup
  temp_file=$(mktemp)
  doCheckStability=$(find_files_to_check | grep -E ".*.go" | grep -v ".*_test.go" | sort | KUBE_ROOT=${KUBE_ROOT} xargs -L 200 go run "test/instrumentation/main.go" "test/instrumentation/decode_metric.go" "test/instrumentation/find_stable_metric.go" "test/instrumentation/error.go" "test/instrumentation/metric.go" -- 1>"${temp_file}")

  if ! $doCheckStability; then
    echo "${red}!!! updating golden list of metrics has failed! ${reset}" >&2
    exit 1
  fi
  mv -f "$temp_file" "${KUBE_ROOT}/test/instrumentation/testdata/stable-metrics-list.yaml"
  echo "${green}Updated golden list of stable metrics.${reset}"
}

kube::update::documentation::list() {
  stability_check_setup
  temp_file=$(mktemp)
  doCheckStability=$(find_files_to_check | grep -E ".*.go" | grep -v ".*_test.go" | sort | KUBE_ROOT=${KUBE_ROOT} xargs -L 200 go run "test/instrumentation/main.go" "test/instrumentation/decode_metric.go" "test/instrumentation/find_stable_metric.go" "test/instrumentation/error.go" "test/instrumentation/metric.go" --allstabilityclasses -- 1>"${temp_file}")

  if ! $doCheckStability; then
    echo "${red}!!! updating golden list of metrics has failed! ${reset}" >&2
    exit 1
  fi
  mv -f "$temp_file" "${KUBE_ROOT}/test/instrumentation/documentation/documentation-list.yaml"
  echo "${green}Updated list of metrics for documentation ${reset}"
}

kube::update::documentation() {
  stability_check_setup
  temp_file=$(mktemp)
  doUpdateDocs=$(go run "test/instrumentation/documentation/main.go" -- 1>"${temp_file}")
  if ! $doUpdateDocs; then
    echo "${red}!!! updating documentation has failed! ${reset}" >&2
    exit 1
  fi
  mv -f "$temp_file" "${KUBE_ROOT}/test/instrumentation/documentation/documentation.md"
  echo "${green}Updated documentation of metrics.${reset}"
}

kube::update::test::stablemetrics() {
  stability_check_setup
  temp_file=$(mktemp)
  doCheckStability=$(find_test_files | grep -E ".*.go" | grep -v ".*_test.go" | sort | KUBE_ROOT=${KUBE_ROOT} xargs -L 200 go run "test/instrumentation/main.go" "test/instrumentation/decode_metric.go" "test/instrumentation/find_stable_metric.go" "test/instrumentation/error.go" "test/instrumentation/metric.go" -- 1>"${temp_file}")

  if ! $doCheckStability; then
    echo "${red}!!! updating golden list of test metrics has failed! ${reset}" >&2
    exit 1
  fi
  mv -f "$temp_file" "${KUBE_ROOT}/test/instrumentation/testdata/test-stable-metrics-list.yaml"
  echo "${green}Updated test list of stable metrics.${reset}"
}

