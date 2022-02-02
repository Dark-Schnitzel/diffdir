#!/bin/sh
# rosenke@dssgmbh.de
# compare 2 directories, including acls and extended attributes 

VERSION=0.01

my=${0##*/}
folder1=$1
folder2=$2

# tmp files for comparing
a=$(mktemp)
b=$(mktemp)

show_help(){
echo "Command Line Options:"
echo "    -s, --stats           Show Results/Stats at the End of the Run"
echo "    -c, --checksum        Compare files via checksum (files only)"
echo "    --diff                Show diff output. If Checksum and diff are used both, only the stats for diff will be shown (different checksum = diff in Content)"
echo "    --acls                Compare ACLs"
echo "    --missing             Missing Files"
echo "    --extattr             Compare extended Attributes"
echo "    -l, --link            Compare Link Targets"
echo "    -o, --owner           Compare Owner permissions"
echo "    -m, --mode            Compare Filemodes"
echo "    -t, --time            Compare Timestamps"
echo "    -a, --all             All the Options above combined (default)"            
echo "    -h, --help            Show this help section"
echo "    -d, --debug           Enable Debugging"
echo "    -v                    Verbose"
exit 1
}

if [ -z $folder1 ] || [ -z $folder2 ]; then
    echo "Utility for comparing folders"
    echo "$my: sourcefolder targetfolder (Options)"
    show_help
fi
# remove the last slash of the dirs
folder1=$(echo $folder1 | sed 's:/*$::')
folder2=$(echo $folder2 | sed 's:/*$::') 
shift 2

for arg in "$@"; do
    case $arg in
        -s | --stats)
            stats=1
            all=0
            shift
            ;;
        -c | --checksum)
            checksum=1
            all=0
            shift
            ;;
        -d | --debug)
            set -x 
            shift
            ;;
        -v )
            verbose=1
            shift
            ;;
        --diff)
            diff=1
            all=0
            shift
            ;;
        --acls)
            acls=1
            all=0
            shift
            ;;
        --missing)
            missing=1
            all=0
            shift
            ;;
        --extattr)
            extattr=1
            all=0
            shift
            ;;
        -l | --link)
            link=1
            all=0
            shift
            ;;
        -o | --owner)
            owner=1
            all=0
            shift
            ;;
        -m | --mode)
            mode=1
            all=0
            shift
            ;;
        -t | --time)
            time=1
            all=0
            shift
            ;;
        -a | --all)
            all=1
            shift
            ;;
        -h | --help | *)
            show_help
            ;;
    esac
done

# set all to default if all is unset (assume that no other arg is present)
if [ -z $all ]; then
    all=1
fi

# Diff without Colours is painful.
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White
NC='\033[0m'              # No Color

# allow spaces in Filenames
IFS=$'\n'

compare(){
    if !(cmp ${a} ${b} > /dev/null 2>&1); then
        echo -e "${Red}$item:${NC} ${Cyan}$1${NC}"
        echo -e "${Red}$folder1/$item:${NC}"
        # we cant colour the output if the output contains a backslash \, this leads to garbish output
        if (grep '\\' ${a}); then
            echo "$(cat ${a})"
        else
            echo -e "${Blue}$(cat ${a})${NC}"
        fi
        echo -e  "${Red}$folder2/$item:${NC}"
        if [ -f ${b} ]; then
            if (grep '\\' ${b}); then
                echo "$(cat ${b})"
            else
                echo -e "${Purple}$(cat ${b})${NC}"
            fi
        fi
        echo
        if [ "$1" = "checksum" ]; then
            counter_checksum=$((counter_checksum+1))
        elif [ "$1" = "ACLs" ]; then
            counter_acls=$((counter_acls+1))
        elif [ "$1" = "extended_attributes" ]; then 
            counter_extattr=$((counter_extattr+1))
        elif [ "$1" = "Owner" ]; then
            counter_owner=$((counter_owner+1))
        elif [ "$1" = "Mode" ]; then
            counter_mode=$((counter_mode+1))
        elif [ "$1" = "Timestamp" ]; then
            counter_time=$((counter_time+1))
        elif [ "$1" = "link" ]; then
            counter_link=$((counter_link+1))      
        fi
        test -f ${a} && rm ${a} 
        test -f ${b} && rm ${b}
#        continue
    fi
    test -f ${a} && rm ${a} 
    test -f ${b} && rm ${b}
}

