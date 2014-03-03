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

source app.conf


# initial log
date=$(get_date)
log_file="log/${script_name}.${date}.log"
user_info_file="user_info.${date}"

if [ ! -d log ]; then
    mkdir log
fi

touch ${log_file}

#set -x
failed_app=""

echo -e "Please input your choice\n 0: all data \n Specified app: ${app_list// /|}"
read choice
choice=${choice//|/ }

echo -e "Creating test data ... \n"
echo '***********************************************' | tee -a ${log_file}
create_app ${jenkins_app} "jenkins" ${rhlogin} ${password} "--no-git"


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || include_item "${choice}" "php_app"; then
    create_app ${php_app} "php" ${rhlogin} ${password} &&
    add_cart ${php_app} "cron" "${rhlogin}" "${password}" &&
    add_cart ${php_app} "postgresql-8.4" "${rhlogin}" "${password}" &&
    run_command "cd ${php_app} && echo 'date >> \${OPENSHIFT_REPO_DIR}php/date.txt' >.openshift/cron/minutely/date.sh && chmod +x .openshift/cron/minutely/date.sh && git add . && git commit -a -mx && git push && cd -" || failed_app="${failed_app}${php_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || include_item "${choice}" "perl_app"; then 
    create_app ${perl_app} "perl-5.10" ${rhlogin} ${password} &&
    add_cart ${perl_app} "mysql" "${rhlogin}" "${password}" &&
    run_command "cp -rf data/test.pl ${perl_app}/perl/ && cd ${perl_app} && git add . && git commit -a -mx && git push && cd -"  || failed_app="${failed_app}${perl_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || include_item "${choice}" "python26_app"; then
    create_app ${python26_app} "python-2.6" ${rhlogin} ${password} &&
    add_cart ${python26_app} "mysql-5.1" "${rhlogin}" "${password}" &&
    run_command "cd ${python26_app} && git remote add upstream -m master git://github.com/openshift/reviewboard-example.git && git pull -s recursive -X theirs upstream master && git push && cd -" || failed_app="${failed_app}${python26_app} "
fi

echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || include_item "${choice}" "python27_app"; then
    create_app ${python27_app} "python-2.7" ${rhlogin} ${password} &&
    run_command "cd ${python27_app} && git remote add upstream -m master git://github.com/openshift/django-example.git && git pull -s recursive -X theirs upstream master && git push && cd -" || failed_app="${failed_app}${python27_app} "
fi

echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || include_item "${choice}" "ruby18_app"; then 
    create_app ${ruby18_app} "ruby-1.8" ${rhlogin} ${password} &&
    add_cart ${ruby18_app} "mysql-5.1" "${rhlogin}" "${password}" &&
    run_command "rhc alias add ${ruby18_app} -l ${rhlogin} -p ${password} bar.${domain}.com" &&
    run_command "cd ${ruby18_app} && rm -rf * && git remote add upstream -m master git://github.com/openshift/openshift-redmine-quickstart.git && git pull -s recursive -X theirs upstream master && git push && cd -" || failed_app="${failed_app}${ruby18_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || include_item "${choice}" "ruby19_app"; then
    create_app ${ruby19_app} "ruby-1.9" ${rhlogin} ${password} || failed_app="${failed_app}${ruby19_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || include_item "${choice}" "nodejs010_app"; then
    create_app ${nodejs010_app} "nodejs-0.10" ${rhlogin} ${password} &&
    run_command "cp -rf data/server.js ${nodejs010_app} && cd ${nodejs010_app} && sed -i '/dependencies/a \ \ \ \ \"websocket\": \">= 1.0.7\"' package.json && git add . && git commit -amt && git push && cd -" || failed_app="${failed_app}${nodejs010_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || include_item "${choice}" "jbossews10_app"; then
    create_app ${jbossews10_app} "jbossews-1.0" ${rhlogin} ${password} || failed_app="${failed_app}${jbossews10_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || include_item "${choice}" "jbossews20_app"; then
    create_app ${jbossews20_app} "jbossews-2.0" ${rhlogin} ${password} &&
    add_cart ${jbossews20_app} "mysql" "${rhlogin}" "${password}" &&
    run_command "cp -rf data/mysql.jsp ${jbossews20_app}/src/main/webapp/ && mkdir -p ${jbossews20_app}/src/main/webapp/WEB-INF/lib && cp -rf data/mysql-connector-java-5.1.20-bin.jar ${jbossews20_app}/src/main/webapp/WEB-INF/lib && cd ${jbossews20_app} && git add . && git commit -amt && git push && cd -" &&
    run_command "cd ${jbossews20_app} && touch .openshift/markers/hot_deploy && git add . && git commit -amt && git push && cd -" || failed_app="${failed_app}${jbossews20_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || include_item "${choice}" "jbosseap_app"; then
    create_app ${jbosseap_app} "jbosseap" ${rhlogin} ${password} &&
    add_cart ${jbosseap_app} "jenkins-client" "${rhlogin}" "${password}" &&
    add_cart ${jbosseap_app} "mysql" "${rhlogin}" "${password}" &&
    output=$(run_command "cp -rf data/test_mysql.jsp ${jbosseap_app}/src/main/webapp/test.jsp && cd ${jbosseap_app} && git add . && git commit -a -mx && git push && cd -") &&
    echo "${output}" &&
    echo "${output}" | grep -q 'Waiting for job to complete' &&
    print_gre_txt "Successfully grep 'Waiting for job to complete' in the above output" || failed_app="${failed_app}${jbosseap_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || include_item "${choice}" "diy_app"; then
    create_app ${diy_app} "diy-0.1" ${rhlogin} ${password} &&
    run_command "cd data && tar -xvzf django-1.3.1.tar.gz && cd - && mv data/Django-1.3.1/django ${diy_app}/diy/ && cd ${diy_app}/diy/ && unzip ../../data/myrawapp.zip && cd -" &&
    run_command "cp data/diyapp_start ${diy_app}/.openshift/action_hooks/start && cp data/diyapp_stop ${diy_app}/.openshift/action_hooks/stop" &&
    run_command "cd ${diy_app} && git add . && git commit -a -mx && git push && cd -" || failed_app="${failed_app}${diy_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || include_item "${choice}" "scalable_php_app"; then
    create_app ${scalable_php_app} "php-5.3" ${rhlogin} ${password} '--scaling' &&
    add_cart ${scalable_php_app} "mysql" "${rhlogin}" "${password}" &&
    min_gear_count=2 &&
    run_command "rhc cartridge scale -c php --min ${min_gear_count} -a ${scalable_php_app} -l ${rhlogin} -p ${password}" &&
    run_command "cd ${scalable_php_app} && git remote add upstream -m master git://github.com/openshift/mediawiki-example.git && git pull -s recursive -X theirs upstream master && git push && cd -" || failed_app="${failed_app}${scalable_php_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || include_item "${choice}" "scalable_perl_app"; then
    create_app ${scalable_perl_app} "perl-5.10" ${rhlogin} ${password} '--scaling' &&
    add_cart ${scalable_perl_app} "jenkins-client" "${rhlogin}" "${password}" &&
    add_cart ${scalable_perl_app} "mysql" "${rhlogin}" "${password}" &&
    min_gear_count=2 &&
    run_command "rhc cartridge scale -c perl-5.10 --min ${min_gear_count} -a ${scalable_perl_app} -l ${rhlogin} -p ${password}" &&
    output=$(run_command "cp -rf data/test.pl ${scalable_perl_app}/perl/ && cd ${scalable_perl_app} && git add . && git commit -a -mx && git push && cd -") &&
    echo "${output}" &&
    echo "${output}" | grep -q 'Waiting for job to complete' &&
    print_gre_txt "Successfully grep 'Waiting for job to complete' in the above output" || failed_app="${failed_app}${scalable_perl_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || include_item "${choice}" "scalable_python26_app"; then
    create_app ${scalable_python26_app} "python-2.6" ${rhlogin} ${password} '--scaling' &&
    add_cart ${scalable_python26_app} "jenkins-client" "${rhlogin}" "${password}" &&
    add_cart ${scalable_python26_app} "mysql" "${rhlogin}" "${password}" &&
    min_gear_count=2 &&
    run_command "rhc cartridge scale -c python-2.6 --min ${min_gear_count} -a ${scalable_python26_app} -l ${rhlogin} -p ${password}" &&
    output=$(run_command "cp -r data/application ${scalable_python26_app}/wsgi/ && cd ${scalable_python26_app} && git add . && git commit -amt && git push && cd -") &&
    echo "${output}" &&
    echo "${output}" | grep -q 'Waiting for job to complete' &&
    print_gre_txt "Successfully grep 'Waiting for job to complete' in the above output" &&
    output=$(run_command "cd ${scalable_python26_app} && touch .openshift/markers/hot_deploy && git add . && git commit -amt && git push && cd -") &&
    echo "${output}" &&
    echo "${output}" | grep -q 'Waiting for job to complete' &&
    print_gre_txt "Successfully grep 'Waiting for job to complete' in the above output" || failed_app="${failed_app}${scalable_python26_app} "
fi

echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || include_item "${choice}" "scalable_python27_app"; then
    create_app ${scalable_python27_app} "python-2.7" ${rhlogin} ${password} '--scaling' &&
    min_gear_count=2 &&
    run_command "rhc cartridge scale -c python-2.7 --min ${min_gear_count} -a ${scalable_python27_app} -l ${rhlogin} -p ${password}" &&
    run_command "rhc app-configure -a ${scalable_python27_app} --no-auto-deploy --keep-deployments 3 -l ${rhlogin} -p ${password}" || failed_app="${failed_app}${scalable_python27_app} "
fi

echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || include_item "${choice}" "scalable_ruby18_app"; then
    create_app ${scalable_ruby18_app} "ruby-1.8" ${rhlogin} ${password} '--scaling' &&
    add_cart ${scalable_ruby18_app} "mysql" "${rhlogin}" "${password}" &&
    run_command "cp -r data/{config.ru,Gemfile} ${scalable_ruby18_app}/ && cd ${scalable_ruby18_app} && bundle install && sed -i -e 's/#dbname/${scalable_ruby18_app}/g' config.ru -e 's/#user/${db_user}/g' config.ru -e 's/#passwd/${db_passwd}/g' config.ru && git add . && git commit -amt && git push && cd -" || failed_app="${failed_app}${scalable_ruby18_app}"
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || include_item "${choice}" "scalable_ruby19_app"; then
    create_app ${scalable_ruby19_app} "ruby-1.9" ${rhlogin} ${password} '--scaling' &&
    add_cart ${scalable_ruby19_app} "mysql" "${rhlogin}" "${password}" &&
    run_command "cd ${scalable_ruby19_app} && git remote add upstream -m master git://github.com/openshift/rails-example.git && git pull -s recursive -X theirs upstream master && git push && cd -" || failed_app="${failed_app}${scalable_ruby19_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || include_item "${choice}" "scalable_nodejs010_app"; then
    create_app ${scalable_nodejs010_app} "nodejs-0.10" ${rhlogin} ${password} '--scaling' &&
    min_gear_count=2 &&
    run_command "rhc cartridge scale -c nodejs-0.10 --min ${min_gear_count} -a ${scalable_nodejs010_app} -l ${rhlogin} -p ${password}" &&
    run_command "cp -rf data/post_start ${scalable_nodejs010_app}/.openshift/action_hooks/post_start_nodejs-0.10 && cd ${scalable_nodejs010_app} && git add . && git commit -amt && git push && cd -" || failed_app="${failed_app}${scalable_nodejs010_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || include_item "${choice}" "scalable_jbossews10_app"; then
    create_app ${scalable_jbossews10_app} "jbossews-1.0" ${rhlogin} ${password} '--scaling' &&
    add_cart ${scalable_jbossews10_app} "mysql" "${rhlogin}" "${password}" &&
    run_command "cp -rf data/mysql.jsp ${scalable_jbossews10_app}/src/main/webapp/ && mkdir -p ${scalable_jbossews10_app}/src/main/webapp/WEB-INF/lib && cp -rf data/mysql-connector-java-5.1.20-bin.jar ${scalable_jbossews10_app}/src/main/webapp/WEB-INF/lib && cd ${scalable_jbossews10_app} && git add . && git commit -amt && git push && cd -" || failed_app="${failed_app}${scalable_jbossews10_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || include_item "${choice}" "scalable_jbossews20_app"; then
    create_app ${scalable_jbossews20_app} "jbossews-2.0" ${rhlogin} ${password} '--scaling' || failed_app="${failed_app}${scalable_jbossews20_app} "
fi


echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || include_item "${choice}" "scalable_jbosseap_app"; then
    create_app ${scalable_jbosseap_app} "jbosseap" ${rhlogin} ${password} '--scaling' &&
    add_cart ${scalable_jbosseap_app} "postgresql-9.2" ${rhlogin} ${password} &&
    run_command "cp -rf data/test_psql.jsp ${scalable_jbosseap_app}/src/main/webapp/test.jsp && cd ${scalable_jbosseap_app} && git add . && git commit -a -mx && git push && cd -" || failed_app="${failed_app}${scalable_jbosseap_app} "

fi

echo '***********************************************' | tee -a ${log_file}
if [ X"$choice" == X"0" ] || include_item "${choice}" "scalable_jbosseap_app1"; then
    create_app ${scalable_jbosseap_app1} "jbosseap" ${rhlogin} ${password} '--scaling' &&
    add_cart ${scalable_jbosseap_app1} "jenkins-client" "${rhlogin}" "${password}" &&
    min_gear_count=2 &&
    run_command "rhc cartridge scale -c jbosseap-6 --min ${min_gear_count} -a ${scalable_jbosseap_app1} -l ${rhlogin} -p ${password}" &&
    run_command "rhc app-configure -a ${scalable_jbosseap_app1} --no-auto-deploy --keep-deployments 3 -l ${rhlogin} -p ${password}" || failed_app="${failed_app}${scalable_jbosseap_app1} "
fi

echo '***********************************************' | tee -a ${log_file}


echo "Failed app list:"
print_red_txt "${failed_app}"

# Save user info into file
#echo "Saving user info for ${domain}"
#rhc domain show -l ${rhlogin} -p ${password} | tee ${user_info_file}

