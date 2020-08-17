#!/bin/bash
#
#Jason Barnett - jason.barnett@besl.org
#
#
#generate_rpm_from_folder.sh
#generate_rpm_from_folder.sh will take a folder as a target and build an RPM file interactively out of it
#generate_rpm_from_folder.sh must be invoked with at least 1 argument, the target folder
#e.g. ./generate_rpm_from_folder.sh myfolder
#
#generate_rpm_from_folder.sh may also be invoked with multiple arguments specifying all required info
#if you know it in advance or don't plan to interactively set them
#i.e. ./generate_rpm_from_folder.sh myfolder myRPMversion myRPMrelease myRPMinstallPrefix "myRPMsummary" "myRPMlicense" "myName" "vendorName" "myRPMdependencies" "myRPMdescription" "myRPMpostInstallDirectives" "myRPMpostDeinstallDirectives"
#e.g. ./generate_rpm_from_folder.sh myfolder 1.0.0 rc1 /opt "This is a test RPM." "GPLv3" "Jason Barnett" "BESL LLC" "kernel, bash" "Test provides the ability for me to test if this RPM generation script is successful and can be installed on another computer." 'echo installed!' 'echo uninstalled!'
#NOTE: if you are specifying all command line arguments and you don't have an install prefix, use the null keyword inplace of the myRPMinstallPrefix variable as the prefix
#e.g. ./generate_rpm_from_folder.sh myfolder myRPMversion myRPMrelease null "myRPMsummary" "myRPMlicense" "myName" "vendorName" "myRPMdependencies" "myRPMdescription" "myRPMpostInstallDirectives" "myRPMpostDeinstallDirectives"
#
#NOTE: Target folders SHOULD BE FORMATTED with EXACT, FULL OVERLAY PATHS INSIDE OF THEM 
#because when the rpm is installed, all files will be copied to the / folder.
#i.e. if you wanted to create an rpm that placed files at /usr/lib64 and at /opt/myrpm
#then your folder stucture should look like the following
#$# tree myrpm
# myrpm/
# |-- opt
# |   `-- myrpm
# |       |-- myrpm.bin
# |       `-- myrpm.txt
# `-- usr
#     `-- lib64
#         `-- myrpmlib.so
#
#NOTE: file permissions and owners of the target directory WILL BE PRESERVED UPON RPM INSTALL!
#
#WARNING: symlinks will be automatically deferenced per source, i.e. if your target folder has
#symlinks present inside of it, those symlinks will instead themselves become the files they
#are referencing!
#
#NOTE: If it is not possible to set up your directory structure as described above...
#generate_rpm_from_folder.sh may also be invoked in special cases with a 4th argument defining the installation prefix
#which specifies the INSTALLPREFIX directory, e.g. where to overlay the files upon installation
#in the filesystem instead of following the format of the myfolder directory structure
#e.g. ./generate_rpm_from_folder.sh myfolder v1.0.1 rc6 /usr/local "myRPMsummary" "myRPMlicense" "myName" "vendorName" "myRPMdependencies" "myRPMdescription" "myRPMpostInstallDirectives" "myRPMpostDeinstallDirectives"
#This would mean that all of the files in myfolder/* would be placed at /usr/local/* instead of /*



###########################################
#BEGIN SCRIPT				  #
###########################################


########################
#VAR SETUP	       #
########################

#define dialog exit codes
: ${DIALOG_OK=0}
: ${DIALOG_CANCEL=1}
: ${DIALOG_HELP=2}
: ${DIALOG_EXTRA=3}
: ${DIALOG_ITEM_HELP=4}
: ${DIALOG_ESC=255}

DIALOGRESPONSE=""

#check to make sure we got a target argument
if [ -z "$1" ]; then
	echo "You must supply an argument to this script which specifies the folder to interactively build the RPM from!"
	echo "E.g. $0 myfolder"
	echo
	echo
	echo "If you are an advanced user, you may specify command line arguments as necessary to build the rpm to skip script interaction."
	echo "This is useful if you know all of your rpm information and this script is being called from another script non-interactively."
	echo "Format: $0 myfolder myRPMversion myRPMrelease myRPMinstallPrefix 'myRPMsummary' 'myRPMlicense' 'myName' 'vendorName' 'myRPMdependencies' 'myRPMdescription' 'myRPMpostInstallDirectives' 'myRPMpostDeinstallDirectives'"
	echo
	echo "E.g. $0 testrpm 1.0.0 1.el7 null 'This is a test summary' 'This is a test License' 'Jason Barnett' 'BESL LLC' 'kernel, bash' 'This is a test description' 'echo installed!' 'echo uninstalled!'"
	echo "would have created an rpm with no install prefix (i.e. the testrpm folder contains the root overlay structure)"
	echo "or"
	echo "E.g. $0 testrpm 1.0.0 1.el7 /opt 'This is a test summary' 'This is a test License' 'Jason Barnett' 'BESL LLC' 'kernel, bash' 'This is a test description' 'echo installed!' 'echo uninstalled!'"
	echo "would have created an rpm with an install prefix of /opt (i.e. all files in testrpm would be placed in /opt when installed)"
	echo
	echo "For more information, open this script and read the information comments at the top."
	echo "We can't continue without the proper arguments."
	exit 1
