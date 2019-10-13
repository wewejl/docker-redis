# 一.创建redis docker基础镜像

1.下载redis安装包，使用版本为：redis-5.0.4

```shell
$ wget http://download.redis.io/releases/redis-5.0.4.tar.gz
```

2.解压编译redis

```shell
$ tar zxvf redis-5.0.4.tar.gz
$ cd   redis-5.0.4/
$ make
```

3.修改redis配置

```shell
$ vim  redis.conf
```

修改bind ip地址

```shell
# ~~~ WARNING ~~~ If the computer running Redis is directly exposed to the
# internet, binding to all the interfaces is dangerous and will expose the
# instance to everybody on the internet. So by default we uncomment the
# following bind directive, that will force Redis to listen only into
# the IPv4 lookback interface address (this means Redis will be able to
# accept connections only from clients running into the same computer it
# is running).
#
# IF YOU ARE SURE YOU WANT YOUR INSTANCE TO LISTEN TO ALL THE INTERFACES
# JUST COMMENT THE FOLLOWING LINE.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#bind 127.0.0.1
bind 0.0.0.0
```

将守护进程yes改成no

```shell
# By default Redis does not run as a daemon. Use 'yes' if you need it.
# Note that Redis will write a pid file in /var/run/redis.pid when daemonized.
daemonize no
```

将密码项注释去掉，添加新密码

```shell
# Warning: since Redis is pretty fast an outside user can try up to
# 150k passwords per second against a good box. This means that you should
# use a very strong password otherwise it will be very easy to break.
#
# requirepass foobared
```

修改为123456

```shell
# Warning: since Redis is pretty fast an outside user can try up to
# 150k passwords per second against a good box. This means that you should
# use a very strong password otherwise it will be very easy to break.
#
requirepass 123456
```

因为配置了密码，所以，配置中另外一处主从连接也需要配置密码

```shell
# If the master is password protected (using the "requirepass" configuration
# directive below) it is possible to tell the slave to authenticate before
# starting the replication synchronization process, otherwise the master will
# refuse the slave request.
#
# masterauth <master-password>
```

修改为

```shell
# If the master is password protected (using the "requirepass" configuration
# directive below) it is possible to tell the slave to authenticate before
# starting the replication synchronization process, otherwise the master will
# refuse the slave request.
#
# masterauth <master-password>
masterauth 123456
```





设置日志路径

```shell
# Specify the log file name. Also the empty string can be used to force
# Redis to log on the standard output. Note that if you use standard
# output for logging but daemonize, logs will be sent to /dev/null
logfile "/var/log/redis/redis-server.log"
```

配置集群相关信息，去掉配置项前面的注释

```shell
# Normal Redis instances can't be part of a Redis Cluster; only nodes that are
# started as cluster nodes can. In order to start a Redis instance as a
# cluster node enable the cluster support uncommenting the following:
#
cluster-enabled yes
 
# Every cluster node has a cluster configuration file. This file is not
# intended to be edited by hand. It is created and updated by Redis nodes.
# Every Redis Cluster node requires a different cluster configuration file.
# Make sure that instances running in the same system do not have
# overlapping cluster configuration file names.
#
cluster-config-file nodes-6379.conf
 
# Cluster node timeout is the amount of milliseconds a node must be unreachable
# for it to be considered in failure state.
# Most other internal time limits are multiple of the node timeout.
#
cluster-node-timeout 15000
```

4.镜像制作

```shell
$ cd /docker_redis_cluster
$ vim Dockerfile
```

   Dockerfile 文件

```shell
# 基础镜像
FROM ubuntu:latest

# 镜像作者
MAINTAINER zhuxinye 1024344053@qq.com

# 执行命令
# 这个是把apt环境换成 中国科大
RUN sed -i 's/archive.canonical.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list
#配置redis环境
ENV REDIS_HOME /usr/local
#将宿主机的redis压缩包，拷贝
ADD ["redis-5.0.4.tar.gz","/"]
#创建安装目录
RUN mkdir -p $REDIS_HOME/redis
ADD ["redis.conf","/usr/local/redis/"]
#来到redis-5.0.4目录里面
WORKDIR /redis-5.0.4
#安装基础工具
RUN apt-get update && apt-get install gcc make -y
#进行编译
RUN make
#编译后，容器只需要可执行文件redis-server
RUN mv /redis-5.0.4/src/redis-server $REDIS_HOME/redis/

WORKDIR /
#删除解压文件
RUN rm -rf /redis-5.0.4
#添加数据卷
VOLUME ["/var/log/redis"]
#暴露端口
EXPOSE 6379

```

