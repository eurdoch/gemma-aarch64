.global _main
.align 2

_main:
  stp   x29, x30, [sp, #-16]!
  mov   x29, sp

  sub   sp, sp, #144
  adrp  x0, model_path@PAGE
  add   x0, x0, model_path@PAGEOFF

  mov   x1, sp

  ldr   x16, =0x2000153
  svc   0x80

  cmp   x0, #0
  b.lt  _error

  ldr   x20, [sp, #96]
  
  adrp  x0, model_path@PAGE
  add   x0, x0, model_path@PAGEOFF
  mov   x1, #0
  mov   x2, #0
  ldr   x16, =0x2000005
  svc   #0x80

  cmp   x0, #0
  b.lt  _error

  mov   x19, x0

  mov   x0, #0
  mov   x1, x20
  mov   x2, #1
  mov   x3, #2
  mov   x4, x19
  mov   x5, #0
  ldr   x16, =0x20000C5
  svc   #0x80

  cmn   x0, #1
  b.eq  _error

  mov   x21, x0

  mov   x0, x19
  ldr   x16, =0x2000006 // mmap
  svc   #0x80
  // model is now in memory

  // at this point parse the safetensors model
  ldr   x22, [x21] // load header size into x22
  add   x23, x21, #8
  add   x24, x23, x22

  mov   x0, x22
  bl    _print_int
  bl    _print_newline

  mov   x0, x21
  mov   x1, x20
  ldr   x16, =0x2000049
  svc   #0x80

  add   sp, sp, #144
  mov   x0, #0
  ldp   x29, x30, [sp], #16
  ret

_error:
  mov   x0, #1
  add   sp, sp, #144
  ldp   x29, x30, [sp], #16
  ret

_print_int:
  stp   x29, x30, [sp, #-16]!
  stp   x19, x20, [sp, #-16]!
  stp   x21, x22, [sp, #-16]!

  mov   x19, x0 // x0 should be parameter to function

  sub   sp, sp, #32
  mov   x21, sp
  add   x22, sp, #31
  mov   x20, x22

  strb  wzr, [x20]
  sub   x20, x20, #1

  cmp   x19, #0
  b.ne  1f

  mov   w1, #0
  strb  w1, [x20]
  b     3f

1:
  cmp   x19, #0
  b.eq  3f

  mov   x1, #10
  udiv  x2, x19, x1
  msub  x3, x2, x1, x19

  add   w3, w3, #'0'
  strb  w3, [x20]

  sub   x20, x20, #1
  mov   x19, x2

  b     1b

3:
  add   x20, x20, #1
  sub   x2, x22, x20

  mov   x0, #1
  mov   x1, x20 
  mov   x16, #0x04
  movk  x16, #0x2000, lsl #16
  svc   #0x80

  add   sp, sp, #32
  ldp   x21, x22, [sp], #16
  ldp   x19, x20, [sp], #16
  ldp   x29, x30, [sp], #16
  ret

_print_newline:
    stp     x29, x30, [sp, #-16]!
    
    mov     x0, #1           // File descriptor 1 = stdout
    adrp    x1, newline@PAGE
    add     x1, x1, newline@PAGEOFF
    mov     x2, #1           // Length = 1
    mov     x16, #0x04       // SYS_write
    movk    x16, #0x2000, lsl #16
    svc     #0x80
    
    ldp     x29, x30, [sp], #16
    ret

.section __DATA,__data
newline:
  .asciz "\n"
model_path:
  .asciz "gemma-3-1b-it/model.safetensors"
