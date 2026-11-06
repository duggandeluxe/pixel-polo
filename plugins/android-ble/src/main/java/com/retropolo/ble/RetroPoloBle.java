package com.retropolo.ble;

import android.Manifest;
import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattServer;
import android.bluetooth.BluetoothGattServerCallback;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.bluetooth.BluetoothStatusCodes;
import android.bluetooth.le.AdvertiseCallback;
import android.bluetooth.le.AdvertiseData;
import android.bluetooth.le.AdvertiseSettings;
import android.bluetooth.le.BluetoothLeAdvertiser;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanFilter;
import android.bluetooth.le.ScanRecord;
import android.bluetooth.le.ScanResult;
import android.bluetooth.le.ScanSettings;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.location.LocationManager;
import android.os.Build;
import android.provider.Settings;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.ParcelUuid;
import android.util.Log;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/**
 * Bluetooth LE link for Retro Polo multiplayer. Works with no Wi-Fi and no signal (airplane mode
 * with Bluetooth switched back on). Star topology: the host is a GATT server that advertises the
 * room; joiners are GATT clients. Host -> client packets go out as notifications on TX, client ->
 * host packets as acknowledged writes on RX. Every packet is split into MTU-sized fragments with a
 * one-byte header (bit 7 = more fragments follow) and put back together on the other side.
 *
 * The GDScript side is res://src/net/ble_transport.gd; the contract is documented there.
 * All Bluetooth work runs on one background thread; signals are handed to Godot's thread.
 */
public class RetroPoloBle extends GodotPlugin {
    private static final String TAG = "RetroPoloBLE";

    static final UUID SERVICE = UUID.fromString("5b0c7e10-9a1d-4c3e-8f21-524f504f4c01");
    static final UUID TX = UUID.fromString("5b0c7e10-9a1d-4c3e-8f21-524f504f4c02");
    static final UUID RX = UUID.fromString("5b0c7e10-9a1d-4c3e-8f21-524f504f4c03");
    static final UUID CCCD = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");
    static final int PROTO_VERSION = 1;
    static final int HOST_ID = 1;
    static final int WANT_MTU = 185;
    static final int REQ_PERMISSIONS = 7301;
    static final int REQ_ENABLE = 7302;
    static final int MAX_MESSAGE = 64 * 1024;
    static final int MAX_QUEUE = 400;
    static final long JOIN_TIMEOUT_MS = 12000;
    static final String NO_HOSTING = "This phone can't host over Bluetooth. Let a friend host, or use Wi-Fi.";

    private final HandlerThread thread;
    private final Handler h;
    private BluetoothManager manager;
    private BluetoothAdapter adapter;
    private BroadcastReceiver stateReceiver;

    // ---------------------------------------------------------------- host
    private BluetoothGattServer server;
    private BluetoothGattCharacteristic txChar;
    private BluetoothLeAdvertiser advertiser;
    private boolean advertising;
    private String roomName = "";
    private int maxPlayers = 4;
    private int players = 1;
    private int nextId = 2;
    private final Map<String, Peer> peersByAddr = new HashMap<>();
    private final Map<Integer, Peer> peersById = new HashMap<>();
    private final Map<String, Integer> mtus = new HashMap<>();   // negotiated before they subscribe

    // ---------------------------------------------------------------- client
    private BluetoothLeScanner scanner;
    private boolean scanning;
    private final Map<String, Long> lastSeen = new HashMap<>();
    private BluetoothGatt gatt;
    private BluetoothGattCharacteristic rxChar;
    private boolean joined;
    private int clientMtu = 23;
    private final ArrayDeque<byte[]> clientQueue = new ArrayDeque<>();
    private boolean clientBusy;
    private final Reassembler clientRx = new Reassembler();
    private Runnable joinTimeout;

    static final class Peer {
        final int id;
        final BluetoothDevice device;
        int mtu = 23;
        boolean subscribed;
        boolean busy;
        final ArrayDeque<byte[]> queue = new ArrayDeque<>();
        final Reassembler rx = new Reassembler();

        Peer(int id, BluetoothDevice device) {
            this.id = id;
            this.device = device;
        }
    }

