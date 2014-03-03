#!/bin/bash

script_dir=$(dirname $0)
script_name=$(basename $0)
pushd $script_dir >/dev/null && script_real_dir=$(pwd) && popd >/dev/null
LIB_DIR="${script_real_dir}/../lib"

source ${LIB_DIR}/openshift.sh
source ${LIB_DIR}/util.sh

function php_app_check() {
    # $1: app_name
    # $2: rhlogin
    # $3: password
    # $4: test string before change
    # $5: test string after change

    local app_url="" last_date_line="" new_date_line=""
    app_url=$(get_app_url ${1} ${2} ${3}) || return 1
    # Test existing data
    run_command "curl ${app_url} | grep 'title' | grep '${4}'" || return 1
    # Test git push
    run_command "cd ${1} && sed -i '/title/s/${4}/${5}/g' php/index.php && git commit -a -m'modify title' && git push && cd -" || return 1
    # Test new data
    run_command "curl ${app_url} | grep 'title' | grep '${5}'" || return 1
    # Test cron
    run_command "sleep 60" &&
    run_command "curl -f ${app_url}date.txt" &&
    last_date_line=$(curl "${app_url}date.txt" | wc -l) &&
    run_command "sleep 60" &&
    new_date_line=$(curl "${app_url}date.txt" | wc -l) &&
    run_command "test ${new_date_line} -gt ${last_date_line}" &&
    print_warnning "Remember to ssh into app to check psql connection!!!" || return 1
}

function perl_app_check() {
    # $1: app_name
    # $2: rhlogin
    # $3: password
    # $4: test string before change
    # $5: test string after change
    # $6: action

    local app_url=""
    app_url=$(get_app_url ${1} ${2} ${3}) || return 1
    # Test idle status and existing data
    if [ X"${6}" == X"modify" ]; then
        run_command "test 1 -eq $(rhc app show -a ${1} -l ${2} -p ${3} --state | grep 'idle' | wc -l)" &&
        run_command "curl -f '${app_url}'" &&
        run_command "sleep 30" &&
        run_command "test 1 -eq $(rhc app show -a ${1} -l ${2} -p ${3} --state | grep 'started' | wc -l)" &&
        run_command "curl '${app_url}test.pl?action=show' | grep 'speaker${4}'" || return 1
    fi
    # Test git push
    run_command "cd ${1} && sed -i '/title/s/${4}/${5}/g' perl/index.pl && git commit -a -m'modify title' && git push && cd -" || return 1
    # Test mysql connection
    run_command "curl -f ${app_url}test.pl?action=${6}" || return 1
    # Test new data
    run_command "curl ${app_url} | grep 'title' | grep '${5}'" &&
    run_command "curl ${app_url}test.pl?action=show | grep 'speaker${5}'" || return 1
}

function python26_app_check() {
    # $1: app_name
    # $2: rhlogin
    # $3: password

    local app_url=""
    app_url=$(get_app_url ${1} ${2} ${3}) || return 1
    # Test quick-start app
    run_command "curl ${app_url}account/login/?next_page=/dashboard/ | grep -i 'review board'" || return 1
}

function python27_app_check() {
    # $1: app_name
    # $2: rhlogin
    # $3: password

    local app_url=""
    app_url=$(get_app_url ${1} ${2} ${3}) || return 1
    # Test quick-start app
    run_command "curl ${app_url} | grep -i 'Yeah Django'" || return 1
}

function ruby18_app_check() {
    # $1: app_name
    # $2: rhlogin
    # $3: password
    # $4: alias string

    local app_url=""
    app_url=$(get_app_url ${1} ${2} ${3}) || return 1
    # Test quick-start app
    run_command "curl ${app_url} | grep -i 'redmine'" || return 1
    # Test alias
    run_command "curl -H 'Host: ${4}' ${app_url} | grep -i 'redmine'" || return 1
}

