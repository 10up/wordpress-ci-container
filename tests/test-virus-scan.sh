#!/usr/bin/env bash

set -uo pipefail

TEST_DIR="$(mktemp -d "/private/tmp/virus-scan-tests.XXXXXX")"
readonly TEST_DIR
REPOSITORY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPOSITORY_DIR
readonly SCRIPT_PATH="${REPOSITORY_DIR}/scripts/virus-scan"

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

assert_file_contains() {
	local file="$1"
	local pattern="$2"
	local description="$3"

	if [[ ! -f "${file}" ]] || ! grep -Eq -- "${pattern}" "${file}"; then
		fail "${description}"
	fi
}

create_fake_binaries() {
	local bin_dir="$1"

	mkdir -p "${bin_dir}"

	cat > "${bin_dir}/clamd" <<'EOF'
#!/usr/bin/env bash
set -u

if [[ "${FAKE_START_MODE:-success}" == "failure" ]]; then
	exit 2
fi

config_file=""
while [[ $# -gt 0 ]]; do
	case "$1" in
		-c|--config-file)
			config_file="$2"
			shift 2
			;;
		*)
			shift
			;;
	esac
done

cp "${config_file}" "${TEST_STATE}/clamd.conf"
printf '%s\n' "$$" > "${TEST_STATE}/clamd.pid"
trap 'touch "${TEST_STATE}/clamd.stopped"; exit 0' TERM INT
while :; do
	sleep 0.05
done
EOF

	cat > "${bin_dir}/clamdscan" <<'EOF'
#!/usr/bin/env bash
set -u

printf '%q ' "$@" >> "${TEST_STATE}/clamdscan.calls"
printf '\n' >> "${TEST_STATE}/clamdscan.calls"

for argument in "$@"; do
	if [[ "${argument}" == --ping* ]]; then
		for _ in {1..50}; do
			[[ -f "${TEST_STATE}/clamd.pid" ]] && exit 0
			sleep 0.01
		done
		exit 2
	fi
done

exit "${FAKE_SCAN_EXIT:-0}"
EOF

	chmod +x "${bin_dir}/clamd" "${bin_dir}/clamdscan"
}

run_scan_case() {
	local name="$1"
	local scan_exit="$2"
	local start_mode="$3"
	local expected_exit="$4"
	local state_dir="${TEST_DIR}/${name}"
	local bin_dir="${state_dir}/bin"
	local work_dir="${state_dir}/work"
	local output_file="${state_dir}/output"
	local actual_exit

	mkdir -p \
		"${state_dir}/database" \
		"${state_dir}/tmp" \
		"${work_dir}/.composer-cache" \
		"${work_dir}/node_modules_cache"
	create_fake_binaries "${bin_dir}"

	set +e
	(
		cd "${work_dir}" || exit 99
		PATH="${bin_dir}:${PATH}" \
			TEST_STATE="${state_dir}" \
			TMPDIR="${state_dir}/tmp" \
			CLAMAV_DB_DIR="${state_dir}/database" \
			FAKE_SCAN_EXIT="${scan_exit}" \
			FAKE_START_MODE="${start_mode}" \
			bash "${SCRIPT_PATH}"
	) > "${output_file}" 2>&1
	actual_exit=$?
	set -e

	assert_status "${expected_exit}" "${actual_exit}" "${name}"
}

run_scan_case clean 0 success 0
assert_file_contains "${TEST_DIR}/clean/clamdscan.calls" '--multiscan' 'clean scan requests multiscan'
assert_file_contains "${TEST_DIR}/clean/clamdscan.calls" '--infected' 'clean scan only reports infected files'
assert_file_contains "${TEST_DIR}/clean/clamd.conf" 'ExcludePath .*\\.composer-cache' 'composer cache exclusion is configured for clamd'
assert_file_contains "${TEST_DIR}/clean/clamd.conf" 'ExcludePath .*node_modules_cache' 'node modules cache exclusion is configured for clamd'
assert_file_contains "${TEST_DIR}/clean/output" 'Clean - no viruses found' 'clean scan reports success'
[[ -f "${TEST_DIR}/clean/clamd.stopped" ]] || fail 'clean scan stops the temporary daemon'

run_scan_case infected 1 success 1
assert_file_contains "${TEST_DIR}/infected/output" 'INFECTED FILE FOUND' 'infected scan reports malware'
[[ -f "${TEST_DIR}/infected/clamd.stopped" ]] || fail 'infected scan stops the temporary daemon'

run_scan_case scan_error 2 success 0
assert_file_contains "${TEST_DIR}/scan_error/output" 'Virus scanner internal error' 'scan errors remain fail-open'
[[ -f "${TEST_DIR}/scan_error/clamd.stopped" ]] || fail 'scan errors stop the temporary daemon'

run_scan_case startup_error 0 failure 0
assert_file_contains "${TEST_DIR}/startup_error/output" 'Virus scanner internal error' 'daemon startup errors remain fail-open'

assert_file_contains "${REPOSITORY_DIR}/Dockerfile" 'clamav-daemon' 'container installs the ClamAV daemon package'

if [[ "${failures}" -gt 0 ]]; then
	printf '%s test assertion(s) failed\n' "${failures}" >&2
	exit 1
fi

printf 'ok - virus-scan behavior\n'
