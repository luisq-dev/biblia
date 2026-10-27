package com.example.biblia

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private var pendingResult: MethodChannel.Result? = null
    private var exportContents: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "biblia1960/backups")
            .setMethodCallHandler { call, result ->
                if (call.method != "exportJson" && call.method != "importJson") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingResult != null) {
                    result.error("busy", "Ya hay un selector de archivos abierto.", null)
                    return@setMethodCallHandler
                }
                val exporting = call.method == "exportJson"
                val contents = call.argument<String>("contents")
                if (exporting && (contents == null || contents.toByteArray(Charsets.UTF_8).size > MAX_BYTES)) {
                    result.error("invalid", "El respaldo está vacío o supera los 32 MB.", null)
                    return@setMethodCallHandler
                }
                val intent = if (exporting) {
                    Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        type = "application/json"
                        putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "biblia-1960-respaldo.json")
                    }
                } else {
                    Intent(Intent.ACTION_OPEN_DOCUMENT).apply { type = "*/*" }
                }
                intent.addCategory(Intent.CATEGORY_OPENABLE)
                pendingResult = result
                exportContents = contents
                try {
                    @Suppress("DEPRECATION")
                    startActivityForResult(intent, if (exporting) EXPORT_REQUEST else IMPORT_REQUEST)
                } catch (error: Exception) {
                    pendingResult = null
                    exportContents = null
                    result.error("unavailable", "No se pudo abrir el selector de archivos.", null)
                }
            }
    }

    @Deprecated("Uses the document picker result API supported by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != EXPORT_REQUEST && requestCode != IMPORT_REQUEST) return
        val result = pendingResult ?: return
        val contents = exportContents
        pendingResult = null
        exportContents = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(if (requestCode == EXPORT_REQUEST) false else null)
            return
        }
        ioExecutor.execute {
            try {
                val response: Any = if (requestCode == EXPORT_REQUEST) {
                    val bytes = requireNotNull(contents).toByteArray(Charsets.UTF_8)
                    require(bytes.size <= MAX_BYTES)
                    requireNotNull(contentResolver.openOutputStream(uri, "wt")).use { it.write(bytes) }
                    true
                } else {
                    val buffer = ByteArrayOutputStream()
                    requireNotNull(contentResolver.openInputStream(uri)).use { input ->
                        val chunk = ByteArray(8192)
                        while (true) {
                            val count = input.read(chunk)
                            if (count == -1) break
                            require(buffer.size() + count <= MAX_BYTES) { "El respaldo supera el límite de 32 MB." }
                            buffer.write(chunk, 0, count)
                        }
                    }
                    buffer.toString(Charsets.UTF_8.name())
                }
                runOnUiThread { result.success(response) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("file_error", if (error is IllegalArgumentException) error.message
                        else "No se pudo leer o guardar el archivo seleccionado.", null)
                }
            }
        }
    }

    override fun onDestroy() {
        pendingResult?.error("cancelled", "El selector de archivos se cerró.", null)
        pendingResult = null
        exportContents = null
        ioExecutor.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val EXPORT_REQUEST = 1960
        private const val IMPORT_REQUEST = 1961
        private const val MAX_BYTES = 32 * 1024 * 1024
    }
}
