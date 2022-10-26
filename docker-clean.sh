#!/bin/bash

## Docker registry cleanup script
##
## Usage:
##	./docker-clean.sh {list|clean}
##
## ./docker-clean.sh list
## 	List the versions, prefixed with 'DELETE' or 'KEEP' to show which versions should be kept.
##
## ./docker-clean.sh clean
## 	Remove all versions that are marker 'DELETE' and run garbage-collect within the container


set -euo pipefail

## Configure maximum number of versions per repo
MAX_PER_REPO="10"

## Protect certain versions
declare -A PROTECT

## For example:
# PROTECT["app"]="v1\.23 "
# PROTECT["mysql"]="v5\.27 "

## Make this point to the correct 'garbage-collect' command (i.e., change docker image name)
GARBAGE_COLLECT="sudo docker exec root_registry_1 bin/registry garbage-collect /etc/docker/registry/config.yml"

## Directory where the repositories reside
root="/docker/docker-registry/docker/registry/v2/repositories"

do-list() {
	ls -d $root/* \
		| xargs -n 1 basename \
		| while read repo; do
			# iterate over tags for this repository

			ls -t -d $root/$repo/_manifests/tags/* \
				| xargs -n 1 basename \
				| while read tag; do
					echo "$repo $tag $(awk -F ":" '{print $2}' < $root/$repo/_manifests/tags/$tag/current/link)"
				done \
				| awk '{ print ((/'"${PROTECT[$repo]:-"MATCH NONE^"}"'/ || NR <= '$MAX_PER_REPO') ? "KEEP" : "DELETE")" "$0 }'
		done;
}

do-clean() {
	_df() {
		sudo df --output=avail -h $root | tail -1
	}
	
	local delete_dirs; 
	local df_before;
	local df_after;

	df_before="$(_df)"
	
	do-list \
		| awk '/^DELETE/ { 
			print "'$root'/"$2"/_manifests/tags/"$3" '$root'/"$2"/_manifests/revisions/sha256/"$4
		}' \
		| while read d; do
			sudo rm -rf $d;
		done;
	$GARBAGE_COLLECT

	df_after="$(_df)"

	echo "Before: $df_before"
	echo "After: $df_after"
}

do-$1;

