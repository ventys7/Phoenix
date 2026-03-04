plugins {
    id("com.android.application")
}

android {
    namespace = "com.phoenix.client"
    compileSdk = 33

    defaultConfig {
        applicationId = "com.phoenix.client"
        minSdk = 19  // Il tuo Android 4.4
        targetSdk = 33
        versionCode = 1
        versionName = "1.0"
    }
}
