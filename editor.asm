; -------------------------------------------------------------------
; 80386
; 32-bit x86 assembly language
; TASM
;
; author:	Thibaut Vandervelden, Ian Vanmeulder
; program:	texteditor

; extra: search, replace
; -------------------------------------------------------------------

IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

; ascii codes
BS			equ 08h 			; backspace ascii vergelijken met al
ESCP 		equ 1bh 			; escape ascii vergelijken met al
WS 			equ 20h 			; whitespace ascii (vergelijken met al)
CR 			equ 0dh 			; carriage return ascii vergelijken met al
CTRLS 		equ 13h 			; ctrl + s

; scan codes (keyboard)
KEYUP 		equ 48h 			; pijl naar boven vergelijken met ah
KEYDOWN 	equ 50h 		; pijl naar beneden vergelijken met ah
KEYLEFT 	equ 4bh 		; pijl naar links vergelijken met ah
KEYRIGHT 	equ 4dh 		; pijl naar rechts vergelijken met ah

; andere constanten (hiervan is nog niets gebruikt geweest)
COLUMNS 	equ 50
ROWS 		equ 10
MAX_X 		equ COLUMNS-1
MAX_Y 		equ ROWS-1

; -------------------------------------------------------------------
; CODE
; -------------------------------------------------------------------
CODESEG

PROC scrollWindow
	uses eax, ebx, ecx, edx
	; BIOS interrupt 10h, service 06h om het scherm naar boven te scrollen
	; Dit gebruiken we om een soort van nieuw scherm te simuleren
	; Met deze service is het ook mogelijk om achtergrondkleur te veranderen,
	; alsook de tekstkleur

	mov ah, 06h 		; we zetten de service code in 'ah'
	mov al, 00h			; als 'al' gelijk is aan 0, dan zal het scherm gecleared worden
	mov bh, 0fh 		; dit zijn de kleuren (0 = zwart (achtergrond), F = wit (text))
	mov cx, 0000h		; 'ch' is de upper row number, 'cl' is de linker kolomnummer
	mov dx, 184fh		; 'dh' is de lower row number (18h = 24), 'dl' is de rechter kolomnummer (4f = 79)
	int 10h				; BIOS interrupt oproepen

	ret			; retourneren van de procedure
ENDP scrollWindow

PROC setCursor
	USES eax, ebx, edx
	; BIOS interrupt 10h, service 02h om de cursor te verplaatsen
	; om de kolom en rij te bepalen gebruiken we 'cursor_x' en
	; 'cursor_y' respectievelijk

	mov ah, 02h			; service code in 'ah'
	mov dl, [cursor_x]	; 'dl' is de kolom
	mov dh, [cursor_y]	; 'dh' is de rij
	mov bh, 0 			; 'bh' is de page number
	int 10h				; interrupt oproepen
	ret			
ENDP setCursor

PROC setCursorAt
	; met deze functie plaatsen we de cursor op een x en y coördinaat
	; hiervoor hebben we dus twee parameters: x en y

	ARG @@xpos:byte, @@ypos:byte
	uses eax

	mov al, [@@xpos]
	mov [cursor_x], al

	mov al, [@@ypos]
	mov [cursor_y], al

	call setCursor

	ret
ENDP setCursorAt

PROC printString
	; deze procedure zal een string afdrukken op de plaats van de cursor

	USES eax, edx
	ARG @@string:word
	mov edx, [offset @@string]
	mov ah, 9
	int 21h

	ret
ENDP printString

PROC printChar
	ARG char:byte
	; een argument wordt meegegeven, namelijk de character dat afgedrukt moet worden op het scherm
	USES eax, ecx, ebx

	; BIOS interrupt 10h, service 0ah om een character te printen op het scherm

	mov dl, [char]		; in 'al' plaatsen we het character
	mov ah, 02h			; service code in 'ah'
	mov cx, 1			; 'cx' is het aantal keren dat het character geprint moet worden
	mov bh, 0			; 'bh' ide page number
	cmp dl, 10
	je @@lineFeed
	cmp dl, 13
	je @@carriageReturn
	int 21h			; interrupt oproepen
	cmp [cursor_x], 75
	je @@addEnter
	inc [cursor_x]		; cursor naar rechts verplaatsen
	jmp @@end

