import com.android.build.gradle.LibraryExtension

allprojects {
    repositories {
        google()
        mavenCentral()
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

    plugins.withId("com.android.library") {
        val manifestFile = file("src/main/AndroidManifest.xml")
        if (manifestFile.exists()) {
            val original = manifestFile.readText()
            val sanitized = original.replace(Regex("\\s+package=\"[^\"]*\""), "")
            if (original != sanitized) {
                manifestFile.writeText(sanitized)
            }
        }

        extensions.configure<LibraryExtension> {
            compileSdk = 36
            if (namespace == null) {
                val sanitizedName = project.name.replace(Regex("[^A-Za-z0-9_]"), "_")
                namespace = "com.spendly.generated.$sanitizedName"
            }
        }
    }

    // Force compileSdk on Groovy-based library plugins (e.g. isar_flutter_libs)
    project.configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.core") {
                useVersion("1.12.0")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}