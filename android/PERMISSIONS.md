# Android Manifest Permissions

After running `flutter create` you need to ADD these permissions to:
android/app/src/main/AndroidManifest.xml

Add inside the <manifest> tag (before <application>):

    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
    <uses-feature android:name="android.hardware.camera" android:required="true"/>

Inside <application>, add:
    android:requestLegacyExternalStorage="true"

For url_launcher (YouTube), inside <queries> tag:
    <intent>
        <action android:name="android.intent.action.VIEW"/>
        <data android:scheme="https"/>
    </intent>

---

# iOS Info.plist additions (ios/Runner/Info.plist)

Add inside the <dict> tag:

    <key>NSCameraUsageDescription</key>
    <string>GymGeek needs camera access to identify gym equipment</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>GymGeek needs photo access to analyse gym equipment images</string>
    <key>io.flutter.embedded_views_preview</key>
    <true/>

These are automatically included when you follow the README setup steps.
