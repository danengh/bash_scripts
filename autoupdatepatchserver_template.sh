#!/bin/bash


# variables
######################
# current user

OldIFS="$IFS"
IFS=$'\n'
currUser=$( ls -l /dev/console | awk '{print $3}' )

# time variables
timestamp=$(date "+%Y-%m-%dT%H:%M:%SZ")
tdate=$(date "+%Y-%m-%d")
ydate=$(date -v -1d "+%Y-%m-%d")

# file variables
computerName=$(scutil --get ComputerName)
basePath="/Users/"$currUser"/Library/AutoPkg/Logs"
mkdir -p "$basePath"
currPackageList=""$basePath"/$tdate-Package-List.txt"
arcPackageList=""$basePath"/$ydate-Package-List.txt"
diffPackageList=""$basePath"/New-Package-List.txt"
packageLog=""$basePath"/newPackage.log"

# create files if they don't exist
if [[ ! -e "$currPackageList" ]]; then
	touch "$currPackageList"
fi

if [[ ! -e "$arcPackageList" ]]; then
	touch "$arcPackageList"
fi

if [[ ! -e "$diffPackageList" ]]; then
	touch "$diffPackageList"
fi

if [[ ! -e "$packageLog" ]]; then
	touch "$packageLog"
fi

# pull any new json files from github repo
pushd /path/to/git/repo/
git pull
popd

# query the jss for package list and start logging
# check to see if the jss_helper doesn't grab info from the JSS for some reason. If it does, it will copy the previous days file
# so we don't get output to hipchat for all packages
jss_helper package > "$currPackageList"
if [ ! -s "$currPackageList" ]; then
	cp "$arcPackageList" "$currPackageList"
fi

echo $(date) >> "$packageLog"
echo "********************************************" >> "$packageLog"
curl -d '{"color":"gray","message":"***************'"$tdate"' '"$computerName"'***************","notify":false,"message_format":"text"}' -H 'Content-Type: application/json' https://hipchat.server.com/v2/room/###/notification?auth_token=<auth token>

# find differences in packages from the previous day to find new packages
diff -yB --suppress-common-lines "$currPackageList" "$arcPackageList" > "$diffPackageList"

# read differences, determine title and version and add them into an array
newPackages=($(awk -F ': ' '{print $3}' "$diffPackageList"))

# split name and version into new arrays for title and version
iter=0
softTitle=()
softVer=()

for item in "${newPackages[@]}"; do
	softTitle[$iter]=$( cut -d'-' -f1 <<< "$item" )
	echo "${softTitle[$iter]}"
	softVer[$iter]=$( cut -d'-' -f2 <<< "$item" )
	echo "${softVer[$iter]}"
	iter=$(( iter + 1 ))
done

# bring iterator back down to last added index
iter=$(( iter - 1 ))

# iterate through stored values in both arrays to mark up json files with new date and version
while [[ $iter -ge 0 ]]; do

# put software title into a useable state for substitution
	updateJson="${softTitle[$iter]}"
	verJson="${softVer[$iter]}"
	echo "$updateJson"" ""$verJson" >> $packageLog

# recursively substitute %20 in place of spaces to find correct json file
# %20 is needed in place of spaces on the patch server for ID
	while [[ "$updateJson" =~ " " ]]; do
		updateJson=${updateJson/" "/%20}
	done

# find json file and old date, version and replace them with new date and version

	softJson=$(find /path/to/git/repo/ -iname "$updateJson"*update*) > /dev/null
	echo "$softJson"
	if [[ "$softJson" != "" ]]; then
		oldVer=$( cat "$softJson" | grep -m 1 version | awk '{print $2}')

		oldDate=$( cat "$softJson" | grep -m 1 releaseDate | awk '{print $2}')

		sed -i '' -e "s|$oldVer|\"${softVer[$iter]}\",|g" "$softJson"
		sed -i '' -e "s|$oldDate|\"$timestamp\",|g" "$softJson"
		curl --http1.1 -H "Content-Type: application/json" http://your.patchserver.com:5000/api/v1/title/"$revJson"/version -T "$softJson" -X POST
		curl -d '{"color":"green","message":"'"$revJson"' '"$verJson"' has been updated on the patch server","notify":false,"message_format":"text"}' -H 'Content-Type: application/json' https://hipchat.server.com/v2/room/###/notification?auth_token=<auth token>
		echo "${softTitle[$iter]}"" has been updated" >> $packageLog
	else
		curl -d '{"color":"green","message":"'"$tdate"' : '"$revJson"' '"$verJson"' has updated. Please update patch definitions manually.","notify":false,"message_format":"text"}' -H 'Content-Type: application/json' https://hipchat.server.com/v2/room/###/notification?auth_token=<auth token>
		echo "${softTitle[$iter]}"" does not have a patch definition" >> $packageLog
	fi
	iter=$(( iter - 1 ))
done

# commit changes to update json files back to github
pushd /path/to/git/repo/
git commit -a -m "daily update"
git push
popd
