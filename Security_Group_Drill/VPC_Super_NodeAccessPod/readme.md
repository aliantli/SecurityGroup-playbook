# 概述
&emsp;安全组作为容器基础设施层的核心流量控制组件，通过节点边界实施粗粒度访问控制，为容器环境提供基础网络隔离保障。然而，用户常因安全组规则复杂性及配置方式不当导致服务不可访问，本文针对VPC-CNI 网络模式下TKE 集群中节点访问超级节点的Pod 服务，通过引导用户分层逐步排查访问链路,最终掌握安全组配置的核心逻辑


# 访问链路
VPC-CNI下原生节点A与超级节点B内pod跨节点访问:<br>
[<img width="500" height="297" alt="Clipboard_Screenshot_1753961751" src="https://github.com/user-attachments/assets/93f8d1fc-cd20-408d-9a7b-8af380fb9a8e" />
](https://github.com/aliantli/sg_playbook_1/blob/66d364b590e719358ba8d4bfec522e7a359016f9/playbook/VPC_Super_NodeAccessPod/image/flowchart2.md)
 <br>&emsp;在日常生产环境中可以通过在上述两处安全组位置设置规则来限制流量入站(一般对流量出站不做限制)，以此控制入口流量的基础过滤，实现流量的精细管控，保障Pod资源安全
<br>**&emsp;安全组继承规则:**<br>
|场景|是否为工作负载绑定安全组|是否为节点绑定安全组|实际使用安全组|
|:--:|:--:|:--:|:--:|
|场景1|✓|✓|工作负载所绑定安全组|
|场景5||✓|节点所绑定安全组|
|场景6|||所在地域ddefault安全组|
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
 1.创建原生节点A和超级节点B并为其绑定安全组
```
[root@VM-35-139-tlinux terraform]# sh create_node_tf.sh 
[root@VM-35-139-tlinux terraform]# terraform apply -auto-approve
```
 2.创建deployment并将其绑定在超级节点上
```
[root@VM-35-139-tlinux terraform]# sh setup_deploy_yaml.sh
[root@VM-35-139-tlinux terraform]# kubectl apply -f deployment.yaml
```

# 演练分析
## 第一步:获取pod服务访问ip
```
[root@VM-35-139-tlinux terraform]# kubectl get pods -o wide -l app=nginx-super|awk '{printf "podname:"$1"\t""pod_ip:"$6"\n"}'|grep -v "NAME"|grep -v IP|
podname:nginx-pod       pod_ip:10.0.35.23
```
## 第二步:获取原生节点ip并登录原生节点
```
[root@VM-35-139-tlinux terraform]#  kubectl get nodes -o wide -l test11=test21 |awk '{print $6}'|grep -v INTERNAL-IP
10.0.35.97
[root@VM-35-139-tlinux terraform]# ssh 10.0.35.97
[root@VM-35-97-tlinux ~]#

```
## 第二步:问题分析
### 若访问时出现以下现象(time out):
```
[root@VM-35-97-tlinux ~]# curl 10.0.35.23
curl: (28) Failed to connect to 10.0.35.23 port 80: Connection timed out
```
**排查方向:**<br>
出现这种情况可能为pod所绑定安全组配置不正确,可
根据上述安全组继承规则查看pod所绑定的安全组是否允许原生节点A访问podB服务端口
```
# 演练环境清理
```
[root@VM-35-179-tlinux ~]# kubectl delete  -f deployment.yaml
[root@VM-35-179-tlinux ~]# terraform destroy -auto-approve
```
# 项目结构
```
VPC-CNIr_NodeAccessPod/  
├──deployment.yaml      # 创建deployment并指定deployment绑定到对应节点上
├── create_node_tf.sh   #配置tf文件脚本
├── create_node.template      #创建节点
├── readme.md        #本文件
├── setup_deploy_yaml.sh  #为deployment指定节点
```


