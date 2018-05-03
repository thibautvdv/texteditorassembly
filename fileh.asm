IDEAL
P386
MODEL FLAT, C
ASSUME cs:_TEXT,ds:FLAT,es:FLAT,fs:FLAT,gs:FLAT

INCLUDE "fileh.inc"

UDATASEG

DATASEG
  DTA db 15h dup(0)               ; Disk Transfer Area (informatie over bestanden)
  file_spec db "*.txt", 0         ; Welke bestanden we gaan zoeken

CODESEG

PROC listFiles
  USES
  ; Eerst moeten we zeggen waar de informatie over het bestand opgeslagen moet worden
  ; Dit kan met functie 1Ah
  mov edx, offset DTA
  mov ah, 1ah   ; Set Disk Transfer Address
  int 21h       ; Call interrupt
  

  ; Nu gaan we zoeken naar het bestand
  ; De naam van de bestanden zit in file_spec 
  mov edx, offset file_spec
  xor cx, cx
  mov ah, 4eh   ; Functie om eerste bestand te zoeken
  int 21h
  jc @@quit     ; als er niets gevonden is dan zal CF hoog zijn

@@print_name:
  lea esi, [DTA + 1eh] ; Uit DTA halen we de naam: DTA + 1eh is gelijk aan de naam

@@next_char:
  lodsb       ; Laden van een byte uit DS:(E)SI in AL
  int 29h     
  test al, al
  jnz @@next_char

  ; enter afdrukken
  mov al, 13
  int 29h
  mov al, 10
  int 29h

  ; zoeken naar een volgend bestand
  mov edx, offset file_spec
  xor cx, cx
  mov ah, 4fh
  int 21h
  jnc @@print_name ; als er een nieuw bestand gevonden is, dan mag die opnieuw afgedrukt worden

@@quit:  
  ret
ENDP listFiles

END