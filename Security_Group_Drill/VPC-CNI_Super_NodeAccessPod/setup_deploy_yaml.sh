IP1=`kubectl get nodes -l lable1=value1 -o jsonpath='{.items[*].metadata.name}'
sed -i 's/<node_ip1>/$IP1/g' deployment.yaml
