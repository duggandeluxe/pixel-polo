@tool
extends EditorPlugin
## Puts the Bluetooth LE Android plugin (tools/build_ble_android.sh -> bin/retropolo-ble.aar) into
## Android exports. Android plugins need "Use Gradle Build"; exports without the AAR are untouched,
## so the plain APK still builds (Bluetooth then shows as unavailable and Wi-Fi works).

var exporter: ExportPlugin

func _enter_tree() -> void:
	exporter = ExportPlugin.new()
	add_export_plugin(exporter)

func _exit_tree() -> void:
	remove_export_plugin(exporter)
	exporter = null

class ExportPlugin extends EditorExportPlugin:
	const AAR := "retropolo_ble/bin/retropolo-ble.aar"      # relative to res://addons/

	func _get_name() -> String:
		return "RetroPoloBLE"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		if not FileAccess.file_exists("res://addons/" + AAR):
			return PackedStringArray()
		return PackedStringArray([AAR])
