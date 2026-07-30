allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Workaround for some older plugins missing `namespace` with AGP 8+.
// We cannot edit pub cache, so we assign a deterministic namespace at build time.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            try {
                val namespaceProp = ext.javaClass.methods.firstOrNull { it.name == "getNamespace" }
                val current = namespaceProp?.invoke(ext) as? String
                if (current.isNullOrBlank()) {
                    val setNamespace = ext.javaClass.methods.firstOrNull { it.name == "setNamespace" && it.parameterTypes.size == 1 }
                    // Use group if present, else fall back to a safe unique namespace.
                    val fallback = if (project.group.toString().isNotBlank() && project.group.toString() != "unspecified") {
                        project.group.toString()
                    } else {
                        "com.dgyardconnect.plugins.${project.name.replace('-', '_')}"
                    }
                    setNamespace?.invoke(ext, fallback)
                }

                // Force Java compile options to 17 to match the app/toolchain.
                val getCompileOptions = ext.javaClass.methods.firstOrNull { it.name == "getCompileOptions" }
                val compileOptions = getCompileOptions?.invoke(ext)
                val javaVersionClass = Class.forName("org.gradle.api.JavaVersion")
                val v17 = javaVersionClass.getMethod("toVersion", Any::class.java).invoke(null, 17)
                compileOptions?.javaClass?.methods?.firstOrNull { it.name == "setSourceCompatibility" }?.invoke(compileOptions, v17)
                compileOptions?.javaClass?.methods?.firstOrNull { it.name == "setTargetCompatibility" }?.invoke(compileOptions, v17)

                // Some plugins still use old compileSdk; bump to avoid Java 9+ toolchain errors.
                // Safe because it only affects compilation, not app manifest/behavior.
                val setCompileSdk = ext.javaClass.methods.firstOrNull { it.name == "setCompileSdk" && it.parameterTypes.size == 1 }
                setCompileSdk?.invoke(ext, 36)
            } catch (_: Throwable) {
                // no-op
            }
        }
    }
}

// Ensure consistent JVM target across Java/Kotlin in all subprojects (AGP 8+ requirement).
subprojects {
    tasks.matching { it.name.startsWith("compile") && it.name.endsWith("Kotlin") }.configureEach {
        try {
            val m = this.javaClass.methods.firstOrNull { it.name == "getKotlinOptions" }
            val opts = m?.invoke(this)
            val set = opts?.javaClass?.methods?.firstOrNull { it.name == "setJvmTarget" && it.parameterTypes.size == 1 }
            // Align with app's Java 17 toolchain.
            set?.invoke(opts, "17")
        } catch (_: Throwable) {
            // no-op
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
