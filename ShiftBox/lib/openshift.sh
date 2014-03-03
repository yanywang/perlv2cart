#!/bin/bash
source "${LIB_DIR}/util.sh"

function create_app() {
    local app_name="$1"
    local cart_name="$2"
    local rhlogin="$3"
    local passwd="$4"
    shift 4
    local options="${@}"

    echo "Creating ${cart_name} app - ${app_name} ..."
    command="rm -rf ${app_name} && rhc app create ${app_name} ${cart_name} -p ${passwd} -l ${rhlogin} ${options}"
    run_command "${command}"
    ret=$?
    if echo "${options}" | grep -q "no-git"; then
        ret=$ret
    else
        run_command "ls ${app_name}"
        ret=$?
    fi
    return $ret
}

function add_cart() {
    local app_name="$1"
    local cart_name="$2"
    local rhlogin="$3"
    local passwd="$4"
    shift 4
    local options="${@}"

    echo "Embedding ${cart_name} to ${app_name} app ..."
    command="rhc cartridge add ${cart_name} -a ${app_name} -l ${rhlogin} -p ${passwd} ${options}"
    run_command "${command}"
    return $?
}

function remove_cart() {
    local app_name="$1"
    local cart_name="$2"
    local rhlogin="$3"
    local passwd="$4"
    shift 4
    local options="${@}"

    echo "Removing ${cart_name} from ${app_name} app ..."
    command="rhc cartridge remove ${cart_name} -a ${app_name} -l ${rhlogin} -p ${passwd} ${options}"
    run_command "${command}"
    return $?
}

function control_app() {
    local app_name="$1"
    local rhlogin="$2"
    local passwd="$3"
    local action="$4"
    shift 4
    local options="${@}"

    echo "${action}ing ${app_name} app ..."
    command="rhc app ${action} ${app_name} -l ${rhlogin} -p ${passwd} ${options}"
    run_command "${command}"
    return $?
}


function destroy_app() {
    local app_name="$1"
    local rhlogin="$2"
    local passwd="$3"
    shift 3
    local options="${@}"

    echo "Destroying ${app_name} app ..."
    command="rhc app delete ${app_name} -l ${rhlogin} -p ${passwd} --confirm ${options}"
    run_command "${command}"
    return $?
}

function dump_app() {
    local app_name="$1"
    local rhlogin="$2"
    local passwd="$3"
    shift 3
    local options="${@}"

    echo "Threaddumping ${app_name} app ..."
    command="rhc threaddump ${app_name} -l ${rhlogin} -p ${passwd} ${options}"
    run_command "${command}"
    return $?
}

function tidy_app() {
    local app_name="$1"
    local rhlogin="$2"
    local passwd="$3"
    shift 3
    local options="${@}"

    echo "Tidying ${app_name} app ..."
    command="rhc app-tidy ${app_name} -l ${rhlogin} -p ${passwd} ${options}"
    run_command "${command}"
    return $?
}

function get_app_url() {
    local app_name="$1"
    local rhlogin="$2"
    local passwd="$3"
    shift 3
    local options="${@}"

    rhc app show -a ${app_name} -l ${rhlogin} -p ${passwd} ${options} | head -1 | awk '{print $3}'
}

function get_app_ssh_url() {
    local app_name="$1"
    local rhlogin="$2"
    local passwd="$3"
    shift 3
    local options="${@}"

    rhc app show -a ${app_name} -l ${rhlogin} -p ${passwd} ${options} | grep 'SSH:' | awk '{print $2}'
}


function get_gear_url() {
    local app_name="$1"
    local rhlogin="$2"
    local passwd="$3"
    local catridge_name="$4"

    for i in $(rhc app show -a ${app_name} --gears -l ${rhlogin} -p ${passwd} | grep '@' | grep "${catridge_name}" | awk -F'@' '{print $NF}'); do
        echo "http://${i}/"
    done
}


