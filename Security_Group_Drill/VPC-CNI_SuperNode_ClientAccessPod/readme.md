# 概述
&emsp;安全组作为容器基础设施层的核心流量控制组件，通过节点边界实施粗粒度访问控制，为容器环境提供基础网络隔离保障。然而，用户常因安全组规则复杂性及配置方式不当导致服务不可访问，本文针对VPC-CNI 网络模式下TKE 集群中创建的超级节点上部署的 Pod 服务，利用脚本创建安全组的方式模拟真实生产环境下的网络访问异常，通过引导用户分层逐步排查访问链路,最终掌握安全组配置的核心逻辑


# 访问链路
VPC-CNI超级节点下clb pod访问<br>
[<img width="576" height="222" alt="Clipboard_Screenshot_1753947044" src="https://github.com/user-attachments/assets/4c31acab-f5e5-4d3f-a5cc-b1ad7c70e1bb" />
](https://github.com/aliantli/sg_playbook_1/blob/d6c7da2565dba6e744b7be53eccae7c939f8bbec/playbook/VPC-CNI%E8%B6%85%E7%BA%A7%E8%8A%82%E7%82%B9%E4%B8%8B%E7%9B%B4%E8%BF%9E%E5%A4%96%E7%BD%91%E8%AE%BF%E9%97%AEpod%E5%AE%89%E5%85%A8%E7%BB%84%E6%BC%94%E7%BB%83/image/flowchart1.md)
 <br>&emsp;在日常生产环境中可以通过在上述两个位置是设置安全组来限制外网流量入站(一般对流量出站不做限制)，以此控制入口流量的基础过滤，实现流量的精细管控，保障Pod资源安全
<br>**&emsp;安全组2继承规则:**<br>
|场景|是否为工作负载绑定安全组|是否为节点绑定安全组|实际使用安全组|
|:--:|:--:|:--:|:--:|
|场景1|✓|✓|工作负载处安全组|
|场景5||✓|节点处安全组|
|场景6|||所在地域default安全组|
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
```
clb层面:出现这种情况一般为clb安全组配置问题，查看clb绑定的安全组，查看其是否放通http/https的监听端口
```

### 若放通clb层安全组后出现以下现象(time out):
```
root@VM-35-82-tlinux ~]# curl 193.112.115.15
curl: (7) Failed to connect to 193.112.115.15 port 80: Connection timed out
```
**排查方向:**<br>
出现这种情况可能为pod所绑定安全组配置不正确,可
根据上述安全组继承规则查看pod所绑定的安全组是否允许来源ip访问pod服务端口

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

