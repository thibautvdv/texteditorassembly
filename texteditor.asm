; -------------------------------------------------------------------
; 80386
; 32-bit x86 assembly language
; TASM
;
; author:	Thibaut Vandervelden, Ian Vanmeulder
; date:		29/09/2017
; program:	texteditor
; -------------------------------------------------------------------

IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

; -------------------------------------------------------------------
; CODE
; -------------------------------------------------------------------
CODESEG

PROC main
	sti            ; set The Interrupt Flag => enable interrupts
	cld            ; clear The Direction Flag


	; Wait for keystroke and read character.
	mov ah,00h
	int 16h

	; Terminate process with return code in response to a keystroke.
  mov	ax,4C00h
	int 21h
ENDP main
; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------
DATASEG


; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main