function ruby19_app_check() {
    # $1: app_name
    # $2: rhlogin
    # $3: password
    # $4: test string before change
    # $5: test string after change

    local app_url="" app_ssh_url="" output="" target_file=""
    app_url=$(get_app_url ${1} ${2} ${3}) &&
    app_ssh_url=$(get_app_ssh_url ${1} ${2} ${3}) || return 1
    # Test existing data
    run_command "curl ${app_url} | grep 'title' | grep '${4}'" || return 1
    # Test git push
    run_command "cd ${1} && sed -i '/title/s/${4}/${5}/g' config.ru && git commit -a -m'modify title' && git push && cd -" || return 1
    # Test new data
    run_command "curl ${app_url} | grep 'title' | grep '${5}'" || return 1
    # Test threaddump
    output=$(dump_app ${1} ${2} ${3}) &&
    echo "${output}" &&
    target_file=$(echo ${output} | awk -F'-f' '{print $2}' | awk '{print $1}' | tr -d [:blank:]) &&
    run_command "ssh ${app_ssh_url} 'cat ${target_file} | grep SignalException'" &&
    print_warnning "Take note of the count of lines to compare with next check!!!" &&
    run_command "curl ${app_url} | grep 'title' | grep '${5}'" || return 1 
}

function nodejs010_app_check() {
    # $1: app_name
    # $2: rhlogin
    # $3: password

    local app_url="" ssh_app_url="" output="" gear_app_url="" count=0
    app_url=$(get_app_url ${1} ${2} ${3}) &&
    app_url_hostname=$(echo "${app_url}" | awk -F"/" '{print $3}') || return 1
    # Test websocket
    output="websocket.output"
    cmd="rm -rf ${output} && node data/client.js ws://${app_url_hostname}:8000/ &> ${output}"
    for i in {1..2}; do 
        print_gre_txt "${cmd}"
        eval "${cmd}" &
        run_command "sleep 10"
        run_command "pkill -u $UID -f 'node data/client.js'"  &&
        run_command "grep 'Received' ${output}" || return 1
    done
}

function jbossews10_app_check() {
    # $1: app_name
    # $2: rhlogin
    # $3: password
    # $4: test string before change
    # $5: test string after change

    local app_url="" ssh_app_url="" output="" old_git_size="" new_git_size=""
    app_url=$(get_app_url ${1} ${2} ${3}) &&
    app_ssh_url=$(get_app_ssh_url ${1} ${2} ${3}) || return 1
    # Test existing data
    run_command "curl ${app_url} | grep 'title' | grep '${4}'" || return 1
    # Test git push
    run_command "cd ${1} && sed -i '/title/s/${4}/${5}/g' src/main/webapp/index.html && git commit -a -m'modify title' && git push && cd -" || return 1
    # Test new data
    run_command "curl ${app_url} | grep 'title' | grep '${5}'" || return 1
    # Test tidyup
    output=$(run_command "ssh ${app_ssh_url} 'du -sk ~/git/${1}.git'") &&
    echo "${output}" &&
    old_git_size=$(echo ${output} | awk '{print $(NF-1)}') &&
    run_command "ssh ${app_ssh_url} 'touch /tmp/${1}_test_file'" &&
    run_command "ssh ${app_ssh_url} 'test -f /tmp/${1}_test_file'" &&
    tidy_app ${1} ${2} ${3} &&
    output=$(run_command "ssh ${app_ssh_url} 'du -sk ~/git/${1}.git'") &&
    echo "${output}" &&
    new_git_size=$(echo ${output} | awk '{print $(NF-1)}') &&
    run_command "test ${old_git_size} -gt ${new_git_size}" &&
    run_command "ssh ${app_ssh_url} '! test -f /tmp/${1}_test_file'" || return 1 
}

function jbossews20_app_check() {
    # $1: app_name
    # $2: rhlogin
    # $3: password
    # $4: test string before change
    # $5: test string after change

    local app_url="" old_pid_list="" new_pid_list=""
    app_url=$(get_app_url ${1} ${2} ${3}) || return 1
    # Test existing data
    run_command "curl ${app_url} | grep 'title' | grep '${4}'" || return 1
    if [ X"${5}" == X"2" ]; then
        run_command "curl '${app_url}mysql.jsp?action=show' | grep '${4} records'" || return 1
    fi
    # Test mysql connection
    run_command "curl -f '${app_url}mysql.jsp?action=insert&size=1'" || return 1
    run_command "curl '${app_url}mysql.jsp?action=show' | grep '${5} records'" &&
    # Test hot_deploy and git push
    print_gre_txt "Get pid list from all the gears of app" &&
    old_pid_list=$(get_app_pid_list ${1} ${2} ${3}) &&
    run_command "cd ${1} && sed -i '/title/s/${4}/${5}/g' src/main/webapp/index.html && git commit -a -m'modify title' && git push && cd -" &&
    print_gre_txt "Get pid list from all the gears of app" &&
    new_pid_list=$(get_app_pid_list ${1} ${2} ${3}) &&
    run_command "test '${old_pid_list}' == '${new_pid_list}'" || return 1
    # Test new data
    run_command "sleep 30"
    run_command "curl ${app_url} | grep 'title' | grep '${5}'" || return 1

}


