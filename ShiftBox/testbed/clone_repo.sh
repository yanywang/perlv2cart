#!/bin/bash
# This script will help user to clone every repo under user's domain.

########################################
###             Main                 ###
########################################

if [ X"$#" != X"2" ]; then
    echo "rhlogin password???"
    exit 1
fi

rhlogin="$1"
passwd="$2"

app_info=`rhc domain show -l ${rhlogin} -p ${passwd}`
for i in `echo "${app_info}" | grep ssh | awk -F'Git URL: ' '{print $2}'`; do
    echo "Git cloning $i"
    git clone $i
    echo "============"
done
