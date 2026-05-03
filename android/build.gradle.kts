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
    
    // Ensure subprojects depend on app evaluation if needed
    if (project.name != "app") {
        evaluationDependsOn(":app")
    }

    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.media3") {
                useVersion("1.4.1")
            }
        }
    }

    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android") as? com.android.build.gradle.BaseExtension
            if (android != null && android.namespace == null) {
                // Surgical fix for better_player and generic for others
                if (project.name == "better_player") {
                    android.namespace = "com.jhomlala.better_player"
                } else if (project.name == "optimize_battery") {
                    android.namespace = "com.gb.optimize_battery"
                } else if (project.name == "better_player_plus") {
                    android.namespace = "uz.shs.better_player_plus"
                } else {
                    android.namespace = "com.tphimx.${project.name.replace("-", "_")}"
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
