# 概述
&emsp;在容器化架构中，安全组作为核心网络管控组件，通过节点边界实施访问控制策略，为容器环境提供基础隔离保障。本文针对VPC-CNI网络模式下TKE集群中存在的典型通信场景——原生节点与超级节点内Pod间的访问异常问题，通过系统化的分层排查方法，帮助客户快速定位并解决因安全组配置不当导致的服务不可访问问题，同时掌握该特定场景下的最佳安全实践方案。


# 访问链路
VPC-CNI下原生节点A与超级节点B内pod跨节点访问:<br>
[<img width="654" height="321" alt="Clipboard_Screenshot_1754028901" src="https://github.com/user-attachments/assets/10a219d9-65cf-412d-b5c1-1d2cfab2cb79" />
](./image/flowchart.md)<br>
 安全组1:绑定在原生节点A上，控制原生节点A流量出站<br>
 安全组2:绑定在超级节点B内pod辅助网卡上，控制流量访问podB
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
## 第一步:获取podB访问ip
```
[root@VM-35-139-tlinux terraform]# kubectl get pods -o wide -l app=nginx-super|awk '{printf "podname:"$1"\t""pod_ip:"$6"\n"}'|grep -v "NAME"|grep -v IP
podname:nginx-pod       pod_ip:10.0.35.23
```
## 第二步:获取原生节点ip并登录原生节点访问podB
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
当返回timed-out时，常见原因是podB辅助网卡的安全组配置存在限制​。<br>
排查建议：
首先根据上面安全组继承规则查看podB具体使用的什么安全组，然后检查安全组规则，确认是否已放行节点A的IP​​对以下端口的访问：<br>
Pod 提供的服务端口​​（即容器内实际监听的端口）<br>
如果发现相关流量被拦截，请在安全组中添加对应的​入站规则​​，允许节点A的IP访问上述端口,到这里返回time-out问题通常可以解决


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