function jbosseap_app_check() {
    # $1: app_name
    # $2: rhlogin
    # $3: password
    # $4: test string before change
    # $5: test string after change
    # $6: action

    local app_url="" output=""
    app_url=$(get_app_url ${1} ${2} ${3}) || return 1
    # Test existing data
    run_command "curl ${app_url} | grep 'title' | grep '${4}'" || return 1
    if [ X"${5}" == X"2" ]; then
        run_command "curl ${app_url}test.jsp?action=show | grep 'speaker${4}'" || return 1
    fi
    # Test mysql connection
    run_command "curl -f ${app_url}test.jsp?action=${6}" || return 1
    # Test jenkins build
    output=$(run_command "cd ${1} && sed -i '/title/s/${4}/${5}/g' src/main/webapp/index.html && git commit -a -m'modify title' && git push && cd -") &&
    echo "${output}" &&
    echo "${output}" | grep -q 'Waiting for job to complete' &&
    print_gre_txt "Successfully grep 'Waiting for job to complete' in the above output" || return 1
    # Test new data
    run_command "curl ${app_url} | grep 'title' | grep '${5}'" &&
    run_command "curl ${app_url}test.jsp?action=show | grep 'speaker${5}'" || return 1
}


function diy_app_check() {
    # $1: app_name
    # $2: rhlogin
    # $3: password

    local app_url=""
    app_url=$(get_app_url ${1} ${2} ${3}) || return 1
    # Test existing data
    run_command "curl ${app_url}version/ | grep '131final0'" || return 1
    # Test git push
    run_command "cd ${1} && touch test${RANDOM} && git add . && git commit -a -m'test' && git push && cd -" &&
    run_command "sleep 10"
    run_command "curl -f ${app_url}version/" &&
    run_command "curl ${app_url}version/ | grep '131final0'" || return 1
}


function scalable_php_app_check() {
    # $1: app_name
    # $2: rhlogin
    # $3: password
    # $4: min gear count

    local app_url=""
    app_url=$(get_app_url ${1} ${2} ${3}) || return 1
    # Test existing data and min setting
    grep_string_from_web_gears ${1} ${2} ${3} "php-5.3" ${4} 'mediawiki' '' 'index.php/Main_Page' &&
    print_warnning "Pls check ${app_url}haproxy-status page to make sure all web gears are listed there!!!" || return 1
}


function scalable_perl_app_check() {
    # $1: app_name
    # $2: rhlogin
    # $3: password
    # $4: test string before change
    # $5: test string after change
    # $6: action
    # $7: min gear count

    local app_url="" output=""
    app_url=$(get_app_url ${1} ${2} ${3}) || return 1
    # Test existing data and min setting
    grep_string_from_web_gears ${1} ${2} ${3} "perl-5.10" ${7} "${4}" 'Y' '' || return 1
    if [ X"${6}" == X"modify" ]; then
        grep_string_from_web_gears ${1} ${2} ${3} "perl-5.10" ${7} "speaker${4}" '' 'test.pl?action=show' || return 1
    fi
    # Test jenkins build
    output=$(run_command "cd ${1} && sed -i '/title/s/${4}/${5}/g' perl/index.pl && git commit -a -m'modify title' && git push && cd -") &&
    echo "${output}" &&
    echo "${output}" | grep -q 'Waiting for job to complete' &&
    print_gre_txt "Successfully grep 'Waiting for job to complete' in the above output" || return 1
    # Test mysql connection
    run_command "curl -f '${app_url}test.pl?action=${6}'" || return 1
    # Test new data and min setting
    grep_string_from_web_gears ${1} ${2} ${3} "perl-5.10" ${7} "${5}" 'Y' '' &&
    grep_string_from_web_gears ${1} ${2} ${3} "perl-5.10" ${7} "speaker${5}" '' 'test.pl?action=show' &&
    print_warnning "Pls check ${app_url}haproxy-status page to make sure all web gears are listed there!!!" || return 1
}


