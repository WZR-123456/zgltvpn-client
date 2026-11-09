package com.zgltvpn.client.update

sealed class UpdateCheckException : Exception() {
    class TrackNotSupported : UpdateCheckException()
}
