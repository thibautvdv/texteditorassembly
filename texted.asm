; -------------------------------------------------------------------
; 80386
; 32-bit x86 assembly language
; TASM
;
; author:	Thibaut Vandervelden, Ian Vanmeulder
; date:		29/09/2017
; program:	texteditor
; -------------------------------------------------------------------
;dit is nog een test

IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

;ascii codes
BS equ 08h ;backspace ascii vergelijken met al
ESCP equ 1bh ;escape ascii vergelijken met al
WS equ 20h
CR equ 0dh ;carriage return ascii vergelijken met al

;scan codes (keyboard)
KEYUP equ 48h ;pijl naar boven vergelijken met ah
KEYDOWN equ 50h ;pijl naar beneden vergelijken met ah
KEYLEFT equ 4bh ;pijl naar links vergelijken met ah
KEYRIGHT equ 4dh ;pijl naar rechts vergelijken met ah

;andere constanten
COLUMNS equ 40
ROWS equ 10
MAX_X equ COLUMNS-1
MAX_Y equ ROWS-1

; -------------------------------------------------------------------
; CODE
; -------------------------------------------------------------------
CODESEG

PROC scrollWindow
	USES eax, ebx, ecx, edx

	;Use BIOS interrupt 10h, Service 06h to scroll window up
	;this creates a clear screen effect
	;also set-up colors (blue background & red text)

	mov ax, 0600h
	mov bh, 0Fh ;dit zijn de kleuren (0 = zwart (achtergrond), F = wit (text))
	mov cx, 0
	mov dx, 184fh
	int 10h

	ret
ENDP scrollWindow

PROC setCursor
	; dit is de procedure om de cursor op de juiste plaats te zetten
	; de procedure gebruikt een interrupt
	; de x-positie wordt gelijk gesteld aan wat er in 'dl' zit (namelijk cursor_x)
	; de y-positie wordt gelijk gestald aan wat er in 'dh' zit (namelijk cursor_y)

	; in deze procedure gebruiken we eax, ebx en edx
	USES eax, ebx, edx

	mov ah, 02h
	mov dl, [cursor_x]
	mov dh, [cursor_y]
	mov bh, 0
	int 10h
	ret
ENDP setCursor

PROC printChar
	ARG char:dword
	USES eax, ecx, ebx

	mov eax, [char]
	mov ah, 0ah
	mov cx, 1
	mov bh, 0
	int 10h
	inc [cursor_x]
	call setCursor
	ret
ENDP printChar

PROC main
	call scrollWindow

@@set_cursor:
	;Use BIOS interrupt 10h, Service 02h to position cursor
	call setCursor

@@loop:

@@read_key:
	;Use BIOS interrupt 16h, Service 00h to read keyboard
	;(returns ASCII code in al)
	mov ah, 0
	int 16h

	cmp al, ESCP
	je @@erase

	cmp al, CR
	jne @@continueCR
	inc [cursor_y]
	mov [cursor_x], 0
	call setCursor
	jmp @@loop

@@continueCR:

	cmp ah, 48h
	jne @@continueKeyUp
	dec [cursor_y]
	jmp @@set_cursor
@@continueKeyUp:

	cmp ah, 4Dh
	jne @@continueKeyRight
	inc [cursor_x]
	jmp @@set_cursor
@@continueKeyRight:

	cmp ah, 4bh
	jne @@continueKeyLeft
	dec [cursor_x]
	jmp @@set_cursor
@@continueKeyLeft:

	cmp ah, 50h
	jne @@continueKeyDown
	inc [cursor_y]
	jmp @@set_cursor
@@continueKeyDown:


	call printChar, eax
	jmp @@loop
	;Use BIOS interrupt 10h, service 0ah to print whitespace
	;at current cursor position (erase)
	mov ah, 0ah
	mov al, WS
	mov cx, 1
	int 10h
	jmp @@loop

@@erase:
	;Use BIOS interrupt 10h, Service 02h to position cursor
	mov ah, 02h
	mov dl, [cursor_x]
	mov dh, [cursor_y]
	mov bh, 0
	int 10h

@@exit:
	call scrollWindow

	;Use DOS interrupt 21h, service 4ch to exit program
	mov ax, 4c00h
	int 21h

ENDP main
; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------
DATASEG
	cursor_x db 0
	cursor_y db 0

UDATASEG
buffer db 100 dup(?), '$'
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main
