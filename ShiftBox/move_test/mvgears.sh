#!/bin/bash 
source app.conf

##RemoteExecute Command by Expect.
RemoteExecute() {
    # $1 username
    # $2 password
    # $3 hostname 
    # $4 remotecmd

templog=tmp/remotecm.log
savelog=tmp/remotecm-`date +"%F-%T"`.log

# Rename tempfile.
mv $templog $savelog

exec 3>&1
exec >$templog

# Check the argurment
if [ 4 -gt $# ] ; then
    echo " ERROR: Function: 'RemoteExecute $*i'; usage: 'RemoteExecute username password hostname remotecmd'"
    exec 1>&3 3>&-
    return 2
fi

echo "RemoteExecute: $*"

username=$1
password=$2
hostname=$3
shift 3
remotecmd=$@

sshhost="ssh $username@$hostname"
 
expect -c "
#    set timeout -1
    set match_max 65535
    spawn $sshhost

    expect {
        \"*yes/no)?\" {send \"yes\r\"; exp_continue} 
        \"* password:\" {send \"$password\r\"; exp_continue}
        \"root@\" {send \"$remotecmd \r exit\r\"; exp_continue}
    }
    "
exec 1>&3 3>&-
return 0
}

getApplist()
{
output=`rhc account`
echo ${output}
}

#check configure file
if [ -z $ConfUser -o -z $ConfUserPassword -o -z $ConfBrokerName ]; then
    echo "ERROR: Setup:Please set ConfUser,ConfUserPassword,ConfBrokerName in app.conf"
    exit 1
fi

#check rhc account
echo "INFO: Have your setup up your openshift account in this terminal(y/n)?"
read choice
if [ X"$choicei" != X"y" ]; then
   echo "ERROR: Please run 'rhc setup --server your server' at first!"
   exit 1
fi

#4#RemoteExecute "$ConfUser" "$ConfUserPassword" "$ConfBrokerName" "oo-mco ping"
#4#GBnodes=`cat tmp/remotecm.log |sed -n "s/time.*$//p"`
#4#node2=`echo ${GBnodes}|awk '{print $2}'`
#4#if [ -z $node2 ]; then
#4#echo "PrepareError: At least two nodes for Move testing"
#4#exit 1
#4#fi
#4#
#4#RemoteExecute "$ConfUser" "$ConfUserPassword" "$ConfBrokerName" "oo-admin-ctl-district"
#4#district=`cat tmp/remotecm.log|grep "No districts created yet"`
#4#if [ ! -z $district ]; then
#4#echo "PrepareError:No district avaible, please specify districts at first"
#4#exit 1
#4#fi

checkapps()
{
   appschoice=$*
   for singleapp in ${appschoice}; do
       fapp=$(eval echo $applist|sed -n /\ $singleapp\ /p)
       if [ X"$fappi" == X"" ]; then
          echo "ERROR: $singleapp doesn't in Openshift, please double check it\n"
          return 1
       fi
   done
return 0
}

applist=`rhc apps|grep '@ http'|awk '{print $1}'`

if [ $# -eq 0 ]; then
     while [ 1==1 ]
     do
          echo "INFO: All apps in server are list as below:"
          echo "$applist"
          echo "INFO: please specify apps to move \n a(all)|appnames(separated by space)|q(quit)"
          read choice
          if [ X"$choice" == X"a" ]; then
              app_list=$applist 
              break
          elif [ X"$choice" == X"q" ]; then
              exit 0
          else
              checkapps $choice
              echo $?
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
    outputsh=tmp/opt${app}.sh
    touch ${outputsh}
    echo "$output" | tee ${outputsh}
    for gear in ${output};do
        uuid=`echo $gear|awk -F"_" '{print $1}'`
        type=`echo $gear|awk -F"_" '{print $2}'`
        dns=`echo $gear|awk -F"@" '{print $2}'`
        echo "#type:${type}" | tee -a ${outputsh}
        echo "#Move Command:" | tee -a ${outputsh}
#       for node in ${GBnodes};do
#          if [ (issamenode ${dns} ${node}) -eq 0 ];then
#          {
#              break;
#          }
#
#       done
     mvcommand="oo-admin-move --gear_uuid $uuid"
     echo "$mvcommand" | tee -a ${outputsh}
     RemoteExecute "$ConfUser" "$ConfUserPassword" "$ConfBrokerName" "$mvcommand"
     echo "Result:" | tee -a $outputsh
     
     echo "Help Command:" | tee -a $outputsh
     echo "ssh ${uuid}@${dns}" | tee -a $outputsh
     done
done