# set counters
counter_missing=0
counter_diff=0
counter_checksum=0
counter_acls=0
counter_extattr=0
counter_owner=0
counter_mode=0
counter_time=0
counter_link=0
counter_skipped_pipes=0
counter_skipped_sockets=0
counter_skipped_block=0
counter_skipped_character=0

for item in $(find $folder1 | sed "s;$folder1/;;g"); do
    if [ "verbose" = "1" ]; then 
        echo $item
    fi
    if [ "$item" != "$folder1" ]; then
        # we dont check pipes or sockets
        if [ -p $folder1/$item ]; then
            [ "$verbose" = "1" ] && echo "${Red}$folder1/$item skipped, the file is a pipe${NC}"
            counter_skipped_pipes=$((counter_skipped_pipes+1))
            continue      
        elif [ -S $folder1/$item ]; then
            [ "$verbose" = "1" ] && echo "${Red}$folder1/$item skipped, the file is a socket${NC}"  
            counter_skipped_sockets=$((counter_skipped_sockets+1))               
            continue
        elif [ -b $folder1/$item ]; then
            [ "$verbose" = "1" ] && echo "${Red}$folder1/$item skipped, the file is a block special file${NC}"  
            counter_skipped_block=$((counter_skipped_block+1))               
            continue
        elif [ -c $folder1/$item ]; then
            [ "$verbose" = "1" ] && echo "${Red}$folder1/$item skipped, the file is a character special file${NC}"  
            counter_skipped_character=$((counter_skipped_character+1))               
            continue
        fi

        # Compare link targetpaths
        if [ "$all" = "1" ] || [ "$link" = "1" ]; then
            if [ -L $folder1/$item ]; then
                readlink $folder1/$item > ${a}
                readlink $folder2/$item > ${b}
                compare link
            fi
        fi

        # Check if the file is missing
        if [ ! -e $folder2/$item ]; then
            if [ "$all" = "1" ] || [ "$missing" = "1" ]; then
                echo -e "${Red}$folder2/$item is ${NC}${Cyan}missing${NC}"
                counter_missing=$((counter_missing+1))
                continue
            else
                continue
            fi
        fi

        # Diff file content
        if [ "$all" = "1" ] || [ "$diff" = "1" ]; then
            if [ -f $folder1/$item ] && !(diff -q $folder1/$item $folder2/$item > /dev/null); then
                echo -e "${Red}$item: ${NC}${Cyan}Content${NC}"
                echo -e "${Purple}$(diff -u $folder1/$item $folder2/$item)${NC}"
                echo 
                counter_diff=$((counter_diff+1))
            fi
        fi

        # Compare Checksums
        if [ "$all" = "1" ] || [ "$checksum" = "1" ]; then
            if [ -f $folder1/$item ]; then
                md5 -q $folder1/$item > ${a}
                md5 -q $folder2/$item > ${b}
                compare checksum
            fi
        fi
        
        # Diff Acls
        if [ "$all" = "1" ] || [ "$acls" = "1" ]; then
            getfacl $folder1/$item | grep -v "# file" > ${a}
            getfacl $folder2/$item | grep -v "# file" > ${b}
            compare ACLs
        fi

        # Diff extended Attributes
        if [ "$all" = "1" ] || [ "$extattr" = "1" ]; then
            # list and compare the available namespaces
            lsextattr -q user $folder1/$item | xargs -n 1 | sort > ${a}
            lsextattr -q user $folder2/$item | xargs -n 1 | sort > ${b}
            compare extended_attributes
            lsextattr -q system $folder1/$item | xargs -n 1 | sort > ${a}
            lsextattr -q system $folder2/$item | xargs -n 1 | sort > ${b}
            compare extended_attributes
            # list and compare the actual values
            for attr in $(lsextattr -q user $folder1/$item | xargs -n 1 | sort); do
                getextattr -q user $attr $folder1/$item > ${a}
            done
            for attr in $(lsextattr -q user $folder2/$item | xargs -n 1 | sort ); do
                getextattr -q user $attr $folder2/$item > ${b}
            done
            if [ -f ${a} ]; then
                compare extended_attributes
            fi

            for attr in $(lsextattr -q system $folder1/$item | xargs -n 1 | sort); do
                getextattr -q system $attr $folder1/$item > ${a}
            done
            for attr in $(lsextattr -q system $folder2/$item | xargs -n 1 | sort); do
                getextattr -q system $attr $folder2/$item > ${b}
            done
            if [ -f ${a} ]; then
                compare extended_attributes
            fi
        fi

        # Diff Owner
        if [ "$all" = "1" ] || [ "$owner" = "1" ]; then
            if [ -d $folder1/$item ]; then
                ls -ld $folder1/$item | awk '{print$3" "$4}' | awk 'NF' > ${a}
                ls -ld $folder2/$item | awk '{print$3" "$4}' | awk 'NF' > ${b}
            else
                ls -la $folder1/$item | awk '{print$3" "$4}' | awk 'NF' > ${a}
                ls -la $folder2/$item | awk '{print$3" "$4}' | awk 'NF' > ${b}
            fi
            compare Owner
        fi

        # Diff Mode
        if [ "$all" = "1" ] || [ "$mode" = "1" ]; then
            if [ -d $folder1/$item ]; then
                ls -ld $folder1/$item | awk '{print$1}' | awk 'NF' | grep -v total > ${a}
                ls -ld $folder2/$item | awk '{print$1}' | awk 'NF' | grep -v total > ${b}
            else
                ls -la $folder1/$item | awk '{print$1}' | awk 'NF' | grep -v total > ${a}
                ls -la $folder2/$item | awk '{print$1}' | awk 'NF' | grep -v total > ${b}
            fi
            compare Mode
        fi

        # Diff Timestamp
        if [ "$all" = "1" ] || [ "$time" = "1" ]; then
            if [ -d $folder1/$item ]; then
                ls -ld $folder1/$item | awk '{print$6" "$7" "$8}' | awk 'NF' > ${a}
                ls -ld $folder2/$item | awk '{print$6" "$7" "$8}' | awk 'NF' > ${b}
            else
                ls -la $folder1/$item | awk '{print$6" "$7" "$8}' | awk 'NF' > ${a}
                ls -la $folder2/$item | awk '{print$6" "$7" "$8}' | awk 'NF' > ${b}
            fi
            compare Timestamp
        fi
    fi
