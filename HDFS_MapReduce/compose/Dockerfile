FROM ubuntu:22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    openjdk-11-jdk \
    ssh \
    rsync \
    curl \
    net-tools \
    nano \
    && rm -rf /var/lib/apt/lists/*

# Set Java
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64

# Create hadoop user
RUN useradd -ms /bin/bash hadoop && \
    echo "hadoop:hadoop" | chpasswd && \
    usermod -aG sudo hadoop

# Download Hadoop
ARG HADOOP_VERSION=3.3.6
RUN curl -fSL https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz \
    -o /tmp/hadoop.tar.gz && \
    tar -xzf /tmp/hadoop.tar.gz -C /opt/ && \
    mv /opt/hadoop-${HADOOP_VERSION} /opt/hadoop && \
    chown -R hadoop:hadoop /opt/hadoop && \
    rm /tmp/hadoop.tar.gz

# Set Hadoop environment
ENV HADOOP_HOME=/opt/hadoop
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

# SSH setup
RUN ssh-keygen -t rsa -P "" -f /root/.ssh/id_rsa && \
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys && \
    chmod 600 /root/.ssh/authorized_keys

USER hadoop
RUN mkdir -p /home/hadoop/.ssh && \
    ssh-keygen -t rsa -P "" -f /home/hadoop/.ssh/id_rsa && \
    cat /home/hadoop/.ssh/id_rsa.pub >> /home/hadoop/.ssh/authorized_keys && \
    chmod 600 /home/hadoop/.ssh/authorized_keys

# Create data directories
RUN mkdir -p /home/hadoop/hadoopdata/namenode \
             /home/hadoop/hadoopdata/datanode \
             /home/hadoop/hadoopdata/tmp

USER root

# SSH config - no strict host checking
RUN echo "Host *\n  StrictHostKeyChecking no\n  UserKnownHostsFile /dev/null" > /home/hadoop/.ssh/config && \
    chown hadoop:hadoop /home/hadoop/.ssh/config && \
    chmod 600 /home/hadoop/.ssh/config

# Configure sshd
RUN mkdir -p /var/run/sshd && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

# Set JAVA_HOME in hadoop-env.sh
RUN echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh

# Copy config files
COPY config/* $HADOOP_CONF_DIR/

# Set permissions
RUN chown -R hadoop:hadoop $HADOOP_HOME

# Hadoop env vars for start scripts
ENV HDFS_NAMENODE_USER=hadoop
ENV HDFS_DATANODE_USER=hadoop
ENV HDFS_SECONDARYNAMENODE_USER=hadoop
ENV YARN_RESOURCEMANAGER_USER=hadoop
ENV YARN_NODEMANAGER_USER=hadoop

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 9870 9000 8088 9864 9868

ENTRYPOINT ["/entrypoint.sh"]