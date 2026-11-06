#pragma once
// Bluetooth LE link for Retro Polo multiplayer on iPhone and iPad (CoreBluetooth).
// Same contract as the Android plugin (plugins/android-ble) and res://src/net/ble_transport.gd:
// a "RetroPoloBLE" singleton with the same methods and signals, the same service and
// characteristic UUIDs, and the same 1-byte fragment header, so iPhones and Android phones
// can play each other. An iPhone host advertises its room as the local name "RP:<name>"
// (iOS adverts can't carry service data); the Android scanner already reads that.

#include "core/object/class_db.h"
#include "core/object/object.h"
#include "core/variant/variant.h"

#ifdef __OBJC__
@class RPBleCore;
#else
typedef void RPBleCore;
#endif

class RetroPoloBLE : public Object {
	GDCLASS(RetroPoloBLE, Object);

	RPBleCore *core = nullptr;

protected:
	static void _bind_methods();

public:
	String getStatus();
	void requestAccess();
	void hostStart(String p_name, int p_max_players);
	void setRoomInfo(int p_players);
	void scanStart();
	void scanStop();
	void join(String p_address);
	void send(int p_to, PackedByteArray p_data);
	void close();

	RetroPoloBLE();
	~RetroPoloBLE();
};
