package fission

import "core:log"
import "core:unicode"

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
    String_Start,
    String_Chunk,
    String_End,
    Punctuation,
    Whitespace,
    Space_Chunk,
    Tab_Chunk,
    Newline,
    Carriage_Return,
    Integer_Prefix,
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
    is_word_start_proc: proc(r: rune) -> bool,
    is_word_continue_proc: proc(r: rune) -> bool,

    str_delimiter: rune,
    at_end_of_str: bool,
}

scanner_init :: proc(
    s: ^Scanner,
    input: []rune,
    opts: Scanner_Options = DEFAULT_SCANNER_OPTIONS,
    is_word_start_proc := is_word_start,
    is_word_continue_proc := is_word_continue,
) {
    s.input = input
    s.line = 1
    s.col = 1
    s.state = .Scanning
    s.offset = 0
    s.opts = opts
    s.is_word_start_proc = is_word_start_proc
    s.is_word_continue_proc = is_word_continue_proc
}

scanner_next_atom :: proc(s: ^Scanner) -> (atom: Atom) {
    atom.offset = s.offset
    atom.line, atom.col = s.line, s.col

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
        next = .Finished
        return next
    }

    switch s.state {
    case .Scanning:
        a.offset, a.line, a.col = s.offset, s.line, s.col
        ch := peek(s)
        switch true {
        case s.at_end_of_str: next = .String_End
        case is_quote(s.str_delimiter): next = .String_Chunk
        case is_quote(ch): next = .String_Start
        case s.is_word_start_proc(ch): next = .Word_Chunk
        case ch == ' ' || ch == '\t': next = .Whitespace
        case ch == '\r': next = .Carriage_Return
        case ch == '\n': next = .Newline

        case ch == '0':
            a.len += 1
            advance(s)
            next = .Integer_Prefix

        case unicode.is_digit(ch): next = .Number_Chunk
        case is_quote(ch): next = .String_Start
        case: next = .Punctuation
        }

    case .Word_Chunk:
        a.kind = .Word
        for s.is_word_continue_proc(peek(s)) {
            log.debugf("word ch: %d (%c)", peek(s), peek(s))
            a.len += 1
            advance(s)
        }
        next = .Finished

    case .Integer_Prefix:
        switch peek(s) {
        case 'b', 'B': a.kind = .Binary_Prefix; next = .Finished
        case 'x', 'X': a.kind = .Hex_Prefix;    next = .Finished
        case 'o', 'O': a.kind = .Octal_Prefix;  next = .Finished
        case:
            // not a prefix
            a.kind = .Number
            next = .Number_Chunk
        }
        a.len += 1
        advance(s)

    case .Number_Chunk:
        a.kind = .Number
        for unicode.is_digit(peek(s)) {
            a.len += 1
            advance(s)
        }
        next = .Finished

    case .String_Start:
        s.str_delimiter = peek(s)
        switch s.str_delimiter {
        case '\'': a.kind = .Single_Quote
        case '"': a.kind = .Double_Quote
        case '`': a.kind = .Backtick
        }
        a.len += 1
        advance(s)
        next = .Finished

    case .String_Chunk:
        a.kind = .String
        for peek(s) != s.str_delimiter {
            advance(s)
            a.len += 1
        }
        s.at_end_of_str = true
        next = .Finished

    case .String_End:
        switch s.str_delimiter {
        case '\'': a.kind = .Single_Quote
        case '"': a.kind = .Double_Quote
        case '`': a.kind = .Backtick
        }
        s.str_delimiter = 0
        s.at_end_of_str = false
        a.len += 1
        advance(s)
        next = .Finished

    case .Punctuation:

    case .Whitespace:
        if .Emit_Whitespace in s.opts {
            if peek(s) == ' ' do next = .Space_Chunk
            if peek(s) == '\t' do next = .Tab_Chunk
        } else {
            for peek(s) == ' ' || peek(s) == '\t' {
                advance(s)
            }
            next = .Scanning
        }

    case .Space_Chunk:
        for peek(s) == ' ' {
            a.len += 1
            advance(s)
        }
        a.kind = .Space
        next = .Finished

    case .Tab_Chunk:
        for peek(s) == '\t' {
            advance(s)
            a.len += 1
        }
        a.kind = .Tab
        next = .Finished

    case .Newline:
        a.kind = .Newline
        a.len += 1
        advance(s)
        next = .Finished

    case .Carriage_Return:
        if .Normalize_Newlines in s.opts {
            a.kind = .Newline
            a.len += 1
            advance(s)
            if peek(s) == '\n' {
                next = .Newline
            } else {
                next = .Finished
            }
        } else {
            a.kind = .Carriage_Return
            a.len += 1
            advance(s)
            next = .Finished
        }

    case .Finished: unreachable()
    }

    return next
}

@(private)
peek :: #force_inline proc(s: ^Scanner) -> rune {
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

@(private)
is_quote :: #force_inline proc(r: rune) -> bool {
    return r == '\'' ||
           r == '"'  ||
           r == '`'
}

// default .Word validation procs
@(private)
is_word_start :: proc(r: rune) -> bool {
    return unicode.is_alpha(r)
}

@(private)
is_word_continue :: proc(r: rune) -> bool {
    return unicode.is_alpha(r) ||
           unicode.is_digit(r) ||
           r == '_'
}
