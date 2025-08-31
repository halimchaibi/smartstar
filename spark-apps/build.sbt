ThisBuild / version := "1.0.0"
ThisBuild / scalaVersion := "2.13.11"
ThisBuild / organization := "com.smartstar"

// Global settings
ThisBuild / scalacOptions ++= Seq(
  "-encoding", "UTF-8",
  "-deprecation",
  "-unchecked", 
  "-feature",
  "-Xlint",
  "-Ywarn-dead-code",
  "-Ywarn-numeric-widen"
)

// Common dependencies
lazy val commonDependencies = Seq(
  // Spark
  "org.apache.spark" %% "spark-core" % "3.5.0" % "provided",
  "org.apache.spark" %% "spark-sql" % "3.5.0" % "provided",
  "org.apache.spark" %% "spark-streaming" % "3.5.0" % "provided",
  "org.apache.spark" %% "spark-mllib" % "3.5.0" % "provided",
  
  // Configuration
  "com.typesafe" % "config" % "1.4.2",
  
  // Logging
  "org.slf4j" % "slf4j-api" % "2.0.7",
  "ch.qos.logback" % "logback-classic" % "1.4.8",
  
  // Testing
  "org.scalatest" %% "scalatest" % "3.2.16" % Test,
  "org.scalamock" %% "scalamock" % "5.2.0" % Test
)

// Root project
lazy val root = (project in file("."))
  .aggregate(common, ingestion, normalization, analytics)
  .settings(
    name := "smartstar-spark-apps",
    publish / skip := true
  )

// Common module
lazy val common = (project in file("modules/common"))
  .settings(
    name := "smartstar-common",
    libraryDependencies ++= commonDependencies
  )

// Ingestion module
lazy val ingestion = (project in file("modules/ingestion"))
  .dependsOn(common)
  .settings(
    name := "smartstar-ingestion",
    libraryDependencies ++= commonDependencies ++ Seq(
      "org.apache.spark" %% "spark-streaming-kafka-0-10" % "3.5.0" % "provided",
      "org.apache.kafka" % "kafka-clients" % "3.5.1",
      "com.amazonaws" % "aws-java-sdk-s3" % "1.12.499"
    )
  )

// Normalization module
lazy val normalization = (project in file("modules/normalization"))
  .dependsOn(common)
  .settings(
    name := "smartstar-normalization", 
    libraryDependencies ++= commonDependencies ++ Seq(
      "io.delta" %% "delta-core" % "2.4.0",
      "org.apache.spark" %% "spark-avro" % "3.5.0" % "provided"
    )
  )

// Analytics module
lazy val analytics = (project in file("modules/analytics"))
  .dependsOn(common)
  .settings(
    name := "smartstar-analytics",
    libraryDependencies ++= commonDependencies ++ Seq(
      "org.apache.spark" %% "spark-mllib" % "3.5.0" % "provided",
      "com.github.fommil.netlib" % "all" % "1.1.2"
    )
  )
