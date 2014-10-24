#!/bin/bash
JENKINS_GIT_COMMAND_FILE="/tmp/jenkins-git-commands.txt"
HISTORY_FILE="${JENKINS_HOME}/userContent/patch-history.txt"

BRANCH="kitkat-mr1-pyrope-dev"
BOARD_NAME="lynx"
TOP="${WORKSPACE}/${BRANCH}"
RESULT_DIR="${TOP}/result"
BOOT_DEVICE_TYPE="spirom"
BUILD_NAME="${BUILD_TAG}-${BOARD_NAME}-${BUILD_ID}"

source ${JENKINS_HOME}/jenkins-nexell-tool/build.sh

PATH=${JENKINS_HOME}/bin:$PATH

project=$(get_project $JENKINS_GIT_COMMAND_FILE)
echo "project: $project"

echo "workspace: ${WORKSPACE}"

if [ ! -e ${WORKSPACE}/${BRANCH} ]; then
    download_android_source ${BRANCH}
else
    cd ${BRANCH}
    repo sync
fi

patch_dir=$(get_patch_dir $project)
echo "patch_dir: $patch_dir"

pushd $(pwd)
cd $patch_dir
patch_cmd=$(get_cmd $JENKINS_GIT_COMMAND_FILE)
echo "patch_cmd: $patch_cmd"
patch_result=$(eval $patch_cmd)
echo "patch_result: $patch_result"
popd

write_history $HISTORY_FILE $(get_id $JENKINS_GIT_COMMAND_FILE)

build_android ${BOARD_NAME}

if [ $? != 0 ]; then
    echo "build failed"
    exit -1
fi
rm -f $JENKINS_GIT_COMMAND_FILE
echo "build success"

source ${JENKINS_HOME}/jenkins-nexell-tool/packaging.sh
get_root_device
generate_partitionmap
generate_2ndboot
mkdir -p ${WORKSPACE}/${BUILD_NAME}/images
cp ${RESULT_DIR}/partmap.txt ${WORKSPACE}/${BUILD_NAME}/images
cp ${RESULT_DIR}/*.bin ${WORKSPACE}/${BUILD_NAME}/images
cp ${RESULT_DIR}/*.img ${WORKSPACE}/${BUILD_NAME}/images
cd ${WORKSPACE}/${BUILD_NAME}
tar cvjf images.tar.bz2 images
rm -rf images

# for LAVA
SNAPSHOT_SERVER=http://192.168.1.18:8080
DEVICE_TYPE=pyrope
TARGET=lynx-nxp4330
BUNDLE_STREAM_NAME="/anonymous/jenkins/"
export LAVA_SERVER=192.168.1.18/RPC2/
export CUSTOM_JSON_URL=${SNAPSHOT_SERVER}/android/${BUILD_NAME}/lava_job_definition.json

cat << EOF > lava_job_definition.json
{
    "timeout": 2000,
    "job_name": "${BUILD_NAME}",
    "device_type": "${DEVICE_TYPE}",
    "target": "${TARGET}",
    "actions": [
        {
            "command": "nexell_reset_or_reboot"
        },
        {
            "command": "nexell_deploy_image",
            "parameters": {
                "interface": "fastboot",
                "image": "${SNAPSHOT_SERVER}/android/${BUILD_NAME}/images.tar.bz2"
            }
        },
        {
            "command": "nexell_boot_image",
            "parameters": {
                "type": "android",
                "check_msg": "healthd: battery",
                "timeout": "300",
                "commands": [
                    "env default -a",
                    "saveenv"
                ],
                "logcat_check_msg": "Displayed com.android.launcher/com.android.launcher2.Launcher",
                "logcat_check_timeout": "600"
            }
        },
        {
            "command": "lava_test_shell",
            "parameters": {
                "testdef_repos": [
                    {
                        "git-repo": "http://git.linaro.org/people/sanjay.rawat/test-definitions2.git",
                        "testdef": "android/ime.yaml"
                    }
                ],
                "timeout": 900
            }
        },
        {
            "command": "submit_results",
            "parameters": {
              "server": "http://${LAVA_SERVER}",
              "stream": "${BUNDLE_STREAM_NAME}"
            }
        }
    ]
}
EOF

cd ${WORKSPACE}

# upload to snapshot server
echo "Upload ${BUILD_NAME} to ${SNAPSHOT_SERVER}/android/${BUILD_NAME}"
python ${JENKINS_HOME}/jenkins-nexell-tool/linaro-cp.py -k 1234abcd --server ${SNAPSHOT_SERVER}/ ${BUILD_NAME} android/${BUILD_NAME}

# register command to LAVA server
echo "Register LAVA JOB: ${CUSTOM_JSON_URL}"
python ${JENKINS_HOME}/jenkins-nexell-tool/post-build-lava.py
