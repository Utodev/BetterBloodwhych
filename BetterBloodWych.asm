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

MouseXPort              EQU     $FBDF                
MouseYPort              EQU     $FFDF
MouseButtonPort         EQU     $FADF
MinMouseXVal            EQU     8
MaxMouseXVal            EQU     248
WatchDogAddr            EQU     22624                   ; If in the game, this should be a 3, at the group creation screen, other value
InventoryWatchDog       EQU     22968                   ; If we are not in game, or inventory is open, here won't be a 5 here

LoadADDR                EQU     $8000
TempADDR                EQU     $4000
FinalADDR               EQU     $FE00

                        ORG LoadADDR

                        LD HL, LoadADDR                 ; First, we move all code from 8000h to 4000h
                        LD DE, TempADDR
                        LD BC, EndCode - LoadADDR 
                        LDIR
                        JP Loader - (LoadADDR - TempADDR) ; This actually jumps to next line, once it has been moved

; From now on, this is actually run at $4000 + Loader
Loader                  LD SP, $5800                    ; Puts Stack on safe place (the screen at  00 attribute area)
                
LoadHeader              XOR A                           ; Loads BYTES: BloowWych Header at $8000
                        SCF
                        LD DE, $0011
                        LD IX, LoadADDR                 ; We reutilize the area we just left
                        CALL $0556      
                        JP NC, $0000                    ; In case of error starts resets
                        LD A, (LoadADDR)
                        CP 03
                        JP NZ, $0000                    ; If notwhat we loaded is not a bytes header (03), resets
                
