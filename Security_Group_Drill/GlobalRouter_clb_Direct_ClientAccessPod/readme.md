# 概述
&emsp;安全组作为容器基础设施层的核心流量控制组件，通过节点边界实施粗粒度访问控制，为容器环境提供基础网络隔离保障。然而，用户常因安全组规则复杂性及配置方式不当导致服务不可访问，本文针对GlobalRouter网络模式下TKE 集群中创建的原生节点上部署的非直连 Pod 服务，利用脚本创建安全组的方式模拟真实生产环境下的网络访问异常，通过引导用户分层逐步排查访问链路,最终掌握安全组配置的核心逻辑


# 访问链路
Global Router下clb直连pod访问:<br>
[<img width="767" height="382" alt="Clipboard_Screenshot_1753945050" src="https://github.com/user-attachments/assets/0f9227c2-31cd-49ed-b608-81f2765898f8" />
](https://github.com/aliantli/SecurityGroup-playbook/blob/3e53a78d7ce50b9364e87d0fb5e1b2baa6d23af6/Security_Group_Drill/GlobalRouter_clb_Direct_ClientAccessPod/image/flowchart.md)
<br>&emsp;在日常生产环境中可以通过在上述两个位置是设置安全组来限制外网流量入站(一般对流量出站不做限制)，以此控制入口流量的基础过滤，实现流量的精细管控，保障Pod资源安全
# 环境部署
## 前提条件
**1.tke集群要求**

TKE版本>=1.20.6
<br>详情可参考:https://cloud.tencent.com/document/product/457/103981<br>
网络模式:GlobalRouter<br>
详情可参考:https://cloud.tencent.com/document/product/457/50354

**2.工具准备**

配置好[terraform:v1.8.2](https://developer.hashicorp.com/terraform)
## 快速开始


**以terraform为例**<br>
1.创建节点与安全组并为节点绑定安全组
```
[root@VM-35-179-tlinux ~]# sh create_node_sg_tf.sh
[root@VM-35-179-tlinux ~]# terraform apply -auto-approve
```
2.服务部署并为clb绑定安全组
```
以clb类型Service为例
[root@VM-35-179-tlinux ~]# sh deploy_service.sh
[root@VM-35-179-tlinux ~]# kubectl patch cm tke-service-controller-config -n kube-system \
  --patch '{"data":{"GlobalRouteDirectAccess":"true"}}'  # 启用全局直连
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

**排查方向:**
<br>
一般出现timeout为clb或节点的安全组配置问题:<br>
1.clb层面:出现这种情况一般为clb安全组配置问题，查看clb绑定的安全组，查看其是否放通http/https的监听端口和用于健康检查的ip:100.64.0.0/10<br>
2.节点层面：出现这种情况一般为节点安全组配置问题，前往节点所绑定的安全组，查看其是否放通service所绑定的主机端口和pod服务所暴露的端口，如果未放通放通即可


# 演练环境清理
```
[root@VM-35-179-tlinux ~]# kubectl delete   -f service.yaml
[root@VM-35-179-tlinux ~]# kubectl delete  -f deployment.yaml
[root@VM-35-179-tlinux ~]# terraform destroy -auto-approve
```
# 项目结构
```
GlobalRouter下直连外网访问pod安全组演练/  
├── service.yaml      # 配置service并为clb绑定安全组
├── create_no_sg_tf.sh   #配置tf文件脚本
├──deploy_service.sh     #配置服务yaml文件脚本
├── deployment.yaml    #部署deployment
├── node_sg.template      #创建节点和安全组并给节点绑定安全组
├── readme.md        #本文件
```

