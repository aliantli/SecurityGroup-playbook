# 概述
&emsp;安全组作为容器基础设施的核心流量管控组件，通过在节点边界实施粗粒度的访问控制策略，为容器环境提供基础网络隔离保障。然而，由于安全组规则配置的复杂性和操作不当，用户常面临服务不可访问的问题。本文针对VPC-CNI网络模式下TKE集群的原生节点与Pod间通信场景，通过分层递进的排查方法，系统梳理访问链路中的关键控制点，帮助用户掌握安全组配置的核心逻辑与最佳实践。


# 访问链路
VPC-CNI下节点与pod跨节点访问:<br>
[<img width="497" height="267" alt="Clipboard_Screenshot_1753963102" src="https://github.com/user-attachments/assets/49851d3e-a6f9-4a00-8ba4-1331495e2179" />
](./image/flowchart2.md)
<br>安全组1:作为节点A的出站流量"守门人"，控制该节点对外发起的访问<br>
安全组2:作为Pod的"可选防护盾"，精细化管控入站流量<br>
# 环境部署
## 前提条件
**1.tke集群要求**

TKE版本>=1.20.6,具体操作可参考:https://cloud.tencent.com/document/product/457/103981<br>
网络模式:VPC-CNI,详情可参考:https://cloud.tencent.com/document/product/457/50355

**2.工具准备**

安装[terraform:v1.8.2](https://developer.hashicorp.com/terraform)
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
## 第一步:获取podB的访问ip
```
[root@VM-35-139-tlinux terraform]# kubectl get pods -o wide -l app=my-app|awk '{printf "pod_ip:"$6}'|grep -v IP
podname:nginx-pod       pod_ip:10.0.35.23
```
## 第二步:获取节点A的ip并登录节点A去访问podB
```
[root@VM-35-139-tlinux terraform]#IP1=`kubectl get nodes -l test11=test21 -o jsonpath='{.items[*].metadata.name}'|awk '{print $2}'
10.0.35.192
[root@VM-35-139-tlinux terraform]# ssh 10.0.35.192
[root@VM-35-192-tlinux ～] #curl 10.0.35.23
```
## 第三步:问题分析
### 若访问podB时出现以下现象(time out):
```
[root@VM-35-192-tlinux ~]# curl 10.0.35.23
curl: (28) Failed to connect to 10.0.35.23 port 80: Connection timed out
```
**排查方向:**<br>
出现timeout报错可能是开启了podB辅助网卡的安全组，但是该安全组的配置有错误，查看该安全组配置，看其是否允许节点A的ip访问podB的服务端口，如果设置为不允许节点A访问，将其修改为允许即可

```
[root@VM-35-192-tlinux ~]# kubectl logs -n kube-system deploy/tke-eni-ipamd | grep "Event"|grep "security groups from"|awk '{print $24}'|awk -F'[' '{print $2}'|awk -F']' '{print $1}'                            ##查询podB所绑定的安全组
sg-xxxxxx            ##输出的为podB辅助网卡所绑定的安全组id
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


