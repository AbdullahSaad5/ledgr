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
}

// Some plugins (file_picker 8.x) still compile against android-34 while
// flutter_plugin_android_lifecycle demands 36. Force every Android
// subproject up to the app's compileSdk so the AAR metadata check passes.
// (evaluationDependsOn above may have evaluated a project already, hence
// the state check instead of a bare afterEvaluate.)
subprojects {
    val bumpCompileSdk: (Project) -> Unit = { p ->
        p.extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
            ?.compileSdkVersion(36)
    }
    if (state.executed) bumpCompileSdk(this) else afterEvaluate { bumpCompileSdk(this) }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
