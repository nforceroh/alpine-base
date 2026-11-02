#!/usr/bin/env bash
# Smoke tests for nforceroh/alpine-base. Pass an image reference as $1.
set -uo pipefail

IMAGE="${1:-ghcr.io/nforceroh/alpine-base:dev}"
export IMAGE
PASS=0
FAIL=0
SETTLE_SECONDS="${SETTLE_SECONDS:-15}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

check() {
	local label="$1"; shift
	if "$@" >/dev/null 2>&1; then
		echo -e "  ${GREEN}PASS${NC}  ${label}"
		PASS=$((PASS + 1))
	else
		echo -e "  ${RED}FAIL${NC}  ${label}"
		FAIL=$((FAIL + 1))
	fi
}

# Runs a command inside the image with the entrypoint bypassed. Use for static
# checks that must not depend on s6 init having run.
in_image() { docker run --rm --entrypoint sh "$IMAGE" -c "$1"; }

# Runs the image with the real entrypoint and greps its output.
check_output() {
	# Call as: check_output "label" "pattern" [docker opts...] -- <command...>
	local label="$1"; local pattern="$2"; shift 2
	local opts="" cmd="" seen_sep=0
	for arg in "$@"; do
		if [ "$arg" = "--" ]; then seen_sep=1; continue; fi
		if [ "$seen_sep" -eq 1 ]; then cmd="$cmd $arg"; else opts="$opts $arg"; fi
	done
	# shellcheck disable=SC2086
	if docker run --rm $opts "$IMAGE" $cmd 2>&1 | grep -qE -- "$pattern"; then
		echo -e "  ${GREEN}PASS${NC}  ${label}"
		PASS=$((PASS + 1))
	else
		echo -e "  ${RED}FAIL${NC}  ${label}"
		FAIL=$((FAIL + 1))
	fi
}

echo -e "${YELLOW}== nforceroh/alpine-base ==${NC}"
echo "  image: ${IMAGE}"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
	echo -e "${RED}image ${IMAGE} not found — build it first (make build)${NC}"
	exit 1
fi

# --- entrypoint and s6 ------------------------------------------------------
check "s6 overlay entrypoint present" in_image 'test -x /init'
check "s6 service database is populated" \
	in_image sh -c '[ -d /etc/s6-overlay/s6-rc.d ] && [ -n "$(ls -A /etc/s6-overlay/s6-rc.d)" ]'

# --- runtime state created by init-adduser ----------------------------------
check_output "default user abc exists" 'uid=[0-9]+\(abc\)' -- id abc
check_output "PUID/PGID are honoured" 'uid=1500\(abc\) gid=1500' \
	-e PUID=1500 -e PGID=1500 -- id abc
check "init creates /app, /config and /defaults" \
	in_image sh -c 'test -d /app && test -d /config && test -d /defaults'

# --- timezone ---------------------------------------------------------------
check_output "TZ is applied" '/zoneinfo/Europe/Paris' \
	-e TZ=Europe/Paris -- readlink /etc/localtime

# --- tooling ----------------------------------------------------------------
check "jq, curl, openssl and bash are present" \
	in_image sh -c 'command -v jq && command -v curl && command -v openssl && command -v bash'

echo
if [ "${FAIL}" -gt 0 ]; then
	echo -e "${RED}${FAIL} failed${NC}, ${PASS} passed"
	exit 1
fi
echo -e "${GREEN}all ${PASS} checks passed${NC}"
