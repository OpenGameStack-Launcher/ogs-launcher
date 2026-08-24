## CryptoUtils: Shared cryptographic utility functions.

extends RefCounted
class_name CryptoUtils

## Computes sha256 for a file path using streaming reads.
static func compute_sha256(file_path: String) -> Dictionary:
	## Computes the SHA-256 hash for a file.
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {"success": false, "error_message": "Failed to read archive for hashing."}
	var hasher = HashingContext.new()
	var start_err = hasher.start(HashingContext.HASH_SHA256)
	if start_err != OK:
		file.close()
		return {"success": false, "error_message": "Failed to initialize hash context."}
	while not file.eof_reached():
		var chunk = file.get_buffer(1024 * 1024)
		if chunk.size() == 0:
			break
		hasher.update(chunk)
	file.close()
	var digest = hasher.finish()
	return {"success": true, "sha256": digest.hex_encode().to_lower()}
