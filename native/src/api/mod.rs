use crate::io::{self, DocKind};
use std::path::Path;

pub fn app_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

pub fn create_document(path: String, kind: DocKind) -> anyhow::Result<()> {
    io::write_container(Path::new(&path), kind, b"{}")
}

pub fn read_document_kind(path: String) -> anyhow::Result<DocKind> {
    Ok(io::read_manifest(Path::new(&path))?.kind)
}
