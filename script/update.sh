#!/bin/bash
#########################
#Create Time: 2018-12-11
#Author: ccTian2015
#Email: chengcai.tian@cctian.com
#########################

#===============================公共变量=================================
#Source function library.（添加函数库）
. /etc/init.d/functions

#按任意键继续函数
get_char() 
{ 
SAVEDSTTY=`stty -g` 
stty -echo 
stty cbreak 
dd if=/dev/tty bs=1 count=1 2> /dev/null 
stty -raw 
stty echo 
stty $SAVEDSTTY 
} 


# Docker Image Warehouse (docker景象仓库地址)
REGISTRY_URL=192.168.1.201:5000
# Working Directory (工作目录)
WORK_DIR=/root/build
SERVICE_DIR=$WORK_DIR/app
# Date (时间格式)
DATE=`date +%Y%m%d%H%M%S`
# Update Service Name (需要更新的服务名)
JAR=`ls  $WORK_DIR | grep jar$`
JAR_NAME=`ls $JAR | awk -F '1.0' '{print $1}'`
SERVICENAME=${JAR_NAME%-*}
# Image Tag (镜像tag)
IMAGE_TAG=$REGISTRY_URL/$SERVICENAME:'v1.0'-$DATE
# Service update record (服务更新记录)
UPDATE_DIR=/root/build/log
UPDATE_DIR_DATE=`date +%Y-%m-%d`
UPDATE_FILE_DATE=`date +%H:%M:%S`
# Service port file (服务端口记录文件)
SERVICE_PORT_FILE=$WORK_DIR/config/ServicePort.txt


#Require root to run this script.（验证用户是否为root）
uid=`id | cut -d\( -f1 | cut -d= -f2`
if [ $uid -ne 0 ];then
  action "Please run this script as root." /bin/false
  action "请检查运行脚本的用户是否为ROOT." /bin/false
  exit 1
fi

#===============================逻辑代码=================================
dockerfile(){
cat <<EOF > $SERVICE_DIR/$SERVICENAME/dockerfile
FROM 192.168.1.201:5000/jdk:1.0.8_45
MAINTAINER ccTian2015
ADD ./$JAR  /data/service/$JAR
EXPOSE $SERVICE_PORT
COPY init.sh /data/service/init.sh
ENTRYPOINT ["/bin/bash","/data/service/init.sh"]
EOF
}

AdminCenterWeb(){
cat <<EOF > $SERVICE_DIR/$SERVICENAME/dockerfile
FROM 192.168.1.201:5000/jdk:1.0.8_45
MAINTAINER ccTian2015
VOLUME ["/home/yunbidding","/data/service/config"]
ADD ./$JAR  /data/service/$JAR
EXPOSE $SERVICE_PORT
COPY init.sh /data/service/init.sh
ENTRYPOINT ["/bin/bash","/data/service/init.sh"]
EOF
}

SERVICE_START(){
if [ $SERVICENAME == 'admin-center-web' ];then
  docker run -d --name $SERVICENAME -v /home/yunbidding:/home/yunbidding $IMAGE_TAG
elif [ $SERVICENAME == 'gateway' ];then
  echo "docker run -d --name $SERVICENAME -p $SERVICE_PORT:$SERVICE_PORT $IMAGE_TAG"
  docker run -d --name $SERVICENAME -p $SERVICE_PORT:$SERVICE_PORT $IMAGE_TAG
elif [ $SERVICENAME == 'discovery' ];then
  docker run -d --name $SERVICENAME -p $SERVICE_PORT:$SERVICE_PORT $IMAGE_TAG
elif [ $SERVICENAME == 'config' ];then
  docker run -d --name $SERVICENAME -p $SERVICE_PORT:$SERVICE_PORT -v /data/donghang/public/config/config:/data/service/config $IMAGE_TAG  
elif [ $SERVICENAME == 'trace-server' ];then
  #echo "docker run -d --name $SERVICENAME -p $SERVICE_PORT:$SERVICE_PORT $IMAGE_TAG"
  docker run -d --name $SERVICENAME -p $SERVICE_PORT:$SERVICE_PORT $IMAGE_TAG   >>/dev/null
else
  docker run -d --name $SERVICENAME  $IMAGE_TAG >>/dev/null
fi
}


