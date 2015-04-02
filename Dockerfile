FROM ubuntu:14.04
MAINTAINER nasuno@ascade.co.jp

RUN apt-get update && \
    apt-get -y install \
      curl \
      wget \
      git \
      libapr1-dev \
      libcurl4-openssl-dev \
      libsasl2-dev \
      libsvn-dev \
      openjdk-7-jdk \
      openssh-server \
      python-dev \
      zookeeper

# Ensure java 7 is the default java.
update-alternatives --set java /usr/lib/jvm/java-7-openjdk-amd64/jre/bin/java

# Docker
RUN wget -qO- https://get.docker.com/ | sh

# Aurora
RUN git clone https://github.com/apache/incubator-aurora.git /aurora
ENV MESOS_VERSION 0.21.1
RUN mkdir -p /aurora/third_party
ADD https://svn.apache.org/repos/asf/incubator/aurora/3rdparty/ubuntu/trusty64/python/mesos.native-$MESOS_VERSION-py2.7-linux-x86_64.egg /aurora/third_party/
ADD http://people.apache.org/~jfarrell/thrift/0.9.1/contrib/deb/ubuntu/12.04/thrift-compiler_0.9.1_amd64.deb /
ADD http://downloads.mesosphere.io/master/ubuntu/12.04/mesos_$MESOS_VERSION-1.0.ubuntu1204_amd64.deb /
RUN dpkg --install thrift-compiler_0.9.1_amd64.deb
RUN dpkg --install mesos_$MESOS_VERSION-1.0.ubuntu1204_amd64.deb

# Docker-in-Docker
ADD https://raw.githubusercontent.com/jpetazzo/dind/master/wrapdocker /usr/local/bin/
RUN chmod +x /usr/local/bin/wrapdocker && chown root:root /usr/local/bin/wrapdocker
RUN sed -i 's/exec bash/#exec bash/' /usr/local/bin/wrapdocker
RUN printf '#!/bin/bash\nexit 0\n' > /sbin/apparmor_parser && \
    chmod +x /sbin/apparmor_parser

# sshd
RUN mkdir -p /var/run/sshd
RUN sed -i 's/^PermitRootLogin without-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
RUN sed -i 's/.*session.*required.*pam_loginuid.so.*/session optional pam_loginuid.so/g' /etc/pam.d/sshd

# script
RUN printf '#!/bin/bash\n\n/usr/sbin/sshd -D\n' > /usr/local/bin/init.sh && \
    chmod +x /usr/local/bin/init.sh
ADD setup-master.sh /usr/local/bin/
ADD setup-slave.sh /usr/local/bin/

# build aurora
ADD _aurorabuild.sh /aurora/
RUN cd /aurora && bash ./_aurorabuild.sh
RUN mkdir -p /etc/aurora

CMD ["/usr/local/bin/init.sh"]
