package com.zgltvpn.client.compose.screen.dashboard

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.zgltvpn.client.R
import com.zgltvpn.client.constant.Status
import com.zgltvpn.client.database.Settings
import com.zgltvpn.client.zglt.ZgltSubscription
import kotlinx.coroutines.launch

/**
 * ZGLTVPN card at the top of the dashboard: sign in, one-tap connect /
 * disconnect, refresh the subscription, and open the account screen.
 */
@Composable
fun ZgltDashboardCard(
    serviceStatus: Status,
    onToggleService: () -> Unit,
    onOpenLogin: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var refreshMessage by remember { mutableStateOf<String?>(null) }
    var refreshing by remember { mutableStateOf(false) }
    val loggedIn = Settings.zgltSubToken.isNotEmpty()
    val running = serviceStatus == Status.Started || serviceStatus == Status.Starting
    val busy = serviceStatus == Status.Starting || serviceStatus == Status.Stopping

    Card(modifier = modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = "ZGLTVPN",
                style = MaterialTheme.typography.titleMedium,
            )
            if (!loggedIn) {
                Text(text = stringResource(R.string.zglt_login_to_connect))
                Button(
                    onClick = onOpenLogin,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(text = stringResource(R.string.zglt_login_button))
                }
            } else {
                Text(
                    text = Settings.zgltEmail,
                    style = MaterialTheme.typography.bodyMedium,
                )
                Button(
                    onClick = { onToggleService() },
                    enabled = !busy,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                ) {
                    Text(
                        text = stringResource(
                            if (running) R.string.zglt_disconnect else R.string.zglt_connect,
                        ),
                        style = MaterialTheme.typography.titleMedium,
                    )
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(
                        onClick = {
                            if (refreshing) return@OutlinedButton
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
                        modifier = Modifier.weight(1f),
                    ) {
                        Text(text = stringResource(R.string.zglt_refresh))
                    }
                    OutlinedButton(
                        onClick = onOpenLogin,
                        modifier = Modifier.weight(1f),
                    ) {
                        Text(text = stringResource(R.string.zglt_account))
                    }
                }
                refreshMessage?.let {
                    Text(
                        text = it,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }
        }
    }
}
