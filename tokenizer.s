.global _tokenizer_init
.global _tokenize_string
.global _load_tokenizer_json
.global _parse_json_object

.struct 0
TOKENIZER_VOCAB:        .space 8    // pointer to vocabulary
TOKENIZER_VOCAB_SIZE:   .space 8    // vocabulary size
TOKENIZER_MERGES:       .space 8    // pointer to merge rules
TOKENIZER_MERGE_COUNT:  .space 8    // number of merge rules
TOKENIZER_BUFFER:       .space 8    // working buffer
TOKENIZER_SIZE:

.struct 0
TOKEN_ID:               .space 4    // token ID
TOKEN_STR:              .space 8    // pointer to token string
TOKEN_LEN:              .space 4    // token string length
TOKEN_PADDING:          .space 4    // padding for alignment
TOKEN_SIZE:

.struct 0
MERGE_PAIR_A:           .space 8    // first token
MERGE_PAIR_B:           .space 8    // second token
MERGE_RESULT:           .space 8    // merged token
MERGE_SIZE:

_tokenizer_init:
  stp   x29, x30, [sp, #-16]!
  mov   x29, sp

  mov   x1, #TOKENIZER_SIZE
  mov   x2, #0

clear_loop:
  strb  w2, [x0], #1
  subs  x1, x1, #1
  b.ne  clear_loop

  mov   x0, #0
  ldp   x29, x30, [sp], #16
  ret

// Load tokenizer.json file
// Parameters:
//   x0 = tokenizer struct pointer
//   x1 = file path pointer
// Returns:
//   x0 = 0 on success, -1 on failure
_load_tokenizer_json:
  stp   x29, x30, [sp, #-48]!
  stp   x19, x20, [sp, #16] 
  stp   x32, x22, [sp, #32]
  mov   x29, sp

  mov   x19, x0
  mov   x20, x1

  mov   x0, x20
  mov   x1, #0
  mov   x16, #5
  svc   #0

  cmp   x0, #0
  b.lt  load_error 
  mov   x21, x0

  sub   sp, sp, #144
  mov   x0, x21
  mov   x1, sp
  mov   x16, #339
  svc   #0

  cmp   x0, #0
  b.ne  load_error_close

  ldr   x22, [sp, #48] // load file size into x22
  add   sp, sp, #144 // clean up stack

  mov   x0, #0
  mov   x1, x22
  mov   x2, #3
  mov   x3, #0x1002
  mov   x4, #-1
  mov   x5, #0
  mov   x16, #222
  svc   #0

  cmp   x0, #0
  b.le  load_error_close

  str   x0, [x19, #TOKENIZER_BUFFER]

  mov   x1, x0
  mov   x0, x21
  mov   x2, x22
  mov   x16, #63 // read into TOKENIZER_BUFFER address
  svc   #0

  mov   x0, x21
  mov   x16, #6
  svc   #0

  ldr   x0, [x19, #TOKENIZER_BUFFER]
  mov   x1, x19
  bl    _parse_json_tokenizer

  cmp   x0, #0
  b.ne  load_error

  mov   x0, #0
  b     load_done

load_error_close:
  mov   x0, x21
  mov   x16, #6
  svc   #0

load_error:
  mov   x0, #-1

load_done:
  ldp   x21, x22, [sp, #32]
  ldp   x19, x20, [sp, #16]
  ldp   x29, x30, [sp], #48
  ret

// Parse JSON tokenizer format
// Parameters:
//   x0 = JSON buffer pointer
//   x1 = tokenizer struct pointer
// Returns:
//   x0 = 0 on success, -1 on error
_parse_json_tokenizer:
  stp   x29, x30, [sp, #-32]!
  stp   x19, x20, [sp, #16]
  mov   x29, sp

  mov   x19, x0
  mov   x20, x1

  bl    skip_whitespace
  ldrb  ldrb w1, [x0] 
  cmp   w1, #'{'
  b.ne  parse_error
  add   x0, x0, #1

find_model:
  bl    skip_whitespace
  bl    parse_json_string
  cmp   x0, #0
  b.eq  parse_error

  adr   x1, model_key
  bl    string_compare
  cmp   x0, #0
  b.ne  find_model

  bl    skip_whitespace
  ldrb  w1, [x0]
  cmp   w1, #':'
  b.ne  parse_error
  add   x0, x0, #1

  bl    skip_whitespace
  bl    parse_model_section

  // TODO
  // look for other keys

  mov   x0, #0
  b     parse_done

parse_error:
  mov   x0, #-1

parse_done:
  ldp   x19, x20, [sp, #16]
  ldp   x29, x30, [sp], #32
  ret

// Parse the model section of the tokenizer JSON
// Parameters:
//   x0 = JSON buffer pointer (at start of model value)
//   x1 = tokenizer struct pointer
// Returns:
//   x0 = updated buffer position
parse_model_section:
  stp   x29, x30, [sp, #-32]!
  stp   x19, x20, [sp, #16]
  mov   x29, sp

  mov   x19, x0
  mov   x20, x1

  ldrb  w1, [x19]
  cmp   w1, #'{'
  b.ne  model_parse_error
  add   x19, x19, #1
model_find_vocab:
  mov   x0, x19
  bl    skip_whitespace
  mov   x19, x0

  ldrb  w1, [x19]
  cmp   w1, #'}'
  b.eq  model_parse_done

  mov   x0, x19
  bl    parse_json_string
  cmp   x0, #0
  b.eq  model_parse_error
  mov   x21, x0
  mov   x19, x1

  mov   x0, x19
  bl    skip_whitespace
  mov   x19, x0
  ldrb  w1, [x19]
  cmp   w1, #':'
  b.ne  model_parse_error
  add   x19, x19, #1

  mov   x0, x21
  adr   x1, vocab_key
  bl    string_compare
  cmp   x0, #0
  b.eq  found_vocab

  mov   x0, x19
  bl    skip_json_value
  mov   x19, x0

// Skip over a JSON value (object, array, string, number, etc.)
// Parameters:
//   x0 = buffer position
// Returns:
//   x0 = position after the value
skip_json_value:
  stp   x29, x30, [sp, #-32]!
  stp   x19, x20, [sp, #16]
  mov   x29, sp

  bl    skip_whitespace
  mov   x19, x0

  ldrb  w1, [x19]

  cmp   w1, #'"'
  b.eq  skip_string_value
  cmp   w1, #'{'
  b.eq  skip_object_value
  cmp   w1, #'['
  b.eq  skip_array_value
    
  // Must be number, true, false, or null
  b     skip_primitive_value
skip_string_value:
  mov   x0, x19
  bl    skip_json_string
  mov   x19, x0
  b     skip_value_done
skip_object_value:


// Compare two null-terminated strings
// Parameters:
//   x0 = pointer to first string
//   x1 = pointer to second string
// Returns:
//   x0 = 1 if strings are equal, 0 if not
string_compare:
  stp   x29, x30, [sp, #-16]!
  mov   x29, sp

  mov   x2, x0
  mov   x3, x1
string_compare_loop:
  ldrb  w4, [x2], #1
  ldrb  w5, [x3], #1

  cmp   w4, w5
  b.ne  strings_differ

  cmp   w4, #0
  b.ne  string_compare_loop

  mov   x0, #1
  b     string_compare_done
strings_differ:
  mov   x0, #0
string_compare_done:
  ldp   x29, x30, [sp], #16
  ret

// Parse a JSON string and return pointer to the string content
// Parameters:
//   x0 = buffer position (should be at opening quote)
// Returns:
//   x0 = pointer to string content (without quotes)
//   x1 = updated buffer position (after closing quote)
parse_json_string:
  stp   x29, x30, [sp, #-48]!
  stp   x19, x20, [sp, #16]
  stp   x21, x22, [sp, #32]
  mov   x29, sp

  ldrb  w1, [x19]
  cmp   w1, #'"'
  b.ne  parse_string_error

  add   x20, x19, #1
  mov   x21, x20
find_string_end:
  ldrb  w1, [x20]
  cbz   w1, parse_string_error

  cmp   w1, #'\\'
  b.eq  handle_escape

  cmp   w1, #'"'
  b.eq  found_string_end

  add   x20, x20, #1
  b     find_string_end
found_string_end:
  mov   w2, #0              // Null terminate the string
  strb  w2, [x20]
  
  mov   x0, x21             // Return string start
  add   x1, x20, #1         // Return position after quote
  
  ldp   x21, x22, [sp, #32]
  ldp   x19, x20, [sp, #16]
  ldp   x29, x30, [sp], #48
  ret
handle_escape:
    stp   x29, x30, [sp, #-16]!
    mov   x29, sp
    
    // Skip past the backslash
    add   x20, x20, #1
    
    // Load the character being escaped
    ldrb  w1, [x20]
    cbz   w1, escape_error      // Error: backslash at end of string
    
    // Check what character is being escaped
    cmp   w1, #'"'              // \"
    b.eq  escape_quote
    
    cmp   w1, #'\\'             // \\
    b.eq  escape_backslash
    
    cmp   w1, #'/'              // \/
    b.eq  escape_slash
    
    cmp   w1, #'b'              // \b (backspace)
    b.eq  escape_backspace
    
    cmp   w1, #'f'              // \f (form feed)
    b.eq  escape_form_feed
    
    cmp   w1, #'n'              // \n (newline)
    b.eq  escape_newline
    
    cmp   w1, #'r'              // \r (carriage return)
    b.eq  escape_carriage_return
    
    cmp   w1, #'t'              // \t (tab)
    b.eq  escape_tab
    
    cmp   w1, #'u'              // \uXXXX (unicode)
    b.eq  escape_unicode
    
    // Unknown escape sequence - this is an error in strict JSON
    b     escape_error
escape_quote:
    mov   w1, #'"'              // ASCII 34 (0x22)
    b     store_escaped_char
escape_backslash:
    mov   w1, #'\\'             // ASCII 92 (0x5C)
    b     store_escaped_char
escape_slash:
    mov   w1, #'/'              // ASCII 47 (0x2F)
    b     store_escaped_char
escape_backspace:
    mov   w1, #8                // ASCII 8 (BS)
    b     store_escaped_char
escape_form_feed:
    mov   w1, #12               // ASCII 12 (FF)
    b     store_escaped_char
escape_newline:
    mov   w1, #10               // ASCII 10 (LF)
    b     store_escaped_char
escape_carriage_return:
    mov   w1, #13               // ASCII 13 (CR)
    b     store_escaped_char
escape_tab:
    mov   w1, #9                // ASCII 9 (HT)
    b     store_escaped_char
escape_unicode:
    // Handle \uXXXX unicode escape sequence
    // This is more complex - need to parse 4 hex digits
    bl    parse_unicode_escape   // Call helper function
    cmp   x0, #0
    b.eq  escape_error
    mov   w1, w0                // Unicode value to store
    b     store_escaped_char
store_escaped_char:
    // Store the actual character (not the escape sequence)
    strb  w1, [x21]
    add   x21, x21, #1          // Move output position forward
    add   x20, x20, #1          // Move input position past escaped char
    
    // Continue parsing the string
    ldp   x29, x30, [sp], #16
    b     find_string_end       // Jump back to main parsing loop
escape_error:
    // Invalid escape sequence
    ldp   x29, x30, [sp], #16
    b     parse_string_error    // Jump to error handler
// Helper function to parse \uXXXX unicode sequences
parse_unicode_escape:
    stp   x29, x30, [sp, #-32]!
    stp   x19, x20, [sp, #16]
    mov   x29, sp
    
    mov   x19, x20              // Save current position
    add   x20, x20, #1          // Skip past 'u'
    mov   x0, #0                // Unicode value accumulator
    mov   x1, #4                // Parse 4 hex digits
parse_hex_loop:
    ldrb  w2, [x20]             // Load next character
    
    // Check if it's 0-9
    cmp   w2, #'0'
    b.lt  unicode_error
    cmp   w2, #'9'
    b.le  hex_digit
    
    // Check if it's A-F
    cmp   w2, #'A'
    b.lt  check_lowercase
    cmp   w2, #'F'
    b.le  hex_upper
check_lowercase:
    // Check if it's a-f
    cmp   w2, #'a'
    b.lt  unicode_error
    cmp   w2, #'f'
    b.gt  unicode_error
    
    // Convert a-f to value
    sub   w2, w2, #'a'
    add   w2, w2, #10
    b     add_hex_digit
hex_upper:
    // Convert A-F to value
    sub   w2, w2, #'A'
    add   w2, w2, #10
    b     add_hex_digit
hex_digit:
    // Convert 0-9 to value
    sub   w2, w2, #'0'
add_hex_digit:
    // Add this hex digit to accumulator
    lsl   x0, x0, #4            // Shift left by 4 bits
    orr   x0, x0, x2            // OR in the new digit
    
    add   x20, x20, #1          // Move to next character
    subs  x1, x1, #1            // Decrement counter
    b.ne  parse_hex_loop
    
    // Successfully parsed 4 hex digits
    // For simplicity, we'll only handle ASCII range (0-127)
    // Full UTF-8 encoding would be more complex
    cmp   x0, #127
    b.gt  unicode_ascii_only
    
    mov   x20, x19              // Restore position for caller
    add   x20, x20, #5          // Skip past \uXXXX (5 chars total)
    
    ldp   x19, x20, [sp, #16]
    ldp   x29, x30, [sp], #32
    ret
unicode_ascii_only:
    // For non-ASCII Unicode, we'd need UTF-8 encoding
    // For now, replace with '?' character
    mov   x0, #'?'
    mov   x20, x19
    add   x20, x20, #5
    
    ldp   x19, x20, [sp, #16]
    ldp   x29, x30, [sp], #32
    ret
unicode_error:
    mov   x0, #0                // Return 0 for error
    mov   x20, x19              // Restore position
    
    ldp   x19, x20, [sp, #16]
    ldp   x29, x30, [sp], #32
    ret
parse_string_error:
  mov   x0, #0
  mov   x1, x19

  ldp   x21, x22, [sp, #32] 
  ldp   x19, x20, [sp, #16]
  ldp   x29, x30, [sp], #48
  ret

// Tokenize a string
// Parameters:
//   x0 = tokenizer struct pointer
//   x1 = input string pointer
//   x2 = output token IDs array pointer
//   x3 = max tokens
// Returns:
//   x0 = number of tokens
_tokenize_string:
  stp   x29, x30, [sp, #-48]!
  stp   x19, x20, [sp, #16]
  stp   x21, x22, [sp, #32]
  mov   x29, sp

  mov   x19, x0 // pointer to tokenizer struct
  mov   x20, x1
  mov   x21, x2
  mov   x22, x3

  mov   x0, x20
  bl    pre_tokenize
  mov   x20, x0

  mov   x0, x19
  mov   x1, x20
  bl    apply_bpe_merges
  mov   x20, x0

  mov   x0, x19
  mov   x1, x20
  mov   x2, x21
  mov   x3, x22
  bl    tokens_to_ids 

  ldp   x21, x22, [sp, #32]
  ldp   x19, x20, [sp, #16]
  ldp   x29, x30, [sp], #48
  ret

// Pre-tokenize: split by whitespace and punctuation
// Parameters:
//   x0 = input string pointer
// Returns:
//   x0 = pre-tokenized string pointer
pre_tokenize:
  stp   x29, x30, [sp, #-32]!
  stp   x19, x20, [sp, #16]
  mov   x29, sp

  mov   x19, x0

  mov   x0, #0
  mov   x1, #4096
  mov   x2, #3
  mov   x3, #0x1002
  mov   x4, #-1
  mov   x5, #0
  mov   x16, #222
  svc   #0

  mov   x20, x0
  mov   x1, x19
  mov   x2, x0

pre_tokenize_loop:
  ldrb  w3, [x1], #1
  cbz   w3, pre_tokenize_done

  // Check if character is whitespace or punctuation
  cmp   w3, #' '
  b.eq  add_separator
  cmp   w3, #'\t'
  b.eq  add_separator
  cmp   w3, #'\n'
  b.eq  add_separator
  
  // Check punctuation
  cmp   w3, #'.'
  b.eq  add_separator_punct
  cmp   w3, #','
  b.eq  add_separator_punct
  cmp   w3, #'!'
  b.eq  add_separator_punct
  cmp   w3, #'?'
  b.eq  add_separator_punct
  
  // Regular character
  strb  w3, [x2], #1
  b     pre_tokenize_loop

add_separator:
  mov   w4, #'_'
  strb  w4, [x2], #1
  b     pre_tokenize_loop

add_separator_punct
  mov   w4, #' '
  strb  w4, [x2], #1
  strb  w3, [x2], #1
  strb  w4, [x2], #1
  b     pre_tokenize_loop

pre_tokenize_done:
  strb  wzr, [x2]
  mov   x0, x20
  ldp   x19, x20, [sp, #16]
  ldp   x29, x30, [sp], #32
  ret

// Apply BPE merges
// Parameters:
//   x0 = tokenizer struct pointer
//   x1 = pre-tokenized string pointer
// Returns:
//   x0 = BPE-tokenized string pointer
apply_bpe_merges:
  stp   x29, x30, [sp, #-48]!
  stp   x19, x20, [sp, #16]
  stp   x21, x22, [sp, #32]
  mov   x29, sp

  mov   x19, x0
  mov   x20, x1 // pretokenized string pointer

  mov   x0, x20 // copy input into x0 to pass to string_length
  bl    string_length // after this x0 contains string_length
  mov   x21, x0

  mov   x0, #0
  add   x1, x21, #1
  mov   x2, #3
  mov   x3, #1002
  mov   x4, #-1
  mov   x5, #0
  mov   x16, #222
  svc   #0

  mov   x22, x0 // allocated buffer pointer returned by mmap

  mov   x0, x22
  mov   x1, x20
  mov   x2, x21
  bl    memcpy

  ldr   x3, [x19, #TOKENIZER_MERGE_COUNT]
  cbz   x3, apply_bpe_done

merge_loop:
  mov   x0, x22
  mov   x1, x19
  bl    find_most_frequent_pair

  cmp   x0, #-1
  b.eq  apply_bpe_done

  mov   x1, x0
  mov   x0, x22
  mov   x2, x19
  bl    apply_single_merge

  b     merge_loop

apply_bpe_done:
  mov   x0, x22             // return working buffer
  
  ldp   x21, x22, [sp, #32]
  ldp   x19, x20, [sp, #16]
  ldp   x29, x30, [sp], #48
  ret

// Convert tokens to IDs
// Parameters:
//   x0 = tokenizer struct pointer
//   x1 = tokenized string pointer
//   x2 = output ID array pointer
//   x3 = max tokens
// Returns:
//   x0 = number of tokens
tokens_to_ids:
  stp   x29, x30, [sp, #-48]!
  stp   x19, x20, [sp, #16]
  stp   x21, x22, [sp, #32]
  mov   x29, sp

  mov   x19, x0             // tokenizer
  mov   x20, x1             // tokenized string
  mov   x21, x2             // output array
  mov   x22, x3             // max tokens

  mov   x23, #0

token_loop:
  mov   x0, x20
  bl    skip_whitespace
  mov   x20, x0

  ldrb  w0, [x20]
  cbz   w0, tokens_done  

  mov   x0, x20
  bl    find_next_token
  mov   x24, x0

  mov   x0, x19
  mov   x1, x20
  sub   x2, x24, x20
  bl    lookup_token_id

  cmp   x23, x22
  b.ge  tokens_done

  str   w0, [x21, x23, lsl #2]
  add   x23, x23, #1

  mov   x20, x24
  b     token_loop
tokens_done:
  mov   x0, x23
  ldp   x21, x22, [sp, #32]
  ldp   x19, x20, [sp, #16]
  ldp   x29, x30, [sp], #48
  ret

// Find the next token in the string
// Parameters:
//   x0 = current position in string
// Returns:
//   x0 = position after the token (or at null terminator)
find_next_token:
  stp   x29, x30, [sp, #-16]!
  mov   x29, sp

  mov   x1, x0
find_token_end:
  ldrb  w2, [x0]
  cbz   w2, found_token_end

  cmp   w2, #' '
  b.eq  found_token_end
  cmp   w2, #'\t'
  b.eq  found_token_end
  cmp   w2, #'\n'
  b.eq  found_token_end

  add   x0, x0, #1
  b     find_token_end
found_token_end:
  ldp   x29, x30, [sp], #16
  ret

// Look up a token in the vocabulary and return its ID
// Parameters:
//   x0 = tokenizer struct pointer
//   x1 = token start pointer
//   x2 = token length
// Returns:
//   x0 = token ID (-1 if not found)
lookup_token_id:
  stp   x29, x30, [sp, #-48]!
  stp   x19, x20, [sp, #16]
  stp   x21, x22, [sp, #32]
  mov   x29, sp

  mov   x19, x0
  mov   x20, x1
  mov   x21, x2

  ldr   x22, [x19, #TOKENIZER_VOCAB]
  ldr   x23, [x19, #TOKENIZER_VOCAB_SIZE]

  mov   x9, #0
lookup_loop:
  cmp   x9, x23
  b.ge  token_not_found

  mov   x10, #TOKEN_SIZE
  mul   x10, x9, x10
  add   x10, x22, x10 // address of entry at index x9

  ldr   x11, [x10, #TOKEN_STR]

  mov   x0, x20
  mov   x1, x11
  mov   x2, x21
  bl    token_compare

  cmp   x0, #1
  b.eq  found_token

  add   x9, x9, #1
  b     lookup_loop
found_token:
  ldr   w0, [x10, #TOKEN_ID]
  b     lookup_done
token_not_found:
  mov   x0, #-1
lookup_done:
  ldp   x21, x22, [sp, #32]
  ldp   x19, x20, [sp, #16]
  ldp   x29, x30, [sp], #48
  ret

// Compare a token with a vocabulary string
// Parameters:
//   x0 = token pointer
//   x1 = vocab string pointer
//   x2 = token length
// Returns:
//   x0 = 1 if match, 0 if no match
token_compare:
  stp   x29, x30, [sp, #-32]!
  stp   x19, x20, [sp, #16]
  mov   x29, sp

  mov   x19, x0
  mov   x20, x1
  mov   x21, x2

  mov   x0, x20
  bl    string_length
  cmp   x0, x21
  b.ne  compare_failed
compare_loop:
  cbz   x21, compare_success

  ldrb  w3, [x19]
  ldrb  w4, [x20]

  cmp   w3, w4
  b.ne  compare_failed

  add   x19, x19, #1
  add   x20, x20, #1
  sub   x21, x21, #1
  b     compare_loop
compare_success:
  mov   x0, #1
  b     compare_done
compare_failed:
  mov   x0, #0
compare_done:
  ldp   x19, x20, [sp, #16]
  ldp   x29, x30, [sp], #32
  ret

// Find the most frequent pair in the working buffer that has a merge rule
// Parameters:
//   x0 = working buffer pointer
//   x1 = tokenizer struct pointer
// Returns:
//   x0 = merge rule index (-1 if no valid merge found)
find_most_frequent_pair:
  stp   x29, x30, [sp, #-64]
  stp   x19, x20, [sp, #16]
  stp   x21, x22, [sp, #32]
  stp   x23, x24, [sp, #48]
  mov   x29, sp

  mov   x19, x0
  mov   x20, x1
  mov   x21, #-1
  mov   x22, #0

  ldr   x23, [x20, #TOKENIZER_MERGES]
  ldr   x24, [x20, #TOKENIZER_MERGE_COUNT]

  mov   x9, #0

check_next_merge:
  cmp   x9, x24
  b.ge  find_best_done

  mov   x10, #MERGE_SIZE
  mul   x10, x9, x10
  add   x10, x23, x10

  ldr   x11, [x10, #MERGE_PAIR_A]
  ldr   x12, [x10, #MERGE_PAIR_B]

  mov   x0, x19
  mov   x1, x11
  mov   x2, x12
  bl    count_token_pairs

  cmp   x0, x22
  b.le  next_merge

  mov   x22, x0
  mov   x21, x9

next_merge:
  add   x9, x9, #1
  b     check_next_merge

find_best_done:
  mov   x0, x21

  ldp   x23, x24, [sp, #48]
  ldp   x21, x22, [sp, #32]
  ldp   x19, x20, [sp, #16]
  ldp   x29, x30, [sp], #64
  ret

// Count occurrences of a token pair in buffer
// Parameters:
//   x0 = buffer pointer
//   x1 = first token pointer
//   x2 = second token pointer
// Returns:
//   x0 = count
count_token_pairs:
  stp   x29, x30, [sp, #-48]!
  stp   x19, x20, [sp, #16]
  stp   x21, x22, [sp, #32]
  mov   x29, sp

  mov   x19, x0
  mov   x20, x1
  mov   x21, x2
  mov   x22, #0

  mov   x0, x20
  bl    string_length
  mov   x23, x0

count_loop:
  mov   x0, x19
  mov   x1, x20
  mov   x2, x23
  bl    string_match_position

  cmp   x0, #0
  b.eq  advance_position

  add   x0, x19, x23  // get position of second token
  bl    skip_whitespace

  mov   x25, x0

  mov   x1, x21
  mov   x2, x24
  bl    string_match_at_position

  cmp   x0, #0
  b.eq  advance_position

  add   x22, x22, #1

  add   x19, x25, x24
  b     continue_search

advance_position:
  add   x19, x19, #1

continue_search:
  ldrb  w0, [x19]
  cbnz  w0, count_loop

  mov   x0, x22

  ldp   x21, x22, [sp, #32]
  ldp   x19, x20, [sp, #16]
  ldp   x29, x30, [sp], #48
  ret

// Check if string matches at specific position
// Parameters:
//   x0 = buffer position
//   x1 = string to match
//   x2 = string length
// Returns:
//   x0 = 1 if match, 0 if no match
string_match_position:
  stp   x29, x30, [sp, #-32]!
  stp   x19, x20, [sp, #16]
  mov   x29, sp

  mov   x19, x0
  mov   x20, x1
  mov   x21, x2

match_loop:
  cbz   x21, match_success

  ldrb  w3, [x19]
  ldrb  w4, [x20]

  cmp   w3, w4
  b.ne  match_failed

  add   x19, x19, #1
  add   x20, x20, #1
  sub   x21, x21, #1
  b     match_loop

match_success:
  mov   x0, #1
  b     match_done

match_failed:
  mov   x0, #0

match_done:
  ldp   x19, x20, [sp, #16]
  ldp   x29, x30, [sp], #32
  ret

memcpy:
  mov   x3, x0
memcpy_loop:
  cbz   x2, memcpy_done
  ldrb  w4, [x1], #1
  strb  w4, [x0], #1
  sub   x2, x2, #1
  b     memcpy_loop
memcpy_done:
  mov   x0, x3
  ret

string_length:
  mov   x1, x0 // move string pointer into x1
strlen_loop:
  ldrb  w2, [x1], #1
  cbnz  w2, strlen_loop
  sub   x0, x1, x0
  sub   x0, x0, #1
  ret

skip_whitespace:
  ldrb  w1, [x0]
  cmp   w1, #' '
  b.eq  skip_ws_next
  cmp   w1, #'\t'
  b.eq  skip_ws_next
  cmp   w1, #'\n'
  b.eq  skip_ws_next
  cmp   w1, #'\r'
  b.eq  skip_ws_next
  ret
skip_ws_next:
  add   x0, x0, #1
  b     skip_whitespace

.data
model_key:
    .asciz "model"
vocab_key:
    .asciz "vocab"
merges_key:
    .asciz "merges"
