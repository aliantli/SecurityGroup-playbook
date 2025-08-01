CLB_ID=`terraform state show tencentcloud_security_group.mgmt_sg | grep id|head -1|awk -F'"' '{printf $2}'`  #获取安全组id
NODE_NAME=`kubectl get nodes -l test11=test21 -o jsonpath='{.items[*].metadata.name}'`    #获取创建节点名字
sed -i "s/<node_name>/$NODE_NAME/g" deployment.yaml  
sed -i "s/<sg-id>/$CLB_ID/g" addservice.yaml 
kubectl apply -f deployment.yaml
kubectl apply -f addservice.yaml