PS.当前镜像非可执行镜像，所以没有包含ENTRYPOINT和CMD指令

5.构建镜像 

```shell
 $ docker build -t ubt_redis0 .
 
 ...
 
Complete!
 ---> 546cb1d34f35
Removing intermediate container 6b6556c5f28d
Step 14/15 : VOLUME /var/log/redis
 ---> Running in 05a6642e4046
 ---> e7e2fb8676b2
Removing intermediate container 05a6642e4046
Step 15/15 : EXPOSE 6379
 ---> Running in 5d7abe1709e2
 ---> 2d1322475f79
Removing intermediate container 5d7abe1709e2
Successfully built 2d1322475f79

```

查看镜像：

```shell
$ docker images


REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
ubt_redis0          v1.0                c204f2906c63        5 hours ago         332MB
```

以上制作redis节点镜像就制作完成了

## 二、制作redis节点镜像

1.基于此前制作的redis基础镜像创建一个redis节点镜像

```shell
$ mkdir docker_redis_nodes
$ cd docker_redis_nodes
$ vim Dockerfile

# 制作redis节点镜像
# Version 4.0.1 版

FROM ubt_redis0:v1.0

# 作者小猪
MAINTAINER zhuxinye 1024344053@qq.com

ENTRYPOINT ["/usr/local/redis/redis-server","/usr/local/redis/redis.conf"]
```

2.构建redis节点镜像 

```shell
$ docker build -t nodes-redis:4.0.1 .

Sending build context to Docker daemon 2.048 kB
Step 1/3 : FROM hakimdstx/cluster-redis:4.0.1
 ---> 1fca5a08a4c7
Step 2/3 : MAINTAINER hakim 1194842583@qq.com
 ---> Running in cc6e07eb2c36
 ---> 55769d3bfacb
Removing intermediate container cc6e07eb2c36
Step 3/3 : ENTRYPOINT /usr/local/redis/redis-server /usr/local/redis/redis.conf
 ---> Running in f5dedf88f6f6
 ---> da64da483559
Removing intermediate container f5dedf88f6f6
Successfully built da64da483559
```



3.查看镜像

```shell
$ docker images

REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
ubt_redis0          v1.0                c204f2906c63        5 hours ago         332MB
nodes-redis         4.0.1               90e070b9ff3d        5 hours ago         332MB
```

三.运行redis集群

1.运行redis容器

```shell
[root@etcd3 docker_redis_nodes]# docker run -d --name redis-6379 -p 6379:6379 hakimdstx/nodes-redis:4.0.1  
1673a7d859ea83257d5bf14d82ebf717fb31405c185ce96a05f597d8f855aa7d
[root@etcd3 docker_redis_nodes]# docker run -d --name redis-6380 -p 6380:6379 hakimdstx/nodes-redis:4.0.1   
df6ebce6f12a6f3620d5a29adcfbfa7024e906c3af48f21fa7e1fa524a361362
[root@etcd3 docker_redis_nodes]# docker run -d --name redis-6381 -p 6381:6379 hakimdstx/nodes-redis:4.0.1  
396e174a1d9235228b3c5f0266785a12fb1ea49efc7ac755c9e7590e17aa1a79
[root@etcd3 docker_redis_nodes]# docker run -d --name redis-6382 -p 6382:6379 hakimdstx/nodes-redis:4.0.1
d9a71dd3f969094205ffa7596c4a04255575cdd3acca2d47fe8ef7171a3be528
[root@etcd3 docker_redis_nodes]# docker run -d --name redis-6383 -p 6383:6379 hakimdstx/nodes-redis:4.0.1
73e4f843d8cb28595456e21b04f97d18ce1cdf8dc56d1150844ba258a3781933
[root@etcd3 docker_redis_nodes]# docker run -d --name redis-6384 -p 6384:6379 hakimdstx/nodes-redis:4.0.1
10c62aafa4dac47220daf5bf3cec84406f086d5261599b54ec6c56bb7da97d6d
```

