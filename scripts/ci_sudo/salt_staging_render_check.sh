#!/bin/bash
# $1 should be $CI_COMMIT_REF_NAME
# $2 should be $CI_COMMIT_SHA
# $3 should be $CI_COMMIT_BEFORE_SHA
# $4 should be repository ssh URL 

if [ "_$1" = "_" ]; then 
	stdbuf -oL -eL echo 'ERROR: $1 ($CI_COMMIT_REF_NAME) is not set'
	exit 1
fi
if [ "_$2" = "_" ]; then 
	stdbuf -oL -eL echo 'ERROR: $2 ($CI_COMMIT_SHA) is not set'
	exit 1
fi
if [ "_$3" = "_" ]; then 
	stdbuf -oL -eL echo 'ERROR: $3 ($CI_COMMIT_BEFORE_SHA) is not set'
	exit 1
fi
if [ "_$4" = "_" ]; then 
	stdbuf -oL -eL echo 'ERROR: $4 ($CI_REPOSITORY_URL) is not set'
	exit 1
fi

WORK_DIR=/tmp/salt_staging/$1
mkdir -p ${WORK_DIR}
cd ${WORK_DIR} || ( stdbuf -oL -eL echo "ERROR: ${WORK_DIR} does not exist"; exit 1 )

# Use locking with timeout to align concurrent git checkouts in a line
LOCK_DIR=${WORK_DIR}/.ci.lock
LOCK_RETRIES=1
LOCK_RETRIES_MAX=180
SLEEP_TIME=5
until mkdir "$LOCK_DIR" || (( LOCK_RETRIES == LOCK_RETRIES_MAX ))
do
	stdbuf -oL -eL echo "NOTICE: Acquiring lock failed on $LOCK_DIR, sleeping for ${SLEEP_TIME}s"
	let "LOCK_RETRIES++"
	sleep ${SLEEP_TIME}
done
if [ ${LOCK_RETRIES} -eq ${LOCK_RETRIES_MAX} ]; then
	stdbuf -oL -eL echo "ERROR: Cannot acquire lock after ${LOCK_RETRIES} retries, giving up on $LOCK_DIR"
	exit 1
else
	stdbuf -oL -eL echo "NOTICE: Successfully acquired lock on $LOCK_DIR"
	trap 'rm -rf "$LOCK_DIR"' 0
fi

GRAND_EXIT=0
mkdir -p ${WORK_DIR}/srv/scripts/ci_sudo
rm -f ${WORK_DIR}/srv/scripts/ci_sudo/$(basename $0).out
exec > >(tee ${WORK_DIR}/srv/scripts/ci_sudo/$(basename $0).out)
exec 2>&1

# Update local repo
( set -x ; stdbuf -oL -eL git -C ${WORK_DIR}/srv pull || ( set -x ; stdbuf -oL -eL mkdir -p ${WORK_DIR}/srv && cd ${WORK_DIR}/srv && stdbuf -oL -eL git init . && stdbuf -oL -eL git remote add origin $4 ) ) || GRAND_EXIT=1
cd ${WORK_DIR}/srv || ( stdbuf -oL -eL echo "ERROR: ${WORK_DIR}/srv does not exist"; exit 1 )
( set -x ; stdbuf -oL -eL git fetch && stdbuf -oL -eL git checkout -B $1 origin/$1 ) || GRAND_EXIT=1
( set -x ; stdbuf -oL -eL git submodule init ) || GRAND_EXIT=1
( set -x ; stdbuf -oL -eL git submodule update --recursive -f --checkout ) || GRAND_EXIT=1
( set -x ; stdbuf -oL -eL ln -sf ../../.githooks/post-merge .git/hooks/post-merge ) || GRAND_EXIT=1
( set -x ; stdbuf -oL -eL .githooks/post-merge ) || GRAND_EXIT=1
stdbuf -oL -eL echo "NOTICE: populating repo/etc/salt for salt-call --local"
( set -x ; mkdir -p ${WORK_DIR}/etc/salt && rsync -av ${WORK_DIR}/srv/.gitlab-ci/staging-etc-with-pillar/ ${WORK_DIR}/etc/salt/ && sed -i -e "s#_WORK_DIR_#${WORK_DIR}#" ${WORK_DIR}/etc/salt/* ) || exit 1

# Get changed files from the last push and try to render some of them
for FILE in $(git diff-tree --no-commit-id --name-only -r $2 $3); do
	stdbuf -oL -eL echo "NOTICE: checking file ${WORK_DIR}/srv/${FILE}"
	if [[ -e "${WORK_DIR}/srv/${FILE}" ]]; then
		if [[ ${FILE} == *.sls || ${FILE} == *.jinja ]]; then
			if stdbuf -oL -eL salt-call --local --config-dir=${WORK_DIR}/etc/salt --retcode-passthrough slsutil.renderer ${WORK_DIR}/srv/${FILE}; then
				stdbuf -oL -eL echo "NOTICE: slsutil.renderer of file ${WORK_DIR}/srv/${FILE} succeeded"
			else
				GRAND_EXIT=1
				stdbuf -oL -eL echo "ERROR: slsutil.renderer of file ${WORK_DIR}/srv/${FILE} failed"
			fi
		else
			stdbuf -oL -eL echo "NOTICE: ${WORK_DIR}/srv/${FILE} is neither .sls nor .jinja"
		fi
	else
		stdbuf -oL -eL echo "NOTICE: ${WORK_DIR}/srv/${FILE} does not exist"
	fi
done

grep -q "^ERROR" ${WORK_DIR}/srv/scripts/ci_sudo/$(basename $0).out && GRAND_EXIT=1

exit $GRAND_EXIT
