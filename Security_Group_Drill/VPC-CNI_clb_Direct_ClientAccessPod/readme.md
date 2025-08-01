# 概述
&emsp;安全组作为容器基础设施层的核心流量控制组件，通过节点边界实施粗粒度访问控制，为容器环境提供基础网络隔离保障。然而，用户常因安全组规则复杂性及配置方式不当导致服务不可访问，本文针对VPC-CNI 网络模式下TKE 集群中创建的原生节点上部署的非直连 Pod 服务，利用脚本创建安全组的方式模拟真实生产环境下的网络访问异常，通过引导用户分层逐步排查访问链路,最终掌握安全组配置的核心逻辑


# 访问链路
VPC-CNI下clb非直连pod访问:<br>
[<img width="710" height="351" alt="Clipboard_Screenshot_1753946799" src="https://github.com/user-attachments/assets/d76ff741-e630-4618-a959-bbc06187e475" />
](https://github.com/aliantli/sg_playbook_1/blob/d25859b6c517ad0078059caee5002b75aaa271af/playbook/VPC-CNI%E4%B8%8B%E9%9D%9E%E7%9B%B4%E8%BF%9E%E5%A4%96%E7%BD%91%E8%AE%BF%E9%97%AEpod%E5%AE%89%E5%85%A8%E7%BB%84%E6%BC%94%E7%BB%83/image/flowchart.md)

 <br>&emsp;在日常生产环境中可以通过在上述三个位置是设置安全组来限制外网流量入站(一般不限制流量出站)，以此控制入口流量的基础过滤，实现流量的精细管控，保障Pod资源安全(pod辅助网卡处的安全组默认关闭可根据自己需求开启)

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
[root@VM-35-179-tlinux ~]# kubectl get service -o wide
NAME         TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)        AGE     SELECTOR
kubernetes   ClusterIP      172.16.0.1      <none>           443/TCP        4h22m   <none>
nginx        LoadBalancer   172.16.60.200   119.91.244.213   80:30713/TCP   156m    app=nginx
```
## 第二步:问题分析
### 若访问时出现以下现象:
```
[root@VM-35-179-tlinux ~]# curl -I http://119.91.244.213
curl: (7) Failed to connect to 119.91.244.213 port 80: Connection timed out
```
排查方向:
```
clb层面:出现这种情况一般为clb安全组配置问题，查看clb绑定的安全组，查看其是否放通http/https的监听端口
```
### 若访问时出现以下现象(504):
```
[root@VM-35-179-tlinux ~]# curl -I http://119.91.244.213
HTTP/1.1 504 Gateway Time-out
Server: stgw
Date: Tue, 22 Jul 2025 12:41:43 GMT
Content-Type: text/html
Content-Length: 159
Connection: keep-alive
```
排查方向:
```
节点层面：出现这种情况一般为节点安全组配置问题，前往节点所绑定的安全组，查看其是否放通service所绑定的主机端口，如果未放通放通即可
```
### 若放通节点和clb层安全组仍然后出现以下现象(504):
```
[root@VM-35-179-tlinux ~]# curl -I http://119.91.244.213
HTTP/1.1 504 Gateway Time-out
Server: stgw
Date: Tue, 22 Jul 2025 12:41:43 GMT
Content-Type: text/html
Content-Length: 159
Connection: keep-alive
```
排查方向:
```
##出现这种情况可能为pod辅助网卡安全组被开启且安全组配置不正确
[root@VM-35-179-tlinux ~]# kubectl logs -n kube-system deploy/tke-eni-ipamd | grep "Event"|grep "security groups from"|awk '{print $24}'|awk -F'[' '{print $2}'|awk -F']' '{print $1}'                            ##查询其所绑定的安全组
sg-xxxxxx            ##输出的为pod(辅助)网卡所绑定的安全组id
##查看其绑定的安全组是否放通pod服务端口如果未放通放通即可
```
# 演练环境清理
```
[root@VM-35-179-tlinux ~]# kubectl delete  -f service.yaml
[root@VM-35-179-tlinux ~]# kubectl delete  -f deployment.yaml
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