2.查看容器信息

```shell
[root@etcd3 redis]# docker ps
CONTAINER ID        IMAGE                         COMMAND                  CREATED             STATUS              PORTS                    NAMES
10c62aafa4da        hakimdstx/nodes-redis:4.0.1   "/usr/local/redis/..."   3 seconds ago       Up 2 seconds        0.0.0.0:6384->6379/tcp   redis-6384
73e4f843d8cb        hakimdstx/nodes-redis:4.0.1   "/usr/local/redis/..."   12 seconds ago      Up 10 seconds       0.0.0.0:6383->6379/tcp   redis-6383
d9a71dd3f969        hakimdstx/nodes-redis:4.0.1   "/usr/local/redis/..."   20 seconds ago      Up 18 seconds       0.0.0.0:6382->6379/tcp   redis-6382
396e174a1d92        hakimdstx/nodes-redis:4.0.1   "/usr/local/redis/..."   3 days ago          Up 3 days           0.0.0.0:6381->6379/tcp   redis-6381
df6ebce6f12a        hakimdstx/nodes-redis:4.0.1   "/usr/local/redis/..."   3 days ago          Up 3 days           0.0.0.0:6380->6379/tcp   redis-6380
1673a7d859ea        hakimdstx/nodes-redis:4.0.1   "/usr/local/redis/..."   3 days ago          Up 3 days           0.0.0.0:6379->6379/tcp   redis-6379
```

3.运行 redis 集群容器
		1.通过远程连接，查看redis  info replication 信息

```shell
[root@etcd2 ~]#  redis-cli -h 192.168.10.52 -p 6379
192.168.10.52:6379> info replication
NOAUTH Authentication required.
192.168.10.52:6379> auth 123456
OK
192.168.10.52:6379> info replication
# Replication
role:master
connected_slaves:0
master_replid:2f0a7b50aed699fa50a79f3f7f9751a070c50ee9
master_replid2:0000000000000000000000000000000000000000
master_repl_offset:0
second_repl_offset:-1
repl_backlog_active:0
repl_backlog_size:1048576
repl_backlog_first_byte_offset:0
repl_backlog_histlen:0
192.168.10.52:6379>
# 其余基本信息同上
```

可以看到，客户连接之后，因为之前设置了密码，所以需要先输入密码认证，否则就无法通过。以上信息，我们知道所有的redis都是master角色 role:master ，这显然不是我们所希望的。

​		2在配置之前我们需要查看所有容器当前的IP地址

```shell
[root@etcd3 redis]# docker ps
CONTAINER ID        IMAGE                         COMMAND                  CREATED             STATUS              PORTS                    NAMES
10c62aafa4da        hakimdstx/nodes-redis:4.0.1   "/usr/local/redis/..."   3 seconds ago       Up 2 seconds        0.0.0.0:6384->6379/tcp   redis-6384
73e4f843d8cb        hakimdstx/nodes-redis:4.0.1   "/usr/local/redis/..."   12 seconds ago      Up 10 seconds       0.0.0.0:6383->6379/tcp   redis-6383
d9a71dd3f969        hakimdstx/nodes-redis:4.0.1   "/usr/local/redis/..."   20 seconds ago      Up 18 seconds       0.0.0.0:6382->6379/tcp   redis-6382
396e174a1d92        hakimdstx/nodes-redis:4.0.1   "/usr/local/redis/..."   3 days ago          Up 3 days           0.0.0.0:6381->6379/tcp   redis-6381
df6ebce6f12a        hakimdstx/nodes-redis:4.0.1   "/usr/local/redis/..."   3 days ago          Up 3 days           0.0.0.0:6380->6379/tcp   redis-6380
1673a7d859ea        hakimdstx/nodes-redis:4.0.1   "/usr/local/redis/..."   3 days ago          Up 3 days           0.0.0.0:6379->6379/tcp   redis-6379
[root@etcd3 redis]#
[root@etcd3 redis]# docker inspect 10c62aafa4da 73e4f843d8cb d9a71dd3f969 396e174a1d92 df6ebce6f12a 1673a7d859ea | grep IPA
            "SecondaryIPAddresses": null,
            "IPAddress": "172.17.0.7",
                    "IPAMConfig": null,
                    "IPAddress": "172.17.0.7",
            "SecondaryIPAddresses": null,
            "IPAddress": "172.17.0.6",
                    "IPAMConfig": null,
                    "IPAddress": "172.17.0.6",
            "SecondaryIPAddresses": null,
            "IPAddress": "172.17.0.5",
                    "IPAMConfig": null,
                    "IPAddress": "172.17.0.5",
            "SecondaryIPAddresses": null,
            "IPAddress": "172.17.0.4",
                    "IPAMConfig": null,
                    "IPAddress": "172.17.0.4",
            "SecondaryIPAddresses": null,
            "IPAddress": "172.17.0.3",
                    "IPAMConfig": null,
                    "IPAddress": "172.17.0.3",
            "SecondaryIPAddresses": null,
            "IPAddress": "172.17.0.2",
                    "IPAMConfig": null,
                    "IPAddress": "172.17.0.2",
```

