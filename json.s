.section __TEXT,__text,regular,pure_instructions
.global _parse_json
.global _main
.p2align 2

_main:
    // Function prologue
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    
    // Call _parse_json with test path
    adrp x0, test_path@PAGE
    add x0, x0, test_path@PAGEOFF
    bl _parse_json
    
    // Exit with status 0
    mov x0, #0
    mov x16, #1  // sys_exit
    svc #0x80
    
    // Function epilogue (unreachable)
    ldp x29, x30, [sp], #16
    ret

.p2align 2

// _parse_json - Parse JSON file
//
// Arguments:
//   x0: Pointer to null-terminated file path string
//
// Return value:
//   x0: Parsed JSON data structure (0 on error)
//
_parse_json:
    // Function prologue
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    
    // Save file path
    str x0, [sp, #16]
    
    // Open file - fopen(path, "r")
    adrp x1, read_mode@PAGE
    add x1, x1, read_mode@PAGEOFF
    bl _fopen
    
    // Check if file opened successfully
    cbz x0, Lfile_error 
    str x0, [sp, #24]  // Save file pointer
    
    // Read and print file contents
Lread_loop:
    // Read one character - fgetc(file)
    ldr x0, [sp, #24]  // Load file pointer
    bl _fgetc
    
    // Check for EOF (-1)
    cmp w0, #-1
    b.eq Lclose_file
    
    // Print character to stdout - putchar(ch)
    bl _putchar
    b Lread_loop
Lclose_file:
    // Close file - fclose(file)
    ldr x0, [sp, #24]
    bl _fclose
    
    // Return 0 for success
    mov x0, #0
    b Lexit_function
Lfile_error:
    // Return -1 for error
    mov x0, #-1
Lexit_function:
    // Function epilogue
    ldp x29, x30, [sp], #64
    ret

.section __TEXT,__cstring,cstring_literals
read_mode:
    .asciz "r"

test_path:
    .asciz "test.json"

.subsections_via_symbols