    /** Joins fragments back into whole packets. */
    static final class Reassembler {
        private final ByteArrayOutputStream buf = new ByteArrayOutputStream();

        /** Returns the whole packet when the last fragment arrives, otherwise null. */
        byte[] add(byte[] frag) {
            if (frag == null || frag.length < 1) {
                return null;
            }
            buf.write(frag, 1, frag.length - 1);
            if (buf.size() > MAX_MESSAGE) {
                buf.reset();
                return null;
            }
            if ((frag[0] & 0x80) != 0) {
                return null;
            }
            byte[] out = buf.toByteArray();
            buf.reset();
            return out;
        }

        void reset() {
            buf.reset();
        }
    }

    static List<byte[]> fragment(byte[] data, int mtu) {
        int chunk = Math.max(mtu - 3 - 1, 19);      // ATT header is 3 bytes, ours is 1
        List<byte[]> out = new ArrayList<>();
        int off = 0;
        do {
            int n = Math.min(chunk, data.length - off);
            byte[] f = new byte[n + 1];
            f[0] = (byte) (off + n < data.length ? 0x80 : 0x00);
            System.arraycopy(data, off, f, 1, n);
            out.add(f);
            off += n;
        } while (off < data.length);
        return out;
    }

    public RetroPoloBle(Godot godot) {
        super(godot);
        thread = new HandlerThread("RetroPoloBLE");
        thread.start();
        h = new Handler(thread.getLooper());
    }

