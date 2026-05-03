package com.spendly.app.spendly

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.provider.Telephony

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            return
        }

        val bundle: Bundle = intent.extras ?: return
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isEmpty()) {
            return
        }

        val sender = messages.firstOrNull()?.displayOriginatingAddress ?: ""
        val body = messages.joinToString(separator = "") { it.displayMessageBody ?: "" }
        val timestampMs = messages.firstOrNull()?.timestampMillis ?: System.currentTimeMillis()

        MainActivity.pushIncomingSmsToFlutter(sender, body, timestampMs)
    }
}
