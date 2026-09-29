use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DocumentEntry {
    pub id: String,
    pub name: String,
    pub ext: String,
    pub pinned: bool,
    pub created_at: u64,
    pub updated_at: u64,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct DocumentIndex {
    pub entries: Vec<DocumentEntry>,
}

fn index_path(dir: &str) -> PathBuf {
    Path::new(dir).join("collecti_index.json")
}

pub fn load_index(dir: &str) -> anyhow::Result<DocumentIndex> {
    let path = index_path(dir);
    if !path.exists() {
        return Ok(DocumentIndex::default());
    }
    let raw = fs::read_to_string(path)?;
    Ok(serde_json::from_str(&raw)?)
}

pub fn save_index(dir: &str, index: &DocumentIndex) -> anyhow::Result<()> {
    fs::create_dir_all(dir)?;
    let path = index_path(dir);
    let tmp = path.with_extension("json.tmp");
    fs::write(&tmp, serde_json::to_vec_pretty(index)?)?;
    fs::rename(tmp, path)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roundtrip_empty_index() {
        let dir = std::env::temp_dir().join("collecti_doc_index_test_empty");
        let dir_str = dir.to_str().unwrap().to_string();
        let _ = fs::remove_dir_all(&dir);
        let index = load_index(&dir_str).unwrap();
        assert!(index.entries.is_empty());
    }

    #[test]
    fn roundtrip_with_entries() {
        let dir = std::env::temp_dir().join("collecti_doc_index_test_entries");
        let dir_str = dir.to_str().unwrap().to_string();
        let _ = fs::remove_dir_all(&dir);
        let mut index = DocumentIndex::default();
        index.entries.push(DocumentEntry {
            id: "d1".to_string(),
            name: "Bao cao".to_string(),
            ext: "awce".to_string(),
            pinned: true,
            created_at: 1,
            updated_at: 2,
        });
        save_index(&dir_str, &index).unwrap();
        let loaded = load_index(&dir_str).unwrap();
        assert_eq!(loaded.entries.len(), 1);
        assert_eq!(loaded.entries[0].name, "Bao cao");
        let _ = fs::remove_dir_all(&dir);
    }
}