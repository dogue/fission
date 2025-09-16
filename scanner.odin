package fission

Atom_Kind :: enum {
    Unknown,
    EOF,
    Alpha,
    Word,
    String,
    Number,

    // punctuation
    Bang,
    At,
    Hash,
    Dollar,
    Percent,
    Caret,
    Ampersand,
    Asterisk,
    Left_Paren,
    Right_Paren,
    Left_Brace,
    Right_Brace,
    Left_Bracket,
    Right_Bracket,
    Plus,
    Equal,
    Minus,
    Underscore,
    Pipe,
    Backslash,
    Slash,
    Question,
    Dot,
    Comma,
    Less_Than,
    Greater_Than,
    Tilde,
    Backtick,
    Single_Quote,
    Double_Quote,
    Colon,
    Semicolon,

    // whitespace
    Space,
    Tab,
    Newline,
    Carriage_Return,

    // integer format prefixes
    Octal_Prefix,
    Hex_Prefix,
    Binary_Prefix,
}

Atom :: struct {
    kind: Atom_Kind,
    offset: int,
    len: int,
    line: int,
    col: int,
}

Scanner_State :: enum {
    Scanning,
    Finished,
    Word_Chunk,
    Number_Chunk,
    String_Chunk,
    Punctuation,
    Whitespace,
    Newline,
}

Scanner_Options :: bit_set[Scanner_Option]
Scanner_Option :: enum {
    Emit_Whitespace,
    Normalize_Newlines,
}

DEFAULT_SCANNER_OPTIONS :: Scanner_Options { .Normalize_Newlines }

Scanner :: struct {
    input: []rune,
    line: int,
    col: int,
    state: Scanner_State,
    offset: int,
    opts: Scanner_Options,
}

scanner_init :: proc(s: ^Scanner, input: []rune, opts: Scanner_Options = DEFAULT_SCANNER_OPTIONS) {
    s.input = input
    s.line = 1
    s.col = 1
    s.state = .Scanning
    s.offset = 0
    s.opts = opts
}

scanner_next_atom :: proc(s: ^Scanner) -> (atom: Atom) {
    for s.state != .Finished {
        s.state = scan(s, &atom)
    }
    s.state = .Scanning
    return atom
}

@(private)
scan :: proc(s: ^Scanner, a: ^Atom) -> (next: Scanner_State) {
    if s.offset >= len(s.input) {
        a.kind = .EOF
        a.len = 0
        a.offset, a.line, a.col = s.offset, s.line, s.col
        next = .Finished
        return next
    }

    switch s.state {
    case .Scanning:
        switch current_rune(s) {
        case 'a'..='z', 'A'..='Z': next = .Word_Chunk
        case '0'..='9': next = .Number_Chunk
        case ' ', '\t': next = .Whitespace
        case '\r', '\n': next = .Newline

        // quotes advance to consume the quote character
        case '\'':
            a.kind = .Single_Quote
            a.len += 1
            advance(s)
            next = .String_Chunk

        case '"':
            a.kind = .Double_Quote
            a.len += 1
            advance(s)
            next = .String_Chunk

        case '`':
            a.kind = .Backtick
            a.len += 1
            advance(s)
            next = .String_Chunk

        // assume anything else is punctuation
        // if not, deal with it in the Punctuation state
        case: next = .Punctuation
        }

    case .Finished:
    case .Word_Chunk:
    case .Number_Chunk:
    case .String_Chunk:
    case .Punctuation:
    case .Whitespace:
    case .Newline:
    }

    return next
}

@(private)
current_rune :: proc(s: ^Scanner) -> rune {
    if s.offset >= len(s.input) {
        return 0
    } else {
        return s.input[s.offset]
    }
}

@(private)
advance :: proc(s: ^Scanner) {
    s.offset += 1

    if s.state == .Newline {
        s.line += 1
        s.col = 0
    }

    s.col += 1
}
