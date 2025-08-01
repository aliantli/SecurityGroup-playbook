# 概述
&emsp;在容器化架构中，安全组作为核心网络管控组件，通过节点边界实施访问控制策略，为容器环境提供基础隔离保障。针对VPC-CNI网络模式下TKE集群中原生节点与Pod间的通信场景，本文系统梳理了因安全组配置不当导致的典型访问异常。采用分层递进的排查方法，帮助运维人员理解安全组配置与流量路径的映射关系，掌握VPC-CNI模式下节点与Pod间通信的最佳安全实践，从而有效解决服务不可访问问题。


# 访问链路
VPC-CNI下节点与pod跨节点访问:<br>
[<img width="497" height="267" alt="Clipboard_Screenshot_1753963102" src="https://github.com/user-attachments/assets/49851d3e-a6f9-4a00-8ba4-1331495e2179" />
](./image/flowchart2.md)
<br>安全组1:绑定在节点A上，控制节点A流量出站<br>
安全组2:绑定在podB辅助网卡上，控制流量服务podB，默认关闭可根据需要手动开启<br>
# 环境部署
## 前提条件
**1.tke集群要求**

TKE版本>=1.20.6,具体操作可参考:https://cloud.tencent.com/document/product/457/103981<br>
网络模式:VPC-CNI,详情可参考:https://cloud.tencent.com/document/product/457/50355

**2.工具准备**

安装[terraform:v1.8.2](https://developer.hashicorp.com/terraform)
## 快速开始
**以terraform为例**<br>
 1.创建节点A、B
```
[root@VM-35-139-tlinux terraform]# sh create_node_tf.sh 
[root@VM-35-139-tlinux terraform]# terraform apply -auto-approve
```
 2.创建deployment并将其绑定在节点B上
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
当返回timed-out时，常见原因是podB辅助网卡的安全组被开启且配置存在限制​。<br>
排查建议:<br>
请检查pod辅助网卡所绑定的安全组(安全组2)规则，确认是否已放行节点A的IP​​对以下端口的访问：<br>
Pod 提供的服务端口​​（即容器内实际监听的端口）<br>
如果发现相关流量被拦截，请在安全组中添加对应的​入站规则​​，允许节点A的IP访问上述端口,到这里返回time-out问题通常可以解决

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


