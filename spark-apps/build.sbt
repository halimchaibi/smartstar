ThisBuild / version := "1.0.0"
ThisBuild / scalaVersion := "2.13.16"
ThisBuild / organization := "com.smartstar"

val sparkVersion = "4.0.0"

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

ThisBuild / assemblyMergeStrategy := {
  // LOG4J PLUGIN FIX - Add this first!
  case PathList("META-INF", "org", "apache", "logging", "log4j", "core", "config", "plugins", "Log4j2Plugins.dat") =>
    MergeStrategy.concat  // Concatenate plugin files instead of failing
    
  case x if x.endsWith("Log4j2Plugins.dat") =>
    MergeStrategy.concat
    
  // Rest of your merge strategy...
  case PathList("META-INF", xs @_*) => xs match {
    case "MANIFEST.MF" :: Nil => MergeStrategy.discard
    case "services" :: xs => MergeStrategy.concat
    case _ => MergeStrategy.discard
  }
  case x => MergeStrategy.first

//  case PathList("META-INF", "MANIFEST.MF") => MergeStrategy.discard
//  case PathList("META-INF", "services", xs*) => MergeStrategy.concat
//  case PathList("META-INF", xs*) => MergeStrategy.discard
}

lazy val assemblySettings = Seq(
  assembly / assemblyExcludedJars := {
    val cp = (assembly / fullClasspath).value  // ✅ Use assembly scope
    cp filter { f =>
      val name = f.data.getName.toLowerCase
      name.startsWith("spark-") ||
        name.startsWith("log4j-1.2-api")
    }
  }
)

// Include config directory in all modules
lazy val configSettings = Seq(
  // Include config directory in classpath
  Compile / unmanagedResourceDirectories += (ThisBuild / baseDirectory).value / "config",

  // Copy config files to target for easier access
  Compile / resourceGenerators += Def.task {
    val configDir = (ThisBuild / baseDirectory).value / "config"
    val targetConfigDir = (Compile / resourceManaged).value / "config"

    if (configDir.exists()) {
      IO.copyDirectory(configDir, targetConfigDir)
      (targetConfigDir ** "*.conf").get
    } else {
      Seq.empty[File]
    }
  }.taskValue,

  // Set MODULE_NAME environment variable for each module
  Test / envVars += "MODULE_NAME" -> name.value.replace("smartstar-", "")
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
  "org.apache.spark" %% "spark-core" % sparkVersion % "provided",
  "org.apache.spark" %% "spark-sql" % sparkVersion % "provided",
  "org.apache.spark" %% "spark-streaming" % sparkVersion % "provided",
  "org.apache.spark" %% "spark-mllib" % sparkVersion % "provided",
  "org.apache.spark" %% "spark-connect-client-jvm" % sparkVersion,
  
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
      "org.apache.spark" %% "spark-sql" % sparkVersion % Provided,
      "org.apache.spark" %% "spark-connect-client-jvm" % sparkVersion,
      "io.grpc" % "grpc-netty-shaded" % "1.75.0"  // transport provider
    ),
    assemblySettings
  )

// Normalization module
lazy val normalization = (project in file("modules/normalization"))
  .dependsOn(common)
  .settings(
    name := "smartstar-normalization",
    libraryDependencies ++= commonDependencies ++ Seq(
      "io.delta" %% "delta-core" % "2.4.0",
      "org.apache.spark" %% "spark-avro" % "4.0.0" % "provided"
    ),
    assemblySettings
  )

// Analytics module
lazy val analytics = (project in file("modules/analytics"))
  .dependsOn(common)
  .settings(
    name := "smartstar-analytics",
    libraryDependencies ++= commonDependencies ++ Seq(
      "org.apache.spark" %% "spark-mllib" % "4.0.0" % "provided",
      "com.github.fommil.netlib" % "all" % "1.1.2"
    ),
    assemblySettings
  )
