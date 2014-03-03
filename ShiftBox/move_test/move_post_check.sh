#!/bin/bash
script_dir=$(dirname $0)
script_name=$(basename $0)
pushd $script_dir >/dev/null && script_real_dir=$(pwd) && popd >/dev/null
LIB_DIR="${script_real_dir}/../lib"

source ${LIB_DIR}/openshift.sh
source ${LIB_DIR}/util.sh
source check_lib.sh
source app.conf


checkApps()
{
   appschoice=$*
   for singleapp in ${appschoice}; do
       flag=0
       for fapp in $app_list; do

           if [ X"${fapp}" == X"${singleapp}" ]; then
                flag=1
                break
           fi
        done

        if [ $flag == 0 ]; then
           print_error "$singleapp can't be created\n"
           return 1
        fi
   done
return 0
}

isSelectedApp()
{
    appschoice=$*
    for singleapp in ${gbApps}; do
        if [ X"${appschoice}" == X"${singleapp}" ]; then
            return 0
        fi
    done
    return 1
}
########################################
###             Main                 ###
########################################


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

#check configure file
if [ -z $rhlogin -o -z $domain -o -z $password ]; then
    echo "ERROR:Setup:Please set rhlogin,domain and password in app.conf"
    exit 1
fi

#check rhc account
echo "Info: have your create  domain:[$domain] for user [$rhlogin]: (y/n)?"
read choice
if [ $choice != "y" ]; then
   echo "Error:please create domain at first!"
   exit 1
fi

gbApps=""