done

# Results
if [ "$all" = "1" ] || [ "$stats" = "1" ]; then
    [ "$counter_missing" != "0" ]           &&   echo -e "${Red}Missing Files:                    $counter_missing${NC}"
    [ "$counter_acls" != "0" ]              &&   echo -e "${Red}Different ACLs:                   $counter_acls${NC}"
    [ "$counter_extattr" != "0" ]           &&   echo -e "${Red}Different Extended Attributes:    $counter_extattr${NC}"
    [ "$counter_owner" != "0" ]             &&   echo -e "${Red}Different Owner:                  $counter_owner${NC}"
    [ "$counter_mode" != "0" ]              &&   echo -e "${Red}Different Mode:                   $counter_mode${NC}"
    [ "$counter_time" != "0" ]              &&   echo -e "${Red}Different Timestamp:              $counter_time${NC}"
    [ "$counter_link" != "0" ]              &&   echo -e "${Red}Different Links:                  $counter_link${NC}"
    [ "$counter_skipped_pipes" != "0" ]     &&   echo -e "${Red}Skipped Pipes:                    $counter_skipped_pipes${NC}"
    [ "$counter_skipped_sockets" != "0" ]   &&   echo -e "${Red}Skipped Sockets:                  $counter_skipped_sockets${NC}"
    [ "$counter_skipped_block" != "0" ]     &&   echo -e "${Red}Skipped Block Special Files:      $counter_skipped_block${NC}"
    [ "$counter_skipped_character" != "0" ] &&   echo -e "${Red}Skipped Character Special Files:  $counter_skipped_character${NC}"
    # different content == different checksum
    # dont show both but show checksum or diff if we want this
    if [ "$counter_diff" != "0" ] && [ "$counter_checksum" -gt "0" ]; then
        echo -e "${Red}Diff in Content:                  $counter_diff${NC}"
    elif [ "$counter_diff" != "0" ]; then
        echo -e "${Red}Diff in Content:                  $counter_diff${NC}"
    elif [ "$counter_checksum" != "0" ]; then
        echo -e "${Red}Different Checksum:               $counter_checksum${NC}"
    fi
fi
