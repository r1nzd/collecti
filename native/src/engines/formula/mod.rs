use crate::model::{Cell, CellRef, CellValue, Sheet};

#[derive(Debug, Clone, PartialEq)]
enum Token {
    Number(f64),
    Cell(CellRef),
    Plus,
    Minus,
    Star,
    Slash,
    LParen,
    RParen,
}

fn tokenize(src: &str) -> Result<Vec<Token>, String> {
    let chars: Vec<char> = src.chars().collect();
    let mut i = 0;
    let mut tokens = Vec::new();
    while i < chars.len() {
        let c = chars[i];
        match c {
            ' ' | '\t' => i += 1,
            '+' => { tokens.push(Token::Plus); i += 1; }
            '-' => { tokens.push(Token::Minus); i += 1; }
            '*' => { tokens.push(Token::Star); i += 1; }
            '/' => { tokens.push(Token::Slash); i += 1; }
            '(' => { tokens.push(Token::LParen); i += 1; }
            ')' => { tokens.push(Token::RParen); i += 1; }
            '0'..='9' | '.' => {
                let start = i;
                while i < chars.len() && (chars[i].is_ascii_digit() || chars[i] == '.') {
                    i += 1;
                }
                let text: String = chars[start..i].iter().collect();
                let n: f64 = text.parse().map_err(|_| format!("Số không hợp lệ: {text}"))?;
                tokens.push(Token::Number(n));
            }
            'A'..='Z' | 'a'..='z' => {
                let start = i;
                while i < chars.len() && chars[i].is_ascii_alphabetic() {
                    i += 1;
                }
                let col_text: String = chars[start..i].iter().collect();
                let row_start = i;
                while i < chars.len() && chars[i].is_ascii_digit() {
                    i += 1;
                }
                if row_start == i {
                    return Err(format!("Tham chiếu ô không hợp lệ gần vị trí {start}"));
                }
                let row_text: String = chars[row_start..i].iter().collect();
                let col = column_letters_to_index(&col_text)?;
                let row: u32 = row_text.parse().map_err(|_| format!("Số dòng không hợp lệ: {row_text}"))?;
                if row == 0 {
                    return Err("Số dòng phải bắt đầu từ 1".to_string());
                }
                tokens.push(Token::Cell(CellRef::new(row - 1, col)));
            }
            _ => return Err(format!("Ký tự không hợp lệ: {c}")),
        }
    }
    Ok(tokens)
}

fn column_letters_to_index(letters: &str) -> Result<u32, String> {
    let mut idx: u32 = 0;
    for c in letters.chars() {
        if !c.is_ascii_alphabetic() {
            return Err(format!("Ký tự cột không hợp lệ: {c}"));
        }
        idx = idx * 26 + (c.to_ascii_uppercase() as u32 - 'A' as u32 + 1);
    }
    if idx == 0 {
        return Err("Thiếu tên cột".to_string());
    }
    Ok(idx - 1)
}

struct Parser<'a> {
    tokens: &'a [Token],
    pos: usize,
}

impl<'a> Parser<'a> {
    fn new(tokens: &'a [Token]) -> Self {
        Self { tokens, pos: 0 }
    }

    fn peek(&self) -> Option<&Token> {
        self.tokens.get(self.pos)
    }

    fn next(&mut self) -> Option<&Token> {
        let t = self.tokens.get(self.pos);
        self.pos += 1;
        t
    }

    fn parse_expr(&mut self, sheet: &Sheet) -> Result<f64, String> {
        let mut left = self.parse_term(sheet)?;
        loop {
            match self.peek() {
                Some(Token::Plus) => { self.next(); left += self.parse_term(sheet)?; }
                Some(Token::Minus) => { self.next(); left -= self.parse_term(sheet)?; }
                _ => break,
            }
        }
        Ok(left)
    }

    fn parse_term(&mut self, sheet: &Sheet) -> Result<f64, String> {
        let mut left = self.parse_factor(sheet)?;
        loop {
            match self.peek() {
                Some(Token::Star) => { self.next(); left *= self.parse_factor(sheet)?; }
                Some(Token::Slash) => {
                    self.next();
                    let rhs = self.parse_factor(sheet)?;
                    if rhs == 0.0 {
                        return Err("Chia cho 0".to_string());
                    }
                    left /= rhs;
                }
                _ => break,
            }
        }
        Ok(left)
    }

    fn parse_factor(&mut self, sheet: &Sheet) -> Result<f64, String> {
        match self.next().cloned() {
            Some(Token::Number(n)) => Ok(n),
            Some(Token::Cell(at)) => cell_to_number(&sheet.get(at)),
            Some(Token::Minus) => Ok(-self.parse_factor(sheet)?),
            Some(Token::LParen) => {
                let v = self.parse_expr(sheet)?;
                match self.next() {
                    Some(Token::RParen) => Ok(v),
                    _ => Err("Thiếu dấu ')'".to_string()),
                }
            }
            other => Err(format!("Biểu thức không hợp lệ tại: {other:?}")),
        }
    }
}

fn cell_to_number(cell: &Cell) -> Result<f64, String> {
    match &cell.value {
        CellValue::Number(n) => Ok(*n),
        CellValue::Empty => Ok(0.0),
        CellValue::Boolean(b) => Ok(if *b { 1.0 } else { 0.0 }),
        CellValue::Text(t) => Err(format!("Không thể dùng văn bản trong phép tính: {t}")),
        CellValue::Error(e) => Err(e.clone()),
    }
}

pub fn evaluate(formula: &str, sheet: &Sheet) -> CellValue {
    let expr = formula.strip_prefix('=').unwrap_or(formula);
    let result = tokenize(expr).and_then(|tokens| {
        let mut parser = Parser::new(&tokens);
        let value = parser.parse_expr(sheet)?;
        if parser.pos != tokens.len() {
            return Err("Dư ký tự ở cuối công thức".to_string());
        }
        Ok(value)
    });
    match result {
        Ok(n) => CellValue::Number(n),
        Err(e) => CellValue::Error(e),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::Cell;

    fn number(n: f64) -> CellValue {
        CellValue::Number(n)
    }

    #[test]
    fn evaluates_arithmetic() {
        let sheet = Sheet::new("Sheet1");
        assert_eq!(evaluate("=1+2*3", &sheet), number(7.0));
        assert_eq!(evaluate("=(1+2)*3", &sheet), number(9.0));
        assert_eq!(evaluate("=10/2-1", &sheet), number(4.0));
    }

    #[test]
    fn evaluates_cell_reference() {
        let mut sheet = Sheet::new("Sheet1");
        sheet.set(CellRef::new(0, 0), Cell { value: number(5.0), formula: None });
        sheet.set(CellRef::new(1, 0), Cell { value: number(2.0), formula: None });
        assert_eq!(evaluate("=A1+A2", &sheet), number(7.0));
    }

    #[test]
    fn division_by_zero_is_error() {
        let sheet = Sheet::new("Sheet1");
        assert!(matches!(evaluate("=1/0", &sheet), CellValue::Error(_)));
    }

    #[test]
    fn column_letters_multi_char() {
        assert_eq!(column_letters_to_index("A").unwrap(), 0);
        assert_eq!(column_letters_to_index("Z").unwrap(), 25);
        assert_eq!(column_letters_to_index("AA").unwrap(), 26);
    }
}