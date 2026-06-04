allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
        maven { url = uri("https://packagecloud.io/arthenica/smart-exception-java/maven2") }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    val setupNamespace = {
        if (project.extensions.findByName("android") != null) {
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            try {
                if (android.namespace == null) {
                    android.namespace = "com.isai.music.${project.name.replace("-", "_")}"
                }
            } catch (e: Exception) {}
        }
    }

    if (project.state.executed) {
        setupNamespace()
    } else {
        project.afterEvaluate { setupNamespace() }
    }

    val stripPackage = {
        try {
            val manifestFile = project.file("src/main/AndroidManifest.xml")
            if (manifestFile.exists()) {
                val content = manifestFile.readText()
                if (content.contains("package=")) {
                    val cleanedContent = content.replace(Regex("""\bpackage="[^"]*""""), "")
                    manifestFile.writeText(cleanedContent)
                }
            }
        } catch (e: Exception) {
            project.logger.warn("Failed to strip package attribute from AndroidManifest.xml: ${e.message}")
        }
    }

    if (project.state.executed) {
        stripPackage()
    } else {
        project.afterEvaluate { stripPackage() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
