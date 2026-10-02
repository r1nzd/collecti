pub mod document;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

pub const MAX_ROWS: u32 = 1_048_576;
pub const MAX_COLS: u32 = 16_384;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct CellRef {
    pub row: u32,
    pub col: u32,
}

impl CellRef {
    pub fn new(row: u32, col: u32) -> Self {
        Self { row, col }
    }

    pub fn key(self) -> u64 {
        ((self.row as u64) << 32) | self.col as u64
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum CellValue {
    Empty,
    Number(f64),
    Text(String),
    Boolean(bool),
    Error(String),
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Cell {
    pub value: CellValue,
    pub formula: Option<String>,
}

impl Default for Cell {
    fn default() -> Self {
        Self {
            value: CellValue::Empty,
            formula: None,
        }
    }
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct Sheet {
    pub name: String,
    pub cells: HashMap<u64, Cell>,
}

impl Sheet {
    pub fn new(name: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            cells: HashMap::new(),
        }
    }

    pub fn get(&self, at: CellRef) -> Cell {
        self.cells.get(&at.key()).cloned().unwrap_or_default()
    }

    pub fn set(&mut self, at: CellRef, cell: Cell) {
        if matches!(cell.value, CellValue::Empty) && cell.formula.is_none() {
            self.cells.remove(&at.key());
        } else {
            self.cells.insert(at.key(), cell);
        }
    }
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct Workbook {
    pub sheets: Vec<Sheet>,
}

impl Workbook {
    pub fn new() -> Self {
        Self {
            sheets: vec![Sheet::new("Sheet1")],
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cell_ref_key_unique() {
        let a = CellRef::new(1, 2).key();
        let b = CellRef::new(2, 1).key();
        assert_ne!(a, b);
    }

    #[test]
    fn set_empty_removes_cell() {
        let mut sheet = Sheet::new("Sheet1");
        let at = CellRef::new(0, 0);
        sheet.set(at, Cell { value: CellValue::Number(1.0), formula: None });
        assert_eq!(sheet.cells.len(), 1);
        sheet.set(at, Cell::default());
        assert_eq!(sheet.cells.len(), 0);
    }

    #[test]
    fn workbook_starts_with_one_sheet() {
        let wb = Workbook::new();
        assert_eq!(wb.sheets.len(), 1);
        assert_eq!(wb.sheets[0].name, "Sheet1");
    }
}