ThisBuild / version := "1.0.0"
ThisBuild / scalaVersion := "2.13.16"
ThisBuild / organization := "com.smartstar"

val sparkVersion = "4.0.0"
val isLocal = sys.env.getOrElse("ENV", "development") == "development"
val sparkScope = if (isLocal) "compile" else "provided"

// Global settings
ThisBuild / scalacOptions ++= Seq(
  "-encoding",
  "UTF-8",
  "-deprecation",
  "-unchecked",
  "-feature",
  "-Xlint",
  "-Ywarn-dead-code",
  "-Ywarn-numeric-widen"
)

ThisBuild / javaOptions += "-Dsbt.background=false"

ThisBuild / assemblyMergeStrategy := {
  // LOG4J PLUGIN FIX!
  case PathList(
        "META-INF",
        "org",
        "apache",
        "logging",
        "log4j",
        "core",
        "config",
        "plugins",
        "Log4j2Plugins.dat"
      ) =>
    MergeStrategy.concat // Concatenate plugin files instead of failing

  case x if x.endsWith("Log4j2Plugins.dat") =>
    MergeStrategy.concat

  // Rest of your merge strategy...
  case PathList("META-INF", xs @ _*) =>
    xs match {
      case "MANIFEST.MF" :: Nil => MergeStrategy.discard
      case "services" :: xs     => MergeStrategy.concat
      case _                    => MergeStrategy.discard
    }
  case x => MergeStrategy.first
}

lazy val assemblySettings = Seq(
  assembly / assemblyExcludedJars := {
    val cp = (assembly / fullClasspath).value
    cp filter { f =>
      val name = f.data.getName.toLowerCase
      (
        name.startsWith("log4j-1.2-api") && !name.contains("iceberg")
      )
    }
  }
)

Test / javaOptions ++= Seq(
  "--add-opens=java.base/jdk.internal.misc=ALL-UNNAMED"
)

// Root project
lazy val root = (project in file("."))
  .aggregate(common, ingestion, normalization, analytics)
  .settings(
    name := "smartstar-spark-apps",
    publish / skip := true
  )

// Common dependencies
lazy val commonDependencies = Seq(
  // Spark
  "org.apache.spark" %% "spark-core" % sparkVersion % sparkScope,
  "org.apache.spark" %% "spark-sql" % sparkVersion % sparkScope,
  "org.apache.spark" %% "spark-streaming" % sparkVersion % sparkScope,
  "org.apache.spark" %% "spark-mllib" % sparkVersion % sparkScope,
  "org.apache.hadoop" % "hadoop-aws" % "3.4.1",
  // "org.apache.spark" %% "spark-connect-client-jvm" % sparkVersion,

  // Configuration
  "com.typesafe" % "config" % "1.4.4",

  // Logging
  "org.slf4j" % "slf4j-api" % "2.0.17",
  "ch.qos.logback" % "logback-classic" % "1.5.18",

  // Testing
  "org.scalatest" %% "scalatest" % "3.2.19" % Test,
  "org.scalamock" %% "scalamock" % "7.4.1" % Test
)

// Common module
lazy val common = (project in file("modules/common"))
  .settings(
    name := "smartstar-common",
    libraryDependencies ++= commonDependencies,
    assemblySettings
  )

// Ingestion module
lazy val ingestion = (project in file("modules/ingestion"))
  .dependsOn(common)
  .settings(
    name := "smartstar-ingestion",
    libraryDependencies ++= commonDependencies ++ Seq(
      "org.apache.spark" %% "spark-sql" % sparkVersion % sparkScope,
      "org.apache.spark" %% "spark-sql-kafka-0-10" % sparkVersion % sparkScope,
      "io.grpc" % "grpc-netty-shaded" % "1.75.0" // transport provider
    ),
    assemblySettings
  )

// Normalization module
lazy val normalization = (project in file("modules/normalization"))
  .dependsOn(common)
  .settings(
    name := "smartstar-normalization",
    libraryDependencies ++= commonDependencies ++ Seq(
      "org.apache.hadoop" % "hadoop-aws" % "3.4.1",
      "org.apache.spark" %% "spark-avro" % "4.0.0" % sparkScope,
      "org.postgresql" % "postgresql" % "42.7.3"
    ),
    assemblySettings
  )

// Analytics module
lazy val analytics = (project in file("modules/analytics"))
  .dependsOn(common)
  .settings(
    name := "smartstar-analytics",
    libraryDependencies ++= commonDependencies ++ Seq(
      "org.apache.spark" %% "spark-mllib" % "4.0.0" % sparkScope,
      "com.github.fommil.netlib" % "all" % "1.1.2"
    ),
    assemblySettings
  )