fi


#set TARGETFOLDER variable to $1 but remove the trailing / if there is one present.
TARGETFOLDER="`echo $1 | tr '/' '\0'`"
CWD="`pwd`"
#we need to make sure that TARGETFOLDER and CWD have no spaces in them so paths don't get messed up
#when commands are executed with these as arguments
if [[ "`echo ${TARGETFOLDER} | wc -w`" -gt "1" || "`echo ${CWD} | wc -w`" -gt "1" ]]; then
	echo "TARGETFOLDER: ${TARGETFOLDER} and CWD: ${CWD} must not contain spaces!"
	echo "Move to a suitable location without spaces for the working directory"
	echo "and/or"
	echo "Rename your target folder to be a directory without spaces! (targets consisting of subfolders with spaces is OK)"
	exit 1
fi

ARCH="`arch`"

########################
#VERIFY ENVIRONMENT    #
########################

#check to make sure we have all the necessary tools to build rpm files...
if [ -z "`rpm -qa | grep rpmdevtools`" ]; then
        echo "Could not find the rpmdevtools utility!"
        echo "Please install the rpmdevtools package!"
        echo "E.g. sudo yum install -y rpmdevtools"
        exit 2
fi

#check to make sure we have the dialog package for interactive text boxes...
if [ -z "`rpm -qa | grep dialog`" ]; then
        echo "Could not find the dialog utility!"
        echo "Please install the dialog package!"
        echo "E.g. sudo yum install -y dialog"
        exit 2
fi


#check if target argument was valid
if ! [ -e "$TARGETFOLDER" ]; then
        echo "$TARGETFOLDER did not exist! Please specify an existing target folder."
        exit 1
fi

#If we didn't get enough arguments to reasonably assume we can build the rpm
#non-interactively, show the helpful entrance dialog, then go figure out what
#rpm information we need and get it interactively
if [ -z "${12}" ]; then
        dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
        --title "Welcome to $0" \
        --msgbox "$0 is a script which will help you generate an rpm file out of a target folder that can be installed and updated on other machines seamlessly. \
                \nTo do that, we need to ask a few questions so that we can build the rpm file. \
                \n\nHere's what we know so far about your rpm:\n\nCWD: ${CWD}\nTARGETFOLDER: ${TARGETFOLDER}\n\n \
		\n\nNote: File user/group permissions will be preserved in the generated RPM with the exception of symlinks. Symlinks will be dereferenced to their source. \
                \n\nLet's collect some more information, and get your rpm built!" \
        20 60
	#get dialog's exit code
        DIALOGRESPONSE="$?"
        # Check exit status of dialog to see if user cancelled, bail if so
        if [ "$DIALOGRESPONSE" != "0" ]; then
                dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
                --title "$0 ERROR $DIALOGRESPONSE" \
                --msgbox "Cancelled! No RPM was built and $1 was not modified" 20 60
                echo "User cancelled or other error occurred."
                exit 1
        fi

fi


#SPECIAL VERSION AND RELEASE VARIABLES
#if you have a way to automatically determine the version and release numbers
#call this script in non-interactive mode (i.e. all necessary arguments provided"

#Determine Version
if [ "$2" ]; then
	VERSION="$2"
else
	#Get VERSION if not specified on command line
	exec 3>&1
	VERSION=$(dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
	--title "Your RPM Version Number" \
	--inputbox "Please enter the version number of the RPM to be built. \
           \n\nE.g. 1.1.2 or 2.0 or 3 or whatever non-whitespace version identifier you want. \
           \n\nThis field must not be left empty! \
           \n\nVersion Number: " 20 60 2>&1 1>&3)
	#get dialog's exit code
	DIALOGRESPONSE="$?"
	# Check exit status of dialog to see if user cancelled, bail if so
	if [ "$DIALOGRESPONSE" != "0" ]; then
  		dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
         	--title "$0 ERROR $DIALOGRESPONSE" \
         	--msgbox "Cancelled! No RPM was built and $1 was not modified" 20 60
  		echo "User cancelled or other error occurred."
		exit 1
	fi
	#trim VERSION to make sure there is no whitespace in it
	VERSION="$(echo -e ${VERSION} | tr -d '[:space:]')"
	#if our interactive response was null, we need to bail out
	if [ -z "${VERSION}" ]; then
        	echo "Received a null value for a required argument, bailing!"
        	exit 1
	fi
	echo "Dialog($DIALOGRESPONSE) set VERSION: $VERSION"
	exec 3>&1
