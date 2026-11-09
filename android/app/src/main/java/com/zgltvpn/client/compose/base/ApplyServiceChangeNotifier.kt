package com.zgltvpn.client.compose.base

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import com.zgltvpn.client.constant.Status

@Composable
fun rememberApplyServiceChangeNotifier(
    serviceStatus: Status,
): (UiEvent.ApplyServiceChange.Mode) -> Unit = remember(serviceStatus) {
    { mode ->
        if (serviceStatus == Status.Started) {
            GlobalEventBus.tryEmit(UiEvent.ApplyServiceChange(mode))
        }
    }
}
