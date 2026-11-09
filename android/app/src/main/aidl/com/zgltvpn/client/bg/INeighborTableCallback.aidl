package com.zgltvpn.client.bg;

import com.zgltvpn.client.bg.ParceledListSlice;

interface INeighborTableCallback {
    oneway void onNeighborTableUpdated(in ParceledListSlice entries);
}