fi

#Determine Release
if [ "$3" ]; then
	RELEASE="$3"
else
	#Get RELEASE if not specified on command line
	exec 3>&1
	RELEASE=$(dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
	--title "Your RPM Release Identifier" \
	--inputbox "Please enter the release identifier of the RPM to be built. \
	   \nThis string should describe the release number AND the target Linux Distro (RHEL 7: .el7, Centos 7: .el7.centos, etc) \
           \n\nE.g. 1.el7 or rc5.fc23 or 1-1.el7.centos or whatever non-whitespace release identifier you want. \
           \n\nThis field must not be left empty! \
           \n\nRelease Identifier: " 20 60 2>&1 1>&3)
	#get dialog's exit code
	DIALOGRESPONSE="$?"
	# Check exit status of dialog to see if user cancelled, bail if so
	if [ "$DIALOGRESPONSE" != "0" ]; then
		dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
         	--title "$0 ERROR $DIALOGRESPONSE" \
         	--msgbox "Cancelled! No RPM was built and $1 was not modified" 20 60
		echo "User cancelled or other error occurred."
		exit 1
	fi
	#trim RELEASE to make sure there is no whitespace in it
	RELEASE="$(echo -e ${RELEASE} | tr -d '[:space:]')"
	#if our interactive response was null, we need to bail out
	if [ -z "${RELEASE}" ]; then
        	echo "Received a null value for a required argument, bailing!"
        	exit 1
	fi
	echo "Dialog ($DIALOGRESPONSE) set RELEASE: $RELEASE"
	exec 3>&1
fi

#INSTALLPREFIX is a prefixed directory for all files inside the rpm to be placed in
#E.g. if your RPM has a myfile/myfile.bin in it, when installed, that myfile.bin 
#would be placed at the root of the drive, e.g. /myfile/myfile.bin
#The INSTALLPREFIX allows you to override the root destination with your own
#such as if INSTALLPREFIX="/opt" and then it would install to /opt/myfile/myfile.bin
#i.e. all myfile.rpm files would end up in the /opt directory
if [ "$4" ]; then
	INSTALLPREFIX="${4}"
	#make sure INSTALLPREFIX has no spaces in it so we don't barf on it downstream
	if [ "`echo ${INSTALLPREFIX} | wc -w`" -gt "1" ]; then
		echo "INSTALLPREFIX: ${INSTALLPREFIX} must not contain a space!"
		exit 1
	fi
	#Make sure INSTALLPREFIX has no trailing / or /s on the path given
        while [ "`echo -n ${INSTALLPREFIX} | tail -c1`" == "/" ]; do
                echo "entered while loop when INSTALLPREFIX was ${INSTALLPREFIX}"
                INSTALLPREFIX="`echo ${INSTALLPREFIX%?}`"
                echo "INSTALLPREFIX IS NOW: ${INSTALLPREFIX}"
                sleep 1
        done

	#if our install prefix is the null keyword, blank it out so we don't barf downstream
	if [ "$INSTALLPREFIX" == "null" ]; then
		INSTALLPREFIX=""
	fi
