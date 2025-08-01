
# 概述
&emsp;安全组作为容器基础设施的核心网络管控组件，通过在节点边界实施访问控制策略，为容器环境提供基础隔离保障。在Global Router网络模式的TKE集群中，当节点需要访问其他原生节点内的Pod服务时，安全组配置的复杂性往往会导致访问异常。本文通过系统化的分层排查方法，从网络入口到目标节点再到Pod服务，逐步引导用户分析访问链路中的关键控制点，帮助客户深入理解安全组规则的核心逻辑，掌握节点与pod跨节点场景下的最佳配置实践，从而有效解决因配置不当导致的服务不可访问问题

# 访问链路
Global Router下节点与pod跨节点访问:<br>
[<img width="546" height="340" alt="Clipboard_Screenshot_1753962179" src="https://github.com/user-attachments/assets/583400f0-bc6b-431f-a0b3-9c3e414cfb10" />
](./image/flowchart2.md)
<br>
 安全组1:绑定在节点A上，控制节点A出站流量<br>
 安全组2:绑定在节点B的节点网卡上，控制访问节点B及Pod的流量
# 环境部署
## 前提条件
**1.tke集群要求**

TKE版本>=1.20.6，具体操作可参考:https://cloud.tencent.com/document/product/457/103981<br>
网络模式:GlobalRouter，详情可参考:https://cloud.tencent.com/document/product/457/50355

**2.工具准备**

安装[terraform:v1.8.2](https://developer.hashicorp.com/terraform)
## 快速开始
**以terraform为例**<br>
 1.创建安全组与原生节点A、B，并将安全组绑定到原生节点A、B上
```
[root@VM-35-20-tlinux terraform]# sh create_node_sg_tf.sh 
[root@VM-35-20-tlinux terraform]# terraform apply -auto-approve
```
 2.创建deployment并将其绑定在原生节点B上
```
[root@VM-35-20-tlinux terraform]# sh setup_deploy_yaml.sh
[root@VM-35-20-tlinux terraform]#kubectl apply -f deployment.yaml
```

# 演练分析
## 第一步:获取podB访问ip
```
[root@VM-35-20-tlinux terraform]# kubectl get pods -o wide -l app=my-app|awk '{printf "podname:"$1"\t""pod_ip:"$6"\n"}'|grep -v "NAME"|grep -v IP
podname:nginx-pod       pod_ip:172.17.0.131
```
## 第二步:获取原生节点A的ip并登录原生节点A
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
当返回time-out时，常见原因之一是​节点B所绑定的安全组(安全组2)配置存在限制​​。<br>
排查建议:<br>>
请检查该安全组规则，确认是否已放行节点A的IP​​对以下端口的访问：<br>
1.Pod提供的服务端口​​（即容器内实际监听的端口）<br>
如果发现相关流量被拦截,请在安全组中添加对应的​​入站规则​​,允许节点A的IP访问上述端口,到这里返回time-out问题通常可以解决。

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


