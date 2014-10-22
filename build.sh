#!/bin/bash

# get from "/tmp/jenkins-git-commands.txt",
function get_id()
{
    echo $(cat $1 | grep "id" | awk -F'#' '{print $2}')
}

function get_project()
{
    echo $(cat $1 | grep "project" | awk -F'#' '{print $2}')
}

function get_cmd()
{
    echo $(cat $1 | grep "cmd" | awk -F'#' '{print $2}')
}

function get_patch_dir()
{
	project=$1
	echo $(repo forall -c 'echo -n "project_dir:$PWD," && git remote -v' | grep $project | awk -F',' '{print $1}' | grep "project_dir" | awk -F ':' '{print $2}')
}

function download_android_source()
{
	branch=$1
	mkdir -p ${branch}
	cd ${branch}
	${JENKINS_HOME}/bin/repo init -u http://git.nexell.co.kr:8081/nexell/android/kitkat/manifest -b ${branch}
	repo sync
}

function build_android()
{
	board=$1
	./device/nexell/tools/build.sh -b ${board}
}

# "/var/lib/jenkins/userContent/patch-history.txt"
function write_history()
{
	history_file=$1
	id=$2
	echo "$id" >> history_file
}

# sequence
# JENKINS_GIT_COMMAND_FILE="/tmp/jenkins-git-commands.txt"
# HISTORY_FILE="/var/lib/jenkins/userContent/patch-history.txt"

# source ${JENKINS_HOME}/jenkins-nexell-tool/build.sh
# download_android_source kitkat-mr1-pyrope-dev
# project=$(get_project $JENKINS_GIT_COMMAND_FILE)
# patch_dir=$(get_patch_dir $project)
# pushd $(pwd)
# cd $patch_dir
# patch_cmd=$(get_cmd $JENKINS_GIT_COMMAND_FILE)
# patch_result=$(eval $patch_cmd)
# popd
# write_history $HISTORY_FILE $(get_id $JENKINS_GIT_COMMAND_FILE)
# build_android lynx
# if [ $? != 0 ]; then
# 	echo "build failed"
# 	exit -1
# fi
# rm -f $JENKINS_GIT_COMMAND_FILE
# echo "build success"
# exit 0