function scalable_python26_app_check() {
    # $1: app_name
    # $2: rhlogin
    # $3: password
    # $4: test string before change
    # $5: test string after change
    # $6: action
    # $7: min gear count

    local app_url="" output="" old_pid_list="" new_pid_list=""
    app_url=$(get_app_url ${1} ${2} ${3}) || return 1
    # Test existing data and min setting
    grep_string_from_web_gears ${1} ${2} ${3} "python-2.6" ${7} "${4}" 'Y' '' || return 1
    if [ X"${6}" == X"modify" ]; then
        grep_string_from_web_gears ${1} ${2} ${3} "python-2.6" ${7} "speaker${4}" '' 'show' || return 1
    fi
    # Test mysql connection
    run_command "curl -f '${app_url}${6}'" || return 1
    # Test hot_deploy marker and jenkins build
    echo ""
    print_gre_txt "Get pid list from all the gears of app" &&
    old_pid_list=$(get_app_pid_list ${1} ${2} ${3}) &&
    output=$(run_command "cd ${1} && sed -i '/title/s/${4}/${5}/g' wsgi/application && git commit -a -m'modify title' && git push && cd -") &&
    echo "${output}" &&
    echo "${output}" | grep -q 'Waiting for job to complete' &&
    print_gre_txt "Successfully grep 'Waiting for job to complete' in the above output" &&
    print_gre_txt "Get pid list from all the gears of app" &&
    new_pid_list=$(get_app_pid_list ${1} ${2} ${3}) &&
    run_command "test '${old_pid_list}' == '${new_pid_list}'" || return 1
    # Test new data and min setting
    grep_string_from_web_gears ${1} ${2} ${3} "python-2.6" ${7} "${5}" 'Y' '' || return 1
    grep_string_from_web_gears ${1} ${2} ${3} "python-2.6" ${7} "speaker${5}" '' 'show' || return 1
    print_warnning "Pls check ${app_url}haproxy-status page to make sure all web gears are listed there!!!" || return 1
}


function scalable_python27_app_check() {
    # $1: app_name
    # $2: rhlogin
    # $3: password
    # $4: test string before change
    # $5: test string after change
    # $6: min gear count

    local app_url="" output="" old_deployment_count="" ref_id="" deploy_id="" new_deployment_count="" last_deploy_id="" deployment_list_cmd=""
    deployment_list_cmd="rhc deployment list -a ${1} -l ${2} -p ${3}"
    app_url=$(get_app_url ${1} ${2} ${3}) || return 1
    # Test existing data and min setting
    grep_string_from_web_gears ${1} ${2} ${3} "python-2.7" ${6} "${4}" 'Y' '' || return 1
    # Test git push
    output=$(run_command "cd ${1} && sed -i '/title/s/${4}/${5}/g' wsgi/application && git commit -a -m'modify title' && git push && cd -") &&
    echo "${output}" &&
    ref_id=$(echo "${output}" | grep '\[master .*\]' | awk -F'master ' '{print $2}' | awk -F']' '{print $1}') &&
    print_gre_txt "ref id: ${ref_id}" || return 1
    # Test no-auto-deploy
    grep_string_from_web_gears ${1} ${2} ${3} "python-2.7" ${6} "${4}" 'Y' '' || return 1
    # Manual deploy
    print_gre_txt "Command: ${deployment_list_cmd}" &&
    output=$(eval "${deployment_list_cmd}") &&
    echo "${output}" &&
    old_deployment_count=$(echo "${output}" | wc -l) &&
    output=$(run_command "rhc app-deploy ${ref_id} -a ${1} -l ${2} -p ${3}") &&
    echo "${output}" &&
    deploy_id=$(echo "${output}" | grep 'Deployment id' | awk '{print $NF}') &&
    print_gre_txt "Deployment id: ${deploy_id}" &&
    grep_string_from_web_gears ${1} ${2} ${3} "python-2.7" ${6} "${5}" 'Y' '' || return 1
    # Test keep-deployments
    print_gre_txt "Command: ${deployment_list_cmd}" &&
    output=$(eval "${deployment_list_cmd}") &&
    echo "${output}" &&
    new_deployment_count=$(echo "${output}" | wc -l) &&
    run_command "rhc deployment list -a ${1} -l ${2} -p ${3} | grep ${deploy_id}" &&
    print_gre_txt "new deployment id is listed in the above output!!!" &&
    run_command "test ${new_deployment_count} -gt ${old_deployment_count}" &&
    print_gre_txt "this deployment is recorded." || return 1
    # Test roll back
    output=$(run_command "rhc deployment list -a ${1} -l ${2} -p ${3}") &&
    echo "${output}"
    last_deploy_id=$(echo "${output}" | grep -B 1 ${deploy_id} | head -n 1 | sed 's/.* deployment \(\w*\).*/\1/g') &&
    run_command "rhc deployment-activate ${last_deploy_id} -a ${1} -l ${2} -p ${3}" &&
    grep_string_from_web_gears ${1} ${2} ${3} "python-2.7" ${6} "${4}" 'Y' '' || return 1
    run_command "rhc deployment-activate ${deploy_id} -a ${1} -l ${2} -p ${3}" &&
    grep_string_from_web_gears ${1} ${2} ${3} "python-2.7" ${6} "${5}" 'Y' '' || return 1
    print_warnning "Pls check ${app_url}haproxy-status page to make sure all web gears are listed there!!!"
}

