#!/usr/bin/env python3
#
# This script can be used to reconstruct /etc/export entries from /export/projects, generated by nfs-provisioner.
#
# Example: ./scripts/exports_from_projects.py '192.168.11.*' < /export/projects
#
# where '192.168.11.*' is the export address wildcard, adapt this to your project
#
# Modify to need if necessary.
#

import sys

for line in sys.stdin:
    if line.find(':') < 0:
        continue
    fsid, directory, quota = line.split(':')
    fsid = int(fsid)
    sys.stdout.write('%s %s(rw,insecure,no_root_squash,fsid=%d)\n' % (directory, sys.argv[1], fsid))