LoadData                LD A, $FF                       ; Loads data where the header says (spoiler: it's at $5800)
                        SCF
                        LD DE, (LoadADDR + $0B)
                        LD IX, (LoadADDR + $0D)
                        CALL $0556
                        JP NC, $0000
                
Patch                   LD HL, Init - (LoadADDR - TempADDR)   ; This includes the extra keyboard handler at FE00h
                        LD DE, FinalADDR
                        LD BC, EndCode - Init
                        LDIR
                    
                        LD HL, $ECCF                    ; This replaces the keyboard handler call with a call to FE00h
                        LD A, $FE           
                        LD (HL), A          
                        DEC HL              
                        XOR A               
                        LD (HL), A


                        LD HL, $A38F                    ;Removes the LDIR code that fills the FE00 area with FDs and avoids overwrite of the new code
                        LD (HL), A                  
                        INC HL
                        LD (HL), A                  
                        INC HL
                        LD (HL), A                  
                        INC HL
                        LD (HL), A                  
                        
                        
                        LD HL, $FEFF                    ; Then we put a FD at FEFF and FF00 so the interrupt picks it 
                        LD A, $FD                   
                        LD (HL), A                  
                        INC HL                          ; This second one is also added by the original code for unknown reasons, so we do it as well
                        LD (HL), A

                        JP $5B00                        ; run game

;------------------------------------------------
; ---- Below is the real keyboard patch code ----
;------------------------------------------------

; This code is actually run at FinalADDR


Init           

CoordsRestore           LD A, (saveY + FinalADDR - Init)    ; Restores previous coordinates if they had been moved
                        OR A
                        JR Z, CoordsRestEnd
                        LD (IX+$3E), A
                        LD A, (saveX + FinalADDR - Init)
                        LD (IX+$3D), A
                        XOR A
                        LD (saveY + FinalADDR - Init), A    ; Set saveY to zero to show no coordinates are saved
CoordsRestEnd                


; --------------------------------
; MOUSE ONLY AREA
; --------------------------------
IF DEFINED kmouse

; ----- Handle X mouse coord
XAxis           
IOMouseX                LD A, HIGH MouseXPort           
                        IN A, (LOW MouseXPort)
                        OR A    
                        JR Z, XAxisEnd    
MinMouseXCheck          CP MinMouseXVal
                        JR NC, MaxMouseXCheck
                        LD A, MinMouseXVal
                        JR SetXAxis                
MaxMouseXCheck          CP MaxMouseXVal
                        JR C, SetXAxis
                        LD A, MaxMouseXVal
SetXAxis                LD (IX+$3D), A
XAxisEnd


; ----- Handle Y mouse coord               
YAxis                   PUSH HL                                            ; Preserver HL as the original keyboard read routine needs it
SetMarginsTable         LD HL, MouseYLimitTable + FinalADDR - Init + 2     ; Check if we are at the play game screen or character selection
                        LD A, (WatchDogAddr)                               ; To determinte which limits to use. Defaults to play screen limits
                        CP 3                                               ; There is a fixed 3 at (WatchDogAddr) in play game screen
                        JR Z, PortMouseY
                        LD HL, MouseYLimitTable + FinalADDR - Init         ; change to char selection screen limits (wider)

PortMouseY              LD A, HIGH MouseYPort
                        IN A, (LOW MouseYPort)
                        OR A
                        JR Z, YAxisEND                                      ; If value is 0, is ignored. Either no K-Mouse or just started playing               
                        CPL                                                 ; Mouse returns Y Axis upside down

MinMouseYCheck          CP (HL)
                        JR NC, MaxMouseYCheck
MinMouseYSet            LD A, (HL)
                        JR SetYAxis
MaxMouseYCheck          INC HL
                        CP (HL)
                        JR C, SetYAxis
MaxMouseYSet            LD A, (HL)           
SetYAxis                LD (IX+$3E), A   
YAxisEND                POP HL                                            ; Restore HL


; ----- Handle mouse button
Buttons         
ReadMouseButton         LD A, HIGH MouseButtonPort
                        IN A, (LOW MouseButtonPort)
                        AND 2
                        JR NZ, OriginalKBD
                        LD D, 16
                        RET ; Skip anything else

ENDIF
; ------------------------------
; END OF MOUSE ONLY AREA
; ------------------------------

                
OriginalKBD             CALL $EA7A; Original read-5-keys routine


IF NOT DEFINED kmouse                                   ; If we are building the keybord only version, we check if any direction key +  caps are pressed
                                                        ; otherwise the extension has nothing to do and just returns to the original code
                        LD A, D
                        AND $1F                         ; Isolate 5 lower bits
                        RET Z                           ; if nothing pressed, nothing special to do in the extension
                        AND $10
                        RET NZ                          ; if fire pressed, we won't do anything special either 
                            
                        LD A, $FE                       ; Check if Caps Shift is pressed
                        IN A, ($FE)               
                        AND 1                           ;  Caps Shift (bit 0 = 0)
                        RET NZ                          ; If Caps Shift is not pressed, we won't do anything special either

ELSE                                                    ; When we are talking about the mouse+kbd version, caps is not needed, we just check a direction key is pressed
                        LD A, D
                        AND $1F                         ; Isolate 4 lower bits
                        RET Z                           ; if no direction key is pressed, extension won't have anything to do
ENDIF

ShortcutsCheck          LD A, (InventoryWatchDog)          ; If the cursors are visible, ther will be a 05 attribute at this position
                        CP 5
                        RET NZ

                ; At this point we know a direction key is pressed and the extension has to simulate on-screen direction or rotation buttons press
                
                ; We will be using HL to prepare button coordinates (H=Y, L=X). Notice that first we check if UP is pressed to set the line 
                ; in the cursor buttons in the screen and then we move the x axis depending on wether left, down or right is pressed.
                ; Thus, if BetterBloodwych UP+LEFT or UP+RIGHT are pressed, we will get the coordinates of the rotation buttons in the screen

                    PUSH HL
                    LD H, $7D                           ; $7D is the lower row of the cursor buttons
Up                  BIT 1, D
                    JR Z, Left
                    LD H, $6F                           ;  But if Up is pressed, then we set to upper row ($6F)
                    LD L, $C4                           ;  X axis for UP button

Left                BIT 3, D
                    JR Z, Down
                    LD L, $B8

Down                BIT 0, D
                    JR Z, Right
                    LD L, $C4

Right               BIT 2, D
                    JR Z, MovePointer
                    LD L, $D8

MovePointer         LD A, (IX+$3D)                      ; First we preserve the current pointer position, to restore on next tick
                    LD (saveX + FinalADDR - Init), A
                    LD A, (IX+$3E)
                    LD (saveY + FinalADDR - Init), A

                    LD (IX+$3D), L                      ; Then we set the new coordinates
                    LD (IX+$3E), H
                    LD A, D                             ; And make sure we return to the original code with D=16, so it thinks fire is pressed
                    AND 11100000b
                    OR 16
                    LD D, A 
                    POP HL
                    RET      

; -------------------
; ---- Variables ----
; -------------------
                    
MouseYLimitTable
MinMouseYChar       DB     24                           ; Max/Min Y coordinates at character selection screen
MaxMouseYChar       DB     192 
MinMouseYPlay       DB     64                           ; Max/Min Y coordinates at game screen
MaxMouseYPlay       DB     126

saveX               DB 0
saveY               DB 0

EndCode

IF EndCode-Init>255                                     ; Get an error if size of patch is too long
.ERROR
ENDIF