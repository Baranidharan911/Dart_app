package com.example.techwiz

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Ensure FLAG_SECURE is not set
        window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
    }
}
