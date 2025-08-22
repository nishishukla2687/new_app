apply plugin: 'com.google.gms.google-services'

android {
    compileSdkVersion 34
    ndkVersion flutter.ndkVersion

    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
        multiDexEnabled true
    }
}

dependencies {
    implementation 'com.android.support:multidex:1.0.3'
}