# APKahlo
This is a simple bash script that will (hopefully) help with repackaging an APK with [Frida](https://frida.re) Gadget injection.

If you are lucky it will work out of the box and you'll have a repackaged APK which is ready to be installed and interacted with `frida`.



# Dependencies

I tried to simplify this script, using only tools that any Android reverser already probably has on their machine.

- apktool - https://github.com/iBotPeaches/Apktool
- openjdk - https://openjdk.java.net/install/index.html 
- libfridagadget.so - Available at https://github.com/frida/frida/releases
- android-sdk-build-tools - https://developer.android.com/studio/releases/build-tools



# How to use

`apkahlo <target_apk> <libfrida-gadget.so>`

`libfrida-gadget.so` **must be for ARMv8 target** 

### Options (you don't have many):

`-b` do not print the pretty colorful ASCII banner :(



# References

If you are lost on what injecting `frida-gadget` is all about, check this blog post for some insight (and how to do it manually if this script crashes and burns - which it probably will) - https://fadeevab.com/frida-gadget-injection-on-android-no-root-2-methods/



# TO-DOS/nice-to-haves

- Allow user to give his own certificate to sign the APK
- More control options (e.g. no useless logging information)
- Work with split APKs
