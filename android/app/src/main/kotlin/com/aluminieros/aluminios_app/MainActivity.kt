package com.aluminieros.aluminios_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Canal de las notificaciones del servidor (Android 8+). El usuario
        // puede silenciarlo desde Ajustes sin apagar las demás.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "avisos",
                "Avisos del taller",
                NotificationManager.IMPORTANCE_HIGH,
            )
            channel.description = "Solicitudes, cotizaciones, abonos y visitas"
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }
}
