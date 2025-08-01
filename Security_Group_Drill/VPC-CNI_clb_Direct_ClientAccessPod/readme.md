# 概述
&emsp;在容器化架构中，安全组作为基础设施层的核心流量管控组件，通过节点边界实施粗粒度访问控制策略，为容器环境提供基础网络隔离保障。针对VPC-CNI网络模式下TKE集群原生节点直连Pod服务的场景，本文通过脚本模拟真实生产环境中因安全组配置不当导致的网络访问异常。采用分层递进的排查方法，帮助客户深入理解安全组规则的核心配置逻辑，掌握直连Pod场景下的最佳安全实践，从而有效解决服务不可访问问题。

# 访问链路
VPC-CNI下clb直连pod访问:<br>
[<img width="576" height="224" alt="Clipboard_Screenshot_1753947859" src="https://github.com/user-attachments/assets/44c3bbb8-c96b-4876-83f8-4498452331ae" />
](./image/flowchart.md)<br>
安全组1​​：绑定在负载均衡器(CLB)上，作为首道防线控制访问CLB的流量。<br>
​​安全组2​​：绑定在pod网卡上，控制访问Pod的流量。<br>
## 前提条件
**1.tke集群要求**

TKE版本>=1.20.6，具体操作可参考:https://cloud.tencent.com/document/product/457/103981<br>
网络模式:VPC-CNI,详情可参考:https://cloud.tencent.com/document/product/457/50355

**2.工具准备**

安装[terraform:v1.8.2](https://developer.hashicorp.com/terraform)
## 快速开始

**以terraform为例**<br>
 1.创建节点与安全组、安全组2并将安全组2绑定到节点上
```
[root@VM-35-179-tlinux ~]# sh crete_node_sg_tf.sh
[root@VM-35-179-tlinux ~]# terraform apply -auto-approve
```
2.部署服务并将安全组1绑定到clb上

```
#以clb类型Service为例
[root@VM-35-179-tlinux ~]# sh deploy_service.sh
[root@VM-35-179-tlinux ~]# kubectl apply -f deployment.yaml
[root@VM-35-179-tlinux ~]# kubectl apply -f service.yaml
```

# 问题分析
## 第一步:获取服务公网访问ip
```
[root@VM-35-179-tlinux ~]# kubectl get service -o wide
NAME         TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)        AGE     SELECTOR
kubernetes   ClusterIP      172.16.0.1      <none>           443/TCP        4h22m   <none>
nginx        LoadBalancer   172.16.60.200   119.91.244.213   80:30713/TCP   156m    app=nginx
```

## 第二步:演练分析
### 若访问出现以下现象(time out):
```
[root@VM-35-179-tlinux ~]# curl -I http://119.91.244.213
curl: (7) Failed to connect to 119.91.244.213 port 80: Connection timed out
```
**排查方向:**<br>
当返回time-out时，常见原因是clb所绑定的安全组(安全组1)配置存在限制​​。<br>
排查建议:<br>
请检查该安全组的规则，确认是否已放行客户端IP​​对以下端口的访问：<br>
1.​​http/https所绑定的主机端口​​（即clb暴露到外网的端口）<br>
如果发现相关流量被拦截，请在安全组中添加对应的​入站规则​​，允许客户端IP访问上述端口,到这里返回time-out问题通常可以解决。
### 若放通clb层安全组后仍然出现以下现象(time out):
```
[root@VM-35-179-tlinux ~]# curl -I http://119.91.244.213
curl: (7) Failed to connect to 119.91.244.213 port 80: Connection timed out
```
**排查方向:**<br>
如果clb所绑定安全组配置正确但是仍然返回time-out时，常见原因是pod辅助网卡的安全组被开启且配置存在限制​。<br>
排查建议:<br>
请检查pod辅助网卡所绑定的安全组(安全组2)规则，确认是否已放行客户端IP​​对以下端口的访问：<br>
Pod 提供的服务端口​​（即容器内实际监听的端口）<br>
如果发现相关流量被拦截，请在安全组中添加对应的​入站规则​​，允许客户端IP访问上述端口,到这里返回time-out问题通常可以解决。<br>
```
[root@VM-35-179-tlinux ~]# kubectl logs -n kube-system deploy/tke-eni-ipamd | grep "Event"|grep "security groups from"|awk '{print $24}'|awk -F'[' '{print $2}'|awk -F']' '{print $1}'                            ##查询其所绑定的安全组
sg-xxxxxxx             ##输出的为pod(辅助)网卡所绑定的安全组id
```
# 演练环境清理
```
[root@VM-35-179-tlinux ~]# kubectl delete -f service.yaml
[root@VM-35-179-tlinux ~]# kubectl delete -f deployment.yaml
[root@VM-35-179-tlinux ~]# terraform destroy -auto-approve
```
# 项目结构
```
VPC-CNI下直连外网访问pod安全组演练/  
├── service.yaml      # 配置service并为clb绑定安全组
├── create_node_sg_td.sh   #配置tf文件脚本
├── deploy_service.sh     #配置服务yaml文件脚本
├── deployment.yaml    #部署deployment
├── node_sg.template      #创建节点和安全组并给节点绑定安全组
├── readme.md        #本文件
```
