#!/usr/bin/env/python

import base64
import os
import sys
import json
import xmlrpclib
import urllib2
import re

snapshots_url = 'http://192.168.1.18:8080'

def lava_submit(config, lava_server):
	print config

	lava_user = os.environ.get('LAVA_USER')
	if lava_user is None:
		raise EnvironmentError('LAVA_USER is not configured')

	lava_token = os.environ.get('LAVA_TOKEN')
	if lava_token is None:
		raise EnvironmentError('LAVA_TOKEN is not configured')

	lava_server_root = lava_server.rstrip('/')
	if lava_server_root.endswith('/RPC2'):
		lava_server_root = lava_server_root[:-len('/RPC2')]

	try:
		server_url = \
		    'https://{lava_user:>s}:{lava_token:>s}@{lava_server:>s}'
		server = \
		    xmlrpclib.ServerProxy(server_url.format(
		    	    lava_user=lava_user,
		    	    lava_token=lava_token,
		    	    lava_server=lava_server))
		lava_job_id = server.scheduler.submit_job(config)
	except xmlrpclib.ProtocolError, e:
		print 'Error making a LAVA request'
		sys.exit(1)

	print 'LAVA Job Id: %s, URL: http://%s/scheduler/job/%s' % \
	(lava_job_id, lava_server_root, lava_job_id)
	json.dump({'lava_url': 'http://' + lava_server_root,
		'job_id': lava_job_id}, open('lava-job-info', 'w'))


def main():
	lava_server = os.environ.get('LAVA_SERVER',
								'192.168.1.18/RPC2/')
	print 'lava_server: ', lava_server

	custom_json_url = os.environ.get('CUSTOM_JSON_URL')
	print 'custom_json_url: ', custom_json_url
	if custom_json_url is not None:
		request = urllib2.Request(custom_json_url)

		try:
			response = urllib2.urlopen(request)
		except urllib2.URLError, e:
			print 'Failed to reach %s.' % custom_json_url
			if hasattr(e, 'reason'):
				print 'Reason: ', e.reason
			elif hasattr(e, 'code'):
				print 'Code: ', e.code
			sys.exit('Failed to get last successful artifact.')

		config = json.dumps(json.load(response), indent=2)

		lava_submit(config, lava_server)


if __name__ == '__main__':
	main()