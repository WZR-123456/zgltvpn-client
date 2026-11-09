package com.zgltvpn.client.zglt

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.zgltvpn.client.R
import com.zgltvpn.client.compose.topbar.LocalScaffoldPadding
import com.zgltvpn.client.compose.topbar.OverrideTopBar
import com.zgltvpn.client.database.Settings
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * ZGLTVPN account screen: sign in with email + password, import the
 * subscription as the "ZGLTVPN" profile, and manage the signed-in account
 * (refresh subscription / sign out).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ZgltLoginScreen(
    onNavigateBack: () -> Unit,
    viewModel: ZgltLoginViewModel = viewModel(),
) {
    OverrideTopBar {
        TopAppBar(
            title = { Text(stringResource(R.string.zglt_login_title)) },
            navigationIcon = {
                IconButton(onClick = onNavigateBack) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = stringResource(R.string.content_description_back),
                    )
                }
            },
        )
    }

    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val scaffoldPadding = LocalScaffoldPadding.current
    val loggedIn = Settings.zgltSubToken.isNotEmpty()

    var refreshMessage by remember { mutableStateOf<String?>(null) }
    var refreshing by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(scaffoldPadding)
            .padding(horizontal = 16.dp)
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Spacer(modifier = Modifier.height(8.dp))

        if (loggedIn) {
            Text(
                text = stringResource(R.string.zglt_logged_in),
                style = MaterialTheme.typography.titleMedium,
            )
            Text(text = Settings.zgltEmail)
            val expires = Settings.zgltExpires
            if (expires > 0) {
                val date = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date(expires))
                Text(text = stringResource(R.string.zglt_expires, date))
            }
            val total = Settings.zgltTrafficTotal
            if (total > 0) {
                val usedGb = Settings.zgltTrafficUsed / 1073741824.0
                val totalGb = total / 1073741824.0
                Text(
                    text = stringResource(
                        R.string.zglt_traffic,
                        String.format(Locale.getDefault(), "%.1f", usedGb),
                        String.format(Locale.getDefault(), "%.1f", totalGb),
                    ),
                )
            }
            refreshMessage?.let { Text(text = it) }
            Button(
                onClick = {
                    if (refreshing) return@Button
                    refreshing = true
                    refreshMessage = null
                    scope.launch {
                        when (val result = ZgltSubscription.importOrUpdate(context.applicationContext)) {
                            is ZgltSubscription.ImportResult.Success -> {
                                refreshMessage = context.getString(
                                    R.string.zglt_refresh_success,
                                    result.nodeCount,
                                )
                            }
                            is ZgltSubscription.ImportResult.Error -> {
                                refreshMessage = context.getString(
                                    R.string.zglt_refresh_failed,
                                    result.message,
                                )
                            }
                        }
                        refreshing = false
                    }
                },
                enabled = !refreshing,
                modifier = Modifier.fillMaxWidth(),
            ) {
                if (refreshing) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(18.dp),
                        strokeWidth = 2.dp,
                    )
                } else {
                    Text(text = stringResource(R.string.zglt_refresh))
                }
            }
            OutlinedButton(
                onClick = { viewModel.logout() },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(text = stringResource(R.string.zglt_logout))
            }
            Text(
                text = stringResource(R.string.zglt_logout_note),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        } else {
            OutlinedTextField(
                value = uiState.email,
                onValueChange = { viewModel.updateEmail(it); viewModel.clearError() },
                label = { Text(stringResource(R.string.zglt_email)) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = uiState.password,
                onValueChange = { viewModel.updatePassword(it); viewModel.clearError() },
                label = { Text(stringResource(R.string.zglt_password)) },
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            if (uiState.totpRequired) {
                OutlinedTextField(
                    value = uiState.totp,
                    onValueChange = { viewModel.updateTotp(it); viewModel.clearError() },
                    label = { Text(stringResource(R.string.zglt_totp)) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            uiState.error?.let { error ->
                Text(
                    text = error,
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
            Button(
                onClick = { viewModel.login(context) { onNavigateBack() } },
                enabled = !uiState.loading,
                modifier = Modifier.fillMaxWidth(),
            ) {
                if (uiState.loading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(18.dp),
                        strokeWidth = 2.dp,
                    )
                } else {
                    Text(text = stringResource(R.string.zglt_login_button))
                }
            }
            Text(
                text = stringResource(R.string.zglt_login_hint),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