else
	#Get INSTALLPREFIX if not specified on command line
	exec 3>&1
	INSTALLPREFIX=$(dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
	--title "Your RPM Installation Prefix" \
	--inputbox "If necessary, please enter the Installation Prefix of the RPM to be built. \
           \n\nE.g. /opt or /opt/myrpm or /usr/bin /bin or whatever non-whitespace containing path you want. \
           \n\nNOTE: this is only required if your $1 target folder directory structure does match the root overlay structure. \
           \nWhen .rpms are installed, they are always installed to the root of the system at the '/' folder. \
           \nIf you don't want $1 target folder installed to the /$1 folder then you need to provide an installation prefix now. \
           \nIf your $1 target folder already DOES contain an overlay structure, e.g. $1/opt/myrpm/myfiles then leave this field empty. \
           \n\nFor more information or if you need help, cancel this operation and open the $0 script and read the comments at the top. \
           \n\nInstallation Prefix: " 30 60 2>&1 1>&3)
	#get dialog's exit code
	DIALOGRESPONSE="$?"
	# Check exit status of dialog to see if user cancelled, bail if so
	if [ "$DIALOGRESPONSE" != "0" ]; then
		dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
        	--title "$0 ERROR $DIALOGRESPONSE" \
         	--msgbox "Cancelled! No RPM was built and $1 was not modified" 20 60
  		echo "User cancelled or other error occurred."
  	exit 1
	fi
	#make sure INSTALLPREFIX has no spaces in it so we don't barf on it downstream
	if [ "`echo ${INSTALLPREFIX} | wc -w`" -gt "1" ]; then
        	echo "INSTALLPREFIX: ${INSTALLPREFIX} must not contain a space!"
        	exit 1
	fi
	#Make sure INSTALLPREFIX has no trailing / or /s on the path given
	while [ "`echo -n ${INSTALLPREFIX} | tail -c1`" == "/" ]; do
        	echo "entered while loop when INSTALLPREFIX was ${INSTALLPREFIX}"
        	INSTALLPREFIX="`echo ${INSTALLPREFIX%?}`"
        	echo "INSTALLPREFIX IS NOW: ${INSTALLPREFIX}"
        	sleep 1
	done
	echo "Dialog($DIALOGRESPONSE) set INSTALLPREFIX: $INSTALLPREFIX"
	exec 3>&1
fi

#RPMSUMMARY is a short summary of what is contained in the rpm file
if [ "${5}" ]; then
	RPMSUMMARY="${5}"
else
	#Get RPMSUMMARY if not specified on command line
	exec 3>&1
	RPMSUMMARY=$(dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
	--title "Your RPM Summary" \
	--inputbox "Please enter a short summary of the RPM to be built. \
           \n\nE.g. $1 is a test rpm that installs the $1 utility to /opt. \
           \n\nThis field must not be left empty! \
           \n\nRPM Summary: " 20 60 2>&1 1>&3)
	#get dialog's exit code
	DIALOGRESPONSE="$?"
	# Check exit status of dialog to see if user cancelled, bail if so
	if [ "$DIALOGRESPONSE" != "0" ]; then
  		dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
         	--title "$0 ERROR $DIALOGRESPONSE" \
         	--msgbox "Cancelled! No RPM was built and $1 was not modified" 20 60
  		echo "User cancelled or other error occurred."
  	exit 1
	fi

	#if our interactive response was null, we need to bail out
	if [ -z "${RPMSUMMARY}" ]; then
        	echo "Received a null value for a required argument, bailing!"
        	exit 1
	fi
	echo "Dialog($DIALOGRESPONSE) set RPMSUMMARY: $RPMSUMMARY"
	exec 3>&1
fi

#RPMLICENSE is a string containing the license type of what is contained in the rpm file
if [ "${6}" ]; then
        RPMLICENSE="${6}"
else
	#Get RPMLICENSE if not specified on command line
	exec 3>&1
	RPMLICENSE=$(dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
	--title "Your RPM License Type" \
	--inputbox "Please enter the license type of the RPM to be built. \
           \n\nE.g. GPLv3 or CCv2.0 or CCBYSA or BESL Proprietary or whatever else you need. \
           \n\nThis field must not be left empty! \
           \n\nRPM License: " 20 60 2>&1 1>&3)
	#get dialog's exit code
	DIALOGRESPONSE="$?"
	# Check exit status of dialog to see if user cancelled, bail if so
	if [ "$DIALOGRESPONSE" != "0" ]; then
		dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
         	--title "$0 ERROR $DIALOGRESPONSE" \
         	--msgbox "Cancelled! No RPM was built and $1 was not modified" 20 60
  		echo "User cancelled or other error occurred."
  		exit 1
	fi

	#if our interactive response was null, we need to bail out
	if [ -z "${RPMLICENSE}" ]; then
        	echo "Received a null value for a required argument, bailing!"
        	exit 1
	fi
	echo "Dialog($DIALOGRESPONSE) set RPMLICENSE: $RPMLICENSE"
	exec 3>&1
fi

#RPMAUTHOR is a string containing the name of the person generating the rpm file
if [ "${7}" ]; then
        RPMAUTHOR="${7}"
