class_name SafeFile
extends RefCounted
## Crash-safe writes for the game's own files (career slots, store.cfg, settings, the profile).
##
## A write goes to `<path>.tmp` first and is read back. Only a complete copy replaces the real
## file, by rename. Just before that, the file being replaced is copied to `<path>.prev`, so there
## is always one earlier good copy. A phone that dies, runs out of battery, or is killed by iOS
## mid-write leaves either the old file or the new one, never half of one. If the real file is
## ever unreadable, readers fall back to `.prev` (read_text / load_config).
##
## The file formats don't change: existing saves load exactly as before.

const TMP := ".tmp"
const PREV := ".prev"

static func _abs(p: String) -> String:
	return ProjectSettings.globalize_path(p)

## Writes `text` to `path` atomically. False (and the old file untouched) on any failure.
static func write_text(path: String, text: String) -> bool:
	var tmp := path + TMP
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SafeFile: can't write %s: %s" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	var werr := f.get_error()
	f.close()
	# read back: the bytes on disk are the bytes we meant to write (a full disk shows up here)
	var want := text.to_utf8_buffer().size()
	var check := FileAccess.open(tmp, FileAccess.READ)
	var got := -1 if check == null else int(check.get_length())
	if check != null:
		check.close()
	if werr != OK or got != want:
		push_error("SafeFile: %s didn't write completely (%d of %d bytes); the old file is kept." % [path, got, want])
		DirAccess.remove_absolute(_abs(tmp))
		return false
	return _commit(path)

## Saves a ConfigFile to `path` atomically (same rules as write_text).
static func save_config(cf: ConfigFile, path: String) -> bool:
	var tmp := path + TMP
	var err := cf.save(tmp)
	if err != OK:
		push_error("SafeFile: can't write %s: %s" % [tmp, error_string(err)])
		return false
	var check := ConfigFile.new()
	if check.load(tmp) != OK:
		push_error("SafeFile: %s didn't write cleanly; the old file is kept." % path)
		DirAccess.remove_absolute(_abs(tmp))
		return false
	return _commit(path)

## The verified tmp file replaces `path`; the file it replaces is kept as `path.prev`.
static func _commit(path: String) -> bool:
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(_abs(path), _abs(path + PREV))   # (best effort: the new file still goes in)
	var err := DirAccess.rename_absolute(_abs(path + TMP), _abs(path))
	if err != OK:
		push_error("SafeFile: can't replace %s: %s" % [path, error_string(err)])
		return false
	return true

## The text of `path`, or of its `.prev` copy when `path` is missing, empty or (with `json`) not a
## JSON object/array. "" when neither is usable. `used_prev` (an Array) gets true appended when the
## earlier copy was the one read.
static func read_text(path: String, json: bool = true, used_prev: Array = []) -> String:
	var text := _read(path)
	if _usable(text, json):
		return text
	var prev := _read(path + PREV)
	if _usable(prev, json):
		push_warning("SafeFile: %s was unreadable; using its previous copy." % path)
		used_prev.append(true)
		return prev
	return text

static func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)

static func _usable(text: String, json: bool) -> bool:
	if text.strip_edges() == "":
		return false
	if not json:
		return true
	var d = JSON.parse_string(text)
	return d is Dictionary or d is Array

## cf.load(path), falling back to `path.prev` when the real file is missing or damaged.
static func load_config(cf: ConfigFile, path: String) -> Error:
	var err := cf.load(path)
	if err == OK:
		return OK
	if FileAccess.file_exists(path + PREV):
		var e2 := cf.load(path + PREV)
		if e2 == OK:
			push_warning("SafeFile: %s was unreadable; using its previous copy." % path)
			return OK
	return err

## Removes `path` and its tmp/prev companions (a deleted career slot, RESET GAME).
static func remove_all(path: String) -> void:
	for p in [path, path + TMP, path + PREV]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(_abs(p))
