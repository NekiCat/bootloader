.model tiny

.code
	ORG 7C00h
	jmp stage1
	
	; FAT-DATEISYSTEMINFORMATIONEN (BIOS Parameter Block)
	ORG 7C03h
	bpbOemName				db "TigeR OS"	; OEM Name (8 Byte)
	bpbBytesPerSector		dw 512			; Bytes pro Sektor
	bpbSectorsPerCluster	db 1			; Sektoren pro Cluster
	bpbReserved				dw 1			; Reservierte Sektoren
	bpbFatCount				db 2			; Anzahl der File Allocation Tables
	bpbMaxRootDirEntries	dw 224			; Max. Einträge im Stammverzeichnis
	bpbSectorCount			dw 2880			; Gesamtzahl der Sektoren
	bpbMediaDescriptor		db 0F0h			; Media Descriptor (3.5" 1.44Mb)
	bpbSectorsPerFat		dw 9			; Anzahl der Sektoren per FAT
	bpbSectorsPerTrack		dw 18			; Sektoren per Track
	bpbHeadCount			dw 2			; Anzahl Lese-/Schreibköpfe
	bpbHiddenSectors		dd 0			; Versteckte Sektoren vor Partition
	bpbSectorCountBig		dd 0			; Gesamtzahl der Sektoren
	
	bpbDriveNumber			db 0			; Physische BIOS-Laufwerksnummer
							db 0			; Reserviert
	bpbExtBootSignature		db 29h			; Erweiterte Bootsignatur
	bpbSerialNumber			dd 0			; ID / Seriennummer
	bpbVolumeLabel			db "TigeR OS   "; Dateisystemname (11 Bytes)
	bpbFileSystem			db "FAT12   "	; FAT-Variante (8 Bytes)
	
	; BOOTLOADER CODE
; IN DS:SI = Stringadresse (Nullterminiert)
; IN DI = Offset für Bildschirmausgabe
; IN AH = Zeichenattribute
stage1_print_str PROC
	push AX
	push SI
	push DI
	push ES
	
	push AX
	mov AX, 0B800h
	mov ES, AX
	pop AX
_print_str_loop:
	mov AL, DS:[SI]
	cmp AL, 0
	je _print_str_ende
	mov ES:[DI], AX
	inc SI
	add DI, 2
	jmp _print_str_loop
	
_print_str_ende:
	pop ES
	pop DI
	pop SI
	pop AX
	ret
stage1_print_str ENDP

stage1_error_halt:
	cli		; Interrupts stoppen
	hlt		; CPU anhalten
	
stage1:
	; Bootmeldung anzeigen
	push CS
	pop DS
	mov SI, OFFSET stage1_lb_booting
	mov DI, 0
	mov AH, 00000111b
	call stage1_print_str
	
stage1_floppy_reset:
	; Diskettenlaufwerk zurücksetzen
	mov AH, 0h
	mov DL, 0
	int 13h
	jc stage1_floppy_reset
	
	; Stammverzeichnis einlesen, um Stage2.sys zu finden
	; Startsektor
	mov AX, bpbSectorsPerFat
	mul bpbFatCount
	add AX, bpbReserved
	push AX
	
	; Stammverzeichnislänge
	mov AX, 32	; Größe eines Verzeichniseintrags
	mul bpbMaxRootDirEntries
	div bpbBytesPerSector
	
	pop CX
	
	mov AH, 2h	; Funktionsnummer
				; AL Anzahl zu lesender Sektoren
	mov CH, 0	; Zylindernummer
				; CL Sektornummer
	mov DH, 0	; Lesekopfnummer
	mov DL, 0	; Laufwerksnummer
	
	mov BX, 7E00h	; Zieladresse
	mov ES, BX
	xor BX, BX
	
	int 13h
	jnc stage1_root_scan
	mov SI, OFFSET stage1_lb_rerror
	add DI, 160
	mov AH, 00001100b
	call stage1_print_str
	jmp stage1_error_halt

	stage1_imgname db "STAGE2  SYS"
stage1_root_scan:
	mov SI, OFFSET stage1_lb_scan
	add DI, 160
	mov AH, 00000111b
	call stage1_print_str


	mov CX, bpbMaxRootDirEntries
	mov SI, OFFSET stage1_imgname
	mov DI, 0
stage1_loop:
	xchg AX, CX
	mov CX, 11
	push DI
	repe cmpsb
	pop DI
	je stage1_load_stage2
	add DI, 32
	xchg AX, CX
	loop stage1_loop
	
	mov AH, 00001100b
	mov SI, OFFSET stage1_lb_err_notfound
	mov DI, 160
	call stage1_print_str
	jmp stage1_error_halt
	
stage1_load_stage2:
	mov DX, [DI+1Ah]
	xor AX, AX
	mov AL, bpbFatCount
	
	jmp stage1_error_halt
	

	
	; Einige Labels
	stage1_lb_booting			db "Boote TigeR OS", 0
	stage1_lb_scan				db "Scanne Root-Dir", 0
	stage1_lb_rerror			db "Lesefehler", 0
	stage1_lb_err_notfound		db "STAGE2.SYS wurde nicht gefunden", 0

	; SIGNATUR FÜR BOOTBARE MEDIEN
	ORG 7E00h-2
	db 55h
	db 0AAh
end
