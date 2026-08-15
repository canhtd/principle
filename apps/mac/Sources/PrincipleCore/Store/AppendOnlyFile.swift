import Foundation

/// Appending one line to a JSONL file that other writers may be appending to at
/// the same moment — the app and a terminal Claude Code session both write
/// `memory/favorites.jsonl` (KTD6), and the app itself can be asked to save two
/// principles in the same instant.
///
/// `seekToEnd()` followed by `write` is two steps: another writer can move the
/// end of the file between them, and then one line lands on top of the other.
/// Opening with `O_APPEND` hands the positioning to the kernel, which places
/// every `write(2)` at the true end atomically — a whole line lands, or none of
/// it does.
enum AppendOnlyFile {
    /// Appends `line`, first repairing a file that was left without its final
    /// newline: a hand-edited file would otherwise glue the two entries together
    /// and cost both of them.
    static func append(_ line: Data, to fileURL: URL) throws {
        // O_RDWR rather than O_WRONLY: the separator check below reads the last
        // byte back. O_APPEND still forces every write to the end.
        let descriptor = open(fileURL.path, O_RDWR | O_APPEND | O_CREAT, 0o644)
        guard descriptor >= 0 else { throw posixError() }
        defer { close(descriptor) }

        // Prepended rather than written separately, so the repair and the entry
        // are the same single append and no other writer can slip between them.
        let payload = try endsWithNewline(descriptor) ? line : Data("\n".utf8) + line
        try writeAll(payload, to: descriptor)
    }

    /// True for an empty file too: there is nothing to separate the first line from.
    private static func endsWithNewline(_ descriptor: Int32) throws -> Bool {
        var info = stat()
        guard fstat(descriptor, &info) == 0 else { throw posixError() }
        guard info.st_size > 0 else { return true }
        var last: UInt8 = 0
        // `pread` reads at an absolute offset without disturbing the append position.
        guard pread(descriptor, &last, 1, off_t(info.st_size - 1)) == 1 else { throw posixError() }
        return last == UInt8(ascii: "\n")
    }

    private static func writeAll(_ data: Data, to descriptor: Int32) throws {
        try data.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            var written = 0
            while written < buffer.count {
                let count = write(descriptor, base + written, buffer.count - written)
                if count < 0 {
                    if errno == EINTR { continue }
                    throw posixError()
                }
                written += count
            }
        }
    }

    /// Snapshots `errno` at the call site; anything else may have moved it.
    private static func posixError() -> any Error {
        NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
}