@@lineFeed:
	mov [cursor_x], 0
	jmp @@end

@@carriageReturn:
	inc [cursor_y]
	jmp @@end

@@addEnter:
	mov [cursor_x], 0
	inc [cursor_y]

@@end:
	call setCursor		; cursor werkelijk op de juiste plaats zetten
	ret					; retourneren van de procedure
ENDP printChar

PROC setWhiteLine
	; deze procedure tekent een witte lijn op het scherm
	USES eax, ecx, ebx
	mov ah, 09h
	mov al, " "
	mov bl, 70h
	mov bh, 0
	mov cx, 80
	int 10h

	ret
ENDP setWhiteLine

PROC readFile
	; deze procedure gaat een bestand uitlezen
	USES eax, ebx, ecx, edx, esi

	; eerst het bestand openen voor een file handler
	mov al, 0 			; read only
	mov edx, offset file_name_buffer
	mov ah, 3dh 			; functie om te openen
	int 21h 			; DOS call
	jc @@cant_open 			; controlleer of het gelukt is
	mov [fileHandler], ax 		; file handler opslaan

	mov [aantalChar], 0
@@read:
	mov ah, 3fh 			; functie om te lezen
	mov bx, [fileHandler] 		; filehandler laden
	mov esi, [dword aantalChar]
	lea dx, [buffer + esi] 		; pointer naar buffer
	mov cx, 1 			; aantal bytes we gaan lezen
	int 21h 			; DOS call
	cmp ax, 0 			; were 0 bytes read?
	jz @@eof 			; yes, end of file found
	mov esi, [dword aantalChar]
	mov dl, [offset buffer + esi] 	; no, load file character
	cmp dl, 1ah 			; is it control-z <EOF>?
	jz @@eof 			; jump if yes
	inc [aantalChar]

	jmp @@read 			; repeat

	; einde van het bestand -> sluiten van het bestand
@@eof:
	mov bx, [fileHandler]
	mov ah, 3eh
	int 21h
	
	call countBufferChars

@@cant_open:
	; error message tonen
	
	
	ret
ENDP readFile

PROC writeFile
	USES eax, ebx, ecx, edx

	mov al, 2
	mov edx, offset file_name_buffer
	mov ah, 3dh
	int 21h
	jc @@cant_open
	mov [fileHandler], ax

	mov bx, [fileHandler]

	call countBufferChars

	mov cx, [aantalChar]
	mov edx, offset buffer
	mov ah, 40h
	int 21h
	jc @@cant_open

	mov bx, [fileHandler]
	mov ah, 3eh
	int 21h

	@@cant_open:

	ret
ENDP writeFile

PROC listFiles

	USES eax, ebx, ecx, edx

	lea edx, [DTA]
	mov ah, 1ah			; set disk transfer area
	int 21h

	lea edx, [file_spec]
	xor cx, cx
	mov ah, 4eh			; functie om het eerste bestand te zoeken
	int 21h

	jc @@quit			; als er geen bestand is gevonden, dan mogen we stoppen met zoeken

@@print_name:
	lea esi, [DTA + 1eh]	; uit de DTA kunnen we de naam van het bestand krijgen
	
@@next_char:
	lodsb			; laden van een byte uit DS:(E)SI in AL
	int 29h
	test al, al
	jnz @@next_char	

	; nieuwe lijn
	mov al, 13
	int 29h
	mov al, 10
	int 29h
	
	inc [cursor_y]				; increment van de y-positie
	mov [cursor_x], 0			; x-positie terug naar begin
	call setCursor				; cursor juist zetten
	
	; zoeken naar een volgend bestand
	lea edx, [file_spec]
	xor cx, cx
	mov ah, 4fh
	int 21h
	jnc @@print_name
	
@@quit:
	ret
ENDP listFiles

PROC createFile
	USES eax, ebx, ecx, edx
	
	mov cx, 00000000b 
	lea dx, [new_file]
	mov ah, 3CH
	int 21h
	
	jc @@failed_to_create_file

	mov [fileHandler], ax
	mov bx, [fileHandler]
	mov ah, 3ch
	int 21h
	
	jmp @@end
	
	
@@failed_to_create_file:
	
	call printString, offset error_msg
	
	add ax, 48
	call printChar, ax
	
