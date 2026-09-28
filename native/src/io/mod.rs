use anyhow::{bail, Context, Result};
use serde::{Deserialize, Serialize};
use std::{
    fs::{self, File},
    io::{Read, Write},
    path::Path,
    time::{SystemTime, UNIX_EPOCH},
};
use zip::{write::SimpleFileOptions, CompressionMethod, ZipArchive, ZipWriter};

pub const FORMAT_VERSION: u32 = 1;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum DocKind {
    Write,
    Present,
    Table,
    Clip,
    Canvas,
    Design,
}

impl DocKind {
    pub fn extension(self) -> &'static str {
        match self {
            DocKind::Write => "awce",
            DocKind::Present => "apce",
            DocKind::Table => "atce",
            DocKind::Clip => "arce",
            DocKind::Canvas => "acce",
            DocKind::Design => "adce",
        }
    }

    pub fn from_extension(ext: &str) -> Option<Self> {
        Some(match ext.to_ascii_lowercase().as_str() {
            "awce" => DocKind::Write,
            "apce" => DocKind::Present,
            "atce" => DocKind::Table,
            "arce" => DocKind::Clip,
            "acce" => DocKind::Canvas,
            "adce" => DocKind::Design,
            _ => return None,
        })
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Manifest {
    pub format_version: u32,
    pub kind: DocKind,
    pub app_version: String,
    pub created_at: u64,
}

pub fn write_container(path: &Path, kind: DocKind, content: &[u8]) -> Result<()> {
    let manifest = Manifest {
        format_version: FORMAT_VERSION,
        kind,
        app_version: env!("CARGO_PKG_VERSION").to_string(),
        created_at: SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs(),
    };
    let tmp = path.with_extension("tmp");
    {
        let file = File::create(&tmp).with_context(|| format!("create {tmp:?}"))?;
        let mut zip = ZipWriter::new(file);
        let opts = SimpleFileOptions::default().compression_method(CompressionMethod::Zstd);
        zip.start_file("manifest.json", opts)?;
        zip.write_all(&serde_json::to_vec_pretty(&manifest)?)?;
        zip.start_file("content.json", opts)?;
        zip.write_all(content)?;
        zip.finish()?.sync_all()?;
    }
    fs::rename(&tmp, path)?;
    Ok(())
}

fn read_entry(path: &Path, name: &str) -> Result<Vec<u8>> {
    let mut zip = ZipArchive::new(File::open(path)?)?;
    let mut entry = zip.by_name(name).with_context(|| format!("missing {name}"))?;
    let mut buf = Vec::new();
    entry.read_to_end(&mut buf)?;
    Ok(buf)
}

pub fn read_manifest(path: &Path) -> Result<Manifest> {
    let m: Manifest = serde_json::from_slice(&read_entry(path, "manifest.json")?)?;
    if m.format_version > FORMAT_VERSION {
        bail!("format_version {} mới hơn bản hiện tại", m.format_version);
    }
    Ok(m)
}

pub fn read_content(path: &Path) -> Result<Vec<u8>> {
    read_entry(path, "content.json")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roundtrip() {
        let p = std::env::temp_dir().join("collecti_test.awce");
        write_container(&p, DocKind::Write, br#"{"pages":[]}"#).unwrap();
        assert_eq!(read_manifest(&p).unwrap().kind, DocKind::Write);
        assert_eq!(read_content(&p).unwrap(), br#"{"pages":[]}"#);
        let _ = fs::remove_file(p);
    }

    #[test]
    fn extensions() {
        for k in [DocKind::Write, DocKind::Present, DocKind::Table, DocKind::Clip, DocKind::Canvas, DocKind::Design] {
            assert_eq!(DocKind::from_extension(k.extension()), Some(k));
        }
    }
}
