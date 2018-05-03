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

include "fileh.inc"
include "texth.inc"

;ascii codes
BS equ 08h            ;backspace ascii vergelijken met al
ESCP equ 1bh          ;escape ascii vergelijken met al
WS equ 20h            ;whitespace ascii (vergelijken met al)
CR equ 0dh            ;carriage return ascii vergelijken met al
CTRLS equ 13h         ; ctrl + s

;scan codes (keyboard)
KEYUP equ 48h         ;pijl naar boven vergelijken met ah
KEYDOWN equ 50h       ;pijl naar beneden vergelijken met ah
KEYLEFT equ 4bh       ;pijl naar links vergelijken met ah
KEYRIGHT equ 4dh      ;pijl naar rechts vergelijken met ah

;andere constanten (hiervan is nog niets gebruikt geweest)
COLUMNS equ 50
ROWS equ 10
MAX_X equ COLUMNS-1
MAX_Y equ ROWS-1

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

  mov ah, 06h 	    ; we zetten de service code in 'ah'
  mov al, 00h		    ; als 'al' gelijk is aan 0, dan zal het scherm gecleared worden
  mov bh, 0fh 	    ; dit zijn de kleuren (0 = zwart (achtergrond), F = wit (text))
  mov cx, 0000h	    ; 'ch' is de upper row number, 'cl' is de linker kolomnummer
  mov dx, 184fh	    ; 'dh' is de lower row number (18h = 24), 'dl' is de rechter kolomnummer (4f = 79)
  int 10h				    ; BIOS interrupt oproepen

  ret	              ; retourneren van de procedure
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
  ret	                ; retourneren van de procedure
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

PROC printChar
	ARG char:byte
  ; een argument wordt meegegeven, namelijk de character dat afgedrukt moet worden op het scherm
	USES eax, ecx, ebx

	; BIOS interrupt 10h, service 0ah om een character te printen op het scherm

	mov dl, [char]			; in 'dl' plaatsen we het character
	mov ah, 02h					; we zetten de service code in 'ah'
	mov cx, 1						; 'cx' is het aantal keren dat het character geprint moet worden
	mov bh, 0						; 'bh' ide page number
  cmp dl, 10
  je @@lineFeed
  cmp dl, 13
  je @@carriageReturn
	int 21h							; BIOS interrupt oproepen
  cmp [cursor_x], 75
  je @@addEnter
  inc [cursor_x]			; cursor naar rechts verplaatsen
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
	call setCursor			; cursor werkelijk op de juiste plaats zetten
	ret	                ; retourneren van de procedure
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
  mov al, 0 ; read only
  mov edx, offset fileName
  mov ah, 3dh ; functie om te openen
  int 21h ; DOS call
  jc @@cant_open ; controlleer of het gelukt is
  mov [fileHandler], ax ; file handler opslaan

  mov [aantalChar], 0
@@read:
  mov ah, 3fh                   ; functie om te lezen
  mov bx, [fileHandler]         ; filehandler laden
  mov esi, [dword aantalChar]
  lea dx, [buffer + esi]        ; pointer naar buffer
  mov cx, 1                     ; aantal bytes we gaan lezen
  int 21h                       ; DOS call
  cmp ax, 0                     ; were 0 bytes read?
	jz @@eof                      ; yes, end of file found
  mov esi, [dword aantalChar]
	mov dl, [offset buffer + esi] ; no, load file character
	cmp dl, 1ah                   ; is it control-z <EOF>?
	jz @@eof                      ; jump if yes
  inc [aantalChar]

	jmp @@read                    ; repeat

  ; einde van het bestand -> sluiten van het bestand
@@eof:
  mov bx, [fileHandler]
  mov ah, 3eh
  int 21h

@@cant_open:
  ; error message tonen

  ret
ENDP readFile

PROC writeFile
  USES eax, ebx, ecx, edx

  mov al, 2
  mov edx, offset fileName2
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

