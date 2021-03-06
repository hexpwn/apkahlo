#!/bin/sh

# ---------------------------------------------------------------------------#
# Source: https://github.com/hexpwn/APKahlo
# Version: 0.2 - "It (still) Probably Won't Work"
# Date: 2021-03-17
#
# This is a simple bash script that will (hopefully) help with repackaging an 
# APK with Frida Gadget
#
# Dependencies:
# 		- apktool
# 		- openjdk
# 		- libfridagadget.so 
#		- android-sdk-build-tools
#
# ---------------------------------------------------------------------------#		

# Color shenanigans
ERROR="\e[31m[ :( ]\e[0m"
SUCC="\e[32m[ :) ]\e[0m"

# Banner
banner () {
printf "\e[32m"
printf '    e Y8b     888 88e  888 88P         888     888           \n'
printf '   d8b Y8b    888 888D 888 8P   ,"Y88b 888 ee  888  e88 88e \n'
printf '  d888b Y8b   888 88"  888 K   "8" 888 888 88b 888 d888 888b \n'
printf ' d888888888b  888      888 8b  ,ee 888 888 888 888 Y888 888P \n'
printf 'd8888888b Y8b 888      888 88b "88 888 888 888 888  "88 88"  \n'
printf "        v0.2 \"It (still) Probably Won't Work\" -  \e[0m\e[31mby @hexpwn\e[0m"
printf "\n";
}

usage () {
	echo "Usage: apkhalo [-b: no banner] <apk_filename_location> \
<frida_gadget_location>";
}

# Check if the necessary arguments were passed
if [ $# -lt 1 ]; then
       usage
       exit 2
else
	# You can cancel the banner with the -b flag
	if [ ! "$1" == -b ]; then
		if [ $# -ne 2 ]; then
			usage
			exit 2
		fi
		banner
		APK="$1"
		FRIDA="$2"
	else
		if [ $# -ne 3 ]; then
			usage
			exit 2
		fi
		APK="$2"
		FRIDA="$3"
	fi
fi

# Look for unpacked APK in a directory named repackaged
if [ ! -d repackaged ]; then
	printf "\n$SUCC Unpacking the APK... this might take a while\n"
	apktool d "$APK" -o repackaged 1>/dev/null

	if [ $? -ne 0 ]; then
		printf "\n$ERROR Failed extracting the apk\n"
		exit 2
	fi
fi

printf "\n$SUCC I need to know the app's entrypoint. I can Guess [default] or you can\
Customize and tell me where I should insert it...\n\n"
PS3="Choice: "
choice=("Customize" "Guess [default]")
select ch in "${choice[@]}"; do
	    case $ch in
			"Customize")
			echo
			read -p "What is the name of the .smali file that constains the onCreate() entrypoint? " smali_name
			break
			;;

			"Guess [default]")
				smali_name="MainActivity.smali"
				break
			;;

		*) smali_name="MainActivity.smali";;
	esac
done

echo "Chosen smali is: $smali_name"

# Try finding the entrypoint in the smali code to inject the frida-gadget call
ENTRY=$(find repackaged -name "$smali_name")

if [ ! "$ENTRY" == "" ]; then
	printf "\n$SUCC Found APK entrypoint at: %s\n" "$ENTRY"
	printf "\n$SUCC Injecting a call to frida-gadget.so\n"
	sed "/ onCreate(Landroid/a    \
const-string v0,\"frida-gadget\"\n    invoke-static {v0}, \
Ljava/lang/System;->loadLibrary(Ljava/lang/String;)V" "$ENTRY" > temp_smali.smali
	if [ $? -ne 0 ]; then
		printf "\n$ERROR I failed at finding the APK entrypoint, I cannot\
 inject frida-gadget.so without knowing this information... sorry...\n"
		exit 2
	else
		cat temp_smali.smali > "$ENTRY"
		rm temp_smali.smali
	fi
else
	printf "\n$ERROR I failed at finding the APK entrypoint, I cannot\
 inject frida-gadget.so without knowing this information... sorry...\n"
	exit 2
fi

# Set the APK to debuggable
APP_ENTRY=$(grep "<application" repackaged/AndroidManifest.xml)
DEBUG_F=$(echo $APP_ENTRY | grep 'android:debuggable="false"')
DEBUG_T=$(echo $APP_ENTRY | grep 'android:debuggable="true"')

if [ ! "$DEBUG_T" == "" ]; then
	printf "\n$SUCC App is already set as DEBUGGABLE :D\n"
elif [ ! "$DEBUG_F" == "" ]; then
	printf "\n$SUCC App is marked as non-debuggable... changing that ;)\n"
	sed -i 's/android:debuggable="false"/android:debuggable="true"/' repackaged/AndroidManifest.xml
else
	printf "\n$SUCC Setting app to DEBUGGABLE 8]\n"
	NEW_APP_ENTRY=$(echo $APP_ENTRY | sed 's/>/ android:debuggable="true">/')	
	sed -i "s|$(echo $APP_ENTRY)|$(echo $NEW_APP_ENTRY)|" repackaged/AndroidManifest.xml
fi

# Check for an existing signed certificate
if [ ! -f custom.keystore ]; then
	printf "\n$SUCC We need to create a new certificate to sign \
the new APK\n"
	printf "       Just press ENTER until the prompt [no], where you should \
type: yes\n"
	keytool -genkey -v -keystore custom.keystore -alias mykeyaliasname \
		-keyalg RSA -storepass password -keysize 2048 -validity 10000
	if [ $? -ne 0 ]; then
		printf "\n$ERROR Failed creating new certificate\n"
		exit 2
	fi
fi

# Copying libfridagadget to the correct folder in the APK
if [ ! -d repackaged/lib/arm64-v8a/ ]; then
	printf "\n$SUCC I could not find the correct directory to put libfridagadget\n"
	printf "       I will create it now.\n"
	mkdir -p repackaged/lib/arm64-v8a/
fi

cp "$FRIDA" repackaged/lib/arm64-v8a/libfrida-gadget.so

if [ $? -ne 0 ]; then
	printf "\n$ERROR Error copying the libfridagadget\n"
	exit 2
fi

# Repackage the APK
printf "\n$SUCC Repackaging the APK... this might take a while\n"
apktool --use-aapt2 b repackaged/ -o repackaged_tmp.apk 1>/dev/null

if [ $? -ne 0 ]; then
	printf "\n$ERROR Something went wrong repackaging the APK...\n"
	exit 2
fi

# Signing the APK with the signed certificate that was generated
printf "\n$SUCC Signing the injected APK\n"
jarsigner -sigalg SHA1withRSA -digestalg SHA1 -keystore custom.keystore \
	-storepass password repackaged_tmp.apk mykeyaliasname

if [ $? -ne 0 ]; then
	printf "\n$ERROR Something went wrong signing the APK...\n"
	exit 2
fi

# Zipalign the signed APK
printf "\n$SUCC Zipaligning the final injected APK\n"
zipalign 4 repackaged_tmp.apk repackaged.apk
if [ $? -ne 0 ]; then
	printf "\n$ERROR Something bad happened...\n"
	exit 2
fi

rm -rf repackaged repackaged_tmp.apk custom.keystore

printf "\n\e[1;32;40m ---------======= ALL DONE! =======---------\e[0m\n"
printf "\e[1;32;40mEnjoy your new APK! You can install it with:\e[0m\n"
printf "\e[1;33;40m         adb install repackaged.apk         \e[0m\n"
exit 0
