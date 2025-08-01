# TKE安全组故障演练全景指南
## 概述
&emsp;在容器化架构中，安全组作为核心网络管控组件，通过节点边界实施访问控制策略，为容器环境提供基础隔离保障。本playbook针对GlobalRouter和VPC-CNI两种网络模式下TKE集群节点Pod服务的访问场景，通过脚本模拟真实生产环境中因安全组配置不当导致的典型网络异常。采用"网络模式→节点入口→Pod访问"的分层排查方法，系统分析不同网络模式下访问链路的关键控制点差异，帮助客户深入理解安全组配置与网络模式的关联性，掌握混合网络环境下的最佳安全实践，从而有效解决服务不可访问问题。
## 访问链路总图
[<img width="762" height="539" alt="Clipboard_Screenshot_1753944807" src="https://github.com/user-attachments/assets/b7754ffa-5913-4a7e-a364-f63bad206ead" />
](./image/flowchart.md)
## 安全组访问场景
| 场景            | 网络模式         |节点类型 |访问场景|
|----------------|----------------|------|--|
| 场景1   | VPC-CNI   |原生节点|[clb直连pod访问](./VPC-CNI_clb_Direct_ClientAccessPod)|
| 场景2  | VPC-CNI      |原生节点|[clb非直连pod访问](./VPC-CNI_clb_non_Direct_ClientAccessPod)|
| 场景3  | VPC-CNI   |超级节点|[clb pod访问](./VPC-CNI_SuperNode_ClientAccessPod)|
| 场景4  | GlobalRouter  |  原生节点|[clb直连pod访问](./GlobalRouter_clb_Direct_ClientAccessPod)|
| 场景5  | GlobalRouter  |   原生节点|[clb非直连pod访问](./GlobalRouter_clb_non_Direct_ClientAccessPod)|
|场景6 |VPC-CNI|原生节点|[pod与pod跨节点访问](./VPC-CNI_PodAccessPod)|
|场景7 |VPC-CNI|原生节点|[节点与pod跨节点访问](./VPC-CNI_NodeAccessPod)|
|场景8 |GlobalRouter |原生节点|[pod与pod跨节点访问](./GlobalRouter_PodAccessPod)|
|场景9 |GlobalRouter |原生节点|[节点与pod跨节点访问](./GlobalRouter_NodeAccessPod)|
|场景10 |VPC-CNI|超级节点|[pod与pod跨节点访问](./VPC-CNI_Super_PodAccessPod)|
|场景11 |VPC-CNI|超级节点|[原生节点与pod跨节点访问](./VPC-CNI_Super_NodeAccessPod)|

