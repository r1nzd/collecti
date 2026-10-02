use crate::io::{self, DocKind};
use crate::model::document::{self, DocumentIndex};
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone)]
pub struct DocumentEntry {
    pub id: String,
    pub name: String,
    pub ext: String,
    pub pinned: bool,
    pub created_at: u64,
    pub updated_at: u64,
}

impl From<document::DocumentEntry> for DocumentEntry {
    fn from(e: document::DocumentEntry) -> Self {
        Self {
            id: e.id,
            name: e.name,
            ext: e.ext,
            pinned: e.pinned,
            created_at: e.created_at,
            updated_at: e.updated_at,
        }
    }
}

impl From<DocumentEntry> for document::DocumentEntry {
    fn from(e: DocumentEntry) -> Self {
        Self {
            id: e.id,
            name: e.name,
            ext: e.ext,
            pinned: e.pinned,
            created_at: e.created_at,
            updated_at: e.updated_at,
        }
    }
}

fn now_secs() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs()
}

fn new_id() -> String {
    format!("d_{}_{:x}", now_secs(), rand_u32())
}

fn rand_u32() -> u32 {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};
    let mut hasher = DefaultHasher::new();
    SystemTime::now().hash(&mut hasher);
    hasher.finish() as u32
}

fn doc_kind_from_ext(ext: &str) -> anyhow::Result<DocKind> {
    DocKind::from_extension(ext).ok_or_else(|| anyhow::anyhow!("Duoi file khong hop le: {ext}"))
}

fn load_index(dir: &str) -> anyhow::Result<DocumentIndex> {
    document::load_index(dir)
}

fn save_index(dir: &str, index: &DocumentIndex) -> anyhow::Result<()> {
    document::save_index(dir, index)
}

pub fn list_documents(dir: String) -> anyhow::Result<Vec<DocumentEntry>> {
    let mut index = load_index(&dir)?;
    index.entries.sort_by(|a, b| b.updated_at.cmp(&a.updated_at));
    Ok(index.entries.into_iter().map(DocumentEntry::from).collect())
}

pub fn create_document_entry(dir: String, name: String, ext: String) -> anyhow::Result<DocumentEntry> {
    let kind = doc_kind_from_ext(&ext)?;
    std::fs::create_dir_all(&dir)?;
    let id = new_id();
    let file_path = Path::new(&dir).join(format!("{id}.{ext}"));
    io::write_container(&file_path, kind, b"{}")?;

    let entry = document::DocumentEntry {
        id,
        name,
        ext,
        pinned: false,
        created_at: now_secs(),
        updated_at: now_secs(),
    };

    let mut index = load_index(&dir)?;
    index.entries.push(entry.clone());
    save_index(&dir, &index)?;
    Ok(DocumentEntry::from(entry))
}

pub fn rename_document_entry(dir: String, id: String, new_name: String) -> anyhow::Result<()> {
    let mut index = load_index(&dir)?;
    let entry = index
        .entries
        .iter_mut()
        .find(|e| e.id == id)
        .ok_or_else(|| anyhow::anyhow!("Khong tim thay tai lieu"))?;
    entry.name = new_name;
    entry.updated_at = now_secs();
    save_index(&dir, &index)
}

pub fn toggle_pin_document(dir: String, id: String) -> anyhow::Result<bool> {
    let mut index = load_index(&dir)?;
    let entry = index
        .entries
        .iter_mut()
        .find(|e| e.id == id)
        .ok_or_else(|| anyhow::anyhow!("Khong tim thay tai lieu"))?;
    entry.pinned = !entry.pinned;
    let pinned = entry.pinned;
    save_index(&dir, &index)?;
    Ok(pinned)
}

pub fn delete_document_entry(dir: String, id: String) -> anyhow::Result<()> {
    let mut index = load_index(&dir)?;
    let removed = index
        .entries
        .iter()
        .find(|e| e.id == id)
        .cloned()
        .ok_or_else(|| anyhow::anyhow!("Khong tim thay tai lieu"))?;
    index.entries.retain(|e| e.id != id);
    save_index(&dir, &index)?;

    let file_path = Path::new(&dir).join(format!("{}.{}", removed.id, removed.ext));
    let _ = std::fs::remove_file(file_path);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_dir(name: &str) -> String {
        let dir = std::env::temp_dir().join(name);
        let _ = std::fs::remove_dir_all(&dir);
        dir.to_str().unwrap().to_string()
    }

    #[test]
    fn create_list_rename_pin_delete() {
        let dir = temp_dir("collecti_docs_api_test3");

        let entry = create_document_entry(dir.clone(), "Tai lieu".to_string(), "awce".to_string()).unwrap();
        let listed = list_documents(dir.clone()).unwrap();
        assert_eq!(listed.len(), 1);
        assert_eq!(listed[0].name, "Tai lieu");

        rename_document_entry(dir.clone(), entry.id.clone(), "Tai lieu moi".to_string()).unwrap();
        let listed = list_documents(dir.clone()).unwrap();
        assert_eq!(listed[0].name, "Tai lieu moi");

        let pinned = toggle_pin_document(dir.clone(), entry.id.clone()).unwrap();
        assert!(pinned);

        delete_document_entry(dir.clone(), entry.id.clone()).unwrap();
        let listed = list_documents(dir.clone()).unwrap();
        assert!(listed.is_empty());

        let _ = std::fs::remove_dir_all(&dir);
    }
}