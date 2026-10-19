#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/install-node-tests.XXXXXX")"
readonly TEST_DIR
REPOSITORY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPOSITORY_DIR
readonly SCRIPT_PATH="${REPOSITORY_DIR}/build/install-node.sh"

failures=0

cleanup() {
	if [[ -d "${TEST_DIR}" ]]; then
		rm -r -- "${TEST_DIR}"
	fi
}
trap cleanup EXIT

fail() {
	printf 'not ok - %s\n' "$1" >&2
	failures=$((failures + 1))
}

assert_status() {
	local expected="$1"
	local actual="$2"
	local description="$3"

	if [[ "${actual}" -ne "${expected}" ]]; then
		fail "${description}: expected exit ${expected}, got ${actual}"
	fi
}

assert_file_equals() {
	local file="$1"
	local expected="$2"
	local description="$3"

	if [[ ! -f "${file}" ]] || [[ "$(cat "${file}")" != "${expected}" ]]; then
		fail "${description}"
	fi
}

# Fake nvm.sh: defines nvm and npm functions that record their calls
create_fake_nvm() {
	local nvm_dir="$1"

	mkdir -p "${nvm_dir}"

	cat > "${nvm_dir}/nvm.sh" <<'EOF'
nvm() {
	printf '%s\n' "$*" >> "${TEST_STATE}/nvm.calls"
	if [[ "$1" == "install" && "$2" == "${FAKE_FAIL_VERSION:-}" ]]; then
		return 3
	fi
}

npm() {
	printf '%s\n' "$*" >> "${TEST_STATE}/npm.calls"
}
EOF
}

run_install_case() {
	local name="$1"
	local expected_exit="$2"
	shift 2
	local state_dir="${TEST_DIR}/${name}"
	local actual_exit

	mkdir -p "${state_dir}"
	create_fake_nvm "${state_dir}/nvm"

	(
		NVM_DIR="${state_dir}/nvm" \
			TEST_STATE="${state_dir}" \
			bash "${SCRIPT_PATH}" "$@"
	) > "${state_dir}/output" 2>&1
	actual_exit=$?

	assert_status "${expected_exit}" "${actual_exit}" "${name}"
}

run_install_case default 0
assert_file_equals "${TEST_DIR}/default/nvm.calls" "$(printf '%s\n' 'install lts/-2' 'install lts/-1' 'install lts/*')" \
	'default installs the three latest LTS lines, oldest first'
assert_file_equals "${TEST_DIR}/default/npm.calls" 'cache clean --force' 'npm cache is cleaned once'

run_install_case single 0 1
assert_file_equals "${TEST_DIR}/single/nvm.calls" 'install lts/*' 'a count of 1 installs only the latest LTS'

run_install_case five 0 5
assert_file_equals "${TEST_DIR}/five/nvm.calls" \
	"$(printf '%s\n' 'install lts/-4' 'install lts/-3' 'install lts/-2' 'install lts/-1' 'install lts/*')" \
	'the LTS count is configurable'

run_install_case zero 1 0
[[ -f "${TEST_DIR}/zero/nvm.calls" ]] && fail 'a count of 0 installs nothing'

run_install_case not_a_number 1 abc
[[ -f "${TEST_DIR}/not_a_number/nvm.calls" ]] && fail 'a non-numeric count installs nothing'

FAKE_FAIL_VERSION='lts/-1' run_install_case install_failure 3
assert_file_equals "${TEST_DIR}/install_failure/nvm.calls" "$(printf '%s\n' 'install lts/-2' 'install lts/-1')" \
	'a failed install stops the build'

if [[ "${failures}" -gt 0 ]]; then
	printf '%s test assertion(s) failed\n' "${failures}" >&2
	exit 1
fi

printf 'ok - install-node behavior\n'
