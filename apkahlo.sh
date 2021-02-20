#!/bin/sh

# ---------------------------------------------------------------------------#
# Source: https://github.com/hexpwn/APKahlo
# Version: 0.1 - "It Probably Won't Work"
# Date: 2021-02-20
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
echo -e "\e[32m"
echo -e '    e Y8b     888 88e  888 88P         888     888           '
echo -e '   d8b Y8b    888 888D 888 8P   ,"Y88b 888 ee  888  e88 88e '
echo -e '  d888b Y8b   888 88"  888 K   "8" 888 888 88b 888 d888 888b '
echo -e ' d888888888b  888      888 8b  ,ee 888 888 888 888 Y888 888P '
echo -e 'd8888888b Y8b 888      888 88b "88 888 888 888 888  "88 88"  '
echo -e "            v0.1 \"It Probably Won't Work\" -  \e[0m\e[31mby @hexpwn\e[0m"
echo -e "";
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
	echo -e "\n$SUCC Unpacking the APK... this might take a while\n"
	apktool d "$APK" -o repackaged 1>/dev/null

	if [ $? -ne 0 ]; then
		echo -e "\n$ERROR Failed extracting the apk\n"
		exit 2
	fi
fi

# Try finding the entrypoint in the smali code to inject the frida-gadget call
ENTRY=$(find . -name "MainActivity.smali")

if [ ! "$ENTRY" == "" ]; then
	echo -e "\n$SUCC Found APK entrypoint at: $ENTRY"
	echo -e "\n$SUCC Injecting a call to frida-gadget.so"
	sed "/.method public constructor <init>()V/a     const-string v0, \
\"frida-gadget\"\n    \
invoke-static {v0}, \
Ljava/lang/System;->loadLibrary(Ljava/lang/String;)V" "$ENTRY" > temp_smali.smali
	if [ $? -ne 0 ]; then
		echo -e "\n$ERROR I failed at finding the APK entrypoint, I cannot\
 inject frida-gadget.so without knowing this information... sorry..."
		exit 2
	else
		cat temp_smali.smali > "$ENTRY"
		rm temp_smali.smali
	fi
else
	echo -e "\n$ERROR I failed at finding the APK entrypoint, I cannot\
 inject frida-gadget.so without knowing this information... sorry..."
	exit 2
fi

# Check for an existing signed certificate
if [ ! -f custom.keystore ]; then
	echo -e "\n$SUCC We need to create a new certificate to sign \
the new APK"
	echo -e "       Just press ENTER until the prompt [no], where you should \
type: yes\n"
	keytool -genkey -v -keystore custom.keystore -alias mykeyaliasname \
		-keyalg RSA -storepass password -keysize 2048 -validity 10000
	if [ $? -ne 0 ]; then
		echo -e "\n$ERROR Failed creating new certificate\n"
		exit 2
	fi
fi

# Copying libfridagadget to the correct folder in the APK
if [ ! -d repackaged/lib/arm64-v8a/ ]; then
	echo -e "\n$ERROR I could not find the correct directory to put libfridagadget"
	echo -e "       Please check if ./repackaged/lib/arm64-v8a exists.\n"
	exit 2
else
	cp "$FRIDA" repackaged/lib/arm64-v8a/libfrida-gadget.so
	if [ $? -ne 0 ]; then
		echo -e "\n$ERROR Error copying the libfridagadget\n"
		exit 2
	fi
fi

# Repackage the APK
echo -e "\n$SUCC Repackaging the APK... this might take a while\n"
apktool --use-aapt2 b repackaged/ -o repackaged_tmp.apk 1>/dev/null

if [ $? -ne 0 ]; then
	echo -e "\n$ERROR Something went wrong repackaging the APK...\n"
	exit 2
fi

# Signing the APK with the signed certificate that was generated
echo -e "\n$SUCC Signing the injected APK\n"
jarsigner -sigalg SHA1withRSA -digestalg SHA1 -keystore custom.keystore \
	-storepass password repackaged_tmp.apk mykeyaliasname

if [ $? -ne 0 ]; then
	echo -e "\n$ERROR Something went wrong signing the APK...\n"
	exit 2
fi

# Zipalign the signed APK
echo -e "\n$SUCC Zipaligning the final injected APK\n"
zipalign 4 repackaged_tmp.apk repackaged.apk
if [ $? -ne 0 ]; then
	echo -e "\n$ERROR Something bad happened...\n"
	exit 2
fi

rm -rf repackaged repackaged_tmp.apk custom.keystore

echo -e "\n ----- ALL DONE! -----"
echo -e "Enjoy your new APK! You can install it with:"
echo -e "adb install repackaged.apk"
exit 0
