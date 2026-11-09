package com.zgltvpn.client.zglt

import android.content.Context
import io.nekohasekai.libbox.Libbox
import com.zgltvpn.client.database.Profile
import com.zgltvpn.client.database.ProfileManager
import com.zgltvpn.client.database.Settings
import com.zgltvpn.client.database.TypedProfile
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.File
import java.util.Date

/**
 * ZGLTVPN subscription -> local profile.
 *
 * Fetch the sing-box subscription with the stored sub_token, merge it with the
 * bundled template ([ZgltApi.mergeSubscription]), validate with
 * [Libbox.checkConfig], and save it as the "ZGLTVPN" profile (selected).
 * Idempotent: if the ZGLTVPN profile already exists it is updated in place
 * instead of creating a duplicate, and the running service is reloaded.
 */
object ZgltSubscription {
    sealed class ImportResult {
        data class Success(val profile: Profile, val nodeCount: Int) : ImportResult()
        data class Error(val message: String) : ImportResult()
    }

    /** Read the bundled sing-box template (client/shared/singbox-template.json). */
    fun loadTemplate(context: Context): String =
        context.assets.open(ZgltApi.TEMPLATE_ASSET).bufferedReader().readText()

    suspend fun importOrUpdate(context: Context): ImportResult = withContext(Dispatchers.IO) {
        try {
            val subToken = Settings.zgltSubToken
            if (subToken.isEmpty()) return@withContext ImportResult.Error("请先登录")
            val subscriptionJson = ZgltApi.fetchSubscription(subToken)
            val merged = ZgltApi.mergeSubscription(subscriptionJson, loadTemplate(context))
            Libbox.checkConfig(merged)
            val nodeCount = countNodes(subscriptionJson)

            val existingId = Settings.zgltProfileId
            val existing = if (existingId != -1L) ProfileManager.get(existingId) else null
            if (existing != null) {
                File(existing.typed.path).writeText(merged)
                existing.typed.lastUpdated = Date()
                ProfileManager.update(existing)
                if (existing.id == Settings.selectedProfile) {
                    try {
                        Libbox.newStandaloneCommandClient().serviceReload()
                    } catch (_: Exception) {
                        // Service not running; the new config applies on next start.
                    }
                }
                ImportResult.Success(existing, nodeCount)
            } else {
                val typedProfile = TypedProfile().apply { type = TypedProfile.Type.Local }
                val profile = Profile(name = ZgltApi.PROFILE_NAME, typed = typedProfile).apply {
                    userOrder = ProfileManager.nextOrder()
                }
                val fileID = ProfileManager.nextFileID()
                val configDirectory = File(context.filesDir, "configs").also { it.mkdirs() }
                val configFile = File(configDirectory, "$fileID.json")
                configFile.writeText(merged)
                typedProfile.path = configFile.path
                typedProfile.lastUpdated = Date()
                val created = ProfileManager.create(profile, andSelect = true)
                Settings.zgltProfileId = created.id
                ImportResult.Success(created, nodeCount)
            }
        } catch (e: Exception) {
            ImportResult.Error(e.message ?: "订阅导入失败")
        }
    }

    /** Count real node outbounds (exclude auto/proxy/direct/dns-out). */
    private fun countNodes(subscriptionJson: String): Int {
        return try {
            val json = Json { ignoreUnknownKeys = true }
            val outbounds = json.parseToJsonElement(subscriptionJson)
                .jsonObject["outbounds"]?.jsonArray ?: return 0
            val reserved = setOf("auto", "proxy", "direct", "dns-out")
            outbounds.count { element ->
                val tag = element.jsonObject["tag"]?.jsonPrimitive?.contentOrNull
                tag != null && tag !in reserved
            }
        } catch (_: Exception) {
            0
        }
    }
}