else
	#Get RPMAUTHOR if not specified on command line
	exec 3>&1
	RPMAUTHOR=$(dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
	--title "Your Name (Who is Building the RPM)" \
	--inputbox "Please enter your name so that we know who built this RPM. \
           \n\nE.g. Jason Barnett \
           \n\nThis field must not be left empty! \
           \n\nRPM Author: " 20 60 2>&1 1>&3)
	#get dialog's exit code
	DIALOGRESPONSE="$?"
	# Check exit status of dialog to see if user cancelled, bail if so
	if [ "$DIALOGRESPONSE" != "0" ]; then
  		dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
         	--title "$0 ERROR $DIALOGRESPONSE" \
         	--msgbox "Cancelled! No RPM was built and $1 was not modified" 20 60
  		echo "User cancelled or other error occurred."
 		exit 1
	fi

	#if our interactive response was null, we need to bail out
	if [ -z "${RPMAUTHOR}" ]; then
        	echo "Received a null value for a required argument, bailing!"
        	exit 1
	fi
	echo "Dialog($DIALOGRESPONSE) set RPMAUTHOR: $RPMAUTHOR"
	exec 3>&1
fi


#RPMVENDOR is a string which identifies the company making the RPM
if [ "${8}" ]; then
        RPMVENDOR="${8}"
else
        #Get RPMVENDOR if not specified on command line
        exec 3>&1
        RPMVENDOR=$(dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
        --title "Vendor of this RPM" \
        --inputbox "Please enter the name of the vendor of this RPM. \
           \n\nE.g. BESL LLC, Acme Inc., etc \
           \n\nThis field must not be left empty! \
           \n\nRPM Vendor: " 20 60 2>&1 1>&3)
        #get dialog's exit code
        DIALOGRESPONSE="$?"
        # Check exit status of dialog to see if user cancelled, bail if so
        if [ "$DIALOGRESPONSE" != "0" ]; then
                dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
                --title "$0 ERROR $DIALOGRESPONSE" \
                --msgbox "Cancelled! No RPM was built and $1 was not modified" 20 60
                echo "User cancelled or other error occurred."
                exit 1
        fi

        #if our interactive response was null, we need to bail out
        if [ -z "${RPMVENDOR}" ]; then
                echo "Received a null value for a required argument, bailing!"
                exit 1
        fi
        echo "Dialog($DIALOGRESPONSE) set RPMVENDOR: $RPMVENDOR"
        exec 3>&1
fi

#RPMREQUIRES is a string list of rpm dependencies, in RPM spec file Requires: field format
if [ "${9}" ]; then
        RPMREQUIRES="${9}"
else
	#Get RPMREQUIRES if not specified on command line
	exec 3>&1
	RPMREQUIRES=$(dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
	--title "Dependencies of this RPM" \
	--inputbox "Please enter the list of dependencies for this RPM in RPM Spec file format. \
           \n\nE.g. kernel, bar, bac >= 2.7, baz = 2.1 \
           \n\nNOTE: Make sure all listed dependencies are valid or else your rpm file will fail to install! \
           \n\nRPM Requires: " 20 60 2>&1 1>&3)
	#get dialog's exit code
	DIALOGRESPONSE="$?"
	# Check exit status of dialog to see if user cancelled, bail if so
	if [ "$DIALOGRESPONSE" != "0" ]; then
		dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
         	--title "$0 ERROR $DIALOGRESPONSE" \
         	--msgbox "Cancelled! No RPM was built and $1 was not modified" 20 60
		echo "User cancelled or other error occurred."
		exit 1
	fi

        #if our interactive response was null, we need to set it to something non-null
        if [ -z "${RPMREQUIRES}" ]; then
                RPMREQUIRES="kernel"
        fi
	echo "Dialog($DIALOGRESPONSE) set RPMREQUIRES: $RPMREQUIRES"
	exec 3>&1
fi

#RPMDESCRIPTION is a string list of rpm dependencies, in RPM spec file Requires: field format
if [ "${10}" ]; then
        RPMDESCRIPTION="${10}"
else
	#Get RPMDESCRIPTION if not specified on command line
	exec 3>&1
	RPMDESCRIPTION=$(dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
	--title "Description of what this RPM does" \
	--inputbox "Please describe what this RPM does or provides. \
           \n\nE.g. $1 provides capability X and feature Y to allow operation Z. \
           \n\nThis field must not be left empty! \
	   \n\nRPM Description: " 20 60 2>&1 1>&3)
	#get dialog's exit code
	DIALOGRESPONSE="$?"
	# Check exit status of dialog to see if user cancelled, bail if so
	if [ "$DIALOGRESPONSE" != "0" ]; then
  		dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
         	--title "$0 ERROR $DIALOGRESPONSE" \
         	--msgbox "Cancelled! No RPM was built and $1 was not modified" 20 60
  		echo "User cancelled or other error occurred."
  		exit 1
	fi

	#if our interactive response was null, we need to bail out
	if [ -z "${RPMDESCRIPTION}" ]; then
        	echo "Received a null value for a required argument, bailing!"
        	exit 1
	fi
	echo "Dialog($DIALOGRESPONSE) set RPMDESCRIPTION: $RPMDESCRIPTION"
	exec 3>&1
