#!/bin/bash
#! /bin/sed -nf


function rmcomments () {
 
         sed 's|/\*|\n&|g;s|*/|&\n|g' ${1}  | sed '/\/\*/,/*\//d'           # remove the comment using sed
}




# This script takes any number of CPP files as parameters.
# For each file, it checks to see if there is a matching call to perror for every syscall.
# If there is not, we assume that proper error checking is not happening.
# Then we output a grade modifier that deducts 5 points for every extra syscall.
#
# BUGS:
# This script will only detect syscalls if they are immediately followed by a parenthesis.
# This should never overcount syscalls, but could undercount them in the presence of macros, function pointers, or other fanciness.
#
# TODO:
# Currently, we run the script on the raw source.
# Would it be better to run the script after the preprocessor has run?
#

scriptdir=`dirname "$0"`
#source "$scriptdir/config.sh"

if [ $# -eq 0 ]; then
    echo "usage: $0 filetograde"
    exit 1
elif [ $# -eq 1 ];then
    if [ -d $1 ]; then
        for s in "$1"/*
        do
            $0 $s
        done
        exit 0
    fi
else
    for f in "$@"
    do
        if [ -d $f ]; then
            for g in "$f"/*
            do
                $0 $g
            done
        else
            $0 $f
        fi
    done
    exit 0
fi

source "$scriptdir/config.sh"

# we'll pipe files through these commands to remove spurious counts
#rmcommnets = "rmcomment"

rmstr="sed s/\"[^\"]*\"//g"
rminclude="sed s/#.*//"

# define all the regexes for syscalls likely to be used by students
syscalls="
    getlogin
    getlogin_r
    gethostname
    execl
    execle
    execlp
    execv
    execve
    execvl
    execvp
    fork
    wait
    waitpid
    ioctl
    open
    close
    read
    write
    opendir
    closedir
    readdir
    readdir_r
    readlink
    lstat
    fstat
    stat
    pipe
    dup2
    dup
    chdir
    getcwd
    getwd
    get_current_dir_name
    signal
    sigaction
    getpwuid
    getgrgid
    kill
    access
    system
    "

#The regex will not match member operators like stream::open.
args=""
for syscall in $syscalls; do

    args="$args -e [^._]\<$syscall\>[^(]*([^)]*) -e ^\<$syscall\>[^(]*([^)]*) "
    #args="$args -e \<$syscall\>[^(]*([^)]*) "
done

# calculate number of syscalls
syscalls=`cat $@ | rmcomments $@ | $rmstr | $rminclude | sed -e 's/^[ \t]*//' | grep -o $args -n | sed -e 's/^\([1234567890][1234567890]\):/0\1:/' | sed -e 's/\([1234567890]\):/\1:  /'`
numsyscalls=$(echo "$syscalls" | wc -l)

# calculate number of perror
perrors=`cat $@ | rmcomments $@ | $rmstr | $rminclude | sed -e 's/^[ \t]*//' | grep -n -e "\<perror\>" | sed -e 's/^\([1234567890][1234567890]\):/0\1:/' | sed -e 's/\([1234567890]\):/\1:  /'`
numperror=`echo "$perrors" | wc -l`

# print vars
function printvars {
    [ ! -z "$2" ] && export GREP_COLOR="$2"
    if [ ! -z "$1" ]; then
        IFS=$'\n'
        for line in $1; do
            IFS=' '
            echo "  $line" | grep -e "\<perror\>([^)]*)" $args --color=always
        done
    fi
}
echo
echo "lines with syscalls:"
out="$(printvars "$syscalls" '1;31')
     $(printvars "$perrors" '1;32')
    "
echo "$out" | sed -e 's/^ */  /' | sort

# calculate the grade modifier
grademod="0"
if [ "$numperror" -lt "$numsyscalls" ]; then
    grademod=$[ 5 * ($numsyscalls - $numperror) ]
fi

# output results
echo
echo "summary:"
echo "  number of syscalls... $numsyscalls"
echo "  number of perror..... $numperror"
echo "  grade modifier....... -$grademod"

#echo
#echo "relevant system calls:"
#for syscall in $syscalls; do
#cat $@ | $rmcomment | $rmstr | grep -ne "$syscall" "$1"
#done
#
#echo
#echo "relevant perror calls:"
#cat $@ | $rmcomment | $rmstr | grep -ne "\<perror\>" "$1"

exit $grademod