function get_gear_ssh_url() {
    local app_name="$1"
    local rhlogin="$2"
    local passwd="$3"
    local catridge_name="$4"

    rhc app show -a ${app_name} --gears -l ${rhlogin} -p ${passwd} | grep '@' | grep "${catridge_name}" | awk '{print $NF}'
}


function get_date() {
    local date=$(date +"%Y-%m-%d-%H-%M-%S")
    echo "$date"
}

function get_db_user() {
    local app_name="$1"
    local rhlogin="$2"
    local passwd="$3"

    rhc app show -a ${app_name} -l ${rhlogin} -p ${passwd} | grep  'Username:' | awk '{print $2}'
}

function get_db_passwd() {
    local app_name="$1"
    local rhlogin="$2"
    local passwd="$3"

    rhc app show -a ${app_name} -l ${rhlogin} -p ${passwd} | grep  'Password:' | awk '{print $2}'
}

function get_app_pid_list() {
    #set -x
    local app_name="$1"
    local rhlogin="$2"
    local passwd="$3"
    local pid_list="" ret=1 gear_ssh_url="" ssh_url="" pid_list=""

    gear_ssh_url=$(get_gear_ssh_url ${app_name} ${rhlogin} ${passwd})
    for ssh_url in ${gear_ssh_url}; do 
        pid_list="${pid_list}$(ssh ${ssh_url} 'pgrep -d " " -P 1') " || break
    done
    echo "${pid_list}"
    if [ X"$(echo "${pid_list}" | awk '{print NF}')" == X"0" ]; then
        ret=1
    else
        ret=0
    fi
    #set +x
    return $ret
}

function grep_string_from_web_gears() {
    #set -x
    local app_name="$1"
    local rhlogin="$2"
    local passwd="$3"
    local cartridge="$4"
    local expect_web_gear_count="$5"
    local expect_string="$6"
    local only_title="$7"
    local path="$8"
    local count=0 gear_url="" url="" cmd="" reg_string=""

    print_gre_txt "Trying to get gear url from output of 'rhc app show -a ${app_name} --gears'"
    gear_url=$(get_gear_url ${app_name} ${rhlogin} ${passwd} ${cartridge}) || return 1
    echo ${gear_url}
    if [ X"${only_title}" == X"Y" ]; then
        reg_string=" | grep 'title' | grep '${expect_string}'"
    else
        reg_string=" | grep '${expect_string}'"
    fi
    for url in ${gear_url}; do
        cmd="curl '${url}${path}' ${reg_string}"
        run_command "${cmd}" || return 1
        count=$(expr ${count} + 1)
    done
    run_command "test ${count} -eq ${expect_web_gear_count}" 
    ret=$?
    #set +x
    return $ret
}

function get_libra_server() {
    if [ -f ~/.openshift/express.conf ]; then
        local config_file="${HOME}/.openshift/express.conf"
        grep "^libra_server" $config_file | cut -d= -f2 | tr -d " " | tr -d "'"
    elif [ -f /etc/openshift/express.conf ]; then
        config_file='/etc/openshift/express.conf'
        grep "^libra_server" $config_file | cut -d= -f2 | tr -d " " | tr -d "'"
    else
        echo "No found express config file !!!"
        return 1
    fi
}

function rest_api_force_clean_domain() {
    local domain_name="$1"
    local rhlogin="$2"
    local passwd="$3"
    local command="curl -k -X DELETE -H 'Accept: application/xml' -d force=true --user ${rhlogin}:${passwd} https://$(get_libra_server)/broker/rest/domains/$domain_name"
    run_command "${command}"
}


function rest_api_app_event() {
    if [ $# -lt 5 ]; then
        echo "app_name event(add-alias|show-port|conceal-port|expose-port|scale-up|scale-down|make-ha)???"
        return 1
    fi

    local app="$1"
    local rhlogin="$2"
    local passwd="$3"
    local domain_name="$4"
    local data="-d event=$5"
    local command="curl -k -X POST -H 'Accept: application/xml' ${data} --user ${rhlogin}:${passwd}  https://$(get_libra_server)/broker/rest/domains/${domain_name}/applications/${app}/events"
    run_command "${command}"
}
