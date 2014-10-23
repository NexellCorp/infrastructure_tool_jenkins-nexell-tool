Jenkins helper scripts for nexell infrastructure
************************************************
.. note::
This help tools are running in Jenkins Server

get_patchset.py
================
This script get patchSets from nexell gerrit server
And, if any patchset is not tested(compare to ${WORKSPACE}/patch-history.txt)
make temporary patchset information file(/tmp/jenkins-git-commands.txt)
Jenkins use this script for scripttrigger

build.sh
========
This script is shell library for building

packaging.sh
============
This script is shell library for packaging

linaro-cp.py
============
This script uploads build output(packaging files) to nexell snapshot server

jenkins-example.sh
==================
Jenkins build shell example

lava_job_definition_example.json
================================
LAVA Job Definition json example
