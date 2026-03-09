package com.auditproltd.auditpromobile

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
	private val channelName = "com.auditproltd.auditpromobile/installer"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"installApk" -> {
						val path = call.argument<String>("path")
						if (path.isNullOrBlank()) {
							result.error("ARG", "Missing 'path'", null)
							return@setMethodCallHandler
						}

						val file = File(path)
						if (!file.exists()) {
							result.error("ENOENT", "APK not found: $path", null)
							return@setMethodCallHandler
						}

						if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
							val canInstall = packageManager.canRequestPackageInstalls()
							if (!canInstall) {
								try {
									val intent = Intent(
										Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
										Uri.parse("package:$packageName")
									).apply {
										addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
									}
									startActivity(intent)
								} catch (_: Exception) {
									// Best-effort.
								}

								result.error(
									"PERMISSION",
									"Install permission not granted. Enable 'Install unknown apps' for Audit Pro Mobile.",
									null
								)
								return@setMethodCallHandler
							}
						}

						try {
							val uri = FileProvider.getUriForFile(
								this,
								"$packageName.fileprovider",
								file
							)

							val intent = Intent(Intent.ACTION_VIEW).apply {
								setDataAndType(uri, "application/vnd.android.package-archive")
								addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
								addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
							}

							startActivity(intent)
							result.success(true)
						} catch (e: ActivityNotFoundException) {
							result.error("NO_HANDLER", "No installer available on this device.", e.toString())
						} catch (e: Exception) {
							result.error("FAILED", "Unable to start installer: ${e.message}", e.toString())
						}
					}

					else -> result.notImplemented()
				}
			}
	}
}
