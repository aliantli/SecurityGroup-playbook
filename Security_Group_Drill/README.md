# TKE安全组故障演练全景指南
## 概述
&emsp;安全组作为容器基础设施层的核心流量控制组件，通过节点边界实施粗粒度访问控制，为容器环境提供基础网络隔离保障。然而，用户常因安全组规则复杂性及配置方式不当导致服务不可访问，本文playbook通过GlobalRouter和VPC-CNI两种网络模式下TKE 集群中创建的节点上部署的Pod服务，利用脚本创建安全组的方式模拟真实生产环境下的网络访问异常，通过引导用户分层逐步排查访问链路,最终掌握安全组配置的核心逻辑
## 访问链路总图
[<img width="762" height="539" alt="Clipboard_Screenshot_1753944807" src="https://github.com/user-attachments/assets/b7754ffa-5913-4a7e-a364-f63bad206ead" />
](https://github.com/aliantli/sg_playbook_1/blob/e7146fc9d53601b87e36ae54f81f09206ae800fc/playbook/image/flowchart.md)
## 安全组访问场景
| 场景            | 网络模式         |节点类型 |访问场景|
|----------------|----------------|------|--|
| 场景1   | VPC-CNI   |原生节点|[clb直连pod访问]|
| 场景2  | VPC-CNI      |原生节点|[clb非直连pod访问]|
| 场景3  | VPC-CNI   |超级节点|[clb pod访问]|
| 场景4  | GlobalRouter  |  原生节点|[clb直连pod访问]|
| 场景5  | GlobalRouter  |   原生节点|[clb非直连pod访问]|
|场景6 |VPC-CNI|原生节点|[pod与pod跨节点访问]|
|场景7 |VPC-CNI|原生节点|[节点与pod跨节点访问]|
|场景8 |GlobalRouter |原生节点|[pod与pod跨节点访问]|
|场景9 |GlobalRouter |原生节点|[节点与pod跨节点访问]|
|场景10 |VPC-CNI|超级节点|[pod与pod跨节点访问]|
|场景11 |VPC-CNI|超级节点|[原生节点与pod跨节点访问]|

