
# 概述
&emsp;在容器化架构中，安全组作为核心网络管控组件，通过节点边界实施访问控制策略，为容器环境提供基础隔离保障。本文针对VPC-CNI网络模式下TKE集群中存在的典型通信场景——不同超级节点内Pod与pod间的访问异常问题，通过系统化的分层排查方法，帮助客户快速定位并解决因安全组配置不当导致的服务不可访问问题，同时掌握该特定场景下的最佳安全实践方案。


# 访问链路
VPC-CNI超级节点下pod与pod跨节点访问:<br>
[<img width="602" height="368" alt="Clipboard_Screenshot_1753950301" src="https://github.com/user-attachments/assets/63dba215-1123-481c-9ba1-dcf0cb60316e" />
](./image/flowchart2.md)
 <br>安全组1:绑定在超级节点A内podA辅助网卡上上，控制podA流量出站<br>
 安全组2:绑定在超级节点B内podB辅助网卡上，控制流量访问podB
<br>**&emsp;安全组继承规则:**<br>
|场景|是否为工作负载绑定安全组|是否为节点绑定安全组|实际使用安全组|
|:--:|:--:|:--:|:--:|
|场景1|✓|✓|工作负载所绑定安全组|
|场景5||✓|节点所绑定安全组|
|场景6|||所在地域ddefault安全组|
# 环境部署
## 前提条件
**1.tke集群要求**

TKE版本>=1.20.6，具体操作可参考:https://cloud.tencent.com/document/product/457/103981<br>
网络模式:VPC-CNI，详情可参考:https://cloud.tencent.com/document/product/457/50355

**2.工具准备**

安装[terraform:v1.8.2](https://developer.hashicorp.com/terraform)
## 快速开始
**以terraform为例**<br>
 1.创建超级节点
```
[root@VM-35-139-tlinux terraform]# sh create_super_node_tf.sh 
[root@VM-35-139-tlinux terraform]# terraform apply -auto-approve
```
 2.创建两个deployment并将其分别绑定在超级节点A超级节点B上
```
[root@VM-35-139-tlinux terraform]# sh setup_deploy_yaml.sh
[root@VM-35-139-tlinux terraform]# kubectl apply -f deployment.yaml
```

# 演练分析
## 第一步:获取pod名称和访问ip并指导podA和podB
```
[root@VM-35-139-tlinux terraform]# kubectl get pods -o wide -l app=nginx-super1|awk '{printf "podA:"$1"\t""pod_ip:"$6"\n"}'|grep -v "NAME"|grep -v IP
podA:nginx-pod       pod_ip:10.0.35.23
[root@VM-35-139-tlinux terraform]# kubectl get pods -o wide -l app=nginx-super2|awk '{printf "podB:"$1"\t""pod_ip:"$6"\n"}'|grep -v "NAME"|grep -v IP
podB:nginx-pod2      pod_ip:10.0.35.150
```
## 第二步:登录podA并访问podB
```
[root@VM-35-139-tlinux terraform]# kubectl exec -it nginx-pod -- sh
#curl 10.0.35.150
```
## 第三步:问题分析
### 若访问时出现以下现象(time out):
```
# curl 10.0.35.150
curl: (28) Failed to connect to 10.0.35.150 port 80: Connection timed out
```
**排查方向:**<br>
当返回timed-out时，常见原因是podB辅助网卡绑定的安全组(安全组2)配置存在限制​。<br>
排查建议：
首先根据上面安全组继承规则查看podB具体使用的什么安全组，然后检查安全组规则，确认是否已放行podA的IP​​对以下端口的访问：<br>
Pod 提供的服务端口​​（即容器内实际监听的端口）<br>
如果发现相关流量被拦截，请在安全组中添加对应的​入站规则​​，允许podA的IP访问上述端口,到这里返回timed-out问题通常可以解决

# 演练环境清理
```
[root@VM-35-179-tlinux ~]# kubectl delete  -f deployment.yaml
[root@VM-35-179-tlinux ~]# terraform destroy -auto-approve
```
# 项目结构
```
VPC-CNIr_NodeAccessPod/  
├── deployment.yaml      # 创建deployment并指定deployment绑定到对应节点上
├── create_super_node_tf.sh   #配置tf文件脚本
├── create_super_node.template      #创建节点
├── readme.md        #本文件
├── setup_deploy_yaml.sh  #为deployment指定节点
```


