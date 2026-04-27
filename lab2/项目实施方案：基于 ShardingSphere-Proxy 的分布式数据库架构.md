这是一份为您量身定制的项目实施方案，结构清晰、技术细节具体，非常适合直接交付给项目工程师进行落地执行。

------

# 项目实施方案：基于 ShardingSphere-Proxy 的分布式数据库架构

## 一、 项目概述

本项目旨在搭建一个高可用、可扩展的分布式数据库架构。核心业务为用户管理模块（`t_user`），通过引入 ShardingSphere-Proxy 作为透明的数据库代理层，实现底层数据的**读写分离**与基于 `user_id` 的**水平分片（Sharding）**。整个架构将采用 Docker Compose 进行容器化编排与部署。

## 二、 架构拓扑与环境规划

系统整体架构分为四层，均部署在 Docker Compose 自定义网络（`sharding_net`）中。

- **接入层（负载均衡）：** 1 个 Nginx 节点，负责对外暴露统一入口，将流量分发至后端应用。
- **应用层（业务逻辑）：** 2 个 Spring Boot 实例，无状态部署，仅需配置连接至 Proxy，无需感知底层物理库。
- **代理层（中间件）：** 1 个 ShardingSphere-Proxy 节点，解析 SQL，执行路由、分片与读写分离逻辑。
- **存储层（物理库）：** MySQL 8.0 集群（1主2从）。
  - `ds_master`：主库，处理所有写请求。
  - `ds_slave_0`：从库 0，处理 `user_id` 为偶数的读请求。
  - `ds_slave_1`：从库 1，处理 `user_id` 为奇数的读请求。

------

## 三、 实施步骤详解

### 阶段一：存储层集群搭建 (MySQL 主从)

1. **编写初始化脚本：** 准备主从复制的 SQL 脚本。开启主库的 Binlog，并在两个从库上配置 `CHANGE MASTER TO` 指向主库，建立单向同步链路。
2. **创建物理库表：** 在 `ds_master` 中创建数据库（如 `user_db`），并创建两张分片物理表 `t_user_0` 和 `t_user_1`。由于主从同步，从库会自动生成这些表。

### 阶段二：代理层配置 (ShardingSphere-Proxy)

此阶段是核心。工程师需要挂载两个核心配置文件到 Proxy 容器的 `conf` 目录下。

**1. server.yaml (基础服务配置)**

配置 Proxy 的认证信息及计算节点属性。

YAML

```
rules:
  - !AUTHORITY
    users:
      - root@%:root  # 为 Spring Boot 提供的连接账号
    provider:
      type: ALL_PRIVILEGES_PERMITTED
```

**2. config-sharding.yaml (分片与读写分离规则)**

定义物理数据源、读写分离逻辑数据源，以及分片规则。

YAML

```
schemaName: logic_db

dataSources:
  ds_master:
    url: jdbc:mysql://ds_master:3306/user_db?serverTimezone=UTC&useSSL=false
    username: root
    password: password
  ds_slave_0:
    url: jdbc:mysql://ds_slave_0:3306/user_db?serverTimezone=UTC&useSSL=false
    username: root
    password: password
  ds_slave_1:
    url: jdbc:mysql://ds_slave_1:3306/user_db?serverTimezone=UTC&useSSL=false
    username: root
    password: password

rules:
  # 1. 读写分离规则
  - !READWRITE_SPLITTING
    dataSources:
      pr_ds_0: # 逻辑读写分离数据源0
        writeDataSourceName: ds_master
        readDataSourceNames: [ds_slave_0]
      pr_ds_1: # 逻辑读写分离数据源1
        writeDataSourceName: ds_master
        readDataSourceNames: [ds_slave_1]

  # 2. 数据分片规则
  - !SHARDING
    tables:
      t_user:
        # 实际数据节点分布在两个读写分离逻辑数据源中
        actualDataNodes: pr_ds_${0..1}.t_user_${0..1}
        tableStrategy:
          standard:
            shardingColumn: user_id
            shardingAlgorithmName: t_user_inline
    shardingAlgorithms:
      t_user_inline:
        type: INLINE
        props:
          algorithm-expression: t_user_${user_id % 2}
```

### 阶段三：应用层开发 (Spring Boot)

1. **依赖与配置：** 引入 Web 和 MySQL Driver 依赖。`application.yml` 的 DataSource URL 指向 Proxy 容器（例如：`jdbc:mysql://sharding-proxy:3307/logic_db`）。
2. **业务代码：**
   - **Controller:** 提供 `/user/save` (POST) 和 `/user/find` (GET) 接口。
   - **Repository/Mapper:** 编写标准 SQL，直接操作逻辑表 `t_user`。**切记：应用层绝对不写分表后缀（如 `t_user_0`）。**

### 阶段四：负载均衡配置 (Nginx)

编写 `nginx.conf`，将前端请求代理到两个后端应用实例。

Nginx

```
upstream backend_app {
    server spring-app-1:8080;
    server spring-app-2:8080;
}

server {
    listen 80;
    location / {
        proxy_pass http://backend_app;
    }
}
```

### 阶段五：Docker Compose 统一编排

工程师需编写 `docker-compose.yml`，定义各服务的启动顺序（MySQL -> Proxy -> App -> Nginx）。使用 `depends_on` 和 `healthcheck` 确保上游服务就绪后再启动下游服务。

------

## 四、 关键知识点总结 (供实验报告归纳)

- **透明化架构：** Proxy 模式的最大优势在于对业务代码零侵入。应用层将其视为一个普通的 MySQL 数据库，复杂的路由和分片由 Proxy 在协议层默默完成。
- **逻辑库与物理库映射：** 逻辑表（`t_user`）是业务视角的统一入口，物理表（`t_user_0`, `t_user_1`）是真实存储数据的载体。Proxy 负责解析 SQL 语法树（AST），将其改写为针对特定物理表的 SQL。
- **读写分离与分片嵌套：** 架构中先定义了读写分离的逻辑数据源（主库+特定从库），再在此基础上配置数据分片规则。这保证了主库集中处理事务，而读压力被精准分摊到对应的从库上。

------

## 五、 常见问题排查指南 (供实验报告记录)

**问题 1：数据写入成功，但立刻读取却查不到数据。**

- **排查方向：** MySQL 主从同步延迟。写操作落在 `ds_master`，读操作瞬间落在 `ds_slave_0` 或 `ds_slave_1`，若 Binlog 尚未同步完成就会出现此现象。
- **解决方案：** 对业务一致性要求高的查询，可通过 ShardingSphere Hint 强制路由到主库读取；或在实验环境中验证时，增加极短暂的 sleep 时间。

**问题 2：Spring Boot 启动报错，无法连接 ShardingSphere-Proxy。**

- **排查方向：** 容器启动顺序问题。Proxy 尚未完成初始化（加载 MySQL 节点），Spring Boot 就尝试建立连接池。
- **解决方案：** 在 `docker-compose.yml` 中为 Proxy 添加基于端口检查的 `healthcheck`，并在 Spring Boot 服务中设置严格的 `depends_on: condition: service_healthy`。

**问题 3：路由结果与预期不符（例如本该去从库 0 的读请求，去到了主库）。**

- **排查方向：** SQL 不规范或强制包含事务。如果在 Spring Boot 的查询方法上加了 `@Transactional`，Proxy 为了保证一致性，会将该事务内的所有读写请求全部路由到主库。
- **解决方案：** 剥离纯查询方法的事务注解，确保其通过读写分离规则路由至从库。