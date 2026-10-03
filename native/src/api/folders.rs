use crate::io::DocKind;
use crate::model::document::{self, DocumentIndex};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone)]
pub struct FolderEntry {
    pub id: String,
    pub name: String,
    pub ext: String,
    pub created_at: u64,
    pub updated_at: u64,
}

#[derive(Debug, Clone)]
pub struct DocumentFolderLink {
    pub document_id: String,
    pub folder_id: String,
}

impl From<document::FolderEntry> for FolderEntry {
    fn from(f: document::FolderEntry) -> Self {
        Self {
            id: f.id,
            name: f.name,
            ext: f.ext,
            created_at: f.created_at,
            updated_at: f.updated_at,
        }
    }
}

fn now_secs() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs()
}

fn rand_u32() -> u32 {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};
    let mut hasher = DefaultHasher::new();
    SystemTime::now().hash(&mut hasher);
    hasher.finish() as u32
}

fn new_id() -> String {
    format!("f_{}_{:x}", now_secs(), rand_u32())
}

fn clean_name(name: &str) -> anyhow::Result<String> {
    let trimmed = name.trim();
    if trimmed.is_empty() {
        anyhow::bail!("Folder name cannot be empty");
    }
    Ok(trimmed.to_string())
}

fn load(dir: &str) -> anyhow::Result<DocumentIndex> {
    document::load_index(dir)
}

fn save(dir: &str, index: &DocumentIndex) -> anyhow::Result<()> {
    document::save_index(dir, index)
}

pub fn list_folders(dir: String, ext: String) -> anyhow::Result<Vec<FolderEntry>> {
    let index = load(&dir)?;
    let mut folders: Vec<document::FolderEntry> =
        index.folders.into_iter().filter(|f| f.ext == ext).collect();
    folders.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
    Ok(folders.into_iter().map(FolderEntry::from).collect())
}

pub fn list_folder_links(dir: String) -> anyhow::Result<Vec<DocumentFolderLink>> {
    let index = load(&dir)?;
    Ok(index
        .folder_of
        .into_iter()
        .map(|(document_id, folder_id)| DocumentFolderLink { document_id, folder_id })
        .collect())
}

pub fn create_folder(dir: String, name: String, ext: String) -> anyhow::Result<FolderEntry> {
    DocKind::from_extension(&ext)
        .ok_or_else(|| anyhow::anyhow!("Invalid file extension: {ext}"))?;
    let name = clean_name(&name)?;
    let now = now_secs();
    let entry = document::FolderEntry {
        id: new_id(),
        name,
        ext,
        created_at: now,
        updated_at: now,
    };
    let mut index = load(&dir)?;
    index.folders.push(entry.clone());
    save(&dir, &index)?;
    Ok(FolderEntry::from(entry))
}

pub fn rename_folder(dir: String, id: String, new_name: String) -> anyhow::Result<()> {
    let name = clean_name(&new_name)?;
    let mut index = load(&dir)?;
    let folder = index
        .folders
        .iter_mut()
        .find(|f| f.id == id)
        .ok_or_else(|| anyhow::anyhow!("Folder not found"))?;
    folder.name = name;
    folder.updated_at = now_secs();
    save(&dir, &index)
}

pub fn delete_folder(dir: String, id: String) -> anyhow::Result<()> {
    let mut index = load(&dir)?;
    if !index.folders.iter().any(|f| f.id == id) {
        anyhow::bail!("Folder not found");
    }
    index.folders.retain(|f| f.id != id);
    index.folder_of.retain(|_, folder_id| *folder_id != id);
    save(&dir, &index)
}

pub fn move_document_to_folder(
    dir: String,
    document_id: String,
    folder_id: Option<String>,
) -> anyhow::Result<()> {
    let mut index = load(&dir)?;
    let doc_ext = index
        .entries
        .iter()
        .find(|e| e.id == document_id)
        .map(|e| e.ext.clone())
        .ok_or_else(|| anyhow::anyhow!("Document not found"))?;
    match folder_id {
        Some(fid) => {
            let folder = index
                .folders
                .iter()
                .find(|f| f.id == fid)
                .ok_or_else(|| anyhow::anyhow!("Folder not found"))?;
            if folder.ext != doc_ext {
                anyhow::bail!("Folder belongs to a different app");
            }
            index.folder_of.insert(document_id, fid);
        }
        None => {
            index.folder_of.remove(&document_id);
        }
    }
    save(&dir, &index)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::documents::{create_document_entry, list_documents};

    fn temp_dir(name: &str) -> String {
        let dir = std::env::temp_dir().join(name);
        let _ = std::fs::remove_dir_all(&dir);
        dir.to_str().unwrap().to_string()
    }

    #[test]
    fn folder_crud_and_moves() {
        let dir = temp_dir("collecti_folders_api_test");
        let doc = create_document_entry(dir.clone(), "Report".to_string(), "awce".to_string()).unwrap();
        let folder = create_folder(dir.clone(), "Work".to_string(), "awce".to_string()).unwrap();

        assert_eq!(list_folders(dir.clone(), "awce".to_string()).unwrap().len(), 1);
        assert!(list_folders(dir.clone(), "apce".to_string()).unwrap().is_empty());

        rename_folder(dir.clone(), folder.id.clone(), "Projects".to_string()).unwrap();
        assert_eq!(list_folders(dir.clone(), "awce".to_string()).unwrap()[0].name, "Projects");

        move_document_to_folder(dir.clone(), doc.id.clone(), Some(folder.id.clone())).unwrap();
        let links = list_folder_links(dir.clone()).unwrap();
        assert_eq!(links.len(), 1);
        assert_eq!(links[0].document_id, doc.id);
        assert_eq!(links[0].folder_id, folder.id);

        move_document_to_folder(dir.clone(), doc.id.clone(), None).unwrap();
        assert!(list_folder_links(dir.clone()).unwrap().is_empty());

        move_document_to_folder(dir.clone(), doc.id.clone(), Some(folder.id.clone())).unwrap();
        delete_folder(dir.clone(), folder.id.clone()).unwrap();
        assert!(list_folders(dir.clone(), "awce".to_string()).unwrap().is_empty());
        assert!(list_folder_links(dir.clone()).unwrap().is_empty());
        assert_eq!(list_documents(dir.clone()).unwrap().len(), 1);

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn rejects_invalid_input() {
        let dir = temp_dir("collecti_folders_api_test_invalid");
        let slides = create_document_entry(dir.clone(), "Slides".to_string(), "apce".to_string()).unwrap();
        let folder = create_folder(dir.clone(), "Work".to_string(), "awce".to_string()).unwrap();

        assert!(create_folder(dir.clone(), "   ".to_string(), "awce".to_string()).is_err());
        assert!(create_folder(dir.clone(), "Bad".to_string(), "xyz".to_string()).is_err());
        assert!(move_document_to_folder(dir.clone(), slides.id.clone(), Some(folder.id.clone())).is_err());
        assert!(move_document_to_folder(dir.clone(), "missing".to_string(), None).is_err());
        assert!(delete_folder(dir.clone(), "missing".to_string()).is_err());

        let _ = std::fs::remove_dir_all(&dir);
    }
}