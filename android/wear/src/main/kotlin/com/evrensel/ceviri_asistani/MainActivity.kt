package com.evrensel.ceviri_asistani

import android.app.Activity
import android.os.Bundle
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.Spinner
import android.widget.Toast
import com.google.android.gms.wearable.Wearable

class MainActivity : Activity() {

    private val languageNames = arrayOf(
        "Türkçe (tr-TR)",
        "İngilizce (en-US)",
        "Rusça (ru-RU)",
        "Almanca (de-DE)",
        "Arapça (ar-SA)",
        "Fransızca (fr-FR)"
    )

    private val languageCodes = arrayOf(
        "tr-TR",
        "en-US",
        "ru-RU",
        "de-DE",
        "ar-SA",
        "fr-FR"
    )

    private var isSpinner1Initial = true
    private var isSpinner2Initial = true

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val spinnerPerson1 = findViewById<Spinner>(R.id.spinnerPerson1)
        val spinnerPerson2 = findViewById<Spinner>(R.id.spinnerPerson2)
        val btnPerson1Start = findViewById<Button>(R.id.btnPerson1Start)
        val btnPerson2Start = findViewById<Button>(R.id.btnPerson2Start)
        val btnStop = findViewById<Button>(R.id.btnStop)

        val adapter = ArrayAdapter(
            this,
            android.R.layout.simple_spinner_item,
            languageNames
        )
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)

        spinnerPerson1.adapter = adapter
        spinnerPerson2.adapter = adapter

        // Varsayılan: 1. Kişi tr-TR (0), 2. Kişi en-US (1)
        spinnerPerson1.setSelection(0, false)
        spinnerPerson2.setSelection(1, false)

        spinnerPerson1.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                if (isSpinner1Initial) {
                    isSpinner1Initial = false
                    return
                }
                val selectedCode = languageCodes[position]
                sendMessageToPhone("/dil/kisi1/$selectedCode")
            }

            override fun onNothingSelected(parent: AdapterView<*>?) {}
        }

        spinnerPerson2.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                if (isSpinner2Initial) {
                    isSpinner2Initial = false
                    return
                }
                val selectedCode = languageCodes[position]
                sendMessageToPhone("/dil/kisi2/$selectedCode")
            }

            override fun onNothingSelected(parent: AdapterView<*>?) {}
        }

        setupAnimatedButton(btnPerson1Start) {
            sendMessageToPhone("/komut/kisi1")
        }

        setupAnimatedButton(btnPerson2Start) {
            sendMessageToPhone("/komut/kisi2")
        }

        setupAnimatedButton(btnStop) {
            sendMessageToPhone("/komut/durdur")
        }
    }

    /// Tıklama hissiyatı veren animasyonlu buton sarmalayıcı
    private fun setupAnimatedButton(button: Button, onClickAction: () -> Unit) {
        button.setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    v.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                    v.animate().scaleX(0.92f).scaleY(0.92f).setDuration(90).start()
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    v.animate().scaleX(1.0f).scaleY(1.0f).setDuration(90).start()
                }
            }
            false
        }
        button.setOnClickListener {
            onClickAction()
        }
    }

    private fun sendMessageToPhone(path: String) {
        val nodeClient = Wearable.getNodeClient(this)
        val messageClient = Wearable.getMessageClient(this)

        nodeClient.connectedNodes.addOnSuccessListener { nodes ->
            if (nodes.isEmpty()) {
                Toast.makeText(this, "Telefon bağlı değil", Toast.LENGTH_SHORT).show()
                return@addOnSuccessListener
            }
            for (node in nodes) {
                messageClient.sendMessage(node.id, path, ByteArray(0))
            }
        }
    }
}
