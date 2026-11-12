package com.focusedmind.focused_mind

import android.Manifest
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Environment
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        // Loading through Java runs the SDK's JNI_OnLoad, which its Android
        // BLE layer needs; Dart then binds the same library with FFI.
        init { System.loadLibrary("neurosdk2") }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Sessions run for up to 90 minutes; keep the screen on.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        // ponytail: asks once at launch; a denied permission surfaces as a scan error.
        val perms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            mutableListOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        // Shows the "session running" notification of SessionService.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            perms += Manifest.permission.POST_NOTIFICATIONS
        }
        requestPermissions(perms.toTypedArray(), 1)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focused_mind/android")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "bond" -> bond(call.arguments as String, result)
                    // ponytail: apps may create files here without a permission on Android 11+;
                    // Android 10 and older would need legacy storage access.
                    "downloadsDir" -> result.success(
                        Environment.getExternalStoragePublicDirectory(
                            Environment.DIRECTORY_DOWNLOADS,
                        ).path,
                    )
                    "startBackground" -> {
                        val service = Intent(this, SessionService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(service)
                        } else {
                            startService(service)
                        }
                        result.success(null)
                    }
                    "stopBackground" -> {
                        stopService(Intent(this, SessionService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Bonds with [address] (as EEGWaves does for Mindo) and answers once bonded. */
    @Suppress("MissingPermission")
    private fun bond(address: String, result: MethodChannel.Result) {
        val adapter = getSystemService(BluetoothManager::class.java).adapter
        val device = adapter.getRemoteDevice(address)
        if (device.bondState == BluetoothDevice.BOND_BONDED) return result.success(null)
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val d: BluetoothDevice? = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                if (d?.address != address) return
                when (intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, -1)) {
                    BluetoothDevice.BOND_BONDED -> {
                        unregisterReceiver(this); result.success(null)
                    }
                    BluetoothDevice.BOND_NONE -> {
                        unregisterReceiver(this)
                        result.error("bond_failed", "Pairing with $address failed", null)
                    }
                }
            }
        }
        registerReceiver(receiver, IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED))
        if (!device.createBond()) {
            unregisterReceiver(receiver)
            result.error("bond_failed", "Could not start pairing with $address", null)
        }
    }
}
