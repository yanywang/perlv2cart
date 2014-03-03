#!/bin/bash 
script_dir=$(dirname $0)
script_name=$(basename $0)
pushd $script_dir >/dev/null && script_real_dir=$(pwd) && popd >/dev/null
LIB_DIR="${script_real_dir}/../lib"

source ${LIB_DIR}/openshift.sh
source ${LIB_DIR}/util.sh
source app.conf

##########################
# Globle Variables
#Turn off Remote Execute 
#RemoteExec=0|1
RemoteExec=0
log_file=log/${script_name}-`date +"%F-%T"`.log
remotelog=tmp/remotecm.log

##RemoteExecute Command by Expect.
RemoteExecute() {
    # $1 username
    # $2 password
    # $3 hostname 
    # $4 remotecmd


if [ $RemoteExec == 1 ]; then
    print_warnning "Function: the Remote Execution is disabled, please execute the command below manualy"
    print_info "$remotecmd"
    print_info "Have your executed the command above(y|n)? "
    read choice

    if [ X"$choice" != X"y" ]; then
        print_info " please execute the command later, you can find it in $Outputsh " 
    fi
    
    return 0
fi


# Check the argurment
if [ 4 -gt $# ] ; then
    print_error " ERROR: Function: 'RemoteExecute $*i'; usage: 'RemoteExecute username password hostname remotecmd'"
    return 2
fi

print_info "RemoteExecute: $*"

username=$1
password=$2
hostname=$3
shift 3
remotecmd=$@

remotelogsave=${remotelog}-`date +"%F-%T"`.log
mv $remotelog $remotelogsave

sshhost="ssh $username@$hostname"
expect -c "
#    set match_max 65535
    log_file $remotelog
    spawn $sshhost

    expect {
        \"*yes/no)?\" {send \"yes\r\"; exp_continue} 
        \"* password:\" {send \"$password\r\"; exp_continue}
        \"root@\" {send \"$remotecmd \r exit\r\"; exp_continue}
    }
    "
return 0
}

checkapps()
{
   appschoice=$*
   for singleapp in ${appschoice}; do
       flag=0
       for fapp in $applist; do
          
           if [ X"${fapp}" == X"${singleapp}" ]; then
                flag=1
                break 
           fi
        done  
        
        if [ $flag == 0 ]; then
           print_error "$singleapp doesn't in Openshift, please double check it\n"
           return 1 
        fi
   done
return 0
}
notsamenode 
{
   dsn=$1
   node=$2
   gears=$3
   
}
########################################
###             Main                 ###
########################################

#check configure file
if [ -z $ConfUser -o -z $ConfUserPassword -o -z $ConfBrokerName ]; then
    print_warning "Setup:Please set ConfUser,ConfUserPassword,ConfBrokerName in app.conf"
    exit 1
fi

#check rhc account
#temp#print_info " Have your setup up your openshift account in this terminal(y/n)?"
#temp#read choice
#temp#if [ X"$choicei" != X"y" ]; then
#temp#   print_warning "Please run 'rhc setup --server your server' at first!"
#temp#   exit 1
#temp#fi
#temp#
#temp#RemoteExecute "$ConfUser" "$ConfUserPassword" "$ConfBrokerName" "oo-mco ping"
#temp#GBnodes=`cat tmp/remotecm.log |sed -n "s/time.*$//p"`
#temp#node2=`echo ${GBnodes}|awk '{print $2}'`
#temp#if [ -z $node2 ]; then
#temp#    print_error "PrepareError: At least two nodes for Move testing"
#temp#exit 1
#temp#fi
#temp#
#temp#RemoteExecute "$ConfUser" "$ConfUserPassword" "$ConfBrokerName" "oo-admin-ctl-district"
#temp#district=`cat ${remotelog}|grep "No districts created yet"`
#temp#if [ ! -z $district ]; then
#temp#    print_error "PrepareError:No district avaible, please specify districts at first"
#temp#exit 1
#temp#fi


applist=`rhc apps|grep '@ http'|awk '{print $1}'|sed -e :a -e "N;s/\n/ /;ba"`

if [ $# -eq 0 ]; then
     while [ 1==1 ]
     do
          print_info "All apps in server are list as below:"
          print_gre_txt "$applist"
          print_info "please specify apps to move \n a(all)|appnames(separated by space)|q(quit)"
          read choice
          if [ X"$choice" == X"a" ]; then
              app_list=$applist 
              break
          elif [ X"$choice" == X"q" ]; then
              exit 0
          else
              checkapps $choice
              if [ $? == 0 ]; then
                   app_list=$choice
                   break
              fi
          fi
     done
else
    checkapps $*
    if [ $? == 1 ]; then
        exit 1
    fi
    app_list="$*"
fi

if [ ! -d tmp ]; then
    mkdir tmp 
fi

for app in ${app_list}; do
    output=`rhc app show ${app} --gears|awk 'NR>2{print $1"_"$3"_"$5"_"$6}'`
    print_gre_txt "$output" 
    for gear in ${output};do
        uuid=`echo $gear|awk -F"_" '{print $1}'`
        type=`echo $gear|awk -F"_" '{print $2}'`
        dns=`echo $gear|awk -F"@" '{print $2}'`
        print_blu_txt "#type:${type}"
        print_blu_txt "#Move Command:" 
        targetnode=""
       gbNodes="nd216.oseanli.cn nd217.oseanli.cn"
       for node in ${gbNodes};do
       if [ (notsamenode ${dns} ${node} ${gears}) -eq 0 ];then
       {
             targetnode="$node"
             break;
       }
       done

     mvcommand="oo-admin-move --gear_uuid $uuidi -i $targetnode"
     print_blu_txt "$mvcommand" 
     RemoteExecute "$ConfUser" "$ConfUserPassword" "$ConfBrokerName" "$mvcommand"
     print_blu_txt "Result:" 
     cat ${remotelog} | print_gre_txt -a $log_file
     print_blu_txt "Help Command:" 
     print_gre_txt "ssh ${uuid}@${dns}"
     done
done
