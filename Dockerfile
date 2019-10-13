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
