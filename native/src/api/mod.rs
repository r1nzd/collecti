pub mod documents;
use crate::io::{self, DocKind};
use crate::model::{Cell, CellRef, CellValue, Workbook};
use crate::engines::formula;
use std::path::Path;
use std::sync::Mutex;

pub fn app_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

pub fn create_document(path: String, kind: DocKind) -> anyhow::Result<()> {
    io::write_container(Path::new(&path), kind, b"{}")
}

pub fn read_document_kind(path: String) -> anyhow::Result<DocKind> {
    Ok(io::read_manifest(Path::new(&path))?.kind)
}

static WORKBOOK: Mutex<Option<Workbook>> = Mutex::new(None);

fn with_workbook<T>(f: impl FnOnce(&mut Workbook) -> T) -> T {
    let mut guard = WORKBOOK.lock().unwrap();
    if guard.is_none() {
        *guard = Some(Workbook::new());
    }
    f(guard.as_mut().unwrap())
}

#[derive(Debug, Clone)]
pub struct CellSnapshot {
    pub row: u32,
    pub col: u32,
    pub display: String,
    pub is_error: bool,
}

pub fn set_cell_input(sheet_index: u32, row: u32, col: u32, input: String) -> Vec<CellSnapshot> {
    with_workbook(|wb| {
        let sheet = &mut wb.sheets[sheet_index as usize];
        let at = CellRef::new(row, col);

        let cell = if let Some(stripped) = input.strip_prefix('=') {
            let formula = format!("={stripped}");
            let value = formula::evaluate(&formula, sheet);
            Cell { value, formula: Some(formula) }
        } else if input.is_empty() {
            Cell::default()
        } else if let Ok(n) = input.parse::<f64>() {
            Cell { value: CellValue::Number(n), formula: None }
        } else {
            Cell { value: CellValue::Text(input), formula: None }
        };

        sheet.set(at, cell);
        recompute_formulas(sheet)
    })
}

fn recompute_formulas(sheet: &mut crate::model::Sheet) -> Vec<CellSnapshot> {
    let keys: Vec<u64> = sheet.cells.keys().copied().collect();
    for key in keys {
        let has_formula = sheet.cells.get(&key).and_then(|c| c.formula.clone());
        if let Some(formula) = has_formula {
            let new_value = formula::evaluate(&formula, sheet);
            if let Some(cell) = sheet.cells.get_mut(&key) {
                cell.value = new_value;
            }
        }
    }
    sheet
        .cells
        .iter()
        .map(|(key, cell)| {
            let row = (*key >> 32) as u32;
            let col = (*key & 0xFFFF_FFFF) as u32;
            cell_snapshot(row, col, cell)
        })
        .collect()
}

fn cell_snapshot(row: u32, col: u32, cell: &Cell) -> CellSnapshot {
    let (display, is_error) = match &cell.value {
        CellValue::Empty => (String::new(), false),
        CellValue::Number(n) => (format_number(*n), false),
        CellValue::Text(t) => (t.clone(), false),
        CellValue::Boolean(b) => ((if *b { "TRUE" } else { "FALSE" }).to_string(), false),
        CellValue::Error(e) => (format!("#LOI: {e}"), true),
    };
    CellSnapshot { row, col, display, is_error }
}

fn format_number(n: f64) -> String {
    if n.fract() == 0.0 && n.abs() < 1e15 {
        format!("{n:.0}")
    } else {
        format!("{n}")
    }
}

pub fn get_sheet_snapshot(sheet_index: u32) -> Vec<CellSnapshot> {
    with_workbook(|wb| {
        let sheet = &wb.sheets[sheet_index as usize];
        sheet
            .cells
            .iter()
            .map(|(key, cell)| {
                let row = (*key >> 32) as u32;
                let col = (*key & 0xFFFF_FFFF) as u32;
                cell_snapshot(row, col, cell)
            })
            .collect()
    })
}

pub fn get_cell_input(sheet_index: u32, row: u32, col: u32) -> String {
    with_workbook(|wb| {
        let sheet = &wb.sheets[sheet_index as usize];
        let cell = sheet.get(CellRef::new(row, col));
        cell.formula.unwrap_or_else(|| match cell.value {
            CellValue::Empty => String::new(),
            CellValue::Number(n) => format_number(n),
            CellValue::Text(t) => t,
            CellValue::Boolean(b) => (if b { "TRUE" } else { "FALSE" }).to_string(),
            CellValue::Error(e) => e,
        })
    })
}
pub fn open_workbook(path: String) -> anyhow::Result<()> {
    let p = Path::new(&path);
    let mut wb = if p.exists() {
        let manifest = io::read_manifest(p)?;
        if manifest.kind != DocKind::Table {
            anyhow::bail!("Tep khong phai bang tinh");
        }
        let bytes = io::read_content(p)?;
        if bytes.as_slice() == b"{}" {
            Workbook::new()
        } else {
            serde_json::from_slice::<Workbook>(&bytes)?
        }
    } else {
        Workbook::new()
    };
    if wb.sheets.is_empty() {
        wb.sheets.push(crate::model::Sheet::new("Sheet1"));
    }
    *WORKBOOK.lock().unwrap() = Some(wb);
    Ok(())
}

pub fn save_workbook(path: String) -> anyhow::Result<()> {
    let bytes = with_workbook(|wb| serde_json::to_vec(wb))?;
    io::write_container(Path::new(&path), DocKind::Table, &bytes)
}

#[cfg(test)]
mod workbook_io_tests {
    use super::*;

    #[test]
    fn save_and_open_roundtrip() {
        let dir = std::env::temp_dir().join("collecti_workbook_io_test");
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("sample.atce").to_str().unwrap().to_string();

        open_workbook(path.clone()).unwrap();
        set_cell_input(0, 0, 0, "7".to_string());
        set_cell_input(0, 1, 0, "=A1*2".to_string());
        save_workbook(path.clone()).unwrap();

        *WORKBOOK.lock().unwrap() = None;
        open_workbook(path.clone()).unwrap();
        assert_eq!(get_cell_input(0, 1, 0), "=A1*2");
        let snapshot = get_sheet_snapshot(0);
        assert!(snapshot.iter().any(|c| c.row == 1 && c.col == 0 && c.display == "14"));

        let _ = std::fs::remove_dir_all(&dir);
    }
}