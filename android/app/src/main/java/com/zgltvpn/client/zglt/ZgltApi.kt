package com.zgltvpn.client.zglt

import com.zgltvpn.client.utils.HTTPClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.put
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/**
 * ZGLTVPN backend API (https://vpn.zgltvpn.workers.dev).
 *
 * Contract (see client/shared/SUBSCRIPTION.md):
 * - POST /api/login {email, password, totp?} -> {token, user:{sub_token, expires,
 *   traffic_total, traffic_used}} | {need_totp:true} | {error:"..."} with 401/403/429.
 * - GET /sub/<sub_token>?format=singbox -> {log, outbounds, route} (no inbounds/dns).
 *
 * Security: token and sub_token are credentials. They are stored only in the
 * local Settings store (see Settings.zgltToken / zgltSubToken) and are NEVER
 * written to logs, crash reports, or profile files.
 */
object ZgltApi {
    const val BASE_URL = "https://vpn.zgltvpn.workers.dev"
    const val PROFILE_NAME = "ZGLTVPN"
    const val TEMPLATE_ASSET = "singbox-template.json"

    sealed class LoginResult {
        data class Success(
            val token: String,
            val subToken: String,
            val expires: Long,
            val trafficTotal: Long,
            val trafficUsed: Long,
        ) : LoginResult()

        /** Account has TOTP enabled; caller must ask for the 6-digit code and retry. */
        object NeedTotp : LoginResult()

        data class Error(val message: String) : LoginResult()
    }

    /**
     * Log in with email + password. Returns Success, NeedTotp, or Error with a
     * user-facing Chinese message (server message preferred; the backend rate
     * limit is 5 failed attempts per 15 minutes -> HTTP 429).
     */
    suspend fun login(email: String, password: String, totp: String? = null): LoginResult =
        withContext(Dispatchers.IO) {
            try {
                val conn = (URL("$BASE_URL/api/login").openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    setRequestProperty("Content-Type", "application/json")
                    connectTimeout = 15000
                    readTimeout = 15000
                    doOutput = true
                }
                val body = buildJsonObject {
                    put("email", email.trim())
                    put("password", password)
                    if (!totp.isNullOrBlank()) put("totp", totp.trim())
                }.toString()
                conn.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
                val code = conn.responseCode
                val text = try {
                    (if (code in 200..299) conn.inputStream else conn.errorStream)
                        ?.bufferedReader()?.readText() ?: ""
                } catch (_: Exception) {
                    ""
                } finally {
                    conn.disconnect()
                }
                if (code in 200..299) {
                    val obj = JSONObject(text)
                    if (obj.optBoolean("need_totp", false)) return@withContext LoginResult.NeedTotp
                    val token = obj.optString("token", "")
                    val user = obj.optJSONObject("user")
                    val subToken = user?.optString("sub_token", "") ?: ""
                    if (token.isEmpty() || subToken.isEmpty()) {
                        return@withContext LoginResult.Error("登录返回异常，请重试")
                    }
                    LoginResult.Success(
                        token = token,
                        subToken = subToken,
                        expires = user?.optLong("expires", 0L) ?: 0L,
                        trafficTotal = user?.optLong("traffic_total", 0L) ?: 0L,
                        trafficUsed = user?.optLong("traffic_used", 0L) ?: 0L,
                    )
                } else {
                    val serverMsg = try {
                        JSONObject(text).optString("error", "")
                    } catch (_: Exception) {
                        ""
                    }
                    val message = when {
                        serverMsg.isNotEmpty() -> serverMsg
                        code == 401 -> "邮箱或密码错误"
                        code == 403 -> "账号已被封禁"
                        code == 429 -> "尝试过多，15 分钟后再试"
                        else -> "登录失败（$code），请检查网络后重试"
                    }
                    LoginResult.Error(message)
                }
            } catch (_: IOException) {
                LoginResult.Error("网络错误，请检查网络后重试")
            } catch (e: Exception) {
                LoginResult.Error("登录失败：${e.message ?: "未知错误"}")
            }
        }

    /** Fetch the sing-box subscription JSON for [subToken]. Throws on failure. */
    suspend fun fetchSubscription(subToken: String): String = withContext(Dispatchers.IO) {
        HTTPClient().use { it.getString("$BASE_URL/sub/$subToken?format=singbox") }
    }

    /**
     * Merge the server subscription JSON with the local template (SUBSCRIPTION.md §3):
     * inbounds + dns come from the template; outbounds = server outbounds plus the
     * template's dns-out; route comes from the template but route.final comes from
     * the server; log.level is info. The experimental.clash_api section of the
     * template is intentionally dropped on Android (libbox has its own stats API).
     */
    fun mergeSubscription(subscriptionJson: String, templateJson: String): String {
        val json = Json { ignoreUnknownKeys = true }
        val sub = json.parseToJsonElement(subscriptionJson).jsonObject
        val tpl = json.parseToJsonElement(templateJson).jsonObject
        val outbounds = buildJsonArray {
            sub["outbounds"]?.jsonArray?.forEach { add(it) }
            tpl["outbounds"]?.jsonArray?.forEach { add(it) }
        }
        val serverFinal = sub["route"]?.jsonObject?.get("final")
        val route = buildJsonObject {
            tpl["route"]?.jsonObject?.entries?.forEach { (key, value) -> put(key, value) }
            if (serverFinal != null) put("final", serverFinal)
        }
        return buildJsonObject {
            put("log", buildJsonObject { put("level", "info") })
            tpl["dns"]?.let { put("dns", it) }
            tpl["inbounds"]?.let { put("inbounds", it) }
            put("outbounds", JsonArray(outbounds))
            put("route", route)
        }.toString()
    }
}