fi

#RPMPOST is a string that contains bash directives to be executed immediately after installing the rpm
#such as adding it to a boot time services setup or something else that should automatically happen
if [ "${11}" ]; then
        RPMPOST="${11}"
else
        #Get RPMPOST if not specified on command line
        exec 3>&1
        RPMPOST=$(dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
        --title "RPM Post-installation Bash Actions" \
        --inputbox "Please write bash directives to describe any actions that must occur after install. \
	   \nTypically this is used to set up boot-time services after the rpm has been installed \
	   \n or perform other actions before the software is run for the first time. \
	   \n\nNOTE: these bash directives are executed as root after installation so make sure your file paths account for that. \
           \n\nE.g.  cp /opt/myrpm/systemd/myrpm.service /etc/systemd/system/; systemctl daemon-reload; systemd enable myrpm; systemd start myrpm\
	   \n\nRPM Post Directives: " 20 60 2>&1 1>&3)
        #get dialog's exit code
        DIALOGRESPONSE="$?"
        # Check exit status of dialog to see if user cancelled, bail if so
        if [ "$DIALOGRESPONSE" != "0" ]; then
                dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
                --title "$0 ERROR $DIALOGRESPONSE" \
                --msgbox "Cancelled! No RPM was built and $1 was not modified" 20 60
                echo "User cancelled or other error occurred."
                exit 1
        fi

        #if our interactive response was null, we need to set it to something non-null
        if [ -z "${RPMPOST}" ]; then
		RPMPOST="echo $TARGETFOLDER installed."
        fi
        echo "Dialog($DIALOGRESPONSE) set RPMPOST: $RPMPOST"
        exec 3>&1
fi


#RPMPOSTUN is a string that contains bash directives to be executed immediately after uninstalling the rpm
#such as removing it from boot time services setup or something else that should automatically happen
if [ "${12}" ]; then
        RPMPOSTUN="${12}"
else
        #Get RPMPOSTUN if not specified on command line
        exec 3>&1
        RPMPOSTUN=$(dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
        --title "RPM Post-Uninstallation Bash Actions" \
        --inputbox "Please write bash directives to describe any actions that must occur after deinstall. \
           \nTypically this is used to remove boot-time services after the rpm has been deinstalled \
           \n or perform other actions after rpm cleanup. \
           \n\nNOTE: these bash directives are executed as root after deinstallation so make sure your file paths account for that. \
           \n\nE.g.  systemctl stop myrpm; sytemctl disable myrpm; rm -f /etc/systemd/system/myrpm.service; systemctl daemon-reload\
           \n\nRPM Post Uninstall Directives: " 20 60 2>&1 1>&3)
        #get dialog's exit code
        DIALOGRESPONSE="$?"
        # Check exit status of dialog to see if user cancelled, bail if so
        if [ "$DIALOGRESPONSE" != "0" ]; then
                dialog --backtitle "$0 by Jason Barnett - jason.barnett@besl.org" \
                --title "$0 ERROR $DIALOGRESPONSE" \
                --msgbox "Cancelled! No RPM was built and $1 was not modified" 20 60
                echo "User cancelled or other error occurred."
                exit 1
        fi

        #if our interactive response was null, we need to set it to something non-null
        if [ -z "${RPMPOSTUN}" ]; then
                RPMPOSTUN="echo $TARGETFOLDER uninstalled."
        fi
        echo "Dialog($DIALOGRESPONSE) set RPMPOSTUN: $RPMPOSTUN"
        exec 3>&1
fi



########################
#RPMBUILD PREP         #
########################

#check if necessary skeleton dirs are already present, create them if not
mkdir -p ${CWD}/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
#redirect output of rpmbuild to our CWD instead of the ~/rpmbuild folder which we using
echo "%_topdir ${CWD}/rpmbuild" > ~/.rpmmacros

