#!/usr/bin/env/python

import sys
import subprocess
import json
import re

def _get_gerrit_open_patchsets(ssh_server, port, user):
	server = "%s@%s" % (user, ssh_server)
	command = ["ssh", 
			    "-p", 
			    port, 
			    server,
			    "gerrit", "query",
			    "--format=JSON",
			    "--patch-sets",
			    "status:open"]
	return subprocess.check_output(command)

def _get_count_of_patchset(query_reply):
	result = query_reply.split('\n')
	stats = result[len(result) - 2]
	json_stats = json.loads(stats)
	count = json_stats['rowCount']
	return count

def  _is_exist_patchset(query_reply):
	count = _get_count_of_patchset(qyery_reply)
	if count > 0:
		return True
	return False

def _get_project_and_refs(query_reply):
	result = query_reply.split('\n')
	json_result = json.loads(result[0])
	patch_sets = json_result['patchSets']
	return (json_result['project'], patch_sets[0]['ref'])

def _write_git_cmds_to_file(file_name, server, project, refs):
	f = open(file_name, 'w')
	cmds = "git fetch %s/%s %s && git checkout FETCH_HEAD" % (server, project, refs)
	f.write(project)
	f.write("\n")
	f.write(cmds)
	f.close()

def _check_patch_id_in_history(patch_id, history_file):
	try:
		f = open(history_file)
	except:
		return False

	pattern = re.compile(patch_id)
	file_contents = f.read()
	m = pattern.search(file_contents)
	if m is None:
		return False
	return True

def _get_available_patchset(query_reply):
	results = query_reply.split('\n')[:-2]
	for r in results:
		# print r
		json_item = json.loads(r)
		patch_set = json_item['patchSets']
		patch_id = json_item['id']
		if not _check_patch_id_in_history(patch_id, "/var/lib/jenkins/userContent/patch-history.txt"):
			project = json_item['project']
			refs = patch_set[0]['ref']
			return (patch_id, project, refs)

	return (None, None, None)

def _write_result_data_to_file(file_name, server, patch_id, project, refs):
	f = open(file_name, 'w')
	str_patch_id = "id#%s\n" % patch_id
	str_project = "project#%s\n" % project
	str_cmd = "cmd#git fetch %s/%s %s && git checkout FETCH_HEAD" % (server, project, refs)
	f.write(str_patch_id)
	f.write(str_project)
	f.write(str_cmd)
	f.close()

if __name__ == '__main__':
	query_reply = _get_gerrit_open_patchsets("git.nexell.co.kr", "29418", "swpark")
	if query_reply is None:
		print("can't get gerrit query reply!!!")
		sys.exit(18)

	# if _is_exist_patchset(query_reply):
	# 	project, refs = _get_project_and_refs(query_reply)
	# 	print("project %s, refs %s") % (project, refs)
	# 	_write_git_cmds_to_file(
	# 		"/tmp/jenkins-git-commands.txt",
	# 		"http://git.nexell.co.kr:8081",
	# 		project,
	# 		refs)
	# 	sys.exit(0)

	patchset_count = _get_count_of_patchset(query_reply)
	if patchset_count > 0:
		patch_id, project, refs = _get_available_patchset(query_reply)	
		if patch_id:
			_write_result_data_to_file(
				"/tmp/jenkins-git-commands.txt",
				"http://git.nexell.co.kr:8081",
				patch_id,
				project,
				refs)
			sys.exit(0)

	print("No Patchset!")
	sys.exit(-1)