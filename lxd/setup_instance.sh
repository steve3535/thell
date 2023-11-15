get_bridge_subnet() {
  # Get the name of the default LXD bridge (usually lxdbr0)
  bridge_name=$(lxc network list | grep YES | awk '{print $2}')
  # Extract the IPv4 address range
  ip_range=$(lxc network show $bridge_name | grep -oP 'ipv4\.address: \K\S+')
  ip_subnet=$(echo $ip_range | cut -d"." -f1-3)
}

gen_ip() {
# Generate random static IP address
last_octet=$(($RANDOM%200 +2))
ip="$ip_subnet.$last_octet"
for i in $(lxc ls -c 4 | grep -oP "10\S+");do
        if [ "$ip" == "$i" ];then
                echo "Conflict !"
                gen_ip
        fi
done
}

gen_clusterid() {
	clusterid="k8s-$(tr -dc 'a-z' </dev/urandom | head -c 3)-C$(tr -dc '0-9' </dev/urandom | head -c 2)"

}

get_bridge_subnet

#Launch instance with ad-hoc netconf
create_vm() {
VMNAME="$2"
IP="$3"
NETCONF="$4"
USERCONF="$5"
#Generate netconf
ansible-playbook vm_settings.play.yaml -e ipaddr="$IP" -e netconf_file="$NETCONF" -e userconf_file="$USERCONF"
lxc launch u2310ctrd $VMNAME --config=user.network-config="$(cat $NETCONF)" --config=user.user-data="$(cat $USERCONF)"
rm -f $NETCONF $USERCONF
}

lxc_wait() {
while ! lxc exec "$1" -- true;do
  sleep 5
done
}


setup_cluster() 
{
	size=$2
	clusterid=$1
	if [ $size -ge 3 ];then
		gen_ip
        	create_vm $clusterid "$clusterid-master" $ip "netconf-$clusterid-master.yaml" "userconf-$clusterid-master.yaml"
		#Shutdown
                echo "Shutdown ..."
                while ! lxc exec "$clusterid-master" -- true;do
                  sleep 5
                done
                lxc exec "$clusterid-master" -- cloud-init status --wait
                lxc stop "$clusterid-master" --timeout 5
                #Set limits
                echo "Raise limits for control plane ..."
                lxc config set "$clusterid-master" limits.cpu=2
                lxc config set "$clusterid-master" limits.memory=3GiB
                lxc start "$clusterid-master"
                cluster=("$ip")

		gen_ip
		create_vm $clusterid "$clusterid-node1" $ip "netconf-$clusterid-node1.yaml" "userconf-$clusterid-node1.yaml"
		cluster+=("$ip")
		gen_ip
		create_vm $clusterid "$clusterid-node2" $ip "netconf-$clusterid-node2.yaml" "userconf-$clusterid-node2.yaml"
		cluster+=("$ip")

		echo "Init k8s ... :)"
                lxc_wait "$clusterid-master" && lxc_wait "$clusterid-node1" && lxc_wait "$clusterid-node2"
                (lxc exec "$clusterid-master" -- /opt/scripts/kubeadm_init.sh 2>&1 | tee -a logs/"$clusterid"-setup.log) && true
                echo "Checking init outcome .."
                tail -2 logs/"$clusterid"-setup.log | grep -oE ^"kubeadm join"
                if [ "$?" -ne 0 ];then
                        echo "something went wrong during kubeadm init ..."
                else
                        join_cmd=$(tail -2 logs/"$clusterid"-setup.log | tr -d '\r\t\n\\')
                        (lxc exec "$clusterid-master" -- /opt/scripts/calico.sh 2>&1 | tee -a logs/"$clusterid"-setup.log) && sleep 10
                        lxc exec "$clusterid-node1" -- bash -c "$join_cmd" 2>&1 | tee -a logs/"$clusterid"-setup.log
                        lxc exec "$clusterid-node2" -- bash -c "$join_cmd" 2>&1 | tee -a logs/"$clusterid"-setup.log
                fi

	else
		gen_ip
                create_vm $clusterid "$clusterid-master" $ip "netconf-$clusterid-master.yaml" "userconf-$clusterid-master.yaml"
		#Shutdown
                echo "Shutdown ..."
                lxc_wait "$clusterid-master"
                lxc exec "$clusterid-master" -- cloud-init status --wait
                lxc stop "$clusterid-master" --timeout 5
                #Set limits
                echo "Raise limits for control plane ..."
                lxc config set "$clusterid-master" limits.cpu=2
                lxc config set "$clusterid-master" limits.memory=3GiB
		lxc start "$clusterid-master"

		cluster=("$ip")

                gen_ip
                create_vm $clusterid "$clusterid-node1" $ip "netconf-$clusterid-node1.yaml" "userconf-$clusterid-node1.yaml"
	        
		cluster+=("$ip")

		echo "Init k8s ... :)"
		lxc_wait "$clusterid-master" && lxc_wait "$clusterid-node1"
		(lxc exec "$clusterid-master" -- /opt/scripts/kubeadm_init.sh 2>&1 | tee -a logs/"$clusterid"-setup.log) && true 
		echo "Checking init outcome .."
		tail -2 logs/"$clusterid"-setup.log | grep -oE ^"kubeadm join"
		if [ "$?" -ne 0 ];then
			echo "something went wrong"
		else
			join_cmd=$(tail -2 logs/"$clusterid"-setup.log | tr -d '\r\t\n\\')
			(lxc exec "$clusterid-master" -- /opt/scripts/calico.sh 2>&1 | tee -a logs/"$clusterid"-setup.log) && sleep 10
			lxc exec "$clusterid-node1" -- bash -c "$join_cmd" 2>&1 | tee -a logs/"$clusterid"-setup.log
		fi

	fi

}

gen_clusterid
setup_cluster $clusterid $1
echo "cluster $clusterid provisioned -- ${cluster[*]}"
