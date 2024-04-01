    processor 6502

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Include required files with VCS register memory mapping and macros
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    include "vcs.h"
    include "macro.h"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Declare the variables starting from memory address $80
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    seg.u Variables
    org $80

JetXPos         byte         ; player 0 x-position
JetYPos         byte         ; player 0 y-position
BomberXPos      byte         ; player 1 x-position
BomberYPos      byte         ; player 1 y-position
MissileXPos     byte         ; missile x-position
MissileYPos     byte         ; missile y-position
ArrowXPos       byte         ; missile x-position
ArrowYPos       byte         ; missile y-position
Score           byte         ; 2-digit score stored as BCD
Timer           byte         ; 2-digit timer stored as BCD
Temp            byte         ; auxiliary variable to store temp values
OnesDigitOffset word         ; lookup table offset for the score Ones digit
TensDigitOffset word         ; lookup table offset for the score Tens digit
JetSpritePtr    word         ; pointer to player0 sprite lookup table
JetColorPtr     word         ; pointer to player0 color lookup table
ArrowSpritePtr  word         ; pointer to Arrow sprite lookup table
BomberSpritePtr word         ; pointer to player1 sprite lookup table
BomberColorPtr  word         ; pointer to player1 color lookup table
JetAnimOffset   byte         ; player0 frame offset for sprite animation
Random          byte         ; used to generate random bomber x-position
ScoreSprite     byte         ; store the sprite bit pattern for the score
TimerSprite     byte         ; store the sprite bit pattern for the timer
TerrainColor    byte         ; store the color of the terrain playfield
RiverColor      byte         ; store the color of the river playfield
CanShootFirework byte        ; Checking if P0 can shoot a firework
FireIsWorking   byte        ; Checking if Firework animation is going
Shooting   byte        ; Checking if Arrow Shoot is Ture or False

