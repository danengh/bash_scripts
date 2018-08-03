#!/bin/bash
# Created by Dan Engh
# Last modified Feb 8, 2018

#Wait for user session
userSession="No"

while [[ "$userSession" == "No" ]]; do
	dockYes=$( pgrep Dock )
	if [[ "$dockYes" != "" ]]; then
		userSession="Yes"
	else
		sleep 1
	fi
done

#Create empty array and txt of software titles

softwareArray=()
mkdir -p /Library/Application\ Support/UMN/
touch /Library/Application\ Support/UMN/softwareList.txt
chmod 777 /Library/Application\ Support/UMN/softwareList.txt
echo "Install all the following or customize:" >> /Library/Application\ Support/UMN/softwareList.txt
echo "" >> /Library/Application\ Support/UMN/softwareList.txt
titleCount=$#
separator=1

for events in "${@:4}"; do
	if [[ "$events" == "" ]]; then
		separator=$((separator+1))
	fi
done

for events in "${@:4}"; do
	if [[ "$events" != "" ]]; then
		echo -n "$events" >> /Library/Application\ Support/UMN/softwareList.txt
	fi
	if [[ $separator -lt $titleCount ]] && [[ "$events" != "" ]]; then
		echo -n ", " >> /Library/Application\ Support/UMN/softwareList.txt
	fi
	separator=$((separator+1))
done

softwareList=$(cat /Library/Application\ Support/UMN/softwareList.txt)

#Use Jamf Helper to find out if they want to install everything or customize
i=0
result=$( /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon "/Library/Application Support/JAMF/bin/Management Action.app/Contents/Resources/Self Service.icns" -title "Software To Install" -button1 "Install All" -button2 "Customize" -defaultButton 1 -description "$softwareList")
if [[ "$result" -eq 0 ]]; then
	for events in "${@:4}"; do
		if [[ "$events" != "" ]]; then
			softwareArray[i]="$events"
			i=$((i + 1))
		fi
	done
else
	for events in "${@:4}"; do
		if [[ "$events" != "" ]]; then
		result=$( /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon "/Library/Application Support/JAMF/bin/Management Action.app/Contents/Resources/Self Service.icns" -title "Software To Install" -button1 "Install" -button2 "Skip" -defaultButton 1 -description "Software Setup: Would you like to install $events?" )
			if [[ "$result" -eq 0 ]]; then
				softwareArray[i]="$events"
				i=$((i + 1))
			fi
		fi
	done
fi

#Once list is done, display progress window
prog=1
for ((iter=0; iter < ${#softwareArray[@]}; iter++)); do
	/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon "/Library/Application Support/JAMF/bin/Management Action.app/Contents/Resources/Self Service.icns" -title "$prog of $i" -description "${softwareArray[$iter]} installing" &
	jamf policy -event "autoinstall-${softwareArray[$iter]}"
	prog=$((prog + 1))
done

#Kill jamfHelper and launch Self Service

jHelper=$(pgrep jamfHelper)
if [[ -z "$jHelper" ]];then
	selfService=$( /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon "/Library/Application Support/JAMF/bin/Management Action.app/Contents/Resources/Self Service.icns" -title "Software Install" -button1 "Launch" -button2 "Quit" -defaultButton 1 -description "To see more software avaialble, launch Self Service" )
	if [[ $selfService -eq 0 ]]; then
    	open -a /Applications/Self\ Service.app
	fi
else
	killall jamfHelper
	selfService=$( /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType utility -icon "/Library/Application Support/JAMF/bin/Management Action.app/Contents/Resources/Self Service.icns" -title "Software Install" -button1 "Launch" -button2 "Quit" -defaultButton 1 -description "To see more software avaialble, launch Self Service" )
	if [[ $selfService -eq 0 ]]; then
    	open -a /Applications/Self\ Service.app
	fi
fi

rm -rf /Library/Application\ Support/UMN/softwareList.txt
jamf recon
