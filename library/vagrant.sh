#!/bin/bash

####
## SYNTAX
##
## tasks:
## - vagrant: 
##     path={{ path_to_Vagrantfile }}    <- path to Vagrantfile or Dir with Vagrantfile
##     state={{ desired_state }}         <- running|started|stopped|poweroff|destroyed
##     # optional:
##     use_private_key=                  <- path to privatekey (can be used with root user connection)
##     add_root_key=                     <- path to private key which will be added to root's authorized_keys

## RETURNED Values:
# {
#     "changed": true,
#     "ip": "127.0.0.1",
#     "key": "PATH_TO_PRIVATE_SSH_KEY"
#     "memory": Memory_IN_MB,
#     "os_name": "OS_RELEASE_NAME",
#     "port": SSH_PORT,
#     "status": "DESIRED_VM_STATUS",
#     "synced_folders": {       
#         "virtualbox": {
#             ...
#         }
#     },
#     "user": "SSH_USER"
# }

function get_status(){
    # https://www.vagrantup.com/docs/cli/machine-readable.html
    vagrant status --machine-readable | awk -F, '$3~/state-human-short/{print $4}'
}

function make_started(){
    function get_vm_settings(){
        ip=$(vagrant ssh-config | grep HostName | awk '{print $2}')
        port=$(vagrant ssh-config | grep Port | awk '{print $2}')
        os_name=$(vagrant ssh -c "cat /etc/system-release" 2>/dev/null | sed 's/[^a-zA-Z 0-9.()]//g')
        memory=$(vagrant ssh -c "cat /proc/meminfo | grep MemTotal | awk '{print \$2}'" 2>/dev/null | sed 's/[^a-zA-Z 0-9.()]//g')
        
        if [ -n "${add_root_key}" ] && [ -f ${add_root_key/\~/$HOME} ] && [ -f ${use_private_key/\~/$HOME} ]; then
            key="${use_private_key/\~/$HOME}"
            user="root"
        else
            key="$(pwd)/.vagrant/machines/default/virtualbox/private_key"
            user="vagrant"
        fi

        echo '"ip": "'${ip}'", 
              "port": '${port}', 
              "os_name": "'${os_name}'", 
              "memory": '${memory}',
              "user": "'${user}'",
              "key": "'${key}'",
              "synced_folders": '$(cat $(pwd)/.vagrant/machines/default/virtualbox/synced_folders)''
    }

    case "$(get_status)" in
    "not created"|"poweroff")
        vagrant up > vagrant.log 2>&1
        if [ -n "${add_root_key}" ] && [ -f ${add_root_key/\~/$HOME} ]; then
            vagrant ssh -c "sudo mkdir -p /root/.ssh; sudo chmod 600 /root/.ssh" 2>/dev/null
            vagrant ssh -c "sudo bash -c 'echo $(cat ${add_root_key/\~/$HOME}) > /root/.ssh/authorized_keys'" 2>/dev/null
        fi
        if [ "$(get_status)" == "running" ]; then
            echo '{"changed": true, "status": "running", '$(get_vm_settings)'}'
        else
            echo '{"failed": true, "reason": "error during start", "log": "'$(pwd)'/vagrant.log"}'
        fi
        ;;
    "running")
        echo '{"changed": false, "status": "running", '$(get_vm_settings)'}'
        ;;
    esac
}

function make_stopped(){
    v_status="$(get_status)"
    case "${v_status}" in
    "poweroff")
        echo '{"changed": false, "status": "stopped"}'
        ;;
    "running")
        vagrant halt >vagrant.log 2>&1
        if [ "$(get_status)" == "poweroff" ]; then
            echo '{"changed": true, "status": "stopped"}'
        else
            echo '{"failed": true, "reason": "error during stop", "log": "'$(pwd)'/vagrant.log"}'
        fi
        ;;
    "not created")
        echo '{"failed": true, "reason": "${v_status}"}'
        ;;
    esac
}

function make_destroyed(){
    case "$(get_status)" in
    "running"|"poweroff")
        vagrant destroy -f >vagrant.log 2>&1
        if [ "$(get_status)" == "not created" ]; then
            echo '{"changed": true, "status": "not created", "destroyed": true}'
        else
            echo '{"failed": true, "reason": "error during destroy", "log": "'$(pwd)'/vagrant.log"}'
        fi
        ;;
    "not created")
        echo '{"changed": false, "status": "not created", "destroyed": false}'
        ;;
    esac
}

source $1

[ -z "$path" ] && echo '{"failed": true, "reason": "missing required parameter \"path\"}' && exit 1
[ -z "$state" ] && echo '{"failed": true, "reason": "missing required parameter \"state\"}' && exit 1

[ -d ${path} ] && path="${path}/Vagrantfile"

v_file="$path"
if [ -f "${v_file}" ]; then
    v_dir=$(cd $(dirname ${v_file}); pwd)
    cd ${v_dir}
    rm -f vagrant.log
else
    echo '{"failed": true, "reason": "Vagrantfile doesnt exist by path '${v_file}'"}'
    exit
fi

case "$state" in
    "started"|"running")
        make_started ;;
    "stopped"|"poweroff")
        make_stopped ;;
    "destroyed"|"not created")
        make_destroyed ;;
    "status")
        echo '{"changed": false, "status": "'$(get_status)'"}' ;;
    *)  echo '{"failed": true, "reason": "invalid state: '${state}'"}'
 esac