@@end:

	ret
ENDP createFile

PROC countBufferChars
	USES eax, ecx

	xor ecx, ecx
@@counterLoop:
	mov eax, [offset buffer + ecx]
	cmp eax, 0
	je @@end
	inc cx
	jmp @@counterLoop

@@end:
	mov [aantalChar], cx

	ret
ENDP countBufferChars

PROC printBuffer
	USES eax, ebx, ecx, edx, esi

	xor esi, esi
@@write:

	mov dl, [offset buffer + esi]
	cmp dl, 00
	je @@stopWrite

	call printChar, dx
	inc esi
	jmp @@write

@@stopWrite:
		ret
ENDP printBuffer

; =====================================================================

PROC main

	call setCursorAt, 0, 0
	call scrollWindow

@@main_loop:

	cmp [program_state], 0
	je @@program_state_0
	cmp [program_state], 1
	je @@program_state_1
	cmp [program_state], 2
	je @@program_state_2
	cmp [program_state], 3
	je @@program_state_3
	jmp @@exit
	
@@program_state_0:

	call setWhiteLine
	call printString, offset file_question
	
	call setCursorAt, 38, 0
	
	mov [program_state], 1
	
@@program_state_1:
	mov ah, 00h
	int 16h
	
	cmp al, ESCP
	je @@exit
	
	cmp al, CR
	jne @@program_state_1_continue_cr
	
	movzx ebx, [file_name_buffer_counter]
	lea edx, [file_name_buffer]
	add edx, ebx
	
	mov [BYTE PTR edx], 0
	
	mov [program_state], 2
	jmp @@program_state_1_end
	
@@program_state_1_continue_cr:
	movzx ebx, [file_name_buffer_counter]
	lea edx, [file_name_buffer]
	add edx, ebx
	
	mov [BYTE PTR edx], al
	
	inc ebx
	mov [BYTE PTR file_name_buffer_counter], bl
	
	call printChar, ax
	
@@program_state_1_end:
	
	jmp @@main_loop
	
@@program_state_2:

	call scrollWindow
	call setCursorAt, 0, 0
	call setWhiteLine
	
	call printString, offset fileNameHeader
	call printString, offset file_name_buffer
	
	call setCursorAt, 0, 24
	call setWhiteLine
	call printString, offset commandsInfo
	
	call setCursorAt, 0, 1
	
	call readFile 				; lezen van het bestand
	call printBuffer 			; printen van de buffer
	
	mov [program_state], 3
	
	jmp @@main_loop
	
@@program_state_3:
	mov ah, 00h
	int 16h
	
	cmp al, ESCP
	je @@exit
	
	cmp al, CTRLS
	jne @@program_state_3_continue_CTRLS
	call writeFile
	jmp @@main_loop
	
@@program_state_3_continue_CTRLS:
	
	jmp @@main_loop
	
	
@@exit:

	call setCursorAt, 0, 0
	call scrollWindow

	mov ah, 4ch
	int 21h

ENDP main

DATASEG
	cursor_x db 0
	cursor_y db 0

	file_name_buffer_counter db 0
	file_name_buffer db 16 dup('$') 	; the ingevoerde chars

	fileNameHeader db "Filename : ", '$' 			; header van het programma om te tonen in welk bestand we zijn
	commandsInfo db "^S : Save, ^O : Open, ^X : Close, ^N : New, esc : exit", '$' ; info dat op de onderste balk wordt weergegeven
	buffer dw 2710 dup(00) 					; buffer om data bij te houden
	aantalChar dw 0 						; aantal chars die uitgeprint zullen worden
	fileHandler dw ? 						; file handler
	new_file db "new_f.txt", 0, '$'
	error_msg db "Bestand niet kunnen aanmaken", 00, '$'
	
	file_question db "Welk bestand moet er geopend worden?", 10, 13, 00, '$'

	DTA db 15h dup(0)						; DISK TRANSFER AREA (informatie over bestanden)
	file_spec db "*.txt", 00				; deze bestanden kunnen we openen
	
	; 0 = vragen welk bestand te openen
	; 1 = tonen van het bestand
	program_state db 0

UDATASEG
;buffer db 100 dup(?), '$' ; buffer moet nog niet
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main
