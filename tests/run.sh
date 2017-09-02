#!/bin/sh

basedir="$(cd `dirname ${0}` ; pwd)"

. "${basedir}/ansible-run.sh"

parse_cli $@
run_ansible $SCREENED_CLI