function scalable_ruby18_app_check() {
    # $1: app_name
    # $2: rhlogin
    # $3: password
    # $4: test string before change
    # $5: test string after change
    # $6: action

    local app_url=""
    app_url=$(get_app_url ${1} ${2} ${3}) || return 1
    # Test old app status and start app
    if [ X"${6}" == X"start" ]; then
        run_command "curl '${app_url}mysql?action=show' | grep '503'" &&
        run_command "test 2 -eq $(rhc app show -a ${1} -l ${2} -p ${3} --state | grep 'stopped' | wc -l)" &&
        control_app ${1} ${2} ${3} ${6} &&
        run_command "test 2 -eq $(rhc app show -a ${1} -l ${2} -p ${3} --state | grep 'started' | wc -l)" || return 1
    fi
    # Test existing data
    run_command "curl ${app_url} | grep '${4}'" || return 1
    if [ X"${5}" == X"2" ]; then
        run_command "curl '${app_url}mysql?action=show' | grep '1 records'" || return 1
    fi
    # Test git push
    run_command "cd ${1} && sed -i 's/${4}/${4}${5}/g' config.ru && git commit -a -m'modify title' && git push && cd -" || return 1
    # Test mysql connection
    run_command "curl -f '${app_url}mysql?action=insert&size=1'" || return 1
    # Test new data
    echo "" &&
    run_command "curl ${app_url} | grep '${4}${5}'" &&
    run_command "curl '${app_url}mysql?action=show' | grep '${5} records'" || return 1
    # Stop app
    if [ X"${6}" == X"stop" ]; then
        run_command "sleep 15" &&
        control_app ${1} ${2} ${3} ${6} &&
        run_command "curl ${app_url} | grep '503'" &&
        run_command "test 2 -eq $(rhc app show -a ${1} -l ${2} -p ${3} --state | grep 'stopped' | wc -l)" || return 1
    fi 
}

function scalable_ruby19_app_check() {
    # $1: app_name
    # $2: rhlogin
    # $3: password

    local app_url="" ssh_url="" output="" old_git_size="" new_git_size=""
    app_url=$(get_app_url ${1} ${2} ${3}) &&
    ssh_url=$(get_app_ssh_url ${1} ${2} ${3}) || return 1
    # Test quick-start app
    run_command "curl ${app_url} | grep -i 'rails'" || return 1
    # Test git push
    run_command "cd ${1} && touch test${RANDOM} && git add . && git commit -a -m'test' && git push && cd -" || return 1
    # Test tidy up
    output=$(run_command "ssh ${ssh_url} 'du -sk ~/git/${1}.git'") &&
    echo "${output}" &&
    old_git_size=$(echo ${output} | awk '{print $(NF-1)}') &&
    run_command "ssh ${ssh_url} 'touch /tmp/${1}_test_file'" &&
    run_command "ssh ${ssh_url} 'test -f /tmp/${1}_test_file'" &&
    tidy_app ${1} ${2} ${3} &&
    output=$(run_command "ssh ${ssh_url} 'du -sk ~/git/${1}.git'") &&
    echo "${output}" &&
    new_git_size=$(echo ${output} | awk '{print $(NF-1)}') &&
    run_command "test ${old_git_size} -gt ${new_git_size}" &&
    run_command "ssh ${ssh_url} '! test -f /tmp/${1}_test_file'"  || return 1
}


