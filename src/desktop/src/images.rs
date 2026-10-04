use std::path::PathBuf;

pub fn resolve(destination: &str, document: Option<&PathBuf>) -> Result<PathBuf, String> {
    let encoded = destination.split(['?', '#']).next().unwrap_or("");
    let chars = encoded.as_bytes();
    for index in 0..chars.len() {
        if chars[index] == b'%'
            && (index + 2 >= chars.len()
                || !chars[index + 1].is_ascii_hexdigit()
                || !chars[index + 2].is_ascii_hexdigit())
        {
            return Err("Invalid image path encoding.".into());
        }
    }
    let decoded = percent_encoding::percent_decode_str(encoded)
        .decode_utf8()
        .map_err(|_| "Use a UTF-8 image path.")?;
    if decoded.is_empty() || decoded.contains('\0') {
        return Err("Use a nonempty image path without NUL.".into());
    }
    if decoded.starts_with("//") {
        return Err("Use a local image path, not a URL.".into());
    }
    if let Some((prefix, tail)) = decoded.split_once(':') {
        let drive = cfg!(windows)
            && prefix.len() == 1
            && prefix.as_bytes()[0].is_ascii_alphabetic()
            && (tail.starts_with('/') || tail.starts_with('\\'));
        if !prefix.contains(['/', '\\']) && !drive {
            return Err("Use a local image path, not a URL.".into());
        }
    }
    let path = PathBuf::from(decoded.as_ref());
    if path.is_absolute() {
        return Ok(path);
    }
    let parent = document
        .and_then(|path| path.parent())
        .ok_or("Save the document before loading a relative image.")?;
    Ok(parent.join(path))
}
pub fn validate(bytes: &[u8]) -> Result<(), String> {
    if bytes.starts_with(b"\x89PNG\r\n\x1a\n")
        || bytes.starts_with(b"\xff\xd8\xff")
        || bytes.starts_with(b"GIF87a")
        || bytes.starts_with(b"GIF89a")
        || (bytes.starts_with(b"RIFF") && bytes.get(8..12) == Some(b"WEBP"))
    {
        return Ok(());
    }
    Err("Use a PNG, JPEG, GIF, or WebP image.".into())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn paths_decode_once_and_retain_document_directory() {
        let directory = tempfile::tempdir().unwrap();
        let document = directory.path().join("doc.md");
        assert_eq!(
            resolve("%E5%9B%BE%20%2520.png#section", Some(&document)).unwrap(),
            directory.path().join("图 %20.png")
        );
        assert!(resolve("relative.png", None).is_err());
        for invalid in ["", "%", "%xy.png", "%00.png", "%ff.png"] {
            assert!(resolve(invalid, Some(&document)).is_err());
        }
        let absolute = directory.path().join("image.png");
        assert_eq!(resolve(absolute.to_str().unwrap(), None).unwrap(), absolute);
    }
    #[test]
    fn signatures_and_bounded_reads_reject_non_images() {
        for bytes in [
            b"\x89PNG\r\n\x1a\n".as_slice(),
            b"\xff\xd8\xff",
            b"GIF89a",
            b"RIFF1234WEBP",
        ] {
            assert!(validate(bytes).is_ok());
        }
        for bytes in [b"<svg></svg>".as_slice(), b"text", b"RIFF", b"GIF"] {
            assert!(validate(bytes).is_err());
        }
        let directory = tempfile::tempdir().unwrap();
        assert!(super::super::read(&directory.path().to_path_buf()).is_err());
        let large = directory.path().join("large.png");
        let file = std::fs::File::create(&large).unwrap();
        file.set_len(super::super::LIMIT as u64 + 1).unwrap();
        assert!(super::super::read(&large).is_err());
    }
    #[cfg(windows)]
    #[test]
    fn windows_drive_and_unc_image_paths_remain_absolute() {
        assert_eq!(
            resolve("C:%5Cimages%5C%E5%9B%BE%20%23100%25.png", None).unwrap(),
            PathBuf::from("C:\\images\\图 #100%.png")
        );
        assert_eq!(
            resolve("%5C%5Cserver%5Cshare%5Ca%20%5Bb%5D%25.png", None).unwrap(),
            PathBuf::from("\\\\server\\share\\a [b]%.png")
        );
    }
}
