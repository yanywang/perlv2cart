#!/bin/bash
script_dir=$(dirname $0)
script_name=$(basename $0)
pushd $script_dir >/dev/null && script_real_dir=$(pwd) && popd >/dev/null
LIB_DIR="${script_real_dir}/../lib"

source ${LIB_DIR}/openshift.sh
source ${LIB_DIR}/util.sh

########################################
###             Main                 ###
########################################

source check_lib.sh
source app.conf


# initial log
date=$(get_date)
log_file="log/${script_name}.${date}.log"
user_info_file="user_info.${date}"

if [ ! -d log ]; then
    mkdir log
fi

touch ${log_file}

print_warnning "Pls firstly run oo-diagnostics on both broker and nodes to make sure your env pass sanity test !!!"

#set -x
failed_app=""

echo -e "Please input your choice\n 0: all data \n Specified app: ${app_list// /|}"
read choice

echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || [ X"$choice" == X"php_app" ]; then
    php_app_check ${php_app} ${rhlogin} ${password} "Welcome to OpenShift" "1" || failed_app="${failed_app}${php_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || [ X"$choice" == X"perl_app" ]; then 
    perl_app_check ${perl_app} ${rhlogin} ${password} "Welcome to OpenShift" "1" "create" &&
    print_warnning "Remember to idle this app on node using oo-admin-ctl-app command!!!" || failed_app="${failed_app}${perl_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || [ X"$choice" == X"python26_app" ]; then
    python26_app_check ${python26_app} ${rhlogin} ${password} || failed_app="${failed_app}${python26_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || [ X"$choice" == X"python27_app" ]; then
    python27_app_check ${python27_app} ${rhlogin} ${password} || failed_app="${failed_app}${python27_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || [ X"$choice" == X"ruby18_app" ]; then 
    ruby18_app_check ${ruby18_app} ${rhlogin} ${password} "bar.${domain}.com" || failed_app="${failed_app}${ruby18_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || [ X"$choice" == X"ruby19_app" ]; then
    ruby19_app_check ${ruby19_app} ${rhlogin} ${password} "Welcome to OpenShift" "1" || failed_app="${failed_app}${ruby19_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || [ X"$choice" == X"nodejs010_app" ]; then
    nodejs010_app_check ${nodejs010_app} ${rhlogin} ${password} || failed_app="${failed_app}${nodejs010_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || [ X"$choice" == X"jbossews10_app" ]; then
    jbossews10_app_check ${jbossews10_app} ${rhlogin} ${password} "Welcome to OpenShift" "1" || failed_app="${failed_app}${jbossews10_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || [ X"$choice" == X"jbossews20_app" ]; then
    jbossews20_app_check ${jbossews20_app} ${rhlogin} ${password} "Welcome to OpenShift" "1" || failed_app="${failed_app}${jbossews20_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || [ X"$choice" == X"jbosseap_app" ]; then
    jbosseap_app_check ${jbosseap_app} ${rhlogin} ${password} "Welcome to OpenShift" "1" "create" || failed_app="${failed_app}${jbosseap_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || [ X"$choice" == X"diy_app" ]; then
    diy_app_check ${diy_app} ${rhlogin} ${password} || failed_app="${failed_app}${diy_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || [ X"$choice" == X"scalable_php_app" ]; then
    scalable_php_app_check ${scalable_php_app} ${rhlogin} ${password} "2" || failed_app="${failed_app}${scalable_php_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || [ X"$choice" == X"scalable_perl_app" ]; then
    scalable_perl_app_check ${scalable_perl_app} ${rhlogin} ${password} "Welcome to OpenShift" "1" "create" "2" || failed_app="${failed_app}${scalable_perl_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || [ X"$choice" == X"scalable_python26_app" ]; then
    scalable_python26_app_check ${scalable_python26_app} ${rhlogin} ${password} "Welcome to OpenShift" "1" "create" "2" || failed_app="${failed_app}${scalable_python26_app} "
fi

echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || [ X"$choice" == X"scalable_python27_app" ]; then
    scalable_python27_app_check ${scalable_python27_app} ${rhlogin} ${password} "Welcome to OpenShift" "1" "2"  || failed_app="${failed_app}${scalable_python27_app} "
fi

echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || [ X"$choice" == X"scalable_ruby18_app" ]; then
    scalable_ruby18_app_check ${scalable_ruby18_app} ${rhlogin} ${password} "rhc-cartridge" "1" "stop"  || failed_app="${failed_app}${scalable_ruby18_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || [ X"$choice" == X"scalable_ruby19_app" ]; then
    scalable_ruby19_app_check ${scalable_ruby19_app} ${rhlogin} ${password} || failed_app="${failed_app}${scalable_ruby19_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || [ X"$choice" == X"scalable_nodejs010_app" ]; then
    scalable_nodejs010_app_check ${scalable_nodejs010_app} ${rhlogin} ${password} "Welcome to OpenShift" "1" "2" || failed_app="${failed_app}${scalable_nodejs010_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || [ X"$choice" == X"scalable_jbossews10_app" ]; then
    scalable_jbossews10_app_check ${scalable_jbossews10_app} ${rhlogin} ${password} "Welcome to OpenShift" "1" || failed_app="${failed_app}${scalable_jbossews10_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || [ X"$choice" == X"scalable_jbossews20_app" ]; then
    scalable_jbossews20_app_check ${scalable_jbossews20_app} ${rhlogin} ${password} "Welcome to OpenShift" "1" || failed_app="${failed_app}${scalable_jbossews20_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || [ X"$choice" == X"scalable_jbosseap_app" ]; then
    scalable_jbosseap_app_check ${scalable_jbosseap_app} ${rhlogin} ${password} "Welcome to OpenShift" "1" "create" || failed_app="${failed_app}${scalable_jbosseap_app} "

fi

echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || [ X"$choice" == X"scalable_jbosseap_app1" ]; then
    scalable_jbosseap_app1_check ${scalable_jbosseap_app1} ${rhlogin} ${password} "Welcome to OpenShift" "1" "2"  || failed_app="${failed_app}${scalable_jbosseap_app1} "
fi

echo '***********************************************' | tee -a ${log_file}

print_warnning "Pls remember to log into web console to make sure it woking well !!!"

echo "Failed app list:"
print_red_txt "${failed_app}"

# Save user info into file
#echo "Saving user info for ${domain}"
#rhc domain show -l ${rhlogin} -p ${password} | tee ${user_info_file}
