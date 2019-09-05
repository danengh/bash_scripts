#!/bin/bash

# Lookup mobile devices and computer via API and return a list of all the installed applications.
# This is designed to be run locally as a logged in user with the terminal (or other similar) application.
# This can create a preference file for future use for each Jamf Pro Server.
# A single Jamf Pro Server parameter is required and will exit with message if not provided.

## Variables ##
deviceList=(

)
logFile="/path/to/file/application_list.txt"

# Do not change these
compPath="/computers/serialnumber/"
mobDevPath="/mobiledevices/serialnumber/"
currentUser=$( ls -l /dev/console | awk '{print $3}' )

# Get the JSS Server location along with credentials. If wanted, a plist can be created so that credentials can be stored and not re-entered every time.
JSSCredentials() {
if [[ -z $1 ]]; then
	read -p "Enter a Jamf Pro host name. example: oit-jss.oit.umn.edu: " jssEntry
    if [[ "$jssEntry" == "" ]]; then
        echo "Jamf server not recognized. Please provide a Jamf URL host name. example: oit-jss.oit.umn.edu"
        exit 1
	else
		jss="https://"$jssEntry":8443/JSSResource"
		if [[ -e ~/Library/Preferences/com.my.company."$jssEntry".plist ]]; then
    		user=$( defaults read com.my.company."$jssEntry".plist api_user )
    		pw=$( defaults read com.my.company."$jssEntry".plist api_pass )
		else
    		read -p "API Username: " user
    		read -p "API Password: " pw
    		read -p "Would you like to save these for later [y/n]? " createPlist
    		if [[ "$createPlist" == "y" ]]; then
        		defaults write com.my.company."$jssEntry".plist api_user "$user"
	        	defaults write com.my.company."$jssEntry".plist api_pass "$pw"
    	    	echo "Preference file com.my.company."$jssEntry".plist created"
    		fi
		fi
    fi
else
    jss="https://"$1":8443/JSSResource"
	if [[ -e ~/Library/Preferences/com.my.company."$1".plist ]]; then
    	user=$( defaults read com.my.company."$1".plist api_user )
    	pw=$( defaults read com.my.company."$1".plist api_pass )
	else
    	read -p "API Username: " user
    	read -p "API Password: " pw
    	read -p "Would you like to save these for later [y/n]? " createPlist
    	if [[ "$createPlist" == "y" ]]; then
        	defaults write com.my.company."$1".plist api_user "$user"
        	defaults write com.my.company."$1".plist api_pass "$pw"
        	echo "Preference file com.my.company."$1".plist created"
    	fi
	fi
fi
}

# Look up the device and if it exists, return the list of installed applications
ApplicationCheck() {
for device in "${deviceList[@]}"; do
	compExists=$( curl -k -u "$user":"$pw" -H"Accept: application/xml" "$jss""$compPath""$device" | xpath "/computer/general/name" | sed -e 's/<[^>]*>//g' )
	mobDevExists=$( curl -k -u "$user":"$pw" -H"Accept: application/xml" "$jss""$mobDevPath""$device" | xpath "/mobile_device/general/name" | sed -e 's/<[^>]*>//g' )
	if [[ "$compExists" != "" ]]; then
        echo "computer exists"
        appList=$( curl -k -u "$user":"$pw" -H"Accept: application/xml" "$jss""$compPath""$device" | xpath "/computer/software/applications/application/name" | sed -e 's/<[^>]*>/ /g' )
		Logging
	elif [[ "$mobDevExists" != "" ]]; then
        appList=$( curl -k -u "$user":"$pw" -H"Accept: application/xml" "$jss""$mobDevPath""$device" | xpath "/mobile_device/applications/application/application_name" | LC_ALL=C sed -e 's/<[^>]*>/ /g' )
		Logging
	else
		Logging
	fi
done
}

# Logging function for writing out the list of apps to a log file as specified in the variable list
Logging() {
    if [[ "$appList" != "" ]]; then
        if [[ "$compExists" != "" ]]; then
            echo ""$device" - "$compExists"" >> "$logFile"
            echo "Application List" >> "$logFile"
            echo "----------------" >> "$logFile"
            echo "$appList" >> "$logFile"
        else
            echo ""$device" - "$mobDevExists"" >> "$logFile"
            echo "Application List" >> "$logFile"
            echo "----------------" >> "$logFile"
            echo "$appList" >> "$logFile"
        fi
    else 
        echo ""$device" is not in Jamf" >> "$logFile"
    fi
}

# Run the programs
JSSCredentials
ApplicationCheck
