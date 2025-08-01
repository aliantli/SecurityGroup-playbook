# 概述
&emsp;在容器化架构中，安全组作为核心网络管控组件，通过节点边界实施访问控制策略，为容器环境提供基础隔离保障。针对VPC-CNI网络模式下TKE集群中原生节点与Pod间的通信场景，本文系统梳理了因安全组配置不当导致的典型访问异常。采用分层递进的排查方法，帮助运维人员理解安全组配置与流量路径的映射关系，掌握VPC-CNI模式下pod与Pod间通信的最佳安全实践，从而有效解决服务不可访问问题。

# 访问链路
VPC-CNI下pod与pod跨节点访问:<br>
[<img width="633" height="373" alt="Clipboard_Screenshot_1753948754" src="https://github.com/user-attachments/assets/0aa15b09-362c-40a9-b007-4832840505b1" />
](./image/flowchart.md)
 <br>安全组1:绑定在podA辅助网卡上，控制podA流量出站，默认关闭可根据需要手动开启<br>
 安全组2:绑定在podB辅助网卡上，控制流量访问podB，默认关闭可根据需要手动开启<br>

# 环境部署
## 前提条件
**1.tke集群要求**

TKE版本>=1.20.6，具体操作可参考:https://cloud.tencent.com/document/product/457/103981<br>
网络模式:VPC-CNI，详情可参考:https://cloud.tencent.com/document/product/457/50355

**2.工具准备**

安装[terraform:v1.8.2](https://developer.hashicorp.com/terraform)
## 快速开始
**以terraform为例**<br>
 1.创建两个原生节点A、B
```
[root@VM-35-139-tlinux terraform]# sh create_node_tf.sh
[root@VM-35-139-tlinux terraform]# terraform apply -auto-approve
```
 2.创建两个deployment并分别绑定在两个原生节点上

```
[root@VM-35-139-tlinux terraform]# sh setup_deploy_yaml.sh
[root@VM-35-139-tlinux terraform]# kubectl apply -f deployment.yaml
```

# 演练分析
## 第一步:获取podA与podB名称与访问ip
```
[root@VM-35-139-tlinux terraform]# kubectl get pods -o wide -l app=my-app1|awk '{printf "podA:"$1"\t""pod_ip:"$6"\n"}'|grep -v "NAME"|grep -v IP
podA:nginx-pod       pod_ip:10.0.35.23
[root@VM-35-139-tlinux terraform]# kubectl get pods -o wide -l app=my-app2|awk '{printf "podB:"$1"\t""pod_ip:"$6"\n"}'|grep -v "NAME"|grep -v IP
podB:nginx-pod2      pod_ip:10.0.35.150
```
## 第二步:登录podA访问podB
```
[root@VM-35-139-tlinux terraform]# kubectl exec -it nginx-pod -- sh
#url 10.0.35.150
```
## 第三步:问题分析
### 若访问时出现以下现象(time out):
```
# curl 10.0.35.150
curl: (28) Failed to connect to 10.0.35.150 port 80: Connection timed out
```
**排查方向:**<br>
当返回timed-out时，常见原因是podB辅助网卡的安全组被开启且配置存在限制​。<br>
排查建议:<br>
请检查pod辅助网卡所绑定的安全组(安全组2)规则，确认是否已放行podA的IP​​对以下端口的访问：<br>
Pod 提供的服务端口​​（即容器内实际监听的端口）<br>
如果发现相关流量被拦截，请在安全组中添加对应的​入站规则​​，允许podA的IP访问上述端口,到这里返回timed-ou问题通常可以解决
```
[root@VM-35-179-tlinux ~]# kubectl logs -n kube-system deploy/tke-eni-ipamd | grep "Event"|grep "security groups from"|awk '{print $24}'|awk -F'[' '{print $2}'|awk -F']' '{print $1}'                            ##查询其所绑定的安全组
sg-xxxxxx            ##输出的为pod(辅助)网卡所绑定的安全组id
sg-xxxxxx            ##同一集群内pod公用一个(辅助)网卡输出安全组为相同的
```


# 演练环境清理
```
[root@VM-35-179-tlinux ~]# kubectl delete  -f deployment.yaml
[root@VM-35-179-tlinux ~]# terraform destroy -auto-approve
```
# 项目结构
```
VPC-CNIr_PodAccessPod/  
├── deployment.yaml      # 创建deployment并指定deployment绑定到对应节点上
├── create_node_tf.sh   #配置tf文件脚本
├── create_node.template      #创建节点
├── readme.md        #本文件
├── setup_deploy_yaml.sh  #为deployment指定节点
```

