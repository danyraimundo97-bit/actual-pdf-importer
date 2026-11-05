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
    // Every plugin builds against the app's SDK. Some ask for another one:
    // receive_sharing_intent 1.9.0 wants 37, which Gradle looks for as "android-37"
    // while the SDK only ships "android-37.0"; file_picker 8 wants 34, too old for
    // what it depends on.
    if (name != "app") {
        afterEvaluate {
            extensions.findByName("android")?.withGroovyBuilder { setProperty("compileSdk", 36) }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