可以知道：  redis-6379：172.17.0.2，redis-6380：172.17.0.3，redis-6381：172.17.0.4，redis-6382：172.17.0.5，redis-6383：172.17.0.6，redis-6384：172.17.0.7  

​			3.配置redis

​			4.ert

4.Redis Cluster 的集群感知操作

```shell
//集群(cluster) 
CLUSTER INFO 打印集群的信息 
CLUSTER NODES 列出集群当前已知的所有节点（node），以及这些节点的相关信息。  
   
//节点(node) 
CLUSTER MEET <ip> <port> 将 ip 和 port 所指定的节点添加到集群当中，让它成为集群的一份子。 
CLUSTER FORGET <node_id> 从集群中移除 node_id 指定的节点。 
CLUSTER REPLICATE <node_id> 将当前节点设置为 node_id 指定的节点的从节点。 
CLUSTER SAVECONFIG 将节点的配置文件保存到硬盘里面。  
   
//槽(slot) 
CLUSTER ADDSLOTS <slot> [slot ...] 将一个或多个槽（slot）指派（assign）给当前节点。 
CLUSTER DELSLOTS <slot> [slot ...] 移除一个或多个槽对当前节点的指派。 
CLUSTER FLUSHSLOTS 移除指派给当前节点的所有槽，让当前节点变成一个没有指派任何槽的节点。 
CLUSTER SETSLOT <slot> NODE <node_id> 将槽 slot 指派给 node_id 指定的节点，如果槽已经指派给另一个节点，那么先让另一个节点删除该槽>，然后再进行指派。 
CLUSTER SETSLOT <slot> MIGRATING <node_id> 将本节点的槽 slot 迁移到 node_id 指定的节点中。 
CLUSTER SETSLOT <slot> IMPORTING <node_id> 从 node_id 指定的节点中导入槽 slot 到本节点。 
CLUSTER SETSLOT <slot> STABLE 取消对槽 slot 的导入（import）或者迁移（migrate）。  
   
//键 (key) 
CLUSTER KEYSLOT <key> 计算键 key 应该被放置在哪个槽上。 
CLUSTER COUNTKEYSINSLOT <slot> 返回槽 slot 目前包含的键值对数量。 
CLUSTER GETKEYSINSLOT <slot> <count> 返回 count 个 slot 槽中的键。
```

redis 集群感知：节点握手——是指一批运行在集群模式的节点通过`Gossip`协议彼此通信，达到感知对方的过程。

