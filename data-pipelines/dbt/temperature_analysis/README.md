Welcome to your new dbt project!

### Using the starter project

Try running the following commands:
- dbt run
- dbt test


### Resources:
- Learn more about dbt [in the docs](https://docs.getdbt.com/docs/introduction)
- Check out [Discourse](https://discourse.getdbt.com/) for commonly asked questions and answers
- Join the [chat](https://community.getdbt.com/) on Slack for live discussions and support
- Find [dbt events](https://events.getdbt.com) near you
- Check out [the blog](https://blog.getdbt.com/) for the latest news on dbt's development and best practices


### put jars in jars/
./bin/spark-sql \
  --packages org.postgresql:postgresql:42.6.0 \
  --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
  --conf spark.sql.catalog.sensors=org.apache.iceberg.spark.SparkCatalog \
  --conf spark.sql.catalog.sensors.type=jdbc \
  --conf spark.sql.catalog.sensors.uri=jdbc:postgresql://localhost:5432/smartstar \
  --conf spark.sql.catalog.sensors.jdbc.user=smartstar \
  --conf spark.sql.catalog.sensors.jdbc.password=smartstar \
  --conf spark.sql.catalog.sensors.warehouse=s3a://smartstar/development/silver/sensors/ \
  --conf spark.sql.catalog.sensors.jdbc.schema-version=V1 \
  --conf spark.sql.shuffle.partitions=8 \
  --conf spark.sql.adaptive.enabled=false \
  --conf spark.sql.adaptive.advisoryPartitionSizeInBytes=67108864 \
  --conf spark.hadoop.fs.s3a.access.key=minioadmin \
  --conf spark.hadoop.fs.s3a.secret.key=minioadmin \
  --conf spark.hadoop.fs.s3a.endpoint=http://localhost:9000 \
  --conf spark.hadoop.fs.s3a.path.style.access=true \
  --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
  
./sbin/start-thriftserver.sh   
--packages org.postgresql:postgresql:42.6.0   
--conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions   --conf spark.sql.catalog.sensors=org.apache.iceberg.spark.SparkCatalog   --conf spark.sql.catalog.sensors.type=jdbc   --conf spark.sql.catalog.sensors.uri=jdbc:postgresql://localhost:5432/smartstar   --conf spark.sql.catalog.sensors.jdbc.user=smartstar   --conf spark.sql.catalog.sensors.jdbc.password=smartstar   --conf spark.sql.catalog.sensors.warehouse=s3a://smartstar/development/silver/sensors/   --conf spark.sql.shuffle.partitions=8   --conf spark.sql.adaptive.enabled=false   --conf spark.sql.adaptive.advisoryPartitionSizeInBytes=67108864   --conf spark.hadoop.fs.s3a.access.key=minioadmin   --conf spark.hadoop.fs.s3a.secret.key=minioadmin   --conf spark.hadoop.fs.s3a.endpoint=http://localhost:9000   --conf spark.hadoop.fs.s3a.path.style.access=true   --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem --conf spark.sql.catalog.sensors.jdbc.schema-version=V1


$SPARK_HOME/sbin/start-thriftserver.sh \
./sbin/start-thriftserver.sh \
  --packages org.postgresql:postgresql:42.6.0 \
  --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
  --conf spark.sql.catalog.sensors=org.apache.iceberg.spark.SparkCatalog \
  --conf spark.sql.catalog.sensors.type=jdbc \
  --conf spark.sql.catalog.sensors.uri=jdbc:postgresql://localhost:5432/smartstar \
  --conf spark.sql.catalog.sensors.jdbc.user=smartstar \
  --conf spark.sql.catalog.sensors.jdbc.password=smartstar \
  --conf spark.sql.catalog.sensors.warehouse=s3a://smartstar/development/silver/sensors/ \
  --conf spark.sql.catalog.sensors.jdbc.schema-version=V1 \
  --conf spark.sql.defaultCatalog=sensors \
  --conf spark.sql.warehouse.dir=s3a://smartstar/development/silver/sensors/ \
  --conf spark.sql.shuffle.partitions=8 \
  --conf spark.sql.adaptive.enabled=false \
  --conf spark.sql.adaptive.advisoryPartitionSizeInBytes=67108864 \
  --conf spark.hadoop.fs.s3a.access.key=minioadmin \
  --conf spark.hadoop.fs.s3a.secret.key=minioadmin \
  --conf spark.hadoop.fs.s3a.endpoint=http://localhost:9000 \
  --conf spark.hadoop.fs.s3a.path.style.access=true \
  --conf spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem \
  --hiveconf hive.server2.thrift.bind.host=0.0.0.0 \
  --hiveconf hive.server2.transport.mode=binary

./sbin/start-thriftserver.sh \
  --packages org.postgresql:postgresql:42.6.0 \
  --conf spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions \
  --hiveconf hive.server2.thrift.bind.host=0.0.0.0 \
  --hiveconf hive.server2.transport.mode=binary