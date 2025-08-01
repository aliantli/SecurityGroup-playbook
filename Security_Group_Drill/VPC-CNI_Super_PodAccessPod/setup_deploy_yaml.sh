IP1=`kubectl get nodes -l label1=value1 -o jsonpath='{.items[*].metadata.name}'|awk '{print $1}'`
IP2=`kubectl get nodes -l label2=value2 -o jsonpath='{.items[*].metadata.name}'|awk '{print $1}'`
sed -i 's/<node_ip1>/$IP1/g' pod.yaml
sed -i 's/<node_ip2>/$IP2/g' pod.yaml
