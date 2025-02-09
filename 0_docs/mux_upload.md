Upload video directly from an Android app
Allow your users to upload content directly to Mux from a native Android app.

Direct Uploads allow you to provide an authenticated upload URL to your client applications so content can be uploaded directly to Mux without needing any intermediate steps. You still get to control who gets an authenticated URL, how long it's viable, and, of course, the Asset settings used when the upload is complete.

The Android Upload SDK allows a client application to upload video files from an Android device to Mux Video. The upload can be paused before completion and resume where it left off, even after process death.

Let's start by uploading a video directly into Mux from an Android application. The code from these examples can be found in our upload example app

Gradle setup
To integrate the Mux Upload SDK into your Android app, you first have to add it to your project, then create a MuxUpload object using an upload URL your app can fetch from a trusted server. Once you create the MuxUpload, you can start it with start().

A working example can be found alongside our source code here.

Add Mux's maven repository to your project
Add our maven repository to your project's repositories block. Depending on your setup, you may need to do this either the settings.gradle under dependencyResolutionManagement or your project's build.gradle.

gradle_kts
gradle_groovy
copy
// In your repositories block
maven {
  url = uri("https://muxinc.jfrog.io/artifactory/default-maven-release-local")
}
Add the Upload SDK to your app's dependencies
Add the upload SDK to your app's dependencies block in its build.gradle file.

gradle_kts
gradle_groovy
copy
// in your app's dependencies
implementation("com.mux.video:upload:0.4.1")
Upload a video
In order to securely upload a video, you will need to create a PUT URL for your video. Once you have created the upload URL, return it to the Android client then use the MuxUpload class to upload the file to Mux.

Getting an Upload URL to Mux Video
In order to upload a new video to Mux, you must first create a new Direct Upload to receive the file. The Direct Upload will contain a resumable PUT url for your Android client to use while uploading the video file.

You should not create your Direct Uploads directly from your app. Instead, refer to the Direct Upload Guide to create them securely on your server backend.

Creating and starting your MuxUpload
To perform the upload from your Android app, you can use the MuxUpload class. At the simplest, you need to build your MuxUpload via its Builder, then add your listeners and start() the upload.

kotlin
java
copy
/**
 * @param myUploadUri PUT URL fetched from a trusted environment
 * @param myVideoFile File where the local video is stored. The app must have permission to read this file
*/
fun beginUpload(myUploadUrl: Uri, myVideoFile: File) {
  val upl = MuxUpload.Builder(myUploadUrl, myVideoFile).build()
  upl.addProgressListener { innerUploads.postValue(uploadList) }
  upl.addResultListener {
    if (it.isSuccess) {
      notifyUploadSuccess()
    } else {
      notifyUploadFail()
    }
  }
  upl.start()
}
Resume uploads after network loss or process death
The upload SDK will keep track of uploads that are in progress. When your app starts, you can restart them using MuxUploadManager. For more information on managing, pausing, and resuming uploads, see the next section of this guide.

kotlin
java
copy
// You can do this anywhere, but it's really effective to do early in app startup
MuxUploadManager.resumeAllCachedJobs()
Upload from a coroutine
If you're using Kotlin coroutines, you don't have to rely on the listener API to receive notifications when an upload succeeds or fails. If you prefer, you can use awaitSuccess in your coroutine.

copy
suspend fun uploadFromCoroutine(videoFile: File): Result<UploadStatus> {
  val uploadUrl = withContext(Dispatchers.IO) {
    getUploadUrl()  // via call to your backend server, see the guide above
  }
  val upload = MuxUpload.Builder(uploadUrl, videoFile).build()
  // Set up your listener here too
  return upload.awaitSuccess()
}
Resuming and managing Uploads
MuxUploads are managed globally while they are in-progress. Your upload can safely continue while your user does other things in your app. Optionally, you can listen for progress updates for these uploads in, eg, a foreground Service with a system notification, or a progress view in another Fragment.

Find Uploads already in progress
MuxUploads are managed internally by the SDK, and you don't have to hold onto a reference to your MuxUpload in order for the upload to complete. You can get a MuxUpload object for any file currently uploading using MuxUploadManager

This example listens for progress updates. You can also pause() or cancel() your uploads this way if desired.

kotlin
java
copy
fun listenToUploadInProgress(videoFile: File) {
  val upload = MuxUploadManager.findUploadByFile(videoFile)
  upload?.setProgressListener { handleProgress(it) }
}
Advanced
Setting a Maximum resolution
If desired, you may choose a maximum resolution for the content being uploaded. You may wish to scale down the video files that are too large for your asset tier, for instance. This can save data costs for your users and it ensures that your assets are available to play as soon as possible.

The Mux Upload SDK scales down any input video larger than 4k (3840x2160 or 2160x3840) by default. You can choose to scale them down further to save on user data, or if you're targeting a basic video quality asset.

Disable Input Standardization
The setting described here will only affect local changes to your input. Mux Video will still convert any non-standard inputs to a standard format during ingestion.

The Upload SDK is capable of processing input videos in order to optimize them for use with Mux Video. This behavior can be disabled if it isn't desired, although this may result in extra processing on Mux's servers. We don't recommend disabling standardization unless you are experiencing issues.

kotlin
java
copy
fun beginUpload(myUploadUrl: Uri, myVideoFile: File) {
  val upl = MuxUpload.Builder(myUploadUrl, myVideoFile)
    .standarizationRequested(false) // disable input processing
    .build()
  // add listeners etc
  upl.start()
}