function scalable_nodejs010_app_check() {
    # $1: app_name
    # $2: rhlogin
    # $3: password
    # $4: test string before change
    # $5: test string after change
    # $6: min gear count
    # $7: scale-up/scale-down flag
    # $8: domain

    local app_url="" new_count=0 output=""
    app_url=$(get_app_url ${1} ${2} ${3}) || return 1
    # Test existing data and min setting
    grep_string_from_web_gears ${1} ${2} ${3} "nodejs-0.10" ${6} "${4}" 'Y' '' || return 1
    # Test git push and action_hook
    output=$(run_command "cd ${1} && sed -i '/title/s/${4}/${5}/g' index.html && git commit -a -m'modify title' && git push && cd -") &&
    echo "${output}" &&
    echo "${output}" | grep -q 'Testing Good' &&
    print_gre_txt "Successfully grep 'Testing Good' in the above output" || return 1
    # Test new data and min setting.
    grep_string_from_web_gears ${1} ${2} ${3} "nodejs-0.10" ${6} "${5}" 'Y' '' || return 1
    # Test scale-down
    if [ X"$7" == X"scale-down" ]; then
        new_count=$(expr ${6} - 1) &&
        run_command "rhc cartridge scale -c nodejs-0.10 --min ${new_count} -a ${1} -l ${2} -p ${3}" &&
        rest_api_app_event  ${1} ${2} ${3} ${8} "scale-down" &&
        grep_string_from_web_gears ${1} ${2} ${3} "nodejs-0.10" ${new_count} "${5}" 'Y' '' || return 1
    fi
    print_warnning "Pls check ${app_url}haproxy-status page to make sure all web gears are listed there!!!"
}


function scalable_jbossews10_app_check() {
    # $1: app_name
    # $2: rhlogin
    # $3: password
    # $4: test string before change
    # $5: test string after change

    local app_url=""
    app_url=$(get_app_url ${1} ${2} ${3}) || return 1
    # Test existing data
    run_command "curl ${app_url} | grep 'title' | grep '${4}'" || return 1
    if [ X"${5}" == X"2" ]; then
        run_command "curl '${app_url}mysql.jsp?action=show' | grep '${4} records'" || return 1
    fi
    # Test git push
    run_command "cd ${1} && sed -i '/title/s/${4}/${5}/g' src/main/webapp/index.html && git commit -a -m'modify title' && git push && cd -" || return 1
    # Test mysql connection
    run_command "curl -f '${app_url}mysql.jsp?action=insert&size=1'" || return 1
    # Test new data
    run_command "curl ${app_url} | grep 'title' | grep '${5}'" &&
    run_command "curl '${app_url}mysql.jsp?action=show' | grep '${5} records'" || return 1
}

function scalable_jbossews20_app_check() {
    # $1: app_name
    # $2: rhlogin
    # $3: password
    # $4: test string before change
    # $5: test string after change

    local app_url="" ssh_url="" output="" target_file=""
    app_url=$(get_app_url ${1} ${2} ${3}) &&
    ssh_url=$(get_app_ssh_url ${1} ${2} ${3}) || return 1
    # Test existing data
    run_command "curl ${app_url} | grep 'title' | grep '${4}'" || return 1
    # Test git push
    run_command "cd ${1} && sed -i '/title/s/${4}/${5}/g' src/main/webapp/index.html && git commit -a -m'modify title' && git push && cd -" || return 1
    # Test new data
    run_command "curl ${app_url} | grep 'title' | grep '${5}'" || return 1
    # Test threaddump
    output=$(dump_app ${1} ${2} ${3}) &&
    echo "${output}" &&
    target_file=$(echo ${output} | awk -F'-f' '{print $2}' | awk '{print $1}' | tr -d [:blank:]) &&
    run_command "ssh ${ssh_url} 'cat ${target_file} | grep PSPermGen'" &&
    print_warnning "Take note of the count of lines to compare with next check!!!" &&
    run_command "curl ${app_url} | grep 'title' | grep '${5}'" || return 1
}