    @Override
    public String getPluginName() {
        return "RetroPoloBLE";
    }

    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> s = new HashSet<>();
        s.add(new SignalInfo("status_changed", String.class));
        s.add(new SignalInfo("room_found", String.class, String.class, Integer.class, Integer.class, Integer.class));
        s.add(new SignalInfo("joined"));
        s.add(new SignalInfo("join_failed", String.class));
        s.add(new SignalInfo("host_lost", String.class));
        s.add(new SignalInfo("host_failed", String.class));
        s.add(new SignalInfo("peer_connected", Integer.class));
        s.add(new SignalInfo("peer_disconnected", Integer.class));
        s.add(new SignalInfo("packet_received", Integer.class, byte[].class));
        return s;
    }

    private void emit(final String name, final Object... args) {
        runOnRenderThread(() -> emitSignal(name, args));
    }

    private Context ctx() {
        Activity a = getActivity();
        return a != null ? a.getApplicationContext() : null;
    }

    private boolean init() {
        if (adapter != null) {
            return true;
        }
        Context c = ctx();
        if (c == null || !c.getPackageManager().hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)) {
            return false;
        }
        manager = (BluetoothManager) c.getSystemService(Context.BLUETOOTH_SERVICE);
        adapter = manager != null ? manager.getAdapter() : null;
        if (adapter != null && stateReceiver == null) {
            stateReceiver = new BroadcastReceiver() {
                @Override
                public void onReceive(Context context, Intent intent) {
                    emit("status_changed", getStatus());
                }
            };
            c.registerReceiver(stateReceiver, new IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED));
        }
        return adapter != null;
    }

    private String[] neededPermissions() {
        if (Build.VERSION.SDK_INT >= 31) {
            return new String[] {Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT,
                    Manifest.permission.BLUETOOTH_ADVERTISE};
        }
        return new String[] {Manifest.permission.ACCESS_FINE_LOCATION};
    }

    private boolean hasPermissions() {
        Context c = ctx();
        if (c == null) {
            return false;
        }
        for (String p : neededPermissions()) {
            if (c.checkSelfPermission(p) != PackageManager.PERMISSION_GRANTED) {
                return false;
            }
        }
        return true;
    }

    // ================================================================ status + access
    @UsedByGodot
    public String getStatus() {
        if (!init()) {
            return "unsupported";
        }
        if (!hasPermissions()) {
            return "no_permission";
        }
        if (!adapter.isEnabled()) {
            return "off";
        }
        if (Build.VERSION.SDK_INT >= 28 && Build.VERSION.SDK_INT < 31) {
            // Android 11 and older only report BLE scan results while Location is on
            LocationManager lm = (LocationManager) ctx().getSystemService(Context.LOCATION_SERVICE);
            if (lm != null && !lm.isLocationEnabled()) {
                return "location_off";
            }
        }
        return "ready";
    }

    @UsedByGodot
    public void requestAccess() {
        final Activity a = getActivity();
        if (a == null || !init()) {
            return;
        }
        String st = getStatus();
        if ("no_permission".equals(st)) {
            a.runOnUiThread(() -> a.requestPermissions(neededPermissions(), REQ_PERMISSIONS));
        } else if ("off".equals(st)) {
            a.runOnUiThread(() -> a.startActivityForResult(new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE), REQ_ENABLE));
        } else if ("location_off".equals(st)) {
            a.runOnUiThread(() -> a.startActivity(new Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)));
        }
    }

    @Override
    public void onMainRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        if (requestCode != REQ_PERMISSIONS) {
            return;
        }
        String st = getStatus();
        emit("status_changed", st);
        if ("off".equals(st) || "location_off".equals(st)) {
            requestAccess();
        }
    }

    @Override
    public void onMainActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == REQ_ENABLE) {
            emit("status_changed", getStatus());
        }
    }

    @Override
    public void onMainDestroy() {
        h.post(this::closeAll);
        Context c = ctx();
        if (c != null && stateReceiver != null) {
            try {
                c.unregisterReceiver(stateReceiver);
            } catch (IllegalArgumentException ignored) {
                // already gone
            }
            stateReceiver = null;
        }
        thread.quitSafely();
    }

    // ================================================================ host
    @UsedByGodot
    public void hostStart(final String name, final int maxPlayersIn) {
        h.post(() -> {
            if (!"ready".equals(getStatus())) {
                emit("host_failed", "Bluetooth is not ready");
                return;
            }
            closeAll();
            if (adapter.getBluetoothLeAdvertiser() == null) {
                emit("host_failed", NO_HOSTING);
                return;
            }
            roomName = name;
            maxPlayers = Math.max(2, maxPlayersIn);
            players = 1;
            nextId = 2;
            try {
                server = manager.openGattServer(ctx(), serverCallback);
                if (server == null) {
                    emit("host_failed", NO_HOSTING);
                    return;
                }
                BluetoothGattService svc = new BluetoothGattService(SERVICE, BluetoothGattService.SERVICE_TYPE_PRIMARY);
                txChar = new BluetoothGattCharacteristic(TX, BluetoothGattCharacteristic.PROPERTY_NOTIFY,
                        BluetoothGattCharacteristic.PERMISSION_READ);
                txChar.addDescriptor(new BluetoothGattDescriptor(CCCD,
                        BluetoothGattDescriptor.PERMISSION_READ | BluetoothGattDescriptor.PERMISSION_WRITE));
                BluetoothGattCharacteristic rx = new BluetoothGattCharacteristic(RX,
                        BluetoothGattCharacteristic.PROPERTY_WRITE | BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
                        BluetoothGattCharacteristic.PERMISSION_WRITE);
                svc.addCharacteristic(txChar);
                svc.addCharacteristic(rx);
                server.addService(svc);      // advertising starts in onServiceAdded
            } catch (SecurityException e) {
                Log.w(TAG, "hostStart", e);
                emit("host_failed", "Bluetooth permission was denied");
            }
        });
    }

    @UsedByGodot
    public void setRoomInfo(final int playersIn) {
        h.post(() -> {
            players = playersIn;
            if (advertising) {
                stopAdvertising();
                startAdvertising();
            }
        });
    }

    /** Scan response payload: version, players, max, name (ASCII, up to 10 bytes). */
    private byte[] roomInfo() {
        byte[] nm = roomName.getBytes(StandardCharsets.US_ASCII);
        int n = Math.min(nm.length, 10);
        byte[] out = new byte[3 + n];
        out[0] = (byte) PROTO_VERSION;
        out[1] = (byte) players;
        out[2] = (byte) maxPlayers;
        System.arraycopy(nm, 0, out, 3, n);
        return out;
    }

    private void startAdvertising() {
        advertiser = adapter.getBluetoothLeAdvertiser();
        if (advertiser == null) {
            return;
        }
        AdvertiseSettings settings = new AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
                .setConnectable(true)
                .setTimeout(0)
                .build();
        AdvertiseData data = new AdvertiseData.Builder()
                .addServiceUuid(new ParcelUuid(SERVICE))
                .setIncludeDeviceName(false)
                .build();
        AdvertiseData scanResponse = new AdvertiseData.Builder()
                .addServiceData(new ParcelUuid(SERVICE), roomInfo())
                .setIncludeDeviceName(false)
                .build();
        try {
            advertiser.startAdvertising(settings, data, scanResponse, advertiseCallback);
            advertising = true;
        } catch (SecurityException e) {
            Log.w(TAG, "startAdvertising", e);
        }
    }

    private void stopAdvertising() {
        if (advertiser != null && advertising) {
            try {
                advertiser.stopAdvertising(advertiseCallback);
            } catch (SecurityException | IllegalStateException e) {
                Log.w(TAG, "stopAdvertising", e);
            }
        }
        advertising = false;
    }

    private final AdvertiseCallback advertiseCallback = new AdvertiseCallback() {
        @Override
        public void onStartFailure(int errorCode) {
            Log.w(TAG, "advertising failed: " + errorCode);
            h.post(() -> {
                advertising = false;
                if (errorCode != ADVERTISE_FAILED_ALREADY_STARTED) {
                    closeAll();
                    emit("host_failed", NO_HOSTING);
                }
            });
        }
    };

    private final BluetoothGattServerCallback serverCallback = new BluetoothGattServerCallback() {
        @Override
        public void onServiceAdded(int status, BluetoothGattService service) {
            h.post(() -> {
                if (status == BluetoothGatt.GATT_SUCCESS && server != null) {
                    startAdvertising();
                }
            });
        }

        // Every LE link to this phone lands here (a watch, earbuds...). A device only becomes a
        // player when it subscribes to our TX characteristic; nothing else is ever touched.
        @Override
        public void onConnectionStateChange(final BluetoothDevice device, int status, final int newState) {
            h.post(() -> {
                if (newState != BluetoothProfile.STATE_DISCONNECTED) {
                    return;
                }
                String addr = device.getAddress();
                mtus.remove(addr);
                Peer p = peersByAddr.remove(addr);
                if (p != null) {
                    peersById.remove(p.id);
                    emit("peer_disconnected", p.id);
                }
            });
        }

        @Override
        public void onMtuChanged(final BluetoothDevice device, final int mtu) {
            h.post(() -> {
                mtus.put(device.getAddress(), mtu);
                Peer p = peersByAddr.get(device.getAddress());
                if (p != null) {
                    p.mtu = mtu;
                }
            });
        }

        @Override
        public void onCharacteristicWriteRequest(final BluetoothDevice device, int requestId,
                BluetoothGattCharacteristic characteristic, boolean preparedWrite, boolean responseNeeded,
                int offset, byte[] value) {
            if (responseNeeded) {
                respond(device, requestId, null);
            }
            final byte[] copy = value != null ? value.clone() : new byte[0];
            final boolean ours = RX.equals(characteristic.getUuid());
            h.post(() -> {
                Peer p = peersByAddr.get(device.getAddress());
                if (p == null || !ours) {
                    return;
                }
                byte[] whole = p.rx.add(copy);
                if (whole != null) {
                    emit("packet_received", p.id, whole);
                }
            });
        }

        @Override
        public void onDescriptorWriteRequest(final BluetoothDevice device, int requestId,
                BluetoothGattDescriptor descriptor, boolean preparedWrite, boolean responseNeeded,
                int offset, byte[] value) {
            if (responseNeeded) {
                respond(device, requestId, null);
            }
            final boolean enable = CCCD.equals(descriptor.getUuid()) && value != null && value.length > 0 && value[0] != 0;
            h.post(() -> {
                String addr = device.getAddress();
                if (server == null || !enable || peersByAddr.containsKey(addr)) {
                    return;
                }
                // room capacity is the lobby's call: it answers a full room with a "reject"
                Peer p = new Peer(nextId++, device);
                Integer mtu = mtus.get(addr);
                if (mtu != null) {
                    p.mtu = mtu;
                }
                p.subscribed = true;
                peersByAddr.put(addr, p);
                peersById.put(p.id, p);
                emit("peer_connected", p.id);
            });
        }

        @Override
        public void onDescriptorReadRequest(BluetoothDevice device, int requestId, int offset,
                BluetoothGattDescriptor descriptor) {
            respond(device, requestId, BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE);
        }

        @Override
        public void onCharacteristicReadRequest(BluetoothDevice device, int requestId, int offset,
                BluetoothGattCharacteristic characteristic) {
            respond(device, requestId, new byte[0]);
        }

        @Override
        public void onNotificationSent(final BluetoothDevice device, int status) {
            h.post(() -> {
                Peer p = peersByAddr.get(device.getAddress());
                if (p != null) {
                    p.busy = false;
                    pumpPeer(p);
                }
            });
        }
    };

    private void respond(BluetoothDevice device, int requestId, byte[] value) {
        BluetoothGattServer s = server;
        if (s == null) {
            return;
        }
        try {
            s.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, value);
        } catch (SecurityException e) {
            Log.w(TAG, "sendResponse", e);
        }
    }

    @SuppressWarnings("deprecation")
    private void pumpPeer(Peer p) {
        if (server == null || p.busy || p.queue.isEmpty()) {
            return;
        }
        byte[] f = p.queue.peek();
        boolean ok;
        try {
            if (Build.VERSION.SDK_INT >= 33) {
                ok = server.notifyCharacteristicChanged(p.device, txChar, false, f) == BluetoothStatusCodes.SUCCESS;
            } else {
                txChar.setValue(f);
                ok = server.notifyCharacteristicChanged(p.device, txChar, false);
            }
        } catch (SecurityException e) {
            ok = false;
        }
        if (ok) {
            p.queue.poll();
            p.busy = true;
        } else {
            h.postDelayed(() -> pumpPeer(p), 8);    // stack busy: try again shortly
        }
    }

    // ================================================================ client
    @UsedByGodot
    public void scanStart() {
        h.post(() -> {
            if (!"ready".equals(getStatus()) || scanning) {
                return;
            }
            scanner = adapter.getBluetoothLeScanner();
            if (scanner == null) {
                return;
            }
            List<ScanFilter> filters = Collections.singletonList(
                    new ScanFilter.Builder().setServiceUuid(new ParcelUuid(SERVICE)).build());
            ScanSettings settings = new ScanSettings.Builder()
                    .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                    .build();
            try {
                scanner.startScan(filters, settings, scanCallback);
                scanning = true;
                lastSeen.clear();
            } catch (SecurityException e) {
                Log.w(TAG, "startScan", e);
            }
        });
    }

    @UsedByGodot
    public void scanStop() {
        h.post(this::stopScanNow);
    }

    private void stopScanNow() {
        if (scanner != null && scanning) {
            try {
                scanner.stopScan(scanCallback);
            } catch (SecurityException | IllegalStateException e) {
                Log.w(TAG, "stopScan", e);
            }
        }
        scanning = false;
    }

    private final ScanCallback scanCallback = new ScanCallback() {
        @Override
        public void onScanResult(int callbackType, final ScanResult result) {
            h.post(() -> onRoom(result));
        }

        @Override
        public void onBatchScanResults(List<ScanResult> results) {
            for (final ScanResult r : results) {
                h.post(() -> onRoom(r));
            }
        }
    };

    private void onRoom(ScanResult result) {
        if (!scanning || result.getDevice() == null) {
            return;
        }
        String addr = result.getDevice().getAddress();
        long now = System.currentTimeMillis();
        Long prev = lastSeen.get(addr);
        if (prev != null && now - prev < 700) {
            return;
        }
        lastSeen.put(addr, now);
        String name = "";
        int p = 0;
        int max = 4;
        ScanRecord rec = result.getScanRecord();
        if (rec != null) {
            byte[] sd = rec.getServiceData(new ParcelUuid(SERVICE));
            if (sd != null && sd.length >= 3) {
                p = sd[1] & 0xff;
                max = sd[2] & 0xff;
                name = new String(sd, 3, sd.length - 3, StandardCharsets.US_ASCII);
            } else if (rec.getDeviceName() != null) {
                name = rec.getDeviceName();          // hosts that can only advertise a name
                if (name.startsWith("RP:")) {
                    name = name.substring(3);
                }
            }
        }
        emit("room_found", addr, name, p, max, result.getRssi());
    }

    @UsedByGodot
    @SuppressWarnings("deprecation")    // connectGatt(..., TRANSPORT_LE) is the call that works on every Android we support
    public void join(final String address) {
        h.post(() -> {
            if (!"ready".equals(getStatus())) {
                emit("join_failed", "Bluetooth is not ready");
                return;
            }
            stopScanNow();
            closeClient();
            try {
                BluetoothDevice dev = adapter.getRemoteDevice(address);
                joined = false;
                clientMtu = 23;
                gatt = dev.connectGatt(ctx(), false, gattCallback, BluetoothDevice.TRANSPORT_LE);
            } catch (IllegalArgumentException | SecurityException e) {
                emit("join_failed", "Could not reach that phone");
                return;
            }
            joinTimeout = () -> {
                if (!joined) {
                    closeClient();
                    emit("join_failed", "Could not reach that phone");
                }
            };
            h.postDelayed(joinTimeout, JOIN_TIMEOUT_MS);
        });
    }

    private final BluetoothGattCallback gattCallback = new BluetoothGattCallback() {
        @Override
        public void onConnectionStateChange(final BluetoothGatt g, final int status, final int newState) {
            h.post(() -> {
                if (g != gatt) {
                    return;
                }
                try {
                    if (newState == BluetoothProfile.STATE_CONNECTED && status == BluetoothGatt.GATT_SUCCESS) {
                        g.requestConnectionPriority(BluetoothGatt.CONNECTION_PRIORITY_HIGH);
                        if (!g.requestMtu(WANT_MTU)) {
                            g.discoverServices();
                        }
                    } else if (newState == BluetoothProfile.STATE_DISCONNECTED || status != BluetoothGatt.GATT_SUCCESS) {
                        boolean was = joined;
                        closeClient();
                        if (was) {
                            emit("host_lost", "Lost the host");
                        } else {
                            emit("join_failed", "Could not reach that phone");
                        }
                    }
                } catch (SecurityException e) {
                    Log.w(TAG, "connect", e);
                }
            });
        }

        @Override
        public void onMtuChanged(final BluetoothGatt g, final int mtu, final int status) {
            h.post(() -> {
                if (g != gatt) {
                    return;
                }
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    clientMtu = mtu;
                }
                try {
                    g.discoverServices();
                } catch (SecurityException e) {
                    Log.w(TAG, "discoverServices", e);
                }
            });
        }

        @Override
        @SuppressWarnings("deprecation")
        public void onServicesDiscovered(final BluetoothGatt g, final int status) {
            h.post(() -> {
                if (g != gatt) {
                    return;
                }
                BluetoothGattService svc = g.getService(SERVICE);
                if (status != BluetoothGatt.GATT_SUCCESS || svc == null) {
                    closeClient();
                    emit("join_failed", "That phone isn't hosting a race");
                    return;
                }
                BluetoothGattCharacteristic tx = svc.getCharacteristic(TX);
                rxChar = svc.getCharacteristic(RX);
                BluetoothGattDescriptor d = tx != null ? tx.getDescriptor(CCCD) : null;
                if (rxChar == null || d == null) {
                    closeClient();
                    emit("join_failed", "That phone isn't hosting a race");
                    return;
                }
                try {
                    g.setCharacteristicNotification(tx, true);
                    if (Build.VERSION.SDK_INT >= 33) {
                        g.writeDescriptor(d, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
                    } else {
                        d.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
                        g.writeDescriptor(d);
                    }
                } catch (SecurityException e) {
                    Log.w(TAG, "subscribe", e);
                }
            });
        }

        @Override
        public void onDescriptorWrite(final BluetoothGatt g, BluetoothGattDescriptor descriptor, final int status) {
            h.post(() -> {
                if (g != gatt || joined) {
                    return;
                }
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    closeClient();
                    emit("join_failed", "The host refused the connection");
                    return;
                }
                joined = true;
                if (joinTimeout != null) {
                    h.removeCallbacks(joinTimeout);
                }
                emit("joined");
                pumpClient();
            });
        }

        @Override
        public void onCharacteristicChanged(BluetoothGatt g, BluetoothGattCharacteristic c, byte[] value) {
            onNotify(g, c, value);
        }

        @Override
        @SuppressWarnings("deprecation")
        public void onCharacteristicChanged(BluetoothGatt g, BluetoothGattCharacteristic c) {
            onNotify(g, c, c.getValue());       // before Android 13
        }

        @Override
        public void onCharacteristicWrite(final BluetoothGatt g, BluetoothGattCharacteristic c, int status) {
            h.post(() -> {
                if (g != gatt) {
                    return;
                }
                clientBusy = false;
                pumpClient();
            });
        }
    };

    private void onNotify(final BluetoothGatt g, BluetoothGattCharacteristic c, byte[] value) {
        if (!TX.equals(c.getUuid()) || value == null) {
            return;
        }
        final byte[] copy = value.clone();
        h.post(() -> {
            if (g != gatt) {
                return;
            }
            byte[] whole = clientRx.add(copy);
            if (whole != null) {
                emit("packet_received", HOST_ID, whole);
            }
        });
    }

    @SuppressWarnings("deprecation")
    private void pumpClient() {
        if (gatt == null || rxChar == null || !joined || clientBusy || clientQueue.isEmpty()) {
            return;
        }
        byte[] f = clientQueue.peek();
        boolean ok;
        try {
            if (Build.VERSION.SDK_INT >= 33) {
                ok = gatt.writeCharacteristic(rxChar, f, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT)
                        == BluetoothStatusCodes.SUCCESS;
            } else {
                rxChar.setWriteType(BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT);
                rxChar.setValue(f);
                ok = gatt.writeCharacteristic(rxChar);
            }
        } catch (SecurityException e) {
            ok = false;
        }
        if (ok) {
            clientQueue.poll();
            clientBusy = true;
        } else {
            h.postDelayed(this::pumpClient, 8);
        }
    }

    // ================================================================ both
    /** to: a peer id (host -> that client) or 1 (client -> host). */
    @UsedByGodot
    public void send(final int to, final byte[] data) {
        final byte[] copy = data.clone();
        h.post(() -> {
            if (server != null) {
                Peer p = peersById.get(to);
                if (p == null || !p.subscribed) {
                    return;
                }
                if (p.queue.size() > MAX_QUEUE) {
                    p.queue.clear();         // a peer that stopped reading: drop the backlog
                }
                p.queue.addAll(fragment(copy, p.mtu));
                pumpPeer(p);
            } else if (gatt != null && to == HOST_ID) {
                if (clientQueue.size() > MAX_QUEUE) {
                    clientQueue.clear();
                }
                clientQueue.addAll(fragment(copy, clientMtu));
                pumpClient();
            }
        });
    }

    @UsedByGodot
    public void close() {
        h.post(this::closeAll);
    }

    private void closeClient() {
        if (joinTimeout != null) {
            h.removeCallbacks(joinTimeout);
            joinTimeout = null;
        }
        if (gatt != null) {
            try {
                gatt.disconnect();
                gatt.close();
            } catch (SecurityException e) {
                Log.w(TAG, "closeClient", e);
            }
        }
        gatt = null;
        rxChar = null;
        joined = false;
        clientBusy = false;
        clientQueue.clear();
        clientRx.reset();
    }

    private void closeAll() {
        stopScanNow();
        stopAdvertising();
        closeClient();
        if (server != null) {
            try {
                for (Peer p : peersByAddr.values()) {
                    server.cancelConnection(p.device);
                }
                server.clearServices();
                server.close();
            } catch (SecurityException e) {
                Log.w(TAG, "closeServer", e);
            }
        }
        server = null;
        txChar = null;
        peersByAddr.clear();
        peersById.clear();
        mtus.clear();
    }
}