#User selection checking
if [ $# -eq 0 ]; then
     while [ 1 == 1 ]
     do
          echo "INFO: Apps list can be selected as below:"
          echo "---------------------"
          echo "${app_list}"
          echo "---------------------"
          echo "INFO: Please specify apps to create \n 0(all)|appnames(separated by space)|q(quit)"
          read choice
          echo "\n"
          if [ X"$choice" == X"0" ]; then
              gbApps=${app_list}
              break
          elif [ X"$choice" == X"q" ]; then
              exit 0
          else
	      if checkApps $choice ; then
                  gbApps=$choice
                  break
              fi
          fi
     done
else
    if ! checkApps $* ; then
          echo "INFO: Valid Apps list is as below:"
          echo "---------------------"
          echo "${app_list}"
          echo "---------------------"
       exit  1
    fi
    gbApps="$*"
fi

echo "INFO: ${gbApps} will be created\n"| tee -a ${log_file}

#echo -e "Please input your choice\n 0: all data \n Specified app: ${app_list// /|}"
#read choice

echo -e "Do you want to delete and re-add jenkins-client for existing apps? [Y|N]"
read re_add_jenkins_clent

echo '***********************************************' | tee -a ${log_file}
if [ X"${re_add_jenkins_clent}" == X"Y" ]; then
    destroy_app "${jenkins_app}" ${rhlogin} ${password}
    create_app ${jenkins_app} "jenkins" ${rhlogin} ${password} "--no-git" || exit 1
    for app in ${app_list}; do
        eval app_name="$"${app}
        if echo ${app_name} | grep -q 'jks'; then
            destroy_app "${app_name}bldr" ${rhlogin} ${password}
            # add_cart "${app_name}" "jenkins-client" ${rhlogin} ${password} || exit 1
            :
        fi
    done
fi

echo '***********************************************' | tee -a ${log_file}
if isSelectedApp "new_app"; then
    create_new_app_check ${new_app} ${rhlogin} ${password} "2" || failed_app="${failed_app}${new_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if isSelectedApp "php_app"; then
    php_app_check ${php_app} ${rhlogin} ${password} "1" "2" "scale-down" || failed_app="${failed_app}${php_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if isSelectedApp "perl_app"; then
    perl_app_check ${perl_app} ${rhlogin} ${password} "1" "2" "modify" || failed_app="${failed_app}${perl_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if isSelectedApp "python26_app"; then
    python26_app_check ${python26_app} ${rhlogin} ${password} || failed_app="${failed_app}${python26_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if isSelectedApp "python27_app"; then
    python27_app_check ${python27_app} ${rhlogin} ${password} || failed_app="${failed_app}${python27_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if isSelectedApp "ruby18_app"; then
    ruby18_app_check ${ruby18_app} ${rhlogin} ${password} "bar.${domain}.com" || failed_app="${failed_app}${ruby18_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if isSelectedApp "ruby19_app"; then
    ruby19_app_check ${ruby19_app} ${rhlogin} ${password} "1" "2" || failed_app="${failed_app}${ruby19_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if isSelectedApp "nodejs010_app"; then
    nodejs010_app_check ${nodejs010_app} ${rhlogin} ${password} || failed_app="${failed_app}${nodejs010_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if isSelectedApp "jbossews10_app"; then
    jbossews10_app_check ${jbossews10_app} ${rhlogin} ${password} "1" "2" || failed_app="${failed_app}${jbossews10_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if isSelectedApp "jbossews20_app"; then
    jbossews20_app_check ${jbossews20_app} ${rhlogin} ${password} "1" "2" || failed_app="${failed_app}${jbossews20_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if isSelectedApp "jbosseap_app"; then
    jbosseap_app_check ${jbosseap_app} ${rhlogin} ${password} "1" "2" "modify" || failed_app="${failed_app}${jbosseap_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if isSelectedApp "diy_app"; then
    diy_app_check ${diy_app} ${rhlogin} ${password} || failed_app="${failed_app}${diy_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if isSelectedApp "scalable_php_app"; then
    scalable_php_app_check ${scalable_php_app} ${rhlogin} ${password} "2" || failed_app="${failed_app}${scalable_php_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if isSelectedApp "scalable_perl_app"; then
    scalable_perl_app_check ${scalable_perl_app} ${rhlogin} ${password} "1" "2" "modify" "2" || failed_app="${failed_app}${scalable_perl_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if isSelectedApp "scalable_python26_app"; then
    scalable_python26_app_check ${scalable_python26_app} ${rhlogin} ${password} "1" "2" "modify" "2" || failed_app="${failed_app}${scalable_python26_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if isSelectedApp "scalable_python27_app"; then
    scalable_python27_app_check ${scalable_python27_app} ${rhlogin} ${password} "1" "2" "2"  || failed_app="${failed_app}${scalable_python27_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if isSelectedApp "scalable_ruby18_app"; then
    scalable_ruby18_app_check ${scalable_ruby18_app} ${rhlogin} ${password} "rhc-cartridge1" "2" "start" || failed_app="${failed_app}${scalable_ruby18_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if isSelectedApp "calable_ruby19_app"; then
    scalable_ruby19_app_check ${scalable_ruby19_app} ${rhlogin} ${password} || failed_app="${failed_app}${scalable_ruby19_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if isSelectedApp "scalable_nodejs010_app"; then
    scalable_nodejs010_app_check ${scalable_nodejs010_app} ${rhlogin} ${password} "1" "2" "2" "scale-down" "${domain}" || failed_app="${failed_app}${scalable_nodejs010_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if isSelectedApp "scalable_jbossews10_app"; then
    scalable_jbossews10_app_check ${scalable_jbossews10_app} ${rhlogin} ${password} "1" "2" || failed_app="${failed_app}${scalable_jbossews10_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if isSelectedApp "scalable_jbossews20_app"; then
    scalable_jbossews20_app_check ${scalable_jbossews20_app} ${rhlogin} ${password} "1" "2" || failed_app="${failed_app}${scalable_jbossews20_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if isSelectedApp "scalable_jbosseap_app"; then
    scalable_jbosseap_app_check ${scalable_jbosseap_app} ${rhlogin} ${password} "1" "2" "modify" "scale-up" || failed_app="${failed_app}${scalable_jbosseap_app} "

fi

echo '***********************************************' | tee -a ${log_file}
if isSelectedApp "scalable_jbosseap_app1"; then
    scalable_jbosseap_app1_check ${scalable_jbosseap_app1} ${rhlogin} ${password} "1" "2" "2"  || failed_app="${failed_app}${scalable_jbosseap_app1} "
fi

echo '***********************************************' | tee -a ${log_file}

print_warnning "Pls remember to log into web console to make sure it still woking well !!!"

echo "Failed app list:"
print_red_txt "${failed_app}"

# Save user info into file
#echo "Saving user info for ${domain}"
#rhc domain show -l ${rhlogin} -p ${password} | tee ${user_info_file}

#set +x
