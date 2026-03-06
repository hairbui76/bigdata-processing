# Hadoop 3-Node Cluster với Docker

## Mô hình

| Container | Hostname | Vai trò                                      |
| --------- | -------- | -------------------------------------------- |
| node1     | node1    | NameNode, SecondaryNameNode, ResourceManager |
| node2     | node2    | DataNode, NodeManager                        |
| node3     | node3    | DataNode, NodeManager                        |

## Cách sử dụng

### 1. Build và Start cluster

```bash
cd hadoop-docker
docker compose up -d --build
```

Lần đầu build sẽ mất khoảng 5-10 phút (tải Hadoop ~700MB).

### 2. Kiểm tra cluster

Đợi khoảng 30 giây sau khi start, rồi:

```bash
# Xem log node1
docker logs node1

# Vào node1 để thao tác
docker exec -it -u hadoop node1 bash

# Trong container node1:
hdfs dfsadmin -report
jps
```

### 3. Web UI

- **HDFS**: http://localhost:9870
- **YARN**: http://localhost:8088

### 4. Thử nghiệm HDFS

```bash
docker exec -it -u hadoop node1 bash

# Tạo thư mục
hdfs dfs -mkdir -p /user/hadoop/input

# Tạo file test và upload
echo "Hello Hadoop Docker" > /tmp/test.txt
hdfs dfs -put /tmp/test.txt /user/hadoop/input/

# Liệt kê
hdfs dfs -ls /user/hadoop/input/

# Đọc file
hdfs dfs -cat /user/hadoop/input/test.txt
```

### 5. Chạy MapReduce WordCount

```bash
docker exec -it -u hadoop node1 bash

# Tạo input
echo "hello world hello hadoop" > /tmp/words.txt
hdfs dfs -mkdir -p /user/hadoop/wordcount/input
hdfs dfs -put /tmp/words.txt /user/hadoop/wordcount/input/

# Chạy WordCount
hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.4.3.jar \
    wordcount /user/hadoop/wordcount/input /user/hadoop/wordcount/output

# Xem kết quả
hdfs dfs -cat /user/hadoop/wordcount/output/part-r-00000
```

### 6. Dừng cluster

```bash
docker compose down
```

### 7. Xóa toàn bộ data (reset)

```bash
docker compose down -v
```

## Troubleshooting

### DataNode không hiện

```bash
# Xem log DataNode
docker logs node2
docker logs node3

# Nếu ClusterID không khớp, reset:
docker compose down -v
docker compose up -d --build
```

### Kiểm tra SSH giữa các node

```bash
docker exec -it -u hadoop node1 bash
ssh node2 "echo ok"
ssh node3 "echo ok"
```

### Xem chi tiết log

```bash
docker exec -it node1 bash
cat /opt/hadoop/logs/hadoop-hadoop-namenode-*.log | tail -50
```
