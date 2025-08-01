# 概述
&emsp;安全组作为容器基础设施层的核心流量控制组件，通过节点边界实施粗粒度访问控制，为容器环境提供基础网络隔离保障。然而，用户常因安全组规则复杂性及配置方式不当导致服务不可访问，本文针对VPC-CNI 网络模式下TKE 集群中创建的两个原生节点里Pod 服务之间访问，通过引导用户分层逐步排查访问链路,最终掌握安全组配置的核心逻辑


# 访问链路
VPC-CNI下节点与pod跨节点访问:<br>
[<img width="497" height="267" alt="Clipboard_Screenshot_1753963102" src="https://github.com/user-attachments/assets/49851d3e-a6f9-4a00-8ba4-1331495e2179" />
](./image/flowchart2.md)
 <br>&emsp;在日常生产环境中可以通过在上述两处安全组位置设置规则来限制流量入站(一般对流量出站不做限制)，以此控制入口流量的基础过滤，实现流量的精细管控，保障Pod资源安全(pod辅助网卡处的安全组默认关闭可根据自己需求开启)

# 环境部署
## 前提条件
**1.tke集群要求**

TKE版本>=1.20.6
<br>详情可参考:https://cloud.tencent.com/document/product/457/103981<br>
网络模式:VPC-CNI<br>
详情可参考:https://cloud.tencent.com/document/product/457/50355

**2.工具准备**

配置好[terraform:v1.8.2](https://developer.hashicorp.com/terraform)
## 快速开始
**以terraform为例**<br>
 1.创建原生节点
```
[root@VM-35-139-tlinux terraform]# sh create_node_tf.sh 
[root@VM-35-139-tlinux terraform]# terraform apply -auto-approve
```
 2.创建deployment并将其绑定在指定原生节点上
```
[root@VM-35-139-tlinux terraform]# sh setup_deploy_yaml.sh
[root@VM-35-139-tlinux terraform]# kubectl apply -f deployment.yaml
```

# 演练分析
## 第一步:获取服务名与访问ip
```
[root@VM-35-139-tlinux terraform]# kubectl get pods -o wide -l app=my-app|awk '{printf "podname:"$1"\t""pod_ip:"$6"\n"}'|grep -v "NAME"|grep -v IP
podname:nginx-pod       pod_ip:10.0.35.23
```
## 第二步:获取未绑定服务的节点ip并登录
```
[root@VM-35-139-tlinux terraform]#IP1=`kubectl get nodes -l test11=test21 -o jsonpath='{.items[*].metadata.name}'|awk '{print $2}'
10.0.35.192
[root@VM-35-139-tlinux terraform]# ssh 10.0.35.192
[root@VM-35-192-tlinux ～] #
```
## 第三步:问题分析
### 若访问时出现以下现象(time out):
```
[root@VM-35-192-tlinux ~]# curl 10.0.35.23
curl: (28) Failed to connect to 10.0.35.23 port 80: Connection timed out
```
**排查方向:**<br>

出现这种情况可能为pod辅助网卡安全组被开启且安全组配置不正确,查看其绑定的安全组是否允许节点A访问podB服务端口如果未放通放通即可
```
[root@VM-35-192-tlinux ~]# kubectl logs -n kube-system deploy/tke-eni-ipamd | grep "Event"|grep "security groups from"|awk '{print $24}'|awk -F'[' '{print $2}'|awk -F']' '{print $1}'                            ##查询其所绑定的安全组
sg-xxxxxx            ##输出的为pod(辅助)网卡所绑定的安全组id
```

# 演练环境清理
```
[root@VM-35-179-tlinux ~]# kubectl delete  -f deploymeny.yaml
[root@VM-35-179-tlinux ~]# terraform destroy -auto-approve
```
# 项目结构
```
VPC-CNIr_NodeAccessPod/  
├── deployment.yaml      # 创建deployment并指定deployment绑定到对应节点上
├── create_node_tf.sh   #配置tf文件脚本
├── create_node.template      #创建节点
├── readme.md        #本文件
├── setup_deploy_yaml.sh  #为deployment指定节点
```


