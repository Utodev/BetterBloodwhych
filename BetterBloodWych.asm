; To be assembled with PASMO. Works with original Blodwych TAP file (71,904 bytes)
;
; The idea is to load this code, the load the screens$, then run this code with RAND USR 32768 ($8000). 
; So the LOADER must be something like 

; 10 PAPER 0: BORDER 0: INK 0: POKE 23624, 0: CLS
; 20 LOAD "" CODE: LOAD "" SCREEN$: RANDOMIZE USR 32768
;
; The loader will load its own "Bytes", then enter the original tape to load 
; the screen (the PROGRAM part will be ignored). Then run from 32768
;
; When run, the code will first relocate itself to 4000h (16384), where thanks
; to black on black attributes it will be invisible (also the loading screen has
; a gap for that). Then it will load the "Bytes:BLOODWYCH" header at 8000h, that
; is a place as any other, pick the bytes address from the header, and load the
; real game code at 23296 (5B00h), which is its original address
; Finally, the code will patch the area at FE00h with the keyboard patch code
; and patch the place where the keyboard read is called so it calls to FE00h
; instead.



                ORG $8000       

Transfer        LD HL, Transfer   ; First, we move all code from 8000h to 4000h
                LD DE, $4000
                LD BC, EndCode -  Transfer
                LDIR
                JP Loader - $4000 ; This actually jumps to next line, once it has been moved

; From now on, this is actually run at $4000 + Loader
Loader          LD SP, $5800    ; Puts Stack on safe place
                
LoadHeader      XOR A           ; Loads BYTES: BloowWych Header at $8000
                SCF
                LD DE, $0011
                LD IX, $8000
                CALL $0556      
                JP NC, $0000    ; In case of error starts resets
                LD A, ($8000)
                CP 03
                JP NZ, $0000    ; If notwhat we loaded is not a bytes header (03), resets
                
LoadData        LD A, $FF       ; Loads data where the header says (spoiler: it's at $5800)
                SCF
                LD DE, ($800B)
                LD IX, ($800D)
                CALL $0556
                JP NC, $0000
                
Patch           LD HL, Init - $4000         ; This includes the extra keyboard handler at FE00h
                LD DE, $FE00
                LD BC, saveY - Init + 1
                LDIR
               
                LD HL, $ECCF                ; This replaces the keyboard handler call with a call to FE00h
                LD A, $FE           
                LD (HL), A          
                DEC HL              
                XOR A               
                LD (HL), A


                LD HL, $A38F                ;Removes the LDIR code that fills the FE00 area with FDs and avoids breaking the new code
                LD (HL), A                  
                INC HL
                LD (HL), A                  
                INC HL
                LD (HL), A                  
                INC HL
                LD (HL), A                  
                
                
                LD HL, $FEFF                ; THen we put a FD at FEFF and FF00 so the interrupt picks it 
                LD A, $FD                   
                LD (HL), A                  
                INC HL                      ; This second one is also added by the original code for unknown reasons, so we do it as well
                LD (HL), A



                XOR A                                  
                OUT ($FE), A                ; Sets black border and go
                JP $5B00

;------------------------------------------------
; ---- Below is the real keyboard patch code ----
;------------------------------------------------

                ; This is actually run at $FE00

Init            CALL $EA7A; Original read-5-keys routine

CoordsRestore   LD A, (saveY -$8000 +$FE00)
                OR A
                JR Z, Exclusions
                LD (IX+$3E), A
                LD A, (saveX -$8000 +$FE00)
                LD (IX+$3D), A
                XOR A
                LD (saveY -$8000 +$FE00), A ; Set saveY to zero to show no coordinates are saved

Exclusions      LD A, D
                AND $1F         ; Isolate 5 lower bits
                JR Z, NoCaps    ; if nothing pressed, Caps Shift modifyer won't do anything anyway
                AND 16
                JR NZ, NoCaps ; if fire pressed, we won't do anything either (Caps+Fire =  Fire)
                
ReadKB          ; Check if Caps Shift is pressed
                LD A, $FE
                IN A, ($FE)               
                AND 1       ;  Caps Shift (bit 0 = 0)
                JR NZ, NoCaps              

                ; At this point we know caps is pressed, and also at least one of the direction keys
                
                ; we will be using HL to prepare button coordinates (H=Y, L=X)
                ; Notice that first we check if up is pressed to set the line in the cursor buttons in the screen
                ; and the we move the x axis depending on wether left, down or right is pressed. Thus, if BetterBloodwych
                ; UP+LEFT or UP+RIGHT are pressed, we will get the coordinates of the rotation buttons in the screen

                PUSH HL
                LD H, $7D   ; $7D is the lower row of the cursor buttons
Up              BIT 1, D
                JR Z, Left
                LD H, $6F   ;  But if Up is pressed, then we set to upper row ($6F)
                LD L, $C4   ;  X axis for UP button

Left            BIT 3, D
                JR Z, Down
                LD L, $B8

Down            BIT 0, D
                JR Z, Right
                LD L, $C4


Right           BIT 2, D
                JR Z, Continue
                LD L, $D8
                


Continue        LD A, (IX+$3D)
                LD (saveX -$8000 +$FE00), A
                LD A, (IX+$3E)
                LD (saveY -$8000 +$FE00), A
                LD (IX+$3D), L
                LD (IX+$3E), H
                LD A, D
                AND 11100000b
                OR 16
                LD D, A; Make as if fire was pressed
                POP HL

NoCaps          RET      
saveX           DB 0
saveY           DB 0
EndCode