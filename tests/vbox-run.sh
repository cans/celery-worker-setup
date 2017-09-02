#!/bin/sh
basedir="$(cd `dirname ${0}` ; pwd)"
ECHO="/bin/echo"

VIRTUALBOX_BASE_VM_NAME="ansible-test-host"
VIRTUALBOX_BIN="/usr/bin/vboxmanage"
VIRTUALBOX_CLONE_SUFFIX="celeryw"
VIRTUALBOX_NET_IFACE="vboxnet0"

. "${basedir}/ansible-run.sh"

# Ensure VM serial number file exists
[ -f "${basedir}/serial" ] || { echo -n 0 > "${basedir}/serial" ; }

vm_ip () {
    ip_unset_value='No value set!'
    ip_address="${ip_unset_value}"
    while [ "${ip_unset_value}" = "${ip_address}" ]
    do
        ip_address="$(LANG=C vboxmanage guestproperty get "${1}" "/VirtualBox/GuestInfo/Net/0/V4/IP")"
        # "${ECHO}" "${ip_address}" >&2
        sleep 0.5
    done
    echo "${ip_address}" | cut -f 2 -d " "
}

vm_exists() {
    LANG=C vboxmanage list vms | grep "${VIRTUALBOX_BASE_VM_NAME}"
}

vm_has_snapshot() {
    LANG=C vboxmanage snapshot ${1} list --machinereadable | grep "SnapshotName=\"${2}\""
}

vm_state() {
    LANG=C vboxmanage showvminfo --machinereadable ansible-test-host-sshauthz-00000001 | sed -nre '/^VMState=/ s/(VMState="?)([^"]*)("?)/\2/ p'
}

vm_poweredoff() {
    [ "poweroff" = "$(vm_state)" ]
}

vm_state_running() {
    [ "running" = "$(vm_state)" ]
}

get_configured_iface() {
    LANG=C nmcli --mode multiline c show --active | grep -m 1 '^DEVICE:  *' | sed 's/^DEVICE:  *//'
}

run_in_vm() {
    serial="$(cat "${basedir}/serial")"
    serial="$(( $serial + 1 ))"
    vm_base="${VIRTUALBOX_BASE_VM_NAME:-ansible-test}"
    vm_snap="${vm_base}-snapshot"
    vm_clone="$(printf "${vm_base}-${VIRTUALBOX_CLONE_SUFFIX:-unknownrole}-%08d" "${serial}")"
    echo "VM to be cloned: ${vm_base} -> ${vm_clone}"
    if ! vm_has_snapshot "${vm_base}" "${vm_snap}"
    then
        vboxmanage snapshot "${vm_base}" take "${vm_snap}" --live --description "Clone for running tests" --uniquename Force
    fi
    vboxmanage clonevm "${vm_base}"  --name "${vm_clone}" --register --options link --snapshot "${vm_snap}"
    vboxmanage modifyvm  "${vm_clone}" --nic1 hostonly --hostonlyadapter1 "${VIRTUALBOX_NET_IFACE}"  # "$(get_configured_iface)"
    vboxmanage startvm "${vm_clone}" --type headless

    "${ECHO}" -ne "VM IP address: \033[u"
    while [ -z "${vm_ip_address}" ]
    do
        vm_ip_address="$(vm_ip "${vm_clone}")"
        "${ECHO}" -ne "\033[u\033[s${vm_ip_address:-?}"
    done

    "${ECHO}" -ne "\nRefresh SSH's known hosts cache ..."
    ssh-keygen -R "${vm_ip_address}" 2>/dev/null >&2
    rm -rf ~/.ssh/known_hosts.old
    ssh-keyscan -H "${vm_ip_address}" 2>/dev/null >> ~/.ssh/known_hosts
    "${ECHO}" "done."

    "${ECHO}" -ne "\nVM Status: \033[s"
    while [ -z "${vm_status}" ]
    do
        vm_status="$(ssh "admin@${vm_ip_address}" -- echo ready 2>/dev/null)"
        "${ECHO}" -ne "\033[u\033[s${vm_status:-?}"
    done
    "${ECHO}" -ne "\nGenerate inventory file ..."
    cat > "${basedir}/inventory.vbox" <<EOF
[servers]
${vm_ip_address}

EOF

    "${ECHO}" "done."

    parse_cli $@
    run_ansible $SCREENED_CLI
    success="${?}"

    vboxmanage controlvm "${vm_clone}" poweroff
    keepstateonfailure="false"
    if [ "${success}" == "0" -a "false" == "${keepstateonfailure}" ]
    then
        vboxmanage unregistervm "${vm_clone}" --delete
        vboxmanage snapshot "${vmbase}"
    fi
    echo -n "${serial}" > "${basedir}/serial"
}

if [ "0" != "${?}" ]
then
    exit 1
else
    run_in_vm
fi