function scalable_jbosseap_app_check() {
    # $1: app_name
    # $2: rhlogin
    # $3: password
    # $4: test string before change
    # $5: test string after change
    # $6: action
    # $7: scale-up/scale-down flag

    local app_url="" ssh_url="" output="" gear_url="" new_count=0
    app_url=$(get_app_url ${1} ${2} ${3}) &&
    ssh_url=$(get_app_ssh_url ${1} ${2} ${3}) || return 1
    # Test existing data
    run_command "curl ${app_url} | grep 'title' | grep '${4}'" || return 1
    if [ X"${5}" == X"2" ]; then
        run_command "curl ${app_url}test.jsp?action=show | grep 'speaker${4}'" || return 1
    fi
    # Test git push
    run_command "cd ${1} && sed -i '/title/s/${4}/${5}/g' src/main/webapp/index.html && git commit -a -m'modify title' && git push && cd -" || return 1
    # Test psql connecton
    run_command "curl -f '${app_url}test.jsp?action=${6}'" || return 1
    print_warnning "Remember to ssh into app to check psql connection!!!"
    # Test new data
    run_command "curl ${app_url} | grep 'title' | grep '${5}'" &&
    run_command "curl '${app_url}test.jsp?action=show' | grep 'speaker${5}'" || return 1
    # Test threaddump
    output=$(dump_app ${1} ${2} ${3}) &&
    echo "${output}" &&
    target_file=$(echo ${output} | awk -F'-f' '{print $2}' | awk '{print $1}' | tr -d [:blank:]) &&
    run_command "ssh ${ssh_url} 'cat ${target_file} | grep PSPermGen'" &&
    print_warnning "Take note of the count of lines to compare with next check!!!" || return 1
    # Test new data and min setting
    if [ X"$7" == X"scale-up" ]; then
        new_count=2 &&
        run_command "rhc cartridge scale -c jbosseap-6 --min ${new_count} -a ${1} -l ${2} -p ${3}" &&
        grep_string_from_web_gears ${1} ${2} ${3} "jbosseap-6" ${new_count} "${5}" 'Y' '' || return 1
        grep_string_from_web_gears ${1} ${2} ${3} "jbosseap-6" ${new_count} "speaker${5}" '' 'test.jsp?action=show' || return 1
        print_warnning "Pls check ${app_url}haproxy-status page to make sure all web gears are listed there!!!"
    fi
}

