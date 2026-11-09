package com.zgltvpn.client.zglt

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.zgltvpn.client.database.Settings
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class ZgltLoginUiState(
    val email: String = "",
    val password: String = "",
    val totp: String = "",
    val totpRequired: Boolean = false,
    val loading: Boolean = false,
    val error: String? = null,
)

/**
 * ZGLTVPN account login. On success the session token, subscription token and
 * plan info are stored in [Settings] (local only) and the subscription is
 * imported as the "ZGLTVPN" profile via [ZgltSubscription].
 */
class ZgltLoginViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(ZgltLoginUiState(email = Settings.zgltEmail))
    val uiState: StateFlow<ZgltLoginUiState> = _uiState.asStateFlow()

    fun updateEmail(value: String) = _uiState.update { it.copy(email = value) }
    fun updatePassword(value: String) = _uiState.update { it.copy(password = value) }
    fun updateTotp(value: String) = _uiState.update { it.copy(totp = value) }
    fun clearError() = _uiState.update { it.copy(error = null) }

    fun login(context: Context, onSuccess: () -> Unit) {
        val state = _uiState.value
        if (state.loading) return
        if (state.email.isBlank() || state.password.isBlank()) {
            _uiState.update { it.copy(error = "请输入邮箱和密码") }
            return
        }
        _uiState.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            when (val result = ZgltApi.login(state.email, state.password, state.totp.ifBlank { null })) {
                is ZgltApi.LoginResult.NeedTotp -> {
                    _uiState.update {
                        it.copy(
                            loading = false,
                            totpRequired = true,
                            error = "账号开启了两步验证，请输入 6 位验证码",
                        )
                    }
                }
                is ZgltApi.LoginResult.Error -> {
                    _uiState.update { it.copy(loading = false, error = result.message) }
                }
                is ZgltApi.LoginResult.Success -> {
                    Settings.zgltEmail = state.email.trim()
                    Settings.zgltToken = result.token
                    Settings.zgltSubToken = result.subToken
                    Settings.zgltExpires = result.expires
                    Settings.zgltTrafficTotal = result.trafficTotal
                    Settings.zgltTrafficUsed = result.trafficUsed
                    when (val imported = ZgltSubscription.importOrUpdate(context.applicationContext)) {
                        is ZgltSubscription.ImportResult.Success -> {
                            _uiState.update { it.copy(loading = false) }
                            onSuccess()
                        }
                        is ZgltSubscription.ImportResult.Error -> {
                            _uiState.update {
                                it.copy(
                                    loading = false,
                                    error = "登录成功，但订阅导入失败：${imported.message}",
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    /** Clear stored credentials. The imported profile is kept so an existing
     * connection keeps working; signing in again updates it in place. */
    fun logout() {
        Settings.zgltToken = ""
        Settings.zgltSubToken = ""
        Settings.zgltProfileId = -1L
        Settings.zgltExpires = 0L
        Settings.zgltTrafficTotal = 0L
        Settings.zgltTrafficUsed = 0L
        _uiState.update { it.copy(password = "", totp = "", totpRequired = false, error = null) }
    }
}