PROC main

  call scrollWindow           ; scherm zwart maken
  call setCursor              ; cursor links boven plaatsen
  call setWhiteLine           ; witte lijn tekenen

  call printString, offset fileNameHeader
  call printString, offset fileName ; printen van huidig bestand

  call setCursorAt, 0, 24     ; cursor links onder plaatsen
  call setWhiteLine           ; witte lijn tekenen
  call printString, offset commandsInfo ; info printen

  call setCursorAt, 0, 1      ; cursor links boven plaatsen (waar we gaan schrijven)
  
  call listFiles
  ;call readFile               ; lezen van het bestand
  ;call printBuffer            ; printen van de buffer

@@loop:
@@read_key:
	; BIOS interrupt 16h, service 00h om de keyboard te lezen
	;	in 'ah' bevindt zich de scan code van de gedrukte knop
	; in 'al' bevindt zich de ASCII waarde van de gedrukte knop
	mov ah, 00h                 ; service 00h in 'ah' plaatsen
	int 16h			                ; interrupt oproepen

	cmp al, ESCP	              ; ASCII code vergelijken met de ASCII code van de escape knop
	je @@exit		                ; als er op escape gedrukt is geweest, ga dan naar 'exit'

	cmp al, CR	              	; ASCII code vergelijken met de ASCII code van de carriage return (enter knop)
	jne @@continueCR	          ; niet op enter gedrukt, skip dan code van enter knop en doe verder (ga naar 'continueCR')
	inc [cursor_y]	            ; increment van de y-positie
	mov [cursor_x], 0	          ; x-positie terug naar begin
	call setCursor	            ; cursor juist zetten
	jmp @@loop	                ; herbeginnen van de loop
@@continueCR:

	cmp ah, KEYUP               ; scan code vergelijken van de arrow up met scan code die zich bevindt in 'ah'
	jne @@continueKeyUp
	cmp [cursor_y], 0
	jle @@cursor_y_is_negative
	dec [cursor_y]
	call setCursor
@@cursor_y_is_negative:
	jmp @@loop
@@continueKeyUp:

	cmp ah, KEYRIGHT            ; scan code vergelijken van de arrow right met scan code die zich bevindt in 'ah'
	jne @@continueKeyRight
	inc [cursor_x]
	call setCursor
	jmp @@loop
@@continueKeyRight:

	cmp ah, KEYLEFT             ; scan code vergelijken van de arrow left met scan code die zich bevindt in 'ah'
	jne @@continueKeyLeft
	dec [cursor_x]
	call setCursor
	jmp @@loop
@@continueKeyLeft:

	cmp ah, KEYDOWN	            ; scan code vergelijken van de arrow down met scan code die zich bevindt in 'ah'
	jne @@continueKeyDown
	inc [cursor_y]
	call setCursor
	jmp @@loop
@@continueKeyDown:

	cmp al, BS                  ; ASCII vergelijken van de backspace met ASCII code van de backspace knop
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

	cmp al, CTRLS
	jne @@continueCTRLS
	;inc [cursor_y]
	;call setCursor
  call writeFile
	jmp @@loop
@@continueCTRLS:

	; als een andere knop ingedrukt is geweest, dan zal dit wel een normale knop zijn
	; de waarde van deze character bevindt zich in ah
	; we geven deze waarde mee aan de procedure die een character print op het scherm
	; na deze procedure herstarten we de loop
	call printChar, ax
	jmp @@loop

@@exit:

  call setCursorAt, 0, 0
  call scrollWindow

  mov ah, 4ch
	int 21h

ENDP main

DATASEG
  
	cursor_x db 0
	cursor_y db 0

	fileName db 'test.txt', 00, '$' ; bestandsnaam
  fileName2 db 'test2.txt', 00, '$' ; bestandnaam (gaat weg)
	fileNameHeader db "Filename : ", '$' ; header van het programma om te tonen in welk bestand we zijn
	commandsInfo db "^S : Save, ^O : Open, ^X : Close, ^N : New, esc : exit", '$' ; info dat op de onderste balk wordt weergegeven
	buffer dw 7d0h dup(00) ; buffer om data bij te houden
  aantalChar dw 0 ; aantal chars die uitgeprint zullen worden
	fileHandler dw ? ; file handler

UDATASEG
;buffer db 100 dup(?), '$' ; buffer moet nog niet
; -------------------------------------------------------------------
; STACK
; -------------------------------------------------------------------
STACK 100h

END main
