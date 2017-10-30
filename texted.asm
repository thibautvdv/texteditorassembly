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

;ascii codes
BS equ 08h ;backspace ascii vergelijken met al
ESCP equ 1bh ;escape ascii vergelijken met al
WS equ 20h ;whitespace ascii (vergelijken met al)
CR equ 0dh ;carriage return ascii vergelijken met al

;scan codes (keyboard)
KEYUP equ 48h ;pijl naar boven vergelijken met ah
KEYDOWN equ 50h ;pijl naar beneden vergelijken met ah
KEYLEFT equ 4bh ;pijl naar links vergelijken met ah
KEYRIGHT equ 4dh ;pijl naar rechts vergelijken met ah

;andere constanten (hiervan is nog niets gebruikt geweest)
COLUMNS equ 40
ROWS equ 10
MAX_X equ COLUMNS-1
MAX_Y equ ROWS-1

; -------------------------------------------------------------------
; CODE
; -------------------------------------------------------------------
CODESEG

PROC scrollWindow
	USES eax, ebx, ecx, edx ; dit is IDEAL syntax

	; BIOS interrupt 10h, service 06h om het scherm naar boven te scrollen
	; Dit gebruiken we om een soort van nieuw scherm te simuleren
	; Met deze service is het ook mogelijk om achtergrondkleur te veranderen,
	; alsook de tekstkleur

	mov ah, 06h 	; we zetten de service code in 'ah'
	mov al, 00h		; als 'al' gelijk is aan 0, dan zal het scherm gecleared worden
	mov bh, 0fh 	; dit zijn de kleuren (0 = zwart (achtergrond), F = wit (text))
	mov cx, 0000h	; 'ch' is de upper row number, 'cl' is de linker kolomnummer
	mov dx, 184fh	; 'dh' is de lower row number (18h = 24), 'dl' is de rechter kolomnummer (4f = 79)
	int 10h				; BIOS interrupt oproepen

	ret	; retourneren van de procedure
ENDP scrollWindow

PROC setCursor
	USES eax, ebx, edx

	; BIOS interrupt 10h, service 02h om de cursor te verplaatsen
	; om de kolom en rij te bepalen gebruiken we 'cursor_x' en
	; 'cursor_y' respectievelijk

	mov ah, 02h					; we zetten de service code in 'ah'
	mov dl, [cursor_x]	; 'dl' is de kolom
	mov dh, [cursor_y]	; 'dh' is de rij
	mov bh, 0 					; 'bh' is de page number
	int 10h							; BIOS interrupt oproepen
	ret	; retourneren van de procedure
ENDP setCursor

PROC printChar
	ARG char:byte			; een argument wordt meegegeven, namelijk de character dat afgedrukt moet worden op het scherm
	USES eax, ecx, ebx

	; BIOS interrupt 10h, service 0ah om een character te printen op het scherm

	mov ah, [char]			; in 'al' plaatsen we het character
	mov ah, 0ah					; we zetten de service code in 'ah'
	mov cx, 1						; 'cx' is het aantal keren dat het character geprint moet worden
	mov bh, 0						; 'bh' ide page number
	int 10h							; BIOS interrupt oproepen
	inc [cursor_x]			; cursor naar rechts verplaatsen
	call setCursor			; cursor werkelijk op de juiste plaats zetten
	ret	; retourneren van de procedure
ENDP printChar

PROC main
	call scrollWindow		; scherm scrollen naar boven
	call setCursor			; cursor links boven zetten

@@loop:
@@read_key:
	; BIOS interrupt 16h, service 00h om de keyboard te lezen
	;	in 'ah' bevindt zich de scan code van de gedrukte knop
	; in 'al' bevindt zich de ASCII waarde van de gedrukte knop
	mov ah, 00h ; service 00h in 'ah' plaatsen
	int 16h			; interrupt oproepen

	cmp al, ESCP	; ASCII code vergelijken met de ASCII code van de escape knop
	je @@exit		; als er op escape gedrukt is geweest, ga dan naar 'exit'

	cmp al, CR		; ASCII code vergelijken met de ASCII code van de carriage return (enter knop)
	jne @@continueCR	; niet op enter gedrukt, skip dan code van enter knop en doe verder (ga naar 'continueCR')
	inc [cursor_y]	; increment van de y-positie
	mov [cursor_x], 0	; x-positie terug naar begin
	call setCursor	; cursor juist zetten
	jmp @@loop	; herbeginnen van de loop
@@continueCR:

	cmp ah, KEYUP ; scan code vergelijken van de arrow up met scan code die zich bevindt in 'ah'
	jne @@continueKeyUp
	cmp [cursor_y], 0
	jle @@cursor_y_is_negative
	dec [cursor_y]
	call setCursor
@@cursor_y_is_negative:
	jmp @@loop
@@continueKeyUp:

	cmp ah, KEYRIGHT ; scan code vergelijken van de arrow right met scan code die zich bevindt in 'ah'
	jne @@continueKeyRight
	inc [cursor_x]
	call setCursor
	jmp @@loop
@@continueKeyRight:

	cmp ah, KEYLEFT ; scan code vergelijken van de arrow left met scan code die zich bevindt in 'ah'
	jne @@continueKeyLeft
	dec [cursor_x]
	call setCursor
	jmp @@loop
@@continueKeyLeft:

	cmp ah, KEYDOWN	; scan code vergelijken van de arrow down met scan code die zich bevindt in 'ah'
	jne @@continueKeyDown
	inc [cursor_y]
	call setCursor
	jmp @@loop
@@continueKeyDown:

	cmp al, BS ; ASCII vergelijken van de backspace met ASCII code van de backspace knop
	jne @@continueBS
	;BIOS interrupt 10h, service 0ah om character te printen (een spatie)
	dec [cursor_x]
	call setCursor
	mov ah, 0ah
	mov al, WS
	mov cx, 1
	int 10h
	jmp @@loop
@@continueBS:

	; als een andere knop ingedrukt is geweest, dan zal dit wel een normale knop zijn
	; de waarde van deze character bevindt zich in ah
	; we geven deze waarde mee aan de procedure die een character print op het scherm
	; na deze procedure herstarten we de loop
	call printChar, ax
	jmp @@loop



@@exit:
	;Use BIOS interrupt 10h, Service 02h to position cursor

	; eerst plaatsen we de cursor weer naar linksboven
	mov [cursor_x], 0
	mov [cursor_y], 0
	call setCursor ; werkelijk verplaatsen van de cursor
	call scrollWindow ; het scherm naar boven scrollen om te clearen

	;DOS interrupt 21h, service 4ch om het programma te stoppen
	mov ah, 4ch
	int 21h

ENDP main
; -------------------------------------------------------------------
; DATA
; -------------------------------------------------------------------
DATASEG
	cursor_x db 0
	cursor_y db 0

UDATASEG
;buffer db 100 dup(?), '$' ; buffer moet nog niet
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main
