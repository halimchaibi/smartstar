// Assembly configuration for analytics module
assembly / assemblyJarName := "smartstar-analytics-assembly-1.0.0.jar"

assembly / assemblyMergeStrategy := {
  case PathList("META-INF", xs @ _*) => MergeStrategy.discard
  case PathList("reference.conf") => MergeStrategy.concat
  case PathList("application.conf") => MergeStrategy.concat
  case _ => MergeStrategy.first
}

assembly / assemblyExcludedJars := {
  val cp = (assembly / fullClasspath).value
  cp filter {_.data.getName == "spark-core_2.13-3.5.0.jar"}
}
