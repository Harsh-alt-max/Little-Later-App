package com.littlelater.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode

/**
 * Opened by Android's Share menu. Shows only the small "Save to Little Later"
 * card on top of the app you were in (Instagram, YouTube…), then closes itself,
 * so you can keep scrolling. Runs the Dart entry point `shareMain`.
 */
class ShareActivity : FlutterActivity() {
    override fun getDartEntrypointFunctionName(): String = "shareMain"

    override fun getDartEntrypointArgs(): List<String> {
        val i = intent
        if (i?.action != Intent.ACTION_SEND) return listOf("")
        val text = i.getStringExtra(Intent.EXTRA_TEXT) ?: ""
        val subject = i.getStringExtra(Intent.EXTRA_SUBJECT) ?: ""
        return listOf(if (subject.isNotBlank() && !text.contains(subject)) "$subject\n$text" else text)
    }

    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun onNewIntent(intent: Intent) {
        // A second share while the card is open: start fresh with the new text.
        super.onNewIntent(intent)
        finish()
        startActivity(intent)
    }
}