```go
这个后面一定要是 6379 
192.168.10.52:6379> CLUSTER MEET 172.17.0.3 6379
OK
192.168.10.52:6379> CLUSTER MEET 172.17.0.4 6379
OK
192.168.10.52:6379> CLUSTER MEET 172.17.0.5 6379
OK
192.168.10.52:6379> CLUSTER MEET 172.17.0.6 6379
OK
192.168.10.52:6379> CLUSTER MEET 172.17.0.7 6379
OK
192.168.10.52:6379>  CLUSTER NODES
54cb5c2eb8e5f5aed2d2f7843f75a9284ef6785c 172.17.0.3:6379@16379 master - 0 1528697195600 1 connected
f45f9109f2297a83b1ac36f9e1db5e70bbc174ab 172.17.0.4:6379@16379 master - 0 1528697195600 0 connected
ae86224a3bc29c4854719c83979cb7506f37787a 172.17.0.7:6379@16379 master - 0 1528697195600 5 connected
98aebcfe42d8aaa8a3375e4a16707107dc9da683 172.17.0.6:6379@16379 master - 0 1528697194000 4 connected
0bbdc4176884ef0e3bb9b2e7d03d91b0e7e11f44 172.17.0.5:6379@16379 master - 0 1528697194995 3 connected
760e4d0039c5ac13d04aa4791c9e6dc28544d7c7 172.17.0.2:6379@16379 myself,master - 0 1528697195000 2 connected
```



当前已经使这六个节点组成集群，但是现在还无法工作，因为集群节点还没有分配槽（slot）。

​			1.分配槽信息
​				查看172.17.0.2:6379 的槽个数

```shell
192.168.10.52:6379> CLUSTER INFO
cluster_state:fail
cluster_slots_assigned:0    # 被分配槽的个数为0
cluster_slots_ok:0
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:6
cluster_size:0
cluster_current_epoch:5
cluster_my_epoch:2
cluster_stats_messages_ping_sent:260418
cluster_stats_messages_pong_sent:260087
cluster_stats_messages_meet_sent:10
cluster_stats_messages_sent:520515
cluster_stats_messages_ping_received:260086
cluster_stats_messages_pong_received:260328
cluster_stats_messages_meet_received:1
cluster_stats_messages_received:520415
```

上面看到集群状态是失败的，原因是槽位没有分配，而且需要一次性把16384个槽位完全分配了，集群才可用。

2.分配槽位：CLUSTER ADDSLOTS  槽位，一个槽位只能分配一个节点，16384个槽位必须分配完，不同节点不能冲突。

所以通过脚本进行分配 addslots.sh：

```shell
#!/bin/bash
# node1 192.168.10.52   172.17.0.2
n=0
for ((i=n;i<=5461;i++))
do
   /usr/local/bin/redis-cli -h 192.168.10.52 -p 6379 -a 123456  CLUSTER ADDSLOTS $i
done
 
 
# node2 192.168.10.52    172.17.0.3
n=5462
for ((i=n;i<=10922;i++))
do
   /usr/local/bin/redis-cli -h 192.168.10.52 -p 6380 -a 123456 CLUSTER ADDSLOTS $i
done
 
 
# node3 192.168.10.52    172.17.0.4
n=10923
for ((i=n;i<=16383;i++))
do
   /usr/local/bin/redis-cli -h 192.168.10.52 -p 6381 -a 123456 CLUSTER ADDSLOTS $i
done
```

其中， -a 123456  表示需要输入的密码。

```shell
以前的
192.168.10.52:6379> CLUSTER INFO
cluster_state:fail　　　　       # 集群状态为失败
cluster_slots_assigned:16101    # 没有完全分配结束
cluster_slots_ok:16101
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:6
cluster_size:3
cluster_current_epoch:5
cluster_my_epoch:2
cluster_stats_messages_ping_sent:266756
cluster_stats_messages_pong_sent:266528
cluster_stats_messages_meet_sent:10
cluster_stats_messages_sent:533294
cluster_stats_messages_ping_received:266527
cluster_stats_messages_pong_received:266666
cluster_stats_messages_meet_received:1
cluster_stats_messages_received:533194<br>
现在的
192.168.10.52:6379> CLUSTER INFO
cluster_state:ok                   # 集群状态为成功
cluster_slots_assigned:16384       # 已经全部分配完成
cluster_slots_ok:16384
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:6
cluster_size:3
cluster_current_epoch:5
cluster_my_epoch:2
cluster_stats_messages_ping_sent:266757
cluster_stats_messages_pong_sent:266531
cluster_stats_messages_meet_sent:10
cluster_stats_messages_sent:533298
cluster_stats_messages_ping_received:266530
cluster_stats_messages_pong_received:266667
cluster_stats_messages_meet_received:1
cluster_stats_messages_received:533198
```

综上可知，当全部槽位分配完成之后，集群还是可行的，如果我们手欠，移除一个槽位，那么集群就立马那不行了，自己去试试吧 ——CLUSTER DELSLOTS 0 。

5.如何变成高可用性
以上我们已经搭建了一套完整的可运行的redis cluster，但是每个节点都是单点，这样子可能出现，一个节点挂掉，整个集群因为槽位分配不完全而崩溃，因此，我们需要为每个节点配置副本备用节点。
前面我们已经提前创建了6个备用节点，搭建集群花了三个，因此还有剩下三个直接可以用来做备用副本。

```shell
192.168.10.52:6379> CLUSTER INFO
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:6   # 总共6个节点
cluster_size:3          # 集群为 3 个节点
cluster_current_epoch:5
cluster_my_epoch:2
cluster_stats_messages_ping_sent:270127
cluster_stats_messages_pong_sent:269893
cluster_stats_messages_meet_sent:10
cluster_stats_messages_sent:540030
cluster_stats_messages_ping_received:269892
cluster_stats_messages_pong_received:270037
cluster_stats_messages_meet_received:1
cluster_stats_messages_received:539930
```

查看所有节点的id

```shell
192.168.10.52:6379> CLUSTER NODES
54cb5c2eb8e5f5aed2d2f7843f75a9284ef6785c 172.17.0.3:6379@16379 master - 0 1528704114535 1 connected 5462-10922
f45f9109f2297a83b1ac36f9e1db5e70bbc174ab 172.17.0.4:6379@16379 master - 0 1528704114000 0 connected 10923-16383
ae86224a3bc29c4854719c83979cb7506f37787a 172.17.0.7:6379@16379 master - 0 1528704114023 5 connected
98aebcfe42d8aaa8a3375e4a16707107dc9da683 172.17.0.6:6379@16379 master - 0 1528704115544 4 connected
0bbdc4176884ef0e3bb9b2e7d03d91b0e7e11f44 172.17.0.5:6379@16379 master - 0 1528704114836 3 connected
760e4d0039c5ac13d04aa4791c9e6dc28544d7c7 172.17.0.2:6379@16379 myself,master - 0 1528704115000 2 connected 0-5461
```

编写脚本，添加副本节点

```shell
[root@etcd2 tmp]# vim addSlaveNodes.sh
里面一定要加 CLUSTER REPLICATE 节点id

#!/bin/bash
 
/usr/local/bin/redis-cli -h 192.168.10.52 -p 6382 -a 123456 CLUSTER REPLICATE 760e4d0039c5ac13d04aa4791c9e6dc28544d7c7
 
/usr/local/bin/redis-cli -h 192.168.10.52 -p 6383 -a 123456 CLUSTER REPLICATE 54cb5c2eb8e5f5aed2d2f7843f75a9284ef6785c
 
/usr/local/bin/redis-cli -h 192.168.10.52 -p 6384 -a 123456 CLUSTER REPLICATE f45f9109f2297a83b1ac36f9e1db5e70bbc174ab
```

注意：1、作为备用的节点，必须是未分配槽位的，否者会操作失败 (error) ERR To set a master the node must be empty and without assigned slots 。
           2、需要从需要添加的节点上面执行操作，CLUSTER REPLICATE [node_id]  ，使当前节点成为 node_id 的副本节点。
           3、添加从节点（集群复制）： 复制的原理和单机的Redis复制原理一样，区别是：集群下的从节点也需要运行在cluster模式下，要先添加到集群里面，再做复制。
查看所有节点信息：

