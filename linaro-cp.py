#!/usr/bin/env python

import argparse
import cStringIO
import os
import pycurl
import sys
import time

# Public artifacts BUILD-INFO.txt
build_info = 'Format-Version: 0.5\n\nFiles-Pattern: *\nLicense-Type: open\n'


def _get_transfer_queue(server_base, src, dst):
    transfer_queue = {}
    src_dir = os.path.abspath(src)
    for root, dirs, files in os.walk(src_dir):
        for f in files:
            src_file = os.path.join(root, f)
            dst_file = os.path.join(root, f)[len(src_dir):]
            dst_file = '%s%s%s' % (server_base, dst, dst_file)
            build_info_file = dst_file.replace(f, 'BUILD-INFO.txt')
            transfer_queue[dst_file] = src_file
            transfer_queue[build_info_file] = 'BUILD-INFO.txt'
    return transfer_queue


def _upload(curl, key, url, filename, retry_count=3):
    response = cStringIO.StringIO()
    send = [
        ('file', (pycurl.FORM_FILE, filename)),
        ('key', (pycurl.FORM_CONTENTS, key)),
    ]
    curl.setopt(pycurl.URL, url)
    curl.setopt(pycurl.HTTPPOST, send)
    curl.setopt(pycurl.WRITEFUNCTION, response.write)
    try:
        curl.perform()
    except Exception as e:
        if retry_count > 0:
            # server could be reloading or something. give it a second and
            # try again
            print('Upload failed for %s, retrying in 2 seconds' % url)
            time.sleep(2)
            return _upload(curl, key, url, filename, retry_count - 1)
        else:
            return str(e)

    return response.getvalue()


def _upload_transfer_queue(key, transfer_queue):
    curl = pycurl.Curl()
    transfer_failures = []
    for transfer_item in transfer_queue:
        http_status = _upload(
            curl, key, transfer_item, transfer_queue[transfer_item])
        if http_status != 'OK':
            transfer_failures.append('%s: %s' % (transfer_item, http_status))
    curl.close()
    return transfer_failures


def main():
    parser = argparse.ArgumentParser(
        description='Copy file(s) from source to destination')
    parser.add_argument('-k', '--key', help='key used for the copy')
    parser.add_argument('--server', default='http://snapshots.linaro.org/',
                        help='Publishing API server. default=%(default)s')
    parser.add_argument('src', help='source file(s) to copy')
    parser.add_argument('dst', help='destination to copy the file(s)')

    arguments = parser.parse_args()
    src = arguments.src
    dst = arguments.dst
    # Publish key is required. Fallback to PUBLISH_KEY environment
    # variable when it isn't passed as an argument
    if arguments.key:
        key = arguments.key
    else:
        key = os.environ.get('PUBLISH_KEY')
        if key is None:
            sys.exit('Key is not defined.')

    # Write BUILD-INFO.txt file on the filesystem
    # A better solution is available in PycURL HEAD,
    # using FORM_BUFFER/FORM_BUFFERPTR
    with open('BUILD-INFO.txt', 'w') as f:
        f.write(build_info)

    transfer_queue = _get_transfer_queue(arguments.server, src, dst)
    transfer_failures = _upload_transfer_queue(key, transfer_queue)

    # Remove temporary BUILD-INFO.txt file
    os.remove('BUILD-INFO.txt')

    if len(transfer_failures) > 0:
        sys.exit('Failed to transfer:\n  %s' % '\n  '.join(transfer_failures))


if __name__ == '__main__':
    main()
