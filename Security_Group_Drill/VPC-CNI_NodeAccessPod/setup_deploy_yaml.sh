IP1=`kubectl get nodes -l test11=test21 -o jsonpath='{.items[*].metadata.name}'|awk '{print $1}'
sed -i 's/<node_ip1>/$IP1/g' deployment.yaml
