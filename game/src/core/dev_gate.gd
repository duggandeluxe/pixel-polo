class_name DevGate
extends RefCounted
## DEVELOPER ACCESS: the one check between the game and the DEV screen (dev_settings: Developer
## Mode, the developer tools, RESET EVERYTHING). Settings' DEV button asks for the four-digit code
## (DevPad); the right one opens a session, and Game.goto lets "dev_settings" through only while one
## is open (anything else is sent to Settings). The session closes whenever the player is back in the
## normal menus (Settings, the title, the hub) and on RESET EVERYTHING, so every new visit to the
## DEV screen asks again; the developer labs it opens (and their back to it) keep it.
## The code itself is never kept here in plain text: only its SHA-256.

const SCREEN := "dev_settings"
const CODE_LEN := 4
const _CODE_SHA256 := "286c897eba57ce67e79fff80229d9eacddde784b29a18a1d47c17bade5ad1a08"
## Leaving the DEV area for these closes the session.
const LOCKS_ON := ["settings", "title", "hub"]

static var _open := false

## RELEASE BUILDS: the DEV screen, its labs and Developer Mode exist only in development builds
## (the editor and debug exports: OS.is_debug_build()) or in an export whose preset adds the custom
## feature tag "dev_tools" (an internal build: never the App Store one). In an App Store (release)
## build no code opens them, the DEV button isn't shown, and Developer Mode stays off.
const DEV_FEATURE := "dev_tools"

## Tests only: behave as an App Store (release) build would.
static var simulate_release := false

static func allowed() -> bool:
	if simulate_release:
		return false
	return OS.is_debug_build() or OS.has_feature(DEV_FEATURE)

## Screens that are developer-only: the DEV screen, every lab (*_lab) and dev_* screen.
static func is_dev_screen(name: String) -> bool:
	return name == SCREEN or name.ends_with("_lab") or name.begins_with("dev_")

## The entered code: right, the session opens (true); wrong, it stays shut.
static func try_unlock(code: String) -> bool:
	if not allowed():
		_open = false
		return false
	_open = code.length() == CODE_LEN and code.is_valid_int() and code.sha256_text() == _CODE_SHA256
	return _open

static func is_open() -> bool:
	return _open

static func lock() -> void:
	_open = false

## Game.goto's check: the screen actually to open for `name`.
static func route(name: String) -> String:
	if name in LOCKS_ON:
		_open = false
	if not allowed() and is_dev_screen(name):
		return "settings"   # (release build: no lab or DEV screen, however it's asked for)
	if name == SCREEN and not _open:
		return "settings"
	return name