function scalable_jbosseap_app1_check() {
    # $1: app_name
    # $2: rhlogin
    # $3: password
    # $4: test string before change
    # $5: test string after change
    # $6: min gear count

    local app_url="" output="" old_deployment_count="" ref_id="" deploy_id="" new_deployment_count="" last_deploy_id="" deployment_list_cmd=""
    deployment_list_cmd="rhc deployment list -a ${1} -l ${2} -p ${3}" &&
    app_url=$(get_app_url ${1} ${2} ${3}) || return 1
    # Test existing data and min setting
    grep_string_from_web_gears ${1} ${2} ${3} "jbosseap-6" ${6} "${4}" 'Y' '' || return 1
    # Test git push
    output=$(run_command "cd ${1} && sed -i '/title/s/${4}/${5}/g' src/main/webapp/index.html && git commit -a -m'modify title' && git push && cd -") &&
    echo "${output}" &&
    ref_id=$(echo "${output}" | grep '\[master .*\]' | awk -F'master ' '{print $2}' | awk -F']' '{print $1}') &&
    print_gre_txt "ref id: ${ref_id}" || return 1
    # Test no-auto-deploy
    grep_string_from_web_gears ${1} ${2} ${3} "jbosseap-6" ${6} "${4}" 'Y' '' || return 1
    # Manual deploy and jenkins build
    print_gre_txt "Command: ${deployment_list_cmd}" &&
    output=$(eval "${deployment_list_cmd}") &&
    echo "${output}" &&
    old_deployment_count=$(echo "${output}" | wc -l) &&
    output=$(run_command "rhc app-deploy ${ref_id} -a ${1} -l ${2} -p ${3}") &&
    echo "${output}" &&
    echo "${output}" | grep -q 'Waiting for job to complete' &&
    echo "${output}" | grep -q 'New build has been deployed' &&
    print_gre_txt "Successfully grep 'Waiting for job to complete' and 'New build has been deployed' in the above output" &&
    grep_string_from_web_gears ${1} ${2} ${3} "jbosseap-6" ${6} "${5}" 'Y' '' || return 1
    # Test keep-deployments
    print_gre_txt "Command: ${deployment_list_cmd}" &&
    output=$(eval "${deployment_list_cmd}") &&
    echo "${output}" &&
    new_deployment_count=$(echo "${output}" | wc -l) &&
    run_command "test ${new_deployment_count} -gt ${old_deployment_count}" &&
    print_gre_txt "this deployment is recorded." || return 1
    # Test roll back
    output=$(run_command "rhc deployment list -a ${1} -l ${2} -p ${3}") &&
    echo "${output}" &&
    deploy_id=$(echo "${output}" | tail -n 1 | sed 's/.* deployment \(\w*\).*/\1/g') &&
    last_deploy_id=$(echo "${output}" | grep -B 1 ${deploy_id} | head -n 1 | sed 's/.* deployment \(\w*\).*/\1/g') &&
    run_command "rhc deployment-activate ${last_deploy_id} -a ${1} -l ${2} -p ${3}" &&
    run_command "sleep 30" &&
    grep_string_from_web_gears ${1} ${2} ${3} "jbosseap-6" ${6} "${4}" 'Y' '' || return 1
    run_command "rhc deployment-activate ${deploy_id} -a ${1} -l ${2} -p ${3}" &&
    run_command "sleep 30" &&
    grep_string_from_web_gears ${1} ${2} ${3} "jbosseap-6" ${6} "${5}" 'Y' '' || return 1
    print_warnning "Pls check ${app_url}haproxy-status page to make sure all web gears are listed there!!!"
}

function create_new_app_check() {
    # $1: app_name
    # $2: rhlogin
    # $3: password
    # $4: min gear count

    local app_url="" output="" i="" ret=1
    # Test app creation
    print_gre_txt "Create new scalable app to make sure env is upgraded successfully" &&
    create_app "${1}" "jbosseap-6" ${2} ${3} '--scaling' &&
    add_cart "${1}" "mysql-5.1" ${2} ${3} &&
    add_cart "${1}" "jenkins-client" ${2} ${3} &&
    run_command "rhc cartridge scale -c jbosseap-6 --min ${4} -a ${1} -l ${2} -p ${3}" || return 1
    # Get app url
    app_url=$(get_app_url ${1} ${2} ${3}) || return 1
    # Test jenkins build
    output=$(run_command "cp -rf data/test_mysql.jsp ${1}/src/main/webapp/test.jsp && cd ${1} && git add . && git commit -a -mx && git push && cd -") &&
    echo "${output}" &&
    echo "${output}" | grep -q 'Waiting for job to complete' &&
    print_gre_txt "Successfully grep 'Waiting for job to complete' in the above output" || return 1
    # Test mysql connection
    ret=1
    for i in {1..2}; do
        run_command "curl -f '${app_url}test.jsp?action=create'" && ret=0 && break
    done
    run_command "test 'X$ret' == 'X0'" || return 1
    # Test min gear setting
    grep_string_from_web_gears ${1} ${2} ${3} "jbosseap-6" ${4} "speaker1" '' 'test.jsp?action=show' || return 1
    # Test snapshot
    run_command "rhc snapshot-save ${1} -l ${2} -p ${3}" || return 1
    run_command "sleep 30" &&
    ret=1
    for i in {1..2}; do
        run_command "curl -f '${app_url}test.jsp?action=modify'" && ret=0 && break
    done
    run_command "test 'X$ret' == 'X0'" || return 1
    grep_string_from_web_gears ${1} ${2} ${3} "jbosseap-6" ${4} "speaker2" '' 'test.jsp?action=show' || return 1
    run_command "rhc snapshot-restore -a ${1} -f ${1}.tar.gz -l ${2} -p ${3}" || return 1
    run_command "sleep 30" &&
    grep_string_from_web_gears ${1} ${2} ${3} "jbosseap-6" ${4} "speaker1" '' 'test.jsp?action=show' || return 1
    print_warnning "Pls check ${app_url}haproxy-status page to make sure all web gears are listed there!!!"
}
