#include "register_types.h"

#include "retropolo_ble.h"

#include "core/config/engine.h"

static RetroPoloBLE *ble_singleton = nullptr;

void register_retropolo_ble_types() {
	GDREGISTER_CLASS(RetroPoloBLE);
	ble_singleton = memnew(RetroPoloBLE);
	Engine::get_singleton()->add_singleton(Engine::Singleton("RetroPoloBLE", ble_singleton));
}

void unregister_retropolo_ble_types() {
	if (ble_singleton) {
		memdelete(ble_singleton);
		ble_singleton = nullptr;
	}
}
