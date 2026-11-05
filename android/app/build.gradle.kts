plugins { id("com.android.application") }
android {
    namespace = "com.oanarinaldi.afterlight"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.oanarinaldi.afterlight"
        minSdk = 29
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    sourceSets { getByName("main") { assets.srcDirs("../web", "../generated/assets"); java.srcDir("../generated/java") } }
    sourceSets { getByName("debug") { assets.srcDir("../festival_art/src/main/assets") } }
    assetPacks += setOf(":festival_art")
    buildFeatures { buildConfig = true }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    signingConfigs {
        providers.environmentVariable("AFTERLIGHT_KEYSTORE").orNull?.let { path ->
            create("upload") {
                storeFile = file(path)
                storePassword = providers.environmentVariable("AFTERLIGHT_STORE_PASSWORD").get()
                keyAlias = providers.environmentVariable("AFTERLIGHT_KEY_ALIAS").getOrElse("upload")
                keyPassword = providers.environmentVariable("AFTERLIGHT_KEY_PASSWORD").get()
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("upload")
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    androidResources { noCompress += listOf("mp3", "bin", "hdr", "pack") }
}
dependencies {
    implementation("androidx.activity:activity:1.13.0")
    implementation("androidx.webkit:webkit:1.15.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test.uiautomator:uiautomator:2.3.0")
}