START(){
PROCESS_NUM=`docker ps -a| grep $SERVICENAME | wc -l`
if [ $PROCESS_NUM == 0 ];then
  echo -e "\033[34m$SERVICENAME 服务未运行,现在开始启动......\033[0m"
  SERVICE_START
else
  SERVICE_STATUS=`docker inspect $SERVICENAME -f '{{.State.Status}}'`
  echo -e "\033[34m$SERVICENAME 的当前状态为$SERVICE_STATUS,现在开始更新...\033[0M"
  if [ $SERVICE_STATUS !=  'running' ];then
    docker rm $SERVICENAME
  else
    docker stop $SERVICENAME >> /dev/null
    CURRENT_STATUS=`docker inspect $SERVICENAME -f '{{.State.Status}}'`
    if [ $CURRENT_STATUS == 'exited' ];then
      echo -e "\033[34m$SERVICENAME的状态为:\033[0m\033[33m$CURRENT_STATUS \033[0m,\033[34m即将删除旧的\033[0m\033[33m$SERVICENAME\033[0m\033[34m容器\033[0m"
    else
      echo -e "\033[33m出现问题，请联系系统管理员。。。\033[0m"
      echo -e "\003[33m联系电话： \033[0m"
      exit 1
    fi
    docker rm $SERVICENAME  >> /dev/null
    DELETE_STATUS=`docker ps -a | grep $SERVICENAME | wc -l`
    if [ $DELETE_STATUS -eq 0 ];then
      echo -e "\033[34m旧的服务\033[0m\033[33m$SERVICENAME \033[0m\033[34m已删除\033[0m"
      echo -e "\033[34m即将启动您上传的服务:\033[0m\033[33m$JAR\033\0m"
    else
      echo -e "\033[34m出现问题，请联系系统管理员。。。\033[0m"
      echo -e "\003[34m联系电话： \033[0m"
      exit 1
    fi
    SERVICE_START
  fi
fi
}


EnvClear(){
if [ ! -d $UPDATE_DIR/$UPDATE_DIR_DATE ];then
  mkdir -p $UPDATE_DIR/$UPDATE_DIR_DATE
fi
echo "[update]--[$UPDATE_FILE_DATE] $SERVICENAME  $SERVICE_PORT  $IMAGE_TAG" >> $UPDATE_DIR/$UPDATE_DIR_DATE/update.log
if [ -e $SERVICE_DIR/$SERVICENAME/$JAR ];then
  rm -f $SERVICE_DIR/$SERVICENAME/$JAR
fi
if [ -e $SERVICE_DIR/$SERVICENAME/dockerfile ];then
  rm -f $SERVICE_DIR/$SERVICENAME/dockerfile
fi
#docker rmi $IMAGE_TAG >> /dev/null
}

clear
echo -e "\033[33m========================================\033[0m"
echo -e "\033[33m    您当前正在使用东航服务更新脚本      \033[0m"   
echo -e "\033[33m========================================\033[0m"
if [ `ls $WORK_DIR| grep jar$ | wc -l` -eq 1 ];then
  if [ `cat $SERVICE_PORT_FILE | grep $SERVICENAME| wc -l` -eq 1 ];then
    SERVICE_PORT=`cat $SERVICE_PORT_FILE | grep $SERVICENAME | awk '{print $2}'`
    if [ ! -d $SERVICE_DIR/$SERVICENAME ];then
      mkdir $SERVICE_DIR/$SERVICENAME
    fi
    echo -e "\033[34m正在更新的服务为:\033[0m\033[33m$SERVICENAME\033[0m"
    mv $WORK_DIR/$JAR $SERVICE_DIR/$SERVICENAME/
    if [ $SERVICENAME == 'admin-center-web' ] || [ $SERVICENAME == 'config' ];then
      AdminCenterWeb
    else
      dockerfile
    fi
    if [ ! -e $SERVICE_DIR/$SERVICENAME/init.sh ];then
      cp $WORK_DIR/config/init.sh $SERVICE_DIR/$SERVICENAME/
    fi
    echo -e "\033[34m开始制作镜像,镜像名为:\033[0m\033[33m$IMAGE_TAG\033[0m"
    cd $SERVICE_DIR/$SERVICENAME && docker build -t $IMAGE_TAG . >>/dev/null
    docker push $IMAGE_TAG >> /dev/null
    echo -e "\033[34m镜像制作完成，开始更新...... \033[0m"
    START
    EnvClear
    echo -e "\033[34m$SERVICENAME 更新完成,开始查看日志.如需退出请按 Ctrl +C\033[0m"
    sleep 5
    docker logs -f $SERVICENAME
  else
    clear
    echo -e "\033[31m###########################ERROR############################\033[0m"
    echo -e "你选择更新的服务包为:\033[31m $JAR \033[0m"
    echo -e "\033[31m$SERVICE_PORT_FILE\033[0m文件中没有该服务\033[31m$SERVICENAME\033[0m"
    echo -e "如果\033[31m$SERVICENAME\033[0m是所需的服务请更新此文件:\033[31m$SERVICE_PORT_FILE \033[0m"
    echo -e "\033[31m############################################################\033[0m"
  fi
else
  echo -e "\033[31m请把需要更新的Jar包放到本目录下......\033[0m"
  exit 1
fi

