package com.carriez.flutter_hbb

// FlowXDesk: atualização automática pelo GitHub Releases da FlowX (copiado por scripts/brand.py).
// Segurança: só aceita URL das Releases da FlowX, confere tamanho e sha256 do manifesto, e o próprio
// Android só instala por cima se o APK tiver a MESMA assinatura do app instalado.

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import android.util.Log
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

object FlowXUpdater {
    private const val TAG = "FlowXUpdater"
    private const val PREFIX = "https://github.com/__UPDATE_REPO__/releases/download/"
    private const val META_URL = "https://github.com/__UPDATE_REPO__/releases/latest/download/flowxdesk-update.json"
    private const val INTERVAL_MS = 1L * 3600 * 1000
    private const val MAX_APK = 300L * 1024 * 1024

    /** Chamado ao abrir o app; no máximo uma checagem por hora. */
    fun maybeCheck(ctx: Context) {
        val app = ctx.applicationContext
        val prefs = app.getSharedPreferences("flowx_updater", Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        if (now - prefs.getLong("last", 0) < INTERVAL_MS) return
        Thread {
            try {
                if (MainService.isStart) return@Thread  // não atualiza no meio de um acesso remoto
                prefs.edit().putLong("last", now).apply()
                check(app)
            } catch (e: Exception) {
                Log.w(TAG, "checagem de atualização falhou", e)
            }
        }.start()
    }

    internal fun versionNumber(v: String): Long {
        val p = v.split(".")
        if (p.size != 3) return -1
        return try { p[0].toLong() * 1_000_000 + p[1].toLong() * 1_000 + p[2].toLong() } catch (e: NumberFormatException) { -1 }
    }

    private fun get(url: String): HttpURLConnection {
        val c = URL(url).openConnection() as HttpURLConnection
        c.connectTimeout = 15_000
        c.readTimeout = 60_000
        c.instanceFollowRedirects = true
        if (c.responseCode != 200) throw IllegalStateException("HTTP ${c.responseCode} em $url")
        return c
    }

    private fun check(ctx: Context) {
        val meta = JSONObject(get(META_URL).inputStream.bufferedReader().use { it.readText() })
        if (meta.optString("app") != "flowxdesk") return
        val latest = meta.getString("version")
        @Suppress("DEPRECATION")
        val current = ctx.packageManager.getPackageInfo(ctx.packageName, 0).versionName ?: return
        if (versionNumber(latest) <= versionNumber(current)) return
        val arts = meta.getJSONArray("artifacts")
        var art: JSONObject? = null
        for (i in 0 until arts.length()) {
            val a = arts.getJSONObject(i)
            if (a.optString("platform") == "android" && a.optString("arch") == "aarch64" && a.optString("format") == "apk") art = a
        }
        art ?: return
        val url = art.getString("url")
        val size = art.getLong("size")
        val sha = art.getString("sha256").lowercase()
        if (!url.startsWith(PREFIX + meta.getString("release_id") + "/") || size <= 0 || size > MAX_APK) {
            Log.w(TAG, "manifesto recusado: $url")
            return
        }
        val file = File(ctx.cacheDir, "flowxdesk-update.apk")
        val md = MessageDigest.getInstance("SHA-256")
        get(url).inputStream.use { input ->
            file.outputStream().use { out ->
                val buf = ByteArray(64 * 1024)
                var total = 0L
                while (true) {
                    val n = input.read(buf)
                    if (n < 0) break
                    total += n
                    if (total > size) throw IllegalStateException("APK maior que o manifesto")
                    md.update(buf, 0, n)
                    out.write(buf, 0, n)
                }
            }
        }
        val got = md.digest().joinToString("") { "%02x".format(it) }
        if (file.length() != size || got != sha) {
            file.delete()
            Log.w(TAG, "sha256/tamanho não confere; atualização descartada")
            return
        }
        Log.i(TAG, "instalando $latest (atual $current)")
        install(ctx, file)
    }

    private fun install(ctx: Context, file: File) {
        val pi = ctx.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        params.setAppPackageName(ctx.packageName)
        if (Build.VERSION.SDK_INT >= 31) {
            // Android 12+: sem pergunta quando o próprio FlowXDesk é o instalador de registro
            params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
        }
        val id = pi.createSession(params)
        pi.openSession(id).use { s ->
            s.openWrite("base.apk", 0, file.length()).use { out ->
                file.inputStream().use { it.copyTo(out) }
                s.fsync(out)
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
            val pending = PendingIntent.getBroadcast(ctx, id, Intent(ctx, FlowXUpdateReceiver::class.java), flags)
            s.commit(pending.intentSender)
        }
        file.delete()
    }
}

class FlowXUpdateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, -999)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                val confirm: Intent? = if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION") intent.getParcelableExtra(Intent.EXTRA_INTENT)
                }
                confirm ?: return
                confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                // Android 10+ bloqueia abrir tela a partir de segundo plano: avisa por notificação (toque = instalar)
                notifyReady(context, confirm)
                try { context.startActivity(confirm) } catch (e: Exception) { Log.i("FlowXUpdater", "confirmação via notificação") }
            }
            PackageInstaller.STATUS_SUCCESS -> Log.i("FlowXUpdater", "atualizado")
            else -> Log.w("FlowXUpdater", "instalação falhou ($status): ${intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)}")
        }
    }

    private fun notifyReady(ctx: Context, confirm: Intent) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        val channel = "flowx_update"
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                android.app.NotificationChannel(channel, "Atualizações do FlowXDesk", android.app.NotificationManager.IMPORTANCE_HIGH))
        }
        val pi = PendingIntent.getActivity(ctx, 7301, confirm,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val n = androidx.core.app.NotificationCompat.Builder(ctx, channel)
            .setSmallIcon(R.mipmap.ic_stat_logo)
            .setContentTitle("Atualização do FlowXDesk pronta")
            .setContentText("Toque para instalar a nova versão.")
            .setContentIntent(pi)
            .setAutoCancel(true)
            .setPriority(androidx.core.app.NotificationCompat.PRIORITY_HIGH)
            .build()
        try { nm.notify(7301, n) } catch (e: SecurityException) { Log.w("FlowXUpdater", "sem permissão de notificação") }
    }
}
