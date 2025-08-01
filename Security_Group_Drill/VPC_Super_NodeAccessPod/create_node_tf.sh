read -p'[演练]输入集群id:' cls_id
read -p'[演练]输入集群的子网id:' sub_net
sed  -e "s/<cls-id>/$cls_id/g" -e "s/<sub-id>/$sub_net/g" create_super_node.template > node.tf        ##根据read输入内容生成terraform的tf文件 
