// Project-level Gradle config.
//
// With flutter_webrtc removed, the compileSdk override that caused so much
// trouble is no longer needed: the remaining plugins build against a modern
// SDK on their own. This is back to the stock Flutter layout.

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    project.layout.buildDirectory.value(newBuildDir.dir(project.name))
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