```shell
192.168.10.52:6379> CLUSTER NODES
54cb5c2eb8e5f5aed2d2f7843f75a9284ef6785c 172.17.0.3:6379@16379 master - 0 1528705604149 1 connected 5462-10922
f45f9109f2297a83b1ac36f9e1db5e70bbc174ab 172.17.0.4:6379@16379 master - 0 1528705603545 0 connected 10923-16383
ae86224a3bc29c4854719c83979cb7506f37787a 172.17.0.7:6379@16379 slave f45f9109f2297a83b1ac36f9e1db5e70bbc174ab 0 1528705603144 5 connected
98aebcfe42d8aaa8a3375e4a16707107dc9da683 172.17.0.6:6379@16379 slave 54cb5c2eb8e5f5aed2d2f7843f75a9284ef6785c 0 1528705603000 4 connected
0bbdc4176884ef0e3bb9b2e7d03d91b0e7e11f44 172.17.0.5:6379@16379 slave 760e4d0039c5ac13d04aa4791c9e6dc28544d7c7 0 1528705603000 3 connected
760e4d0039c5ac13d04aa4791c9e6dc28544d7c7 172.17.0.2:6379@16379 myself,master - 0 1528705602000 2 connected 0-5461
```

可以看到我们现在实现了三主三从的一个高可用集群。

6.高可用测试——故障转移
查看当前运行状态：

```shell
192.168.10.52:6379> CLUSTER NODES
54cb5c2eb8e5f5aed2d2f7843f75a9284ef6785c 172.17.0.3:6379@16379 master - 0 1528705604149 1 connected 5462-10922
f45f9109f2297a83b1ac36f9e1db5e70bbc174ab 172.17.0.4:6379@16379 master - 0 1528705603545 0 connected 10923-16383
ae86224a3bc29c4854719c83979cb7506f37787a 172.17.0.7:6379@16379 slave f45f9109f2297a83b1ac36f9e1db5e70bbc174ab 0 1528705603144 5 connected
98aebcfe42d8aaa8a3375e4a16707107dc9da683 172.17.0.6:6379@16379 slave 54cb5c2eb8e5f5aed2d2f7843f75a9284ef6785c 0 1528705603000 4 connected
0bbdc4176884ef0e3bb9b2e7d03d91b0e7e11f44 172.17.0.5:6379@16379 slave 760e4d0039c5ac13d04aa4791c9e6dc28544d7c7 0 1528705603000 3 connected
760e4d0039c5ac13d04aa4791c9e6dc28544d7c7 172.17.0.2:6379@16379 myself,master - 0 1528705602000 2 connected 0-5461
```

以上，运行正常



尝试关闭一个master，选择端口为6380的容器，停掉之后：

```shell
1:S 11 Jun 09:57:46.712 # Cluster state changed: ok
1:S 11 Jun 09:57:46.718 * (Non critical) Master does not understand REPLCONF listening-port: -NOAUTH Authentication required.
1:S 11 Jun 09:57:46.718 * (Non critical) Master does not understand REPLCONF capa: -NOAUTH Authentication required.
1:S 11 Jun 09:57:46.719 * Partial resynchronization not possible (no cached master)
1:S 11 Jun 09:57:46.719 # Unexpected reply to PSYNC from master: -NOAUTH Authentication required.
1:S 11 Jun 09:57:46.719 * Retrying with SYNC...
1:S 11 Jun 09:57:46.719 # MASTER aborted replication with an error: NOAUTH Authentication required.
1:S 11 Jun 09:57:46.782 * Connecting to MASTER 172.17.0.6:6379
1:S 11 Jun 09:57:46.782 * MASTER <-> SLAVE sync started
1:S 11 Jun 09:57:46.782 * Non blocking connect for SYNC fired the event.
```

可以看到，主从之间访问需要auth，之前忘记了配置 redis.conf  中的 # masterauth <master-password> ，所以导致主从之间无法通讯。修改配置之后，自动故障转移正常。



有时候需要实施人工故障转移：



登录6380端口的从节点：6383，执行 CLUSTER FAILOVER 命令：

```shell
192.168.10.52:6383> CLUSTER  FAILOVER
(error) ERR Master is down or failed, please use CLUSTER FAILOVER FORCE
```



发现因为master已经down了，所以我们需要执行强制转移



```shell
192.168.10.52:6383> CLUSTER FAILOVER FORCE
OK
```

查看当前 cluster node 情况：



