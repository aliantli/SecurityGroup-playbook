
# 概述
&emsp;安全组作为容器基础设施层的核心流量控制组件，通过节点边界实施粗粒度访问控制，为容器环境提供基础网络隔离保障。然而，用户常因安全组规则复杂性及配置方式不当导致服务不可访问，本文针对Global Router网络模式下TKE 集群中节点访问另一个原生节点里Pod 服务，通过引导用户分层逐步排查访问链路,最终掌握安全组配置的核心逻辑


# 访问链路
Global Router下节点与pod跨节点访问:<br>
[<img width="546" height="340" alt="Clipboard_Screenshot_1753962179" src="https://github.com/user-attachments/assets/583400f0-bc6b-431f-a0b3-9c3e414cfb10" />
](https://github.com/aliantli/SecurityGroup-playbook/blob/597e708731943d1b3e8b9a47e4f7429549c9364b/Security_Group_Drill/GlobalRouter_NodeAccessPod/image/flowchart2.md)
 <br>&emsp;在日常生产环境中可以通过在上述两处安全组位置设置规则来限制流量入站(一般对流量出站不做限制)，以此控制入口流量的基础过滤，实现流量的精细管控，保障Pod资源安全
# 环境部署
## 前提条件
**1.tke集群要求**

TKE版本>=1.20.6
<br>详情可参考:https://cloud.tencent.com/document/product/457/103981<br>
网络模式:GlobalRouter<br>
详情可参考:https://cloud.tencent.com/document/product/457/50355

**2.工具准备**

配置好[terraform:v1.8.2](https://developer.hashicorp.com/terraform)
## 快速开始
**以terraform为例**<br>
 1.创建原生节点和安全组并将安全组绑定到节点上
```
[root@VM-35-20-tlinux terraform]# sh create_node_sg_tf.sh 
[root@VM-35-20-tlinux terraform]# terraform apply -auto-approve
```
 2.创建deployment并将其绑定在指定原生节点上
```
[root@VM-35-20-tlinux terraform]# sh setup_deploy_yaml.sh
[root@VM-35-20-tlinux terraform]#kubectl apply -f deployment.yaml
```

# 演练分析
## 第一步:获取服务名与访问ip
```
[root@VM-35-20-tlinux terraform]# kubectl get pods -o wide -l app=my-app|awk '{printf "podname:"$1"\t""pod_ip:"$6"\n"}'|grep -v "NAME"|grep -v IP
podname:nginx-pod       pod_ip:172.17.0.131
```
## 第二步:获取未绑定服务的节点
```
[root@VM-35-139-tlinux terraform]#IP1=`kubectl get nodes -l test11=test21 -o jsonpath='{.items[*].metadata.name}'|awk '{print $2}'
10.0.35.192
[root@VM-35-139-tlinux terraform]# ssh 10.0.35.192
[root@VM-35-192-tlinux ～] #
```
## 第三步:问题分析
### 若访问时出现以下现象(time out):
```
[root@VM-35-20-tlinux terraform]# 172.17.0.131
curl: (28) Failed to connect to 172.17.0.131 port 80: Connection timed out
```
**排查方向:**<br>

节点层面：出现这种情况一般为节点组网卡安全组配置问题，前往节点所绑定的安全组，查看其是否允许节点A访问访问端口，如果未放通放通即可

# 演练环境清理
```
[root@VM-35-20-tlinux terraform]# kubectl delete  -f deployment.yaml
[root@VM-35-20-tlinux terraform]# terraform destroy -auto-approve
```
# 项目结构
```
GlobalRouter_NodeAccessPod/  
├── deployment.yaml      # 创建deployment并指定deployment绑定到对应节点上
├── create_node_sg_tf.sh   #配置tf文件脚本
├── create_node_sg.template      #创建节点和安全组并给节点绑定安全组
├── readme.md        #本文件
├── setup_deploy_yaml.sh  #为deployment指定节点
```