#make sure that if there are any empty directories in the target folder, we put something in them now
#so that when we generate the file list, there is a file in the previously empty dir, which will
#force the directory to be made when the rpm is installed.
find ${TARGETFOLDER} -type d -empty -exec touch '{}'/.rpmkeep \;
echo
#if we got an INSTALLPREFIX, we must remake the folder structure as appropriate and then tar it
if [ "$INSTALLPREFIX" ]; then
	echo "Got an INSTALLPREFIX argument of ${INSTALLPREFIX}, we need to remake the target folder with INSTALLPREFIX format now."
	echo "This might take awhile depending on how big your target folder was..."
	#mkdir -p testrpm_prefixed/opt/whatever
	#cp -r testrpm/* testrpm_prefixed/opt/whatever/
	mkdir -p ${TARGETFOLDER}_prefixed/${INSTALLPREFIX}
	cp -rL ${TARGETFOLDER}/* ${TARGETFOLDER}_prefixed/${INSTALLPREFIX} &
	#build a spinner so we know we didn't freeze...
	PID=$!; i=1; sp="/-\|"; echo -n ' '; while [ -d /proc/$PID ]; do printf "\b${sp:i++%${#sp}:1}"; sleep 0.5; done; echo;
	echo "Creating .tar.gz file for use in rpm file..."
	tar --transform "s|${TARGETFOLDER}_prefixed|${TARGETFOLDER}-${VERSION}|" -zcf ${CWD}/rpmbuild/SOURCES/${TARGETFOLDER}.tar.gz ${TARGETFOLDER}_prefixed &
	#build a spinner so we know we didn't freeze...
	PID=$!; i=1; sp="/-\|"; echo -n ' '; while [ -d /proc/$PID ]; do printf "\b${sp:i++%${#sp}:1}"; sleep 0.5; done; echo;
	#generate our RPM file list, making sure to handle filenames with spaces in them correctly
	echo "Generating rpm file list..."
	cd ${CWD}/${TARGETFOLDER}_prefixed
	RPMFILES="`find . -type f | cut -c2- | sed 's/^/\"/' | sed 's/$/\"/'`"
	cd ${CWD}
	#remove our temp directory
	rm -rf ${CWD}/${TARGETFOLDER}_prefixed
else
	#generate our RPM file list, making sure to handle filenames with spaces in them correctly
	echo "Generating rpm file list..."
        cd ${CWD}/${TARGETFOLDER}
        RPMFILES="`find . -type f | cut -c2- | sed 's/^/\"/' | sed 's/$/\"/'`"
        cd ${CWD}
	echo "Creating .tar.gz file for use in rpm file..."
	#remake our target folder as a tarball in the SOURCES folder, and place it there now with the correct name.
	tar --transform "s|${TARGETFOLDER}|${TARGETFOLDER}-${VERSION}|" -zcf ${CWD}/rpmbuild/SOURCES/${TARGETFOLDER}.tar.gz ${TARGETFOLDER} &
	#build a spinner so we know we didn't freeze...
	PID=$!; i=1; sp="/-\|"; echo -n ' '; while [ -d /proc/$PID ]; do printf "\b${sp:i++%${#sp}:1}"; sleep 0.5; done; echo;

fi
#create the spec file
echo "Generating RPM SPEC file for ${TARGETFOLDER}..."
SPECFILECONTENTS="$(cat <<-EOF 
		###############################################################################
		# Spec file for ${TARGETFOLDER}
		################################################################################
		# Configured to be built by root by the $0 script
		################################################################################
		#
		Summary: ${RPMSUMMARY}
		Name: ${TARGETFOLDER}
		Version: ${VERSION}
		Release: ${RELEASE}
		License: ${RPMLICENSE}
		Group: Unspecified
		Packager: ${RPMAUTHOR}
		Requires: ${RPMREQUIRES}
		Vendor: ${RPMVENDOR}
		BuildArch: ${ARCH}
		Source0: ${TARGETFOLDER}.tar.gz
		BuildRoot: ${CWD}/rpmbuild

		%description
		${RPMDESCRIPTION}

		%prep
		%setup -q

		%build

		%install
		#copy the files to the real system, using the paths from the buildroot overlay
		cp -rfavL * %{buildroot}
		#do not generate any compiled artifacts like perl .pyo or .pyc files, just exit clean
		exit 0
		
		%files
		#We assume no file permissions need to be changed
		#%defattr(-, user, group)
		${RPMFILES}

		%post
		#kick off any installation scripts, setup systemd services, whatever
		#this gets executed at the end of the rpm -ivh myfile.rpm command to finish setting it up
		${RPMPOST}

		%postun
		# kick off any uninstallation scripts, remove systemd services, whatever
		#this gets executed at the end of the yum remove -y myfile.rpm command to finish uninstalling it
		${RPMPOSTUN}

		%clean
		#clean our our rpmbuild working directories
		rm -rf %{buildroot}/*

EOF
)"
echo "${SPECFILECONTENTS}" > ${CWD}/rpmbuild/SPECS/${TARGETFOLDER}.spec




########################
#CREATE RPM FILES      #
########################

echo 
echo
echo "Building rpm file for target ${TARGETFOLDER} version ${VERSION} release ${RELEASE}..."
rpmbuild --quiet --define "debug_package %{nil}" --buildroot ${CWD}/rpmbuild/BUILDROOT -bb rpmbuild/SPECS/${TARGETFOLDER}.spec 2>&1 | tee rpmbuild-${TARGETFOLDER}-${VERSION}-${RELEASE}.${ARCH}.log &
#build a spinner so we know we didn't freeze...
PID=$!; i=1; sp="/-\|"; echo -n ' '; while [ -d /proc/$PID ]; do printf "\b${sp:i++%${#sp}:1}"; sleep 0.5; done; echo;

rm -f ~/.rpmmacros

if [ -e "${CWD}/rpmbuild/RPMS/x86_64/${TARGETFOLDER}-${VERSION}-${RELEASE}.${ARCH}.rpm" ]; then
	echo "rpmbuild for ${CWD}/rpmbuild/RPMS/x86_64/${TARGETFOLDER}-${VERSION}-${RELEASE}.${ARCH}.rpm SUCCEEDED!"
	echo
	echo "You can verify contents of the .rpm file by doing a"
	echo "rpm -qlp ${CWD}/${TARGETFOLDER}-${VERSION}-${RELEASE}.${ARCH}.rpm"
	echo
	echo "You can verify the package metadata of the .rpm file by doing a"
	echo "rpm -qip ${CWD}/${TARGETFOLDER}-${VERSION}-${RELEASE}.${ARCH}.rpm"
	echo
	rm -f rpmbuild-${TARGETFOLDER}-${VERSION}-${RELEASE}.${ARCH}.log
	mv ${CWD}/rpmbuild/RPMS/x86_64/${TARGETFOLDER}-${VERSION}-${RELEASE}.${ARCH}.rpm ${CWD}
	echo
	echo
	echo "Your .rpm file is at ${CWD}/${TARGETFOLDER}-${VERSION}-${RELEASE}.${ARCH}.rpm"
	rm -rf ${CWD}/rpmbuild
else
	#print out all of our command line options in case we want to run this again
	#in non-interactive mode
	echo "Here are your rpm build options (you can copy this and run the command again to skip interaction):"
	if [ -z "${INSTALLPREFIX}" ]; then
        	echo "$0 ${TARGETFOLDER} ${VERSION} ${RELEASE} null \"${RPMSUMMARY}\" \"${RPMLICENSE}\" \"${RPMAUTHOR}\" \"${RPMVENDOR}\" \"${RPMREQUIRES}\" \"${RPMDESCRIPTION}\" \"${RPMPOST}\" \"${RPMPOSTUN}\""
	else
        	echo "$0 ${TARGETFOLDER} ${VERSION} ${RELEASE} ${INSTALLPREFIX} \"${RPMSUMMARY}\" \"${RPMLICENSE}\" \"${RPMAUTHOR}\" \"${RPMVENDOR}\" \"${RPMREQUIRES}\" \"${RPMDESCRIPTION}\" \"${RPMPOST}\" \"${RPMPOSTUN}\""
	fi

	echo "RPM build failed. Check log at rpmbuild-${TARGETFOLDER}-${VERSION}-${RELEASE}.${ARCH}.log"
	rm -rf ${CWD}/rpmbuild
	exit 3
fi
echo
echo
#print out all of our command line options in case we want to run this again
#in non-interactive mode
echo "Here are your rpm build options (you can copy this and run the command again to skip interaction):"
if [ -z "${INSTALLPREFIX}" ]; then
        echo "$0 ${TARGETFOLDER} ${VERSION} ${RELEASE} null \"${RPMSUMMARY}\" \"${RPMLICENSE}\" \"${RPMAUTHOR}\" \"${RPMVENDOR}\" \"${RPMREQUIRES}\" \"${RPMDESCRIPTION}\" \"${RPMPOST}\" \"${RPMPOSTUN}\""
else
        echo "$0 ${TARGETFOLDER} ${VERSION} ${RELEASE} ${INSTALLPREFIX} \"${RPMSUMMARY}\" \"${RPMLICENSE}\" \"${RPMAUTHOR}\" \"${RPMVENDOR}\" \"${RPMREQUIRES}\" \"${RPMDESCRIPTION}\" \"${RPMPOST}\" \"${RPMPOSTUN}\""
fi


###########################################
#END SCRIPT                               #
###########################################
exit 0
