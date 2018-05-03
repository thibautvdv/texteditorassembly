IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

INCLUDE "texth.inc"

UDATASEG

DATASEG

CODESEG

PROC printString
  ; deze procedure zal een string afdrukken op de plaats van de cursor

  USES eax, edx
  ARG @@string:word
  mov edx, [offset @@string]
  mov ah, 9
  int 21h

  ret
ENDP printString

END