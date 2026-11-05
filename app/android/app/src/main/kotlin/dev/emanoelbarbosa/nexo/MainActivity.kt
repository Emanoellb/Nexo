package dev.emanoelbarbosa.nexo

import android.graphics.drawable.ColorDrawable
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Fundo da janela igual ao Surface do tema ativo do app (claro ou
        // escuro), mesmo quando ele é o contrário do modo do sistema.
        // Chamado por WindowBackgroundSync (lib/app/window_background.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nexo/window")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setBackgroundColor" -> {
                        val argb = (call.arguments as? Number)?.toInt()
                        if (argb == null) {
                            result.error("bad_args", "Cor ARGB esperada", null)
                        } else {
                            window.setBackgroundDrawable(ColorDrawable(argb))
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
