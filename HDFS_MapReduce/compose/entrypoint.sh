#!/bin/bash

# Start SSH daemon
service ssh start

# Share SSH keys between containers (for passwordless SSH)
if [ ! -f /home/hadoop/.ssh/shared_done ]; then
    # Wait for shared volume
    sleep 2

    # Copy public key to shared volume
    cp /home/hadoop/.ssh/id_rsa.pub /home/hadoop/.ssh/shared/${HOSTNAME}.pub 2>/dev/null || true

    # Wait for all nodes to share their keys
    sleep 5

    # Add all public keys to authorized_keys
    for key in /home/hadoop/.ssh/shared/*.pub; do
        if [ -f "$key" ]; then
            cat "$key" >> /home/hadoop/.ssh/authorized_keys
        fi
    done

    chmod 600 /home/hadoop/.ssh/authorized_keys
    chown hadoop:hadoop /home/hadoop/.ssh/authorized_keys
    touch /home/hadoop/.ssh/shared_done
fi

# If this is NameNode (node1)
if [ "$HADOOP_ROLE" = "namenode" ]; then
    # Format NameNode if not already formatted
    if [ ! -d /home/hadoop/hadoopdata/namenode/current ]; then
        echo "Formatting NameNode..."
        su - hadoop -c "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 && \
            export HADOOP_HOME=/opt/hadoop && \
            export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin && \
            hdfs namenode -format -force"
    fi

    # Wait for DataNodes to be ready
    echo "Waiting for DataNodes..."
    sleep 10

    # Start HDFS and YARN
    su - hadoop -c "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 && \
        export HADOOP_HOME=/opt/hadoop && \
        export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop && \
        export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin && \
        export HDFS_NAMENODE_USER=hadoop && \
        export HDFS_DATANODE_USER=hadoop && \
        export HDFS_SECONDARYNAMENODE_USER=hadoop && \
        export YARN_RESOURCEMANAGER_USER=hadoop && \
        export YARN_NODEMANAGER_USER=hadoop && \
        start-dfs.sh && start-yarn.sh"

    echo "=========================================="
    echo " Hadoop Cluster Started!"
    echo " HDFS Web UI:  http://localhost:9870"
    echo " YARN Web UI:  http://localhost:8088"
    echo "=========================================="
fi

# Keep container running
tail -f /dev/null