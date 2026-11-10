package dev.emanoelbarbosa.nexo

import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.graphics.drawable.ColorDrawable
import android.net.Uri
import android.provider.Settings
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
        // "Não perturbe" do Foco (aprovado em 09/11/2026). Chamado por
        // AndroidFocusSystem (lib/features/focus/data/android_focus_system.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nexo/focus")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "dndAccessGranted" -> result.success(notifications().isNotificationPolicyAccessGranted)
                    "openDndSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
                            result.success(true)
                        } catch (e: ActivityNotFoundException) {
                            result.success(false)
                        }
                    }
                    "setDnd" -> {
                        val on = call.arguments as? Boolean
                        if (on == null) {
                            result.error("bad_args", "Booleano esperado", null)
                        } else {
                            result.success(if (on) dndOn() else dndRestore())
                        }
                    }
                    "restoreDnd" -> result.success(dndRestore())
                    else -> result.notImplemented()
                }
            }
        // Suporte e versão do Perfil (09/11/2026). Chamado por
        // DeviceActions (lib/core/data/device_actions.dart). Abre direto com
        // startActivity: sem permissão e sem <queries> no manifesto. O
        // discador só preenche o número (não liga).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nexo/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openEmail" -> {
                        // {address, subject?, body?}: mailto com o assunto e
                        // o texto codificados (o app de e-mail só preenche).
                        val args = call.arguments as? Map<*, *>
                        val address = args?.get("address") as? String
                        if (address == null) {
                            result.error("bad_args", "Endereço esperado", null)
                        } else {
                            val query = listOfNotNull(
                                (args?.get("subject") as? String)?.let { "subject=${Uri.encode(it)}" },
                                (args?.get("body") as? String)?.let { "body=${Uri.encode(it)}" },
                            ).joinToString("&")
                            val uri = "mailto:${Uri.encode(address, "@")}" +
                                if (query.isEmpty()) "" else "?$query"
                            result.success(open(Intent(Intent.ACTION_SENDTO, Uri.parse(uri))))
                        }
                    }
                    "openDialer" -> result.success(
                        open(Intent(Intent.ACTION_DIAL, Uri.parse("tel:${call.arguments}")))
                    )
                    "appVersion" -> result.success(
                        packageManager.getPackageInfo(packageName, 0).versionName
                    )
                    else -> result.notImplemented()
                }
            }
    }

    private fun open(intent: Intent): Boolean = try {
        startActivity(intent)
        true
    } catch (e: ActivityNotFoundException) {
        false
    }

    private fun notifications() =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun focusPrefs() = getSharedPreferences("nexo_focus", Context.MODE_PRIVATE)

    // Liga o silêncio (prioridade) e guarda o estado de antes, uma vez só:
    // se o app fechar no meio, a próxima abertura volta a esse estado.
    private fun dndOn(): Boolean {
        val nm = notifications()
        if (!nm.isNotificationPolicyAccessGranted) return false
        val prefs = focusPrefs()
        if (!prefs.contains(KEY_PREVIOUS)) {
            prefs.edit().putInt(KEY_PREVIOUS, nm.currentInterruptionFilter).apply()
        }
        nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
        return true
    }

    // Volta ao estado de antes do foco, se o Nexo ligou o silêncio. Se a
    // pessoa mudou o modo no meio do foco, o modo dela fica.
    private fun dndRestore(): Boolean {
        val prefs = focusPrefs()
        if (!prefs.contains(KEY_PREVIOUS)) return false
        val previous = prefs.getInt(KEY_PREVIOUS, NotificationManager.INTERRUPTION_FILTER_ALL)
        prefs.edit().remove(KEY_PREVIOUS).apply()
        val nm = notifications()
        if (nm.isNotificationPolicyAccessGranted &&
            nm.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_PRIORITY
        ) {
            nm.setInterruptionFilter(previous)
        }
        return true
    }

    private companion object {
        const val KEY_PREVIOUS = "dnd_previous_filter"
    }
}