FrameNumber     byte        ; every frame is +1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Define constants
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
JET_HEIGHT = 9               ; player0 sprite height (# rows in lookup table)
BOMBER_HEIGHT = 9            ; player1 sprite height (# rows in lookup table)
DIGITS_HEIGHT = 5            ; scoreboard digit height (#rows in lookup table)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Start our ROM code at memory address $F000
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    seg Code
    org $F000

Reset:
    CLEAN_START              ; call macro to reset memory and registers

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialize RAM variables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #68
    sta JetXPos              ; JetXPos = 68
    lda #0
    sta JetYPos              ; JetYPos = 10
    lda #62
    sta BomberXPos           ; BomberXPos = 62
    lda #75
    sta BomberYPos           ; BomberYPos = 75
    lda #15
    sta ArrowXPos           ; ArrowXPos = 15
    lda #55
    sta ArrowYPos           ; ArrowYPos = 55
    lda #%11010100
    sta Random               ; Random = $D4
    lda #0
    sta Score                ; Score = 0
    sta Timer                ; Timer = 0
    sta FireIsWorking        ; FireIsWorking = False 
    sta FrameNumber          ; FrameNumber = 0 
    sta Shooting                ; Shooting = False
    lda #1
    sta CanShootFirework    ; CanShootFirework = True

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Declare a MACRO to check if we should display the missile 0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    MAC DRAW_MISSILE
;	lda #%11111111               ; stretching missile not working
;	sta HMM0
        lda #%00000000
        cpx MissileYPos      ; compare X (current scanline) with missile Y pos
        bne .SkipMissileDraw ; if (X != missile Y position), then skip draw
.DrawMissile:                ; else:
        lda #%00000010       ;     enable missile 0 display
        inc MissileYPos      ;     MissileYPos++
.SkipMissileDraw:
        sta ENAM0            ; store correct value in the TIA missile register
    ENDM



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Initialize the pointers to the correct lookup table adresses
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #<JetSprite
    sta JetSpritePtr         ; lo-byte pointer for jet sprite lookup table
    lda #>JetSprite
    sta JetSpritePtr+1       ; hi-byte pointer for jet sprite lookup table

    lda #<JetColor
    sta JetColorPtr          ; lo-byte pointer for jet color lookup table
    lda #>JetColor
    sta JetColorPtr+1        ; hi-byte pointer for jet color lookup table

    lda #<ArrowSprite
    sta ArrowSpritePtr          ; lo-byte pointer for Arrow lookup table
    lda #>ArrowSprite
    sta ArrowSpritePtr+1        ; hi-byte pointer for Arrow lookup table

    lda #<BomberSprite
    sta BomberSpritePtr      ; lo-byte pointer for bomber sprite lookup table
    lda #>BomberSprite
    sta BomberSpritePtr+1    ; hi-byte pointer for bomber sprite lookup table

    lda #<BomberColor
    sta BomberColorPtr       ; lo-byte pointer for bomber color lookup table
    lda #>BomberColor
    sta BomberColorPtr+1     ; hi-byte pointer for bomber color lookup table

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Start the main display loop and frame rendering
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
StartFrame:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Display VSYNC and VBLANK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #2
    sta VBLANK               ; turn on VBLANK
    sta VSYNC                ; turn on VSYNC
    REPEAT 3
        sta WSYNC            ; display 3 recommended lines of VSYNC
    REPEND
    lda #0


    sta VSYNC                ; turn off VSYNC
    sta WSYNC            ; display the recommended lines of VBLANK

    lda FrameNumber      ; incrementing Frame Number
    adc #1
    sta FrameNumber

    cmp #128            ; just for debugging P1 (firework/bomber) logic
    bcc .SetTrue
    jmp .SetFalse
.SetTrue
    lda #1
    sta FireIsWorking
    jmp .EndCond
.SetFalse
    lda #0
    sta FireIsWorking
    jmp .EndCond

.EndCond

    lda #0
    REPEAT 29                ; not 37 vecayse some operations are made
        sta WSYNC            ; display the recommended lines of VBLANK
    REPEND

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Calculations and tasks performed during the VBLANK section
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;





    lda JetXPos
    ldy #0
    jsr SetObjectXPos        ; set player0 horizontal position

    lda #0                ; is false
    cmp FireIsWorking     ; checking weather set xpos for firework or bomber 
    bne .SetBomberX       ; if FireworkIsWorking = False, set bomber x pos
    jmp .SetArrowX        ; ptjerwose seet arrow x pos


.SetBomberX
    lda BomberXPos
    ldy #1
    jsr SetObjectXPos        ; set player1 horizontal position
    jmp .SkipP1

.SetArrowX
    lda #1
    cmp Shooting
    beq .test
    jmp .EndShooting

.test
    lda #100
    cmp ArrowXPos
    bcc .ResetArrow
    inc ArrowXPos
    inc ArrowXPos
    jmp .EndShooting

.ResetArrow
    lda #15
    sta ArrowXPos
    lda #0
    sta Shooting
    

.EndShooting

    lda ArrowXPos
    ldy #1
    jsr SetObjectXPos        ; set player1 horizontal position
    jmp .SkipP1

.SkipP1
    lda #0
    sta WSYNC

    lda MissileXPos
    ldy #2
    jsr SetObjectXPos        ; set missile horizontal position

    jsr CalculateDigitOffset ; calculate scoreboard digits lookup table offset

    jsr GenerateJetSound     ; configure and enable our jet engine audio

    sta WSYNC
    sta HMOVE                ; apply the horizontal offsets previously set

    lda #0
    sta VBLANK               ; turn off VBLANK

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Display the scoreboard lines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #0                   ; reset TIA registers before displaying the score
    sta COLUBK
    sta PF0
    sta PF1
    sta PF2
    sta GRP0
    sta GRP1
    sta CTRLPF

    lda #$1E
    sta COLUPF               ; set the scoreboard playfield color with yellow

    ldx #DIGITS_HEIGHT       ; start X counter with 5 (height of digits)

.ScoreDigitLoop:
    ldy TensDigitOffset      ; get the tens digit offset for the Score
    lda Digits,Y             ; load the bit pattern from lookup table
    and #$F0                 ; mask/remove the graphics for the ones digit
    sta ScoreSprite          ; save the score tens digit pattern in a variable

    ldy OnesDigitOffset      ; get the ones digit offset for the Score
    lda Digits,Y             ; load the digit bit pattern from lookup table
    and #$0F                 ; mask/remove the graphics for the tens digit
    ora ScoreSprite          ; merge it with the saved tens digit sprite
    sta ScoreSprite          ; and save it
    sta WSYNC                ; wait for the end of scanline
    sta PF1                  ; update the playfield to display the Score sprite

    ldy TensDigitOffset+1    ; get the left digit offset for the Timer
    lda Digits,Y             ; load the digit pattern from lookup table
    and #$F0                 ; mask/remove the graphics for the ones digit
    sta TimerSprite          ; save the timer tens digit pattern in a variable

    ldy OnesDigitOffset+1    ; get the ones digit offset for the Timer
    lda Digits,Y             ; load digit pattern from the lookup table
    and #$0F                 ; mask/remove the graphics for the tens digit
    ora TimerSprite          ; merge with the saved tens digit graphics
    sta TimerSprite          ; and save it

    jsr Sleep12Cycles        ; wastes some cycles

    sta PF1                  ; update the playfield for Timer display

    ldy ScoreSprite          ; preload for the next scanline
    sta WSYNC                ; wait for next scanline

    sty PF1                  ; update playfield for the score display
    inc TensDigitOffset
    inc TensDigitOffset+1
    inc OnesDigitOffset
    inc OnesDigitOffset+1    ; increment all digits for the next line of data

    jsr Sleep12Cycles        ; waste some cycles

    dex                      ; X--


    sta PF1                  ; update the playfield for the Timer display
    bne .ScoreDigitLoop      ; if dex != 0, then branch to ScoreDigitLoop

    sta WSYNC

    lda #0
    sta PF0
    sta PF1
    sta PF2
    sta WSYNC
    sta WSYNC
    sta WSYNC

;;;;; Firework successfully went off  ;;;;;
    lda #75
    cmp MissileYPos
    bne .fireworkNotWorked
    jsr FireWorked           ; firework was successful and got a score
.fireworkNotWorked
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Display the remaining visible scanlines of our main game (2-line kernel)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GameVisibleLine:
    lda TerrainColor
    sta COLUPF               ; set the terrain background color

    lda RiverColor
    sta COLUBK               ; set the river background color

    lda #%00000001
    sta CTRLPF               ; enable playfield reflection
    lda #$F0
    sta PF0                  ; setting PF0 bit pattern
    lda #$FC
    sta PF1                  ; setting PF1 bit pattern
    lda #0
    sta PF2                  ; setting PF2 bit pattern

    ldx #89                  ; X counts the number of remaining scanlines

.GameLineLoop:
    DRAW_MISSILE             ; macro to check if we should draw the missile
;    UPDATE_ARROWXPOS             ; Broken, doesn't work

.AreWeInsideJetSprite:
    txa                      ; transfer X to A
    sec                      ; make sure carry flag is set before subtraction
    sbc JetYPos              ; subtract sprite Y-coordinate
    cmp #JET_HEIGHT          ; are we inside the sprite height bounds?
    bcc .DrawSpriteP0        ; if result < SpriteHeight, call the draw routine
    lda #0                   ; else, set lookup index to zero


.DrawSpriteP0:
    clc                      ; clear carry flag before addition
    adc JetAnimOffset        ; jump to correct sprite frame address in memory
    tay                      ; load Y so we can work with the pointer
    lda (JetSpritePtr),Y     ; load player0 bitmap data from lookup table
    sta WSYNC                ; wait for scanline
    sta GRP0                 ; set graphics for player0
    lda (JetColorPtr),Y      ; load player color from lookup table
    sta COLUP0               ; set color of player 0

.AreWeInsideBomberSprite:
    txa                      ; transfer X to A
    sec                      ; make sure carry flag is set before subtraction
    sbc BomberYPos           ; subtract sprite Y-coordinate
    cmp #BOMBER_HEIGHT       ; are we inside the sprite height bounds?
    bcc .DrawSpriteP1        ; if result < SpriteHeight, call the draw routine
    lda #0                   ; else, set lookup index to zero


.AreWeInsideArrowSprite:
    txa                      ; transfer X to A
    sec                      ; make sure carry flag is set before subtraction
    sbc ArrowYPos           ; subtract sprite Y-coordinate
    cmp #BOMBER_HEIGHT       ; are we inside the sprite height bounds?
    bcc .DrawArrowP1        ; if result < SpriteHeight, call the draw routine
    lda #0                   ; else, set lookup index to zero

.DrawSpriteP1:
    cpx #70                 ; Compare Y register with the value 70 
    bcc .DrawArrowP1         ; Branch if Y < 70 so that the sprite don't glitch

    ldy FireIsWorking
    cpy #0                   ; if false, don't draw bomber
    beq .DrawArrowP1

    
    tay                      ; load Y so we can work with the pointer

    lda #%00000101
    sta NUSIZ1               ; stretch player 1 sprite

    lda (BomberSpritePtr),Y  ; load player1 bitmap data from lookup table
    sta WSYNC                ; wait for scanline
    sta GRP1                 ; set graphics for player1
    lda (BomberColorPtr),Y   ; load player color from lookup table
    sta COLUP1               ; set color of player 1
    jmp .EndLoop

.DrawArrowP1:
    cpx #70                 ; Compare Y register with the value 70 
    bcs .EndLoop         ; Branch if Y < 70 so that the sprite don't glitch
    beq .EndLoop         ; also when its equal

    ldy FireIsWorking
    cpy #1                   ; if true, don't draw arrow
    beq .EndLoop

    tay                      ; load Y so we can work with the pointer

    lda (ArrowSpritePtr),Y  ; load player1 bitmap data from lookup table
    sta WSYNC                ; wait for scanline
    sta GRP1                 ; set graphics for player1
    lda (ArrowSpritePtr),Y   ; load player color from lookup table

.EndLoop
;;; loop end ;;;
    dex                      ; X--
    bne .GameLineLoop        ; repeat next main game scanline until finished

    lda #0
    sta JetAnimOffset        ; reset jet animation frame to zero each frame

    sta WSYNC                ; wait for a scanline

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Display VBLANK Overscan
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    lda #2
    sta VBLANK               ; turn on VBLANK again to display overscan
    REPEAT 30
        sta WSYNC            ; display recommended lines of overscan
    REPEND
    lda #0
    sta VBLANK               ; turn off VBLANK

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Process joystick input for player 0 up/down/left/right
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CheckP0Up:
    lda #%00010000           ; joystick up for player 0
    bit SWCHA
    bne CheckP0Down
    lda JetYPos
    cmp #70                  ; if (player0 Y position > 70)
    bpl CheckP0Down          ;    then: skip increment
.P0UpPressed:                ;    else:
;    inc JetYPos              ;        increment Y position
    lda #0
    sta JetAnimOffset        ;        set jet animation frame to zero

CheckP0Down:
    lda #%00100000           ; joystick down for player 0
    bit SWCHA
    bne CheckP0Left
    lda JetYPos
    cmp #5                   ; if (player0 Y position < 5)
    bmi CheckP0Left          ;    then: skip decrement
.P0DownPressed:              ;    else:
    dec JetYPos              ;        decrement Y position
    lda #0
    sta JetAnimOffset        ;        set jet animation frame to zero

CheckP0Left:
    lda #%01000000           ; joystick left for player 0
    bit SWCHA
    bne CheckP0Right
    lda JetXPos
    cmp #35                  ; if (player0 X position < 35)
    bmi CheckP0Right         ;    then: skip decrement

.P0LeftPressed:              ;    else:
    dec JetXPos              ;        decrement X position
    lda #JET_HEIGHT
    sta JetAnimOffset        ;        set new offset to display second frame

CheckP0Right:
    lda #%10000000           ; joystick right for player 0
    bit SWCHA
    bne CheckButtonPressed
    lda JetXPos
    cmp #100                 ; if (player0 X position > 100)
    bpl CheckButtonPressed   ;    then: skip increment

.P0RightPressed:             ;    else:
    inc JetXPos              ;        increment X position
    lda #JET_HEIGHT
    sta JetAnimOffset        ;        set new offset to display second frame

CheckButtonPressed:
    lda #%10000000           ; if button is pressed
    bit INPT4
    bne CheckFButtonPressed

    lda #1
    cmp CanShootFirework     ; checking if firework can be fired
    bne EndInputCheck

.ButtonPressed:
    lda #0
    sta CanShootFirework     ; can't fire firework
    lda JetXPos
    clc
    adc #5
    sta MissileXPos          ; set the missile X position equal to the player 0
    lda JetYPos
    clc
    adc #8
    sta MissileYPos          ; set the missile Y position equal to the player 0


CheckFButtonPressed:
    lda #%10000000           ; if button is pressed
    bit INPT5
    bne EndInputCheck

    lda #1
;    cmp CanShootFirework     ; checking if firework can be fired
;    bne EndInputCheck

.ButtonFPressed:
    lda #1                 ; Shooting = True
    sta Shooting          ; set the arrow X position 
    

EndInputCheck:               ; fallback when no input was performed

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Calculations to update position for next frame
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;UpdateBomberPosition:
;    lda BomberYPos
;    clc
;    cmp #0                   ; compare bomber y-position with 0
;    bmi .ResetBomberPosition ; if it is < 0, then reset y-position to the top
;    dec BomberYPos           ; else, decrement enemy y-position for next frame
;    jmp EndPositionUpdate
;.ResetBomberPosition:
;    jsr GetRandomBomberPos   ; call subroutine for random bomber position

.SetScoreValues:
    sed                      ; set BCD mode for score and timer values
    lda Timer
    clc
    adc #1
    sta Timer                ; add 1 to the Timer (BCD does not like INC)
    cld                      ; disable BCD after updating Score and Timer

EndPositionUpdate:           ; fallback for the position update code

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Check for object collision
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CheckCollisionP0P1:
    lda #%10000000           ; CXPPMM bit 7 detects P0 and P1 collision
    bit CXPPMM               ; check CXPPMM bit 7 with the above pattern
    bne .P0P1Collided        ; if collision P0 and P1 happened, then game over
    jsr SetGreenBlueTerrain  ; else, set river and terrain to green and blue
    jmp CheckCollisionM0P1   ; check next possible collision

.P0P1Collided:
    jsr GameOver             ; call GameOver subroutine

CheckCollisionM0P1:
    lda #%10000000           ; CXM0P bit 7 detects M0 and P1 collision
    bit CXM0P                ; check CXM0P bit 7 with the above pattern
    bne .M0P1Collided        ; collision missile 0 and player 1 happened
    jmp EndCollisionCheck

.M0P1Collided:
    sed
    lda Score
    clc
    sbc #1
    sta Score                ; adds 1 to the Score using decimal mode
    cld
    lda #0
    sta MissileYPos          ; reset the missile position
    lda #1
    sta CanShootFirework          ; 


EndCollisionCheck:           ; fallback
    sta CXCLR                ; clear all collision flags before the next frame

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Loop back to start a brand new frame
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    jmp StartFrame           ; continue to display the next frame




FireWorked subroutine
    lda #1
    sta CanShootFirework     ; allow to refire firework

    lda MissileXPos          ; P1 firework animation point set
    sec                      ; P1 is the firework, missile 1 is the player 1
    sbc #10
    sta BomberXPos

    sed
    lda Score
    clc
    adc #1
    sta Score                ; adds 1 to the Score using decimal mode
    cld
    lda #0
    sta MissileYPos          ; reset the missile position
    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Generate audio for the jet engine sound based on the jet y-position
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The frequency/pitch will be modified based on the jet current y-position.
;; Normally, the TIA audio frequency goes from 0 (highest) to 31 (lowest).
;; We subtract 31 - (JetYPos/8) to achieve the desired final pitch value.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GenerateJetSound subroutine
    lda #3
    sta AUDV0                ; set the audio volume register

    lda #8
    sta AUDC0                ; set the audio control register to white noise

    lda JetYPos              ; loads the accumulator with the jet y-position
    lsr
    lsr
    lsr                      ; divide the accumulator by 8 (using right-shifts)
    sta Temp                 ; save the Y/8 value in a temp variable
    lda #31
    sec
    sbc Temp                 ; subtract 31-(Y/8)
    sta AUDF0                ; set the audio frequency/pitch register

    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Set the colors for the terrain and river to green & blue
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SetGreenBlueTerrain subroutine
    lda #$C2
    sta TerrainColor         ; set terrain color to green
    lda #$84
    sta RiverColor           ; set river color to blue
    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Subroutine to handle object horizontal position with fine offset
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; A is the target x-coordinate position in pixels of our object
;; Y is the object type (0:player0, 1:player1, 2:missile0, 3:missile1, 4:ball)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SetObjectXPos subroutine
    sta WSYNC                ; start a fresh new scanline
    sec                      ; make sure carry-flag is set before subtracion
.Div15Loop
    sbc #15                  ; subtract 15 from accumulator
    bcs .Div15Loop           ; loop until carry-flag is clear
    eor #7                   ; handle offset range from -8 to 7
    asl
    asl
    asl
    asl                      ; four shift lefts to get only the top 4 bits
    sta HMP0,Y               ; store the fine offset to the correct HMxx
    sta RESP0,Y              ; fix object position in 15-step increment
    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Game Over subroutine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GameOver subroutine
    lda #$30
    sta TerrainColor         ; set terrain color to red
    sta RiverColor           ; set river color to red
    lda #0
    sta Score                ; Score = 0
    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Subroutine to generate a Linear-Feedback Shift Register random number
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Generate a LFSR random number for the X-position of the bomber.
;; Divide the random value by 4 to limit the size of the result to match river.
;; Add 30 to compensate for the left green playfield
;; The routine also sets the Y-position of the bomber to the top of the screen.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;GetRandomBomberPos subroutine
;    lda Random
;    asl
;    eor Random
;    asl
;    eor Random
;    asl
;    asl
;    eor Random
;    asl
;    rol Random               ; performs a series of shifts and bit operations
;    lsr
;    lsr                      ; divide the value by 4 with 2 right shifts
;    sta BomberXPos           ; save it to the variable BomberXPos
;    lda #30
;    adc BomberXPos           ; adds 30 + BomberXPos to compensate for left PF
;    sta BomberXPos           ; and sets the new value to the bomber x-position
;
;    lda #96
;    sta BomberYPos           ; set the y-position to the top of the screen
;
;    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Subroutine to handle scoreboard digits to be displayed on the screen
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The scoreboard is stored using BCD, so the display shows hex numbers.
;; This converts the high and low nibbles of the variable Score and Timer
;; into the offsets of digits lookup table so the values can be displayed.
;; Each digit has a height of 5 bytes in the lookup table.
;;
;; For the low nibble we need to multiply by 5
;;   - we can use left shifts to perform multiplication by 2
;;   - for any number N, the value of N*5 = (N*2*2)+N
;;
;; For the upper nibble, since its already times 16, we need to divide it
;; and then multiply by 5:
;;   - we can use right shifts to perform division by 2
;;   - for any number N, the value of (N/16)*5 is equal to (N/4)+(N/16)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CalculateDigitOffset subroutine
    ldx #1                   ; X register is the loop counter
.PrepareScoreLoop            ; this will loop twice, first X=1, and then X=0

    lda Score,X              ; load A with Timer (X=1) or Score (X=0)
    and #$0F                 ; remove the tens digit by masking 4 bits 00001111
    sta Temp                 ; save the value of A into Temp
    asl                      ; shift left (it is now N*2)
    asl                      ; shift left (it is now N*4)
    adc Temp                 ; add the value saved in Temp (+N)
    sta OnesDigitOffset,X    ; save A in OnesDigitOffset+1 or OnesDigitOffset

    lda Score,X              ; load A with Timer (X=1) or Score (X=0)
    and #$F0                 ; remove the ones digit by masking 4 bits 11110000
    lsr                      ; shift right (it is now N/2)
    lsr                      ; shift right (it is now N/4)
    sta Temp                 ; save the value of A into Temp
    lsr                      ; shift right (it is now N/8)
    lsr                      ; shift right (it is now N/16)
    adc Temp                 ; add the value saved in Temp (N/16+N/4)
    sta TensDigitOffset,X    ; store A in TensDigitOffset+1 or TensDigitOffset

    dex                      ; X--
    bpl .PrepareScoreLoop    ; while X >= 0, loop to pass a second time

    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Subroutine to waste 12 cycles
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; jsr takes 6 cycles
;; rts takes 6 cycles
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Sleep12Cycles subroutine
    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Declare ROM lookup tables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Digits:
    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###

    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #

    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %00110011          ;  ##  ##
    .byte %00010001          ;   #   #
    .byte %01110111          ; ### ###

    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #

    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #

    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %01110111          ; ### ###

    .byte %00100010          ;  #   #
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #

    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01100110          ; ##  ##
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01000100          ; #   #
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###

    .byte %01100110          ; ##  ##
    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #
    .byte %01100110          ; ##  ##

    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01100110          ; ##  ##
    .byte %01000100          ; #   #
    .byte %01000100          ; #   #

JetSprite:
    .byte #%00000000         ;
    .byte #%00010100         ;   # #
    .byte #%01111111         ; #######
    .byte #%00111110         ;  #####
    .byte #%00011100         ;   ###
    .byte #%00011100         ;   ###
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #

JetSpriteTurn:
    .byte #%00000000         ;
    .byte #%00001000         ;    #
    .byte #%00111110         ;  #####
    .byte #%00011100         ;   ###
    .byte #%00011100         ;   ###
    .byte #%00011100         ;   ###
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #

BomberSprite:
    .byte #%00000000         ;
    .byte #%00001000         ;    #
    .byte #%00001000         ;    #
    .byte #%00101010         ;  # # #
    .byte #%00111110         ;  #####
    .byte #%01111111         ; #######
    .byte #%00101010         ;  # # #
    .byte #%00001000         ;    #
    .byte #%00011100         ;   ###


ArrowSprite:
    .byte #%00000000         ;
    .byte #%00000000         ;     
    .byte #%00000100         ;      # 
    .byte #%00000010         ;       #
    .byte #%11111111         ; ########
    .byte #%00000010         ;       #
    .byte #%00000100         ;      #
    .byte #%00000000         ;     
    .byte #%00000000         ;     

JetColor:
    .byte #$00
    .byte #$FE
    .byte #$0C
    .byte #$0E
    .byte #$0E
    .byte #$04
    .byte #$BA
    .byte #$0E
    .byte #$08

JetColorTurn:
    .byte #$00
    .byte #$FE
    .byte #$0C
    .byte #$0E
    .byte #$0E
    .byte #$04
    .byte #$0E
    .byte #$0E
    .byte #$08

BomberColor:
    .byte #$00
    .byte #$32
    .byte #$32
    .byte #$0E
    .byte #$40
    .byte #$40
    .byte #$40
    .byte #$40
    .byte #$40

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Complete ROM size with exactly 4KB
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    org $FFFC                ; move to position $FFFC
    word Reset               ; write 2 bytes with the program reset address
    word Reset               ; write 2 bytes with the interruption vector
