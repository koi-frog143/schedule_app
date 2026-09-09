package com.example.schedule_app

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioAttributes
import android.os.Build
import android.os.PowerManager
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import kotlin.math.abs
import kotlin.math.sqrt

object VibrationFailsafe {
    private const val TAG = "VibrationFailsafe"

    @Volatile
    var hasVibrated = false

    fun triggerVibrationWithFailsafe(context: Context) {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "schedule_app:vibrate_failsafe")
        wakeLock.acquire(12000) // Keep CPU awake while verifying vibration

        Thread {
            val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
            val accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            var lastAccel = 0f
            var accelJitter = 0f

            val sensorListener = object : SensorEventListener {
                override fun onSensorChanged(event: SensorEvent) {
                    val x = event.values[0]
                    val y = event.values[1]
                    val z = event.values[2]
                    val currentAccel = sqrt((x * x + y * y + z * z).toDouble()).toFloat()
                    val delta = abs(currentAccel - lastAccel)
                    lastAccel = currentAccel
                    accelJitter = accelJitter * 0.7f + delta * 0.3f
                    // If physical vibration tremor is detected from the motor
                    if (accelJitter > 0.25f) {
                        hasVibrated = true
                    }
                }
                override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
            }

            try {
                if (accelerometer != null) {
                    sensorManager?.registerListener(sensorListener, accelerometer, SensorManager.SENSOR_DELAY_FASTEST)
                }

                val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val vm = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                    vm?.defaultVibrator ?: @Suppress("DEPRECATION") (context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator)
                } else {
                    @Suppress("DEPRECATION")
                    context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                }

                if (vibrator == null || !vibrator.hasVibrator()) {
                    Log.w(TAG, "No vibrator hardware detected.")
                    return@Thread
                }

                hasVibrated = false
                val timings = longArrayOf(0, 1000, 200, 1000, 200, 1000)

                var attempts = 0
                val maxAttempts = 6

                while (!hasVibrated && attempts < maxAttempts) {
                    attempts++
                    Log.d(TAG, "Executing vibration attempt #$attempts...")

                    try {
                        when (attempts % 3) {
                            1 -> {
                                // Method 1: Waveform without amplitude array (supports ERM and LRA motors)
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                    val effect = VibrationEffect.createWaveform(timings, -1)
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                        val attributes = VibrationAttributes.Builder()
                                            .setUsage(VibrationAttributes.USAGE_ALARM)
                                            .build()
                                        vibrator.vibrate(effect, attributes)
                                    } else {
                                        val audioAttributes = AudioAttributes.Builder()
                                            .setUsage(AudioAttributes.USAGE_ALARM)
                                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                            .build()
                                        vibrator.vibrate(effect, audioAttributes)
                                    }
                                } else {
                                    @Suppress("DEPRECATION")
                                    vibrator.vibrate(timings, -1)
                                }
                            }
                            2 -> {
                                // Method 2: Legacy raw timings with AudioAttributes USAGE_ALARM
                                val audioAttributes = AudioAttributes.Builder()
                                    .setUsage(AudioAttributes.USAGE_ALARM)
                                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                    .build()
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                    vibrator.vibrate(VibrationEffect.createWaveform(timings, -1), audioAttributes)
                                } else {
                                    @Suppress("DEPRECATION")
                                    vibrator.vibrate(timings, -1, audioAttributes)
                                }
                            }
                            0 -> {
                                // Method 3: Direct discrete single-shot pulses
                                for (p in 0 until 3) {
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                        vibrator.vibrate(
                                            VibrationEffect.createOneShot(900, VibrationEffect.DEFAULT_AMPLITUDE)
                                        )
                                    } else {
                                        @Suppress("DEPRECATION")
                                        vibrator.vibrate(900)
                                    }
                                    Thread.sleep(1100)
                                }
                                hasVibrated = true
                                break
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in attempt #$attempts: ${e.message}")
                    }

                    // Check via reflection if vendor exposes isVibrating()
                    try {
                        val isVibratingMethod = vibrator.javaClass.getMethod("isVibrating")
                        val result = isVibratingMethod.invoke(vibrator) as? Boolean
                        if (result == true) {
                            hasVibrated = true
                        }
                    } catch (_: Exception) {}

                    // Wait up to 1 second while monitoring accelerometer jitter
                    var checkCount = 0
                    while (checkCount < 10 && !hasVibrated) {
                        Thread.sleep(100)
                        checkCount++
                    }

                    if (hasVibrated) {
                        Log.d(TAG, "Vibration successfully verified on attempt #$attempts.")
                        break
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in vibration failsafe thread: ${e.message}")
            } finally {
                if (accelerometer != null) {
                    try {
                        sensorManager?.unregisterListener(sensorListener)
                    } catch (_: Exception) {}
                }
                if (wakeLock.isHeld) {
                    wakeLock.release()
                }
            }
        }.start()
    }
}
