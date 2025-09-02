#!/bin/bash
set -e


#######################
#
# - Set up error handling
#
me="$0"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )


declare -a cleanup_commands
add_cleanup() {
	local cmd="$1"
	cleanup_commands=("$cmd" "${cleanup_commands[@]}")
}
cleanup() {
	for cmd in "${cleanup_commands[@]}"; do eval "$cmd"; done
}
trap cleanup EXIT



#######################
#
# - Handle command line options
#
#usage() {
#	echo "$me [options] [args ...]"
#	echo "options:"
#	echo "	--debug: when 'up' in args, containers have debug configuration"
#	echo "	--develop: same as --debug"
#	echo "	--help: print this help"
#	echo "	--no-cache: use no cached layers during build"
#	echo "args:"
#	echo "	run 'docker compose <args>' after build"
#}
#
#develop_mode=0
#execute_up=0
#other_args=()
#build_args=()
#for arg in "$@"; do
#	case "x$arg" in
#	x--help) usage && exit 0 ;;
#
#	x--debug| x--develop) develop_mode=1 ;;
#
#	x--no-cache) build_args+=("--no-cache") ;;
#
#	xup) execute_up=1 ;;& # fallthrough
#
#	*) other_args+=("$arg") ;;
#
#	esac
#done


#######################
#
# - Start support services
#
start_web_server() {
  docker run --rm -d \
	--name erpnext-build-git-server \
	-v /media/git:/srv/git \
	"git-server" || exit 1
  add_cleanup "docker kill erpnext-build-git-server"

  ip=$(docker inspect erpnext-build-git-server --format '{{.NetworkSettings.IPAddress}}')
  port=4444
  export ERPNEXT_BUILD_GIT_URL="http://${ip}:${port}/git"
  echo "Temporary git server running at $ERPNEXT_BUILD_GIT_URL"
}
start_web_server

start_redis_cache() {
  docker run --rm -d \
	--name erpnext-build-redis-cache \
	redis:6.2-alpine || exit 1
  add_cleanup "docker kill erpnext-build-redis-cache"
  redis_ip=$(docker inspect erpnext-build-redis-cache --format '{{.NetworkSettings.IPAddress}}')
  export ERPNEXT_BUILD_REDIS_CACHE_IP=$redis_ip
  echo "Temporary redis cache running on ip $ERPNEXT_BUILD_REDIS_CACHE_IP"
}
start_redis_cache


#######################
#
# - Build the Frappe apps.json file
#
pyscript() {
cat<<EOF
import os
import sys

for l in sys.stdin:
  sys.stdout.write( l.replace("\${ERPNEXT_BUILD_GIT_URL}",
                   os.environ.get("ERPNEXT_BUILD_GIT_URL","")
  ))
EOF
}

rendered_config() {
cat $SCRIPT_DIR/apps.json | python3 <(pyscript)
}

echo Using configuration:
rendered_config
export APPS_JSON_BASE64=$(rendered_config | base64 -w 0 )

# Validate the config decodes correctly
diff <(rendered_config) <(echo -n $APPS_JSON_BASE64 | base64 -d) || exit 1


#######################
#
# - Build the Frappe apps.json file
#
#cd ${SCRIPT_DIR}/frappe_docker
#
#docker compose build "${build_args[@]}" || exit $?
docker compose build
#
#if [ $execute_up -eq 1 ]; then
#	docker compose down || exit $?
#	if [ $develop_mode -eq 1 ]; then
#		other_args=( "-f" "compose.yml" "-f" "compose.jon-debug.yml" "${other_args[@]}" )
#	fi
#fi
#if [ ${#other_args[@]} -gt 0 ]; then
#	docker compose "${other_args[@]}"
#fi
