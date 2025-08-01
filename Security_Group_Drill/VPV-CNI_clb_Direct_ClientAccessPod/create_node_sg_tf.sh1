read -p'[演练]输入集群标签的key值:' key 
read -p'[演练]输入集群标签的values值:' values
read -p'[演练]输入集群id:' cls_id
read -p'[演练]输入集群的子网id:' sub_net
sed -e "s/<key>/$key/g" -e "s/<values>/$values/g" -e "s/<cls-id>/$cls_id/g" -e "s/<sub-id>/$sub_net/g" node_sg.template > no_sg.tf       ##根据read输入内容生成terraform的tf文件 
