#!/bin/bash
source "${LIB_DIR}/color.sh"

run_command() {
    local command="$1"
    echo -e "${BGre}Command:${RCol} ${command}" 2>&1 | tee -a ${log_file}
    #Method 1
    #output=$(eval "${command}" 2>&1)
    #ret=$?
    #echo -e "$output\n" | tee -a ${log_file}

    #Method 2
    #(eval "${command}"; echo "ret=$?" >/tmp/ret) 2>&1 | tee -a ${log_file}
    #source /tmp/ret
    #rm -rf /tmp/ret
    #echo ""

    #Method 3
    eval "${command}" 2>&1 | tee -a ${log_file}
    ret=${PIPESTATUS[0]}
    return $ret
}

print_gre_txt() {
    local msg="$1"
    echo -e "${BGre}${msg}${RCol}" 2>&1 | tee -a ${log_file}
    ret=${PIPESTATUS[0]}
    return $ret
}

print_red_txt(){
    local msg="$1"
    echo -e "${BRed}${msg}${RCol}" 2>&1 | tee -a ${log_file}
    ret=${PIPESTATUS[0]}
    return $ret
}

print_yel_txt(){
    local msg="$1"
    echo -e "${BYel}${msg}${RCol}" 2>&1 | tee -a ${log_file}
    ret=${PIPESTATUS[0]}
    return $ret
}

print_blu_txt(){
    local msg="$1"
    echo -e "${BBlu}${msg}${RCol}" 2>&1 | tee -a ${log_file}
    ret=${PIPESTATUS[0]}
    return $ret
}

print_info() {
    local msg="$1"
    print_gre_txt "INFO: ${msg}"
    return $?
}

print_error() {
    local msg="$1"
    print_red_txt "ERROR: ${msg}"
    return $?
}

print_warnning() {
    local msg="$1"
    print_blu_txt "WARNNING: ${msg}"
    return $?
}


initial_log() {
    local date=$(get_date)
    local file_name=$(basename $0 | awk -F. '{print $1}')
    local logfile="log/${file_name}.${date}.log"
    if [ ! -d log ]; then
        mkdir log
    fi
    > ${logfile}
    echo ${logfile}
}


ssh_config() {
    ssh_config_file="~/.ssh/config"
    cat <<EOF > $ssh_config
Host broker.*.com
    User root
    IdentityFile ~/.ssh/libra.pem

Host *.ose*.com
    IdentityFile ~/.ssh/id_rsa
    VerifyHostKeyDNS yes
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
}

include_item() {
    local items="$1"
    local test_str="$2"
    local i
    for i in ${items}; do 
        if [ X"${i}" == X"${test_str}" ]; then
            return 0
        fi
    done
    return 1
}
