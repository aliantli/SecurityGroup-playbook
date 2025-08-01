
# 概述
&emsp;安全组作为容器基础设施的核心流量管控组件，通过在节点边界实施粗粒度的访问控制策略，为容器环境提供基础网络隔离保障。然而，由于安全组规则配置的复杂性和操作不当，用户常面临服务不可访问的问题。本文针对GlobalRouter网络模式下TKE集群的原生节点非直连Pod场景，通过自动化脚本模拟真实生产环境中的网络异常，采用分层递进的排查方法，系统梳理访问链路中的关键控制点，帮助用户掌握安全组配置的核心逻辑与最佳实践。
# 访问链路
Global Router下clb非直连pod访问:<br>
[<img width="767" height="382" alt="Clipboard_Screenshot_1753945050" src="https://github.com/user-attachments/assets/8ebea6b2-e233-4462-a9ac-5f8280467200" />
](./image/flowchart.md)
<br>安全组1:作为第一道防线，过滤公网/外部流量
<br>安全组2:保护节点和Pod的底层网络平面，精细化控制流量出入
# 环境部署
## 前提条件
**1.tke集群要求**

TKE版本>=1.20.6，具体操作可参考:https://cloud.tencent.com/document/product/457/103981<br>
网络模式:GlobalRouter，详情可参考:https://cloud.tencent.com/document/product/457/50354

**2.工具准备**

安装[terraform:v1.8.2](https://developer.hashicorp.com/terraform)
## 快速开始


**以terraform为例**<br>
1.创建原生节点与安全组1、安全组2，并将安全组2绑定到原生节点上
```
[root@VM-35-179-tlinux ~]# sh create_node_sg_tf.sh
[root@VM-35-179-tlinux ~]# terraform apply -auto-approve
```
2.部署服务并将安全组1绑定到clb上

```
#以clb类型Service为例
[root@VM-35-179-tlinux ~]# sh deploy_service.sh
[root@VM-35-179-tlinux ~]# kubectl apply -f deployment.yaml
[root@VM-35-179-tlinux ~]# kubectl apply -f service.yaml
```


# 演练分析
## 第一步:获取服务公网访问ip
```
[root@VM-35-179-tlinux ~]# kubectl get service -o wide
NAME         TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)        AGE     SELECTOR
kubernetes   ClusterIP      172.16.0.1      <none>           443/TCP        4h22m   <none>
nginx        LoadBalancer   172.16.60.200   119.91.244.213   80:30713/TCP   156m    app=nginx
```
## 第二步:问题分析
### 若访问出现以下现象(time out):
```
[root@VM-35-179-tlinux ~]# curl -I http://119.91.244.213
curl: (7) Failed to connect to 119.91.244.213 port 80: Connection timed out
```
**排查方向:**<br>
一般情况下，出现timeout报错的原因是绑定在clb上的安全组1配置有错误，查看安全组1配置，看其是否允许客户端ip访问http/https所绑定的监听端口，如果没有放通将其放通即可

### 若访问出现以下现象(504):
```
[root@VM-35-179-tlinux ~]# curl -I http://119.91.244.213
HTTP/1.1 504 Gateway Time-out
Server: stgw
Date: Tue, 22 Jul 2025 12:41:43 GMT
Content-Type: text/html
Content-Length: 159
Connection: keep-alive
```
**排查方向:**<br>
一般情况下，出现504状态码的原因是绑定在节点网卡的安全组2配置有错误，查看安全组2配置，看其是否允许客户端ip访问service所绑定的主机端口和pod的服务端口，如果没有放通放通即可



# 演练环境清理
```
[root@VM-35-179-tlinux ~]# kubectl delete  -f service.yaml
[root@VM-35-179-tlinux ~]# kubectl delete -f deployment.yaml
[root@VM-35-179-tlinux ~]# terraform destroy -auto-approve
```
# 项目结构

```
GlobalRouter下非直连外网访问pod安全组演练/   
├── service.yaml      # 配置service并为clb绑定安全组
├── create_no_sg_tf.sh   #配置tf文件脚本
├──deploy_service.sh     #配置服务yaml文件脚本
├── deployment.yaml    #部署deployment
├── node_sg.template      #创建节点和安全组并给节点绑定安全组
├── readme.md        #本文件
```

