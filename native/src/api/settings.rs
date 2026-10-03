use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

const THEME_MODES: [&str; 3] = ["system", "light", "dark"];
const ACCENTS: [&str; 5] = ["purple", "blue", "green", "orange", "pink"];

fn default_theme_mode() -> String {
    "system".to_string()
}

fn default_accent() -> String {
    "purple".to_string()
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct AppSettings {
    #[serde(default = "default_theme_mode")]
    pub theme_mode: String,
    #[serde(default = "default_accent")]
    pub accent: String,
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            theme_mode: default_theme_mode(),
            accent: default_accent(),
        }
    }
}

fn sanitize(mut settings: AppSettings) -> AppSettings {
    if !THEME_MODES.contains(&settings.theme_mode.as_str()) {
        settings.theme_mode = default_theme_mode();
    }
    if !ACCENTS.contains(&settings.accent.as_str()) {
        settings.accent = default_accent();
    }
    settings
}

fn settings_path(dir: &str) -> std::path::PathBuf {
    Path::new(dir).join("collecti_settings.json")
}

pub fn load_settings(dir: String) -> anyhow::Result<AppSettings> {
    let path = settings_path(&dir);
    if !path.exists() {
        return Ok(AppSettings::default());
    }
    let raw = fs::read_to_string(path)?;
    match serde_json::from_str::<AppSettings>(&raw) {
        Ok(settings) => Ok(sanitize(settings)),
        Err(_) => Ok(AppSettings::default()),
    }
}

pub fn save_settings(dir: String, settings: AppSettings) -> anyhow::Result<()> {
    let settings = sanitize(settings);
    fs::create_dir_all(&dir)?;
    let path = settings_path(&dir);
    let tmp = path.with_extension("json.tmp");
    fs::write(&tmp, serde_json::to_vec_pretty(&settings)?)?;
    fs::rename(tmp, path)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_dir(name: &str) -> String {
        let dir = std::env::temp_dir().join(name);
        let _ = fs::remove_dir_all(&dir);
        dir.to_str().unwrap().to_string()
    }

    #[test]
    fn missing_file_gives_defaults() {
        let dir = temp_dir("collecti_settings_test_missing");
        let settings = load_settings(dir).unwrap();
        assert_eq!(settings, AppSettings::default());
        assert_eq!(settings.theme_mode, "system");
        assert_eq!(settings.accent, "purple");
    }

    #[test]
    fn save_then_load_roundtrip() {
        let dir = temp_dir("collecti_settings_test_roundtrip");
        let settings = AppSettings {
            theme_mode: "dark".to_string(),
            accent: "green".to_string(),
        };
        save_settings(dir.clone(), settings.clone()).unwrap();
        assert_eq!(load_settings(dir.clone()).unwrap(), settings);
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn unknown_values_fall_back_to_defaults() {
        let dir = temp_dir("collecti_settings_test_invalid");
        let settings = AppSettings {
            theme_mode: "neon".to_string(),
            accent: "teal".to_string(),
        };
        save_settings(dir.clone(), settings).unwrap();
        assert_eq!(load_settings(dir.clone()).unwrap(), AppSettings::default());
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn partial_and_corrupt_files_do_not_fail() {
        let dir = temp_dir("collecti_settings_test_partial");
        fs::create_dir_all(&dir).unwrap();
        fs::write(settings_path(&dir), br#"{"accent":"pink"}"#).unwrap();
        let partial = load_settings(dir.clone()).unwrap();
        assert_eq!(partial.accent, "pink");
        assert_eq!(partial.theme_mode, "system");

        fs::write(settings_path(&dir), b"not json").unwrap();
        assert_eq!(load_settings(dir.clone()).unwrap(), AppSettings::default());
        let _ = fs::remove_dir_all(&dir);
    }
}