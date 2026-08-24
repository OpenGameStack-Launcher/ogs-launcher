## BaseHydrator: Base class for mirror hydrators providing shared utilities.
extends RefCounted
class_name BaseHydrator

## Copies an archive to a temp path using chunked reads to avoid memory spikes.
## Returns the temp_path on success, or empty string on failure.
func _copy_archive_to_temp(source_path: String, temp_path: String) -> String:
	var source = FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return ""
	var dest = FileAccess.open(temp_path, FileAccess.WRITE)
	if dest == null:
		source.close()
		return ""
	while not source.eof_reached():
		var chunk = source.get_buffer(1024 * 1024)
		if chunk.size() == 0:
			break
		dest.store_buffer(chunk)
	source.close()
	dest.close()
	return temp_path
