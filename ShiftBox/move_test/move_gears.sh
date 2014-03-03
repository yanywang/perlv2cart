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
#RemoteExec=0|1|2
RemoteExec=2
log_file=log/${script_name}-`date +"%F-%T"`.log
remotelog=tmp/remotecm.log

##RemoteExecute Command by Expect.
RemoteExecute() {
    # $1 username
    # $2 password
    # $3 hostname 
    # $4 remotecmd

# Check the argurment
if [ 4 -gt $# ] ; then
    print_error " ERROR: Function: 'usage: 'RemoteExecute username password hostname remotecmd'"
    return 2
fi

username=$1
password=$2
hostname=$3
shift 3
remotecmd=$@


print_info "RemoteExecute: $remotecmd"

if [ $RemoteExec == 2 ]; then
   return 0
elif [ $RemoteExec == 1 ]; then
    print_warnning "Function: the Remote Execution is disabled, please execute the command below manualy"
    print_info "Have your executed the command above(y|n)? "
    read choice

    if [ X"$choice" != X"y" ]; then
        print_info " please execute the command later, you can find it in $log_file " 
    fi
    
    return 0
fi


remotelogsave=${remotelog}-`date +"%F-%T"`.log
mv $remotelog $remotelogsave

sshhost="ssh $username@$hostname"
expect -c "
   set timeout 120
#  set match_max 65535
    log_file $remotelog
    spawn $sshhost

    expect {
        \"*yes/no)?\" {send \"yes\r\"; exp_continue} 
        \"* password:\" {send \"$password\r\"; exp_continue}
        \"root@\" {send \"$remotecmd \r exit\r\"; exp_continue}
    }
    "
print_blu_txt "Result:" 
cat ${remotelog} | print_gre_txt $log_file

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

issamenode()
{
   dns=$1
   node=$2

   gearip=$(eval ping $dns -c  2|sed '1{s/[^(]*(//;s/).*//;q}')
   nodeip=$(eval ping $node -c 2|sed '1{s/[^(]*(//;s/).*//;q}')

   if [ X"$gearip" == X"$nodeip" ]; then
      return 0
   fi
   return 1
}

########################################
###             Main                 ###
########################################

#check configure file

if [ -z $rhlogin -o -z $domain -o -z $password ]; then
    echo "ERROR:Setup:Please set rhlogin,domain and password in app.conf"
    exit 1
fi


if [ -z $ConfUser -o -z $ConfUserPassword -o -z $ConfBrokerName ]; then
    print_warning "Setup:Please set ConfUser,ConfUserPassword,ConfBrokerName and  ConfNodes in app.conf"
    exit 1
fi

gbNodes=(${ConfNodes})
if [ -z ${gbNodes[1]} ]; then
    print_error "PrepareError: At least two nodes for Move testing"
 exit 1
fi

#check rhc account
#tag# print_info " Have your setup up your openshift account in this terminal(y/n)?"
#tag# read choice
#tag# if [ X"$choicei" != X"y" ]; then
#tag#    print_warning "Please run 'rhc setup --server your server' at first!"
#tag#    exit 1
#tag# fi
#tag# 
#tag# RemoteExecute "$ConfUser" "$ConfUserPassword" "$ConfBrokerName" "oo-mco ping"
#tag# GBnodes=`cat tmp/remotecm.log |sed -n "s/time.*$//p"`
#tag# node2=`echo ${GBnodes}|awk '{print $2}'`
#tag# if [ -z $node2 ]; then
#tag#     print_error "PrepareError: At least two nodes for Move testing"
#tag# exit 1
#tag# fi
#tag# 
#tag# RemoteExecute "$ConfUser" "$ConfUserPassword" "$ConfBrokerName" "oo-admin-ctl-district"
#tag# district=`cat ${remotelog}|grep "No districts created yet"`
#tag# if [ ! -z $district ]; then
#tag#     print_error "PrepareError:No district avaible, please specify districts at first"
#tag# exit 1
#tag# fi


applist=`rhc apps -l $rhlogin -p $password |grep '@ http'|awk '{print $1}'|sed -e :a -e "N;s/\n/ /;ba"`

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
              if checkapps $choice; then
                   app_list=$choice
                   break
              fi
          fi
     done
else
    if ! checkapps $* ; then
        exit 1
    fi
    app_list="$*"
fi

if [ ! -d tmp ]; then
    mkdir tmp 
fi

istep="1"
for app in ${app_list}; do
    output=`rhc app show ${app} --gears -l $rhlogin -p $password|awk 'NR>2 {print $0}'|sed 's/ /_/g'`
    print_blu_txt "\n\n${istep} Move gears for $app" 

    jstep="1"
    print_blu_txt "$output" 
    for gear in ${output};do
        uuid=`echo $gear|awk -F"_" '{print $1}'`
        type=`echo $gear|awk -F" " '{print $3}'`
        dns=`echo $gear|awk -F"@" '{print $2}'`
        targetnode=${gbNodes[0]}
        if issamenode ${dns} ${gbNodes[0]} ; then
             targetnode="${gbNodes[1]}"
        fi
        print_blu_txt "AppName:${app} CartType:${type} "
        print_blu_txt "\n${istep}.${jstep} Move gear $type:" 
        mvcommand="oo-admin-move --gear_uuid $uuid -i $targetnode"
        print_red_txt "$mvcommand" 
        RemoteExecute "$ConfUser" "$ConfUserPassword" "$ConfBrokerName" "$mvcommand"
        jstep=`expr $jstep + 1`
        print_blu_txt "Help Command:" 
        print_blu_txt "ssh ${uuid}@${dns}"
        print_blu_txt "http://${dns}"
        print_blu_txt "ssh root@${targetnode}"
        print_blu_txt "cd /var/lib/openshift/${uuid}"
        print_blu_txt "monogo openshift_broker -u openshift -p mongopass"
        print_blu_txt "db.applicationis.find(\"name:$app\")"
     done
     istep=`expr $istep + 1`
done
