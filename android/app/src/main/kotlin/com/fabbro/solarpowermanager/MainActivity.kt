package com.fabbro.solarpowermanager

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private var pendingPermissionResult: MethodChannel.Result? = null
	private val requestUnknownSourcesCode = 43021

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"com.fabbro.solarpowermanager/apk_install",
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"canRequestPackageInstalls" -> result.success(canRequestPackageInstalls())
				"requestPackageInstallPermission" -> requestPackageInstallPermission(result)
				else -> result.notImplemented()
			}
		}
	}

	private fun canRequestPackageInstalls(): Boolean {
		return Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()
	}

	private fun requestPackageInstallPermission(result: MethodChannel.Result) {
		if (canRequestPackageInstalls()) {
			result.success(true)
			return
		}

		if (pendingPermissionResult != null) {
			result.error(
				"permission_request_in_progress",
				"A package install permission request is already in progress.",
				null,
			)
			return
		}

		pendingPermissionResult = result
		val intent = Intent(
			Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
			Uri.parse("package:$packageName"),
		)
		startActivityForResult(intent, requestUnknownSourcesCode)
	}

	@Deprecated("Deprecated in Java")
	override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
		super.onActivityResult(requestCode, resultCode, data)

		if (requestCode != requestUnknownSourcesCode) return

		val result = pendingPermissionResult ?: return
		pendingPermissionResult = null
		result.success(canRequestPackageInstalls())
	}
}
