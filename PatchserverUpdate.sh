#!/bin/bash

# update the patch server using curl
# Copyright (C) 2019  Dan Engh

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# variables
# patch server URL
# example: https://beta2.communitypatch.com/api/v1/titles
server=""
# JSON XML location
# example: /Users/engh/Documents/Github/Patchserver_Files
xmlLocation=""
# API Key
APIKey=""
# nameing scheme for new patch definition files
# example: _new_definition
newDefinitionScheme=""
# nameing scheme for new patch definition files
# example: _definition_update
updateDefinitionScheme=""

FileCheck() {
	if [[ $2 != "" ]]; then
		if [[ ! -e "$xmlLocation""$2""$updateDefinitionScheme".json ]] || [[ ! -e "$xmlLocation""$2""$newDefinitionScheme".json ]]; then
			echo "Unable to find a file that matches the software title. Please check the name and try again."
			exit 1
		fi
	else
		PatchUsage
		exit 1
	fi
}

PatchUsage() {
	echo "Usage"
	echo "-----------------------------"
	echo "Options:"
	echo "--create"
	echo "--update [old version] [new version]"
	echo "--before [version]"
	echo "--after [version]"
	echo "--delete"
	echo "Examples:"
	echo "patchupdate --create CitrixWorkspace"
	echo "patchupdate --update CitrixWorkspace"
	echo "patchupdate --update CitrixWorkspace 10.0 10.1"
	echo "patchupdate --delete Adobe%20Acrobat%20DC"
	echo "some titles may require that %20 replace spaces"
}

# Update, create or delete a definition
if [[ $1 == "--update" ]]; then
	# FileCheck
	if [[ $3 != "" ]]; then
		if [[ $4 != "" ]]; then
			sed -i '' -e "s|${3}|"${4}"|g" "$xmlLocation""$2""$updateDefinitionScheme".json
		else
			echo "You must provide both an old version and a new version"
			echo "ex. patchupdate --update [software title] [old version] [new version]"
			exit 1
		fi
	fi
	curl --http1.1 -H "Content-Type: application/json" -H 'Authorization: Bearer "'{$APIKey}'"' "$server"/$2/version -T "$xmlLocation""$2""$updateDefinitionScheme".json -X POST
elif [[ $1 == "--create" ]]; then
	# FileCheck
	curl --http1.1 -H "Content-Type: application/json" -H 'Authorization: Bearer "'{$APIKey}'"' "$server" -T "$xmlLocation""$2""$newDefinitionScheme".json -X POST
elif [[ $1 == "--before" ]]; then
	# FileCheck
	curl --http1.1 -H "Content-Type: application/json" -H 'Authorization: Bearer "'{$APIKey}'"' "$server"/$2/version?insert_before="$3" -T "$xmlLocation""$2""$updateDefinitionScheme".json -X POST
elif [[ $1 == "--after" ]]; then
	# FileCheck
	curl --http1.1 -H "Content-Type: application/json" -H 'Authorization: Bearer "'{$APIKey}'"' "$server"/$2/version?insert_after="$3" -T "$xmlLocation""$2""$updateDefinitionScheme".json -X POST
elif [[ $1 == "--delete" ]]; then
	curl --http1.1 -H "Content-Type: application/json" -H 'Authorization: Bearer "'{$APIKey}'"' "$server"/$2 -X DELETE
else
	PatchUsage
fi
