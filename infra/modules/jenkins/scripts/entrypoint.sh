#!/bin/bash
chmod 666 /var/run/docker.sock
exec /usr/bin/tini -- /usr/local/bin/jenkins.sh "$@"