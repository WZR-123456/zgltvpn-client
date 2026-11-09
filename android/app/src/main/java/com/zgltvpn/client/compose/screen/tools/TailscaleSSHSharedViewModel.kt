package com.zgltvpn.client.compose.screen.tools

import com.zgltvpn.client.compose.base.BaseViewModel
import com.zgltvpn.client.terminal.TailscaleSSHPresentedSession

data class TailscaleSSHSharedState(
    val pendingSession: TailscaleSSHPresentedSession? = null,
)

class TailscaleSSHSharedViewModel : BaseViewModel<TailscaleSSHSharedState, Nothing>() {
    override fun createInitialState() = TailscaleSSHSharedState()

    fun setPendingSession(session: TailscaleSSHPresentedSession) {
        updateState { copy(pendingSession = session) }
    }

    fun consumePendingSession(): TailscaleSSHPresentedSession? {
        val session = currentState.pendingSession
        updateState { copy(pendingSession = null) }
        return session
    }
}