```shell
192.168.10.52:6383>  CLUSTER NODES
0bbdc4176884ef0e3bb9b2e7d03d91b0e7e11f44 172.17.0.5:6379@16379 slave 760e4d0039c5ac13d04aa4791c9e6dc28544d7c7 0 1528707535332 3 connected
ae86224a3bc29c4854719c83979cb7506f37787a 172.17.0.7:6379@16379 slave f45f9109f2297a83b1ac36f9e1db5e70bbc174ab 0 1528707534829 5 connected
f45f9109f2297a83b1ac36f9e1db5e70bbc174ab 172.17.0.4:6379@16379 master - 0 1528707534527 0 connected 10923-16383
98aebcfe42d8aaa8a3375e4a16707107dc9da683 172.17.0.6:6379@16379 myself,master - 0 1528707535000 6 connected 5462-10922
760e4d0039c5ac13d04aa4791c9e6dc28544d7c7 172.17.0.2:6379@16379 master - 0 1528707535834 2 connected 0-5461
54cb5c2eb8e5f5aed2d2f7843f75a9284ef6785c 172.17.0.3:6379@16379 master,fail - 1528707472833 1528707472000 1 connected
```



从节点已经升级为master节点。这时候，我们尝试重启了，6380节点的redis（其实是重新启动停掉的容器）：



```shell
192.168.10.52:6383>  CLUSTER NODES
0bbdc4176884ef0e3bb9b2e7d03d91b0e7e11f44 172.17.0.5:6379@16379 slave 760e4d0039c5ac13d04aa4791c9e6dc28544d7c7 0 1528707556044 3 connected
ae86224a3bc29c4854719c83979cb7506f37787a 172.17.0.7:6379@16379 slave f45f9109f2297a83b1ac36f9e1db5e70bbc174ab 0 1528707555000 5 connected
f45f9109f2297a83b1ac36f9e1db5e70bbc174ab 172.17.0.4:6379@16379 master - 0 1528707556000 0 connected 10923-16383
98aebcfe42d8aaa8a3375e4a16707107dc9da683 172.17.0.6:6379@16379 myself,master - 0 1528707556000 6 connected 5462-10922
760e4d0039c5ac13d04aa4791c9e6dc28544d7c7 172.17.0.2:6379@16379 master - 0 1528707556000 2 connected 0-5461
54cb5c2eb8e5f5aed2d2f7843f75a9284ef6785c 172.17.0.3:6379@16379 slave 98aebcfe42d8aaa8a3375e4a16707107dc9da683 0 1528707556547 6 connected
```

我们发现，6380节点反而变成了 6383节点的从节点。





现在集群应该是完整的了，所以，集群状态应该已经恢复了，我们查看下：

```shell
192.168.10.52:6383> CLUSTER INFO
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:6
cluster_size:3
cluster_current_epoch:6
cluster_my_epoch:6
cluster_stats_messages_ping_sent:19419
cluster_stats_messages_pong_sent:19443
cluster_stats_messages_meet_sent:1
cluster_stats_messages_auth-req_sent:5
cluster_stats_messages_update_sent:1
cluster_stats_messages_sent:38869
cluster_stats_messages_ping_received:19433
cluster_stats_messages_pong_received:19187
cluster_stats_messages_meet_received:5
cluster_stats_messages_fail_received:4
cluster_stats_messages_auth-ack_received:2
cluster_stats_messages_received:38631
```

OK，没有问题。





7.集群访问
get key同时把该slot对应的节点告诉客户端，客户端可以去该节点执行命令
客户端在初始化的时候只需要知道一个节点的地址即可，客户端会先尝试向这个节点执行命令，比如   ，如果key所在的slot刚好在该节点上，则能够直接执行成功。如果slot不在该节点，则节点会返回MOVED错误，

```shell
192.168.10.52:6383> get hello
(error) MOVED 866 172.17.0.2:6379
 
192.168.10.52:6379> set number 20004
(error) MOVED 7743 172.17.0.3:6379
```

　另外，redis集群版只使用db0，select命令虽然能够支持select 0。其他的db都会返回错误。

```shell
192.168.10.52:6383> select 0
OK
192.168.10.52:6383> select 1
(error) ERR SELECT is not allowed in cluster mode
```

