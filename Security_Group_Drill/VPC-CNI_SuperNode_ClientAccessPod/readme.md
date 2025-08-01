# 概述
&emsp;在容器化架构中，安全组作为核心网络管控组件，通过节点边界实施访问控制策略，为容器环境提供基础隔离保障。针对VPC-CNI网络模式下TKE集群超级节点Pod服务的访问场景，本文通过脚本模拟真实生产环境中因安全组配置不当导致的典型网络异常。帮助客户深入理解安全组配置与流量路径的映射关系，掌握超级节点场景下的最佳安全实践，从而有效解决服务不可访问问题。


# 访问链路
VPC-CNI超级节点下clb pod访问<br>
[<img width="576" height="222" alt="Clipboard_Screenshot_1753947044" src="https://github.com/user-attachments/assets/6968b52c-c2a3-4770-bf02-417c18aa630b" />
](./image/flowchart1.md)
 <br>安全组1​​：绑定在负载均衡器(CLB)上，作为首道防线控制访问CLB的流量。<br>
​​安全组2​​：绑定在pod网卡上，控制访问Pod的流量。
<br>**&emsp;安全组2继承规则:**<br>
|场景|是否为工作负载绑定安全组|是否为节点绑定安全组|实际使用安全组|
|:--:|:--:|:--:|:--:|
|场景1|✓|✓|工作负载处安全组|
|场景5||✓|节点处安全组|
|场景6|||所在地域default安全组|
# 环境部署
## 前提条件
**1.tke集群要求**

TKE版本>=1.20.6，具体操作可参考:https://cloud.tencent.com/document/product/457/103981<br>
网络模式:VPC-CNI，详情可参考:https://cloud.tencent.com/document/product/457/50355

**2.工具准备**

安装[terraform:v1.8.2](https://developer.hashicorp.com/terraform)
## 快速开始
**以terraform为例**<br>
 1.创建节点与安全组并为节点绑定安全组
```
[root@VM-35-179-tlinux ~]# sh crete_node_sg_tf.sh
[root@VM-35-179-tlinux ~]# terraform apply -auto-approve
```
 2.服务部署并为clb绑定安全组

```
#以clb类型Service为例
[root@VM-35-179-tlinux ~]# sh deploy_service.sh
[root@VM-35-179-tlinux ~]# kubectl apply -f deployment.yaml
[root@VM-35-179-tlinux ~]# kubectl apply -f service.yaml
```

# 演练分析
## 第一步:获取服务公网访问ip
```
NAME         TYPE           CLUSTER-IP       EXTERNAL-IP      PORT(S)        AGE     SELECTOR
kubernetes   ClusterIP      192.168.0.1      <none>           443/TCP        5h44m   <none>
nginx        LoadBalancer   192.168.9.250    193.112.115.15   80:31234/TCP   74m     app=nginx
```
## 第二步:问题分析
### 若访问时出现以下现象(time out):
```
root@VM-35-82-tlinux ~]# curl 193.112.115.15
curl: (7) Failed to connect to 193.112.115.15 port 80: Connection timed out
```
**排查方向:**<br>



<br>当返回time-out时，常见原因是​clb所绑定的安全组(安全组1)或节点网卡绑定的安全组(安全组2)配置存在限制​​。<br>
排查建议:<br>
首先请检查clb所绑定安全组规则，确认是否已放行客户端IP​​对以下端口的访问：<br>
1.​​http/https所绑定的主机端口​​（即clb暴露到外网的端口）<br>
如果发现相关流量被拦截,请在安全组中添加对应的​入站规则​​，允许客户端IP访问上述端口<br>如果允许客户端IP访问上述端口后仍然返回time-out，请检查pod所绑定的安全组(安全组2)规则.<br>
1.先根据上面安全组继承规则查看pod具体使用的什么安全组<br>
2.检查该安全组规则，确认是否已放行客户端的IP​​对以下端口的访问：<br>
Pod 提供的服务端口​​（即容器内实际监听的端口）<br>
如果发现相关流量被拦截，请在安全组中添加对应的​入站规则​​，允许客户端的IP访问上述端口,到这里返回timed-out问题通常可以解决

# 演练环境清理
```
[root@VM-35-179-tlinux ~]# kubectl delete -f service.yaml
[root@VM-35-179-tlinux ~]# kubectl delete -f deployment.yaml
[root@VM-35-179-tlinux ~]# terraform destroy -auto-approve
```
# 项目结构
```
VPC-CNI下非直连外网访问pod安全组演练/  
├── service.yaml      # 配置service并为clb绑定安全组
├── create_node_sg_tf.sh   #配置tf文件脚本
├── deploy_service.sh     #配置服务yaml文件脚本
├── deployment.yaml    #部署deployment
├── node_sg.template      #创建节点和安全组并给节点绑定安全组
├── readme.md        #本文件
```

