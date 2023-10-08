/*
 * MIT License
 *
 * Copyright (c) 2023 Maciej Małecki
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import "common/lib/invoke-global.asm"
#import "chipset/lib/vic2-global.asm"
#import "chipset/lib/cia-global.asm"
#import "chipset/lib/mos6510-global.asm"

#import "_zero-page.asm"
#import "_constants.asm"


.label CM_SCREEN = 1024
.label MAX_DELAY = 200


cheatMenu: {
    lda #%10011011
    sta c64lib.CONTROL_1
    lda #%00001000
    sta c64lib.CONTROL_2
    lda #%00010110
    sta c64lib.MEMORY_CONTROL
    lda #BLACK
    sta c64lib.BORDER_COL
    sta c64lib.BG_COL_0

    jsr clearScreen
    jsr displayText

    lda #0
    sta gameCheatState

    // setup keyboard
    lda #0
    sta c64lib.CIA1_DATA_DIR_B

    ldy #0
    loop:
        lda #WHITE
        jsr highlightLine

        // read keyboard
    readKeyboard:
        lda #%11100111
        jsr readKey
        cmp #%10000000 // N
        beq no
        cmp #%00000010 // Y
        beq yes
        lda #%11111110
        jsr readKey
        cmp #%00000010 // CR
        beq quit
        jsr readJoy
        and #%00010000
        cmp #%00010000
        beq quit
        jmp readKeyboard
    continue:
        lda #0
        jsr readKey
        cmp #0
        bne continue

        lda #LIGHT_GRAY
        jsr highlightLine
        iny
        cpy #5
    bne loop
    quit:
        rts

    readKey: {
        pha
        lda #$ff
        sta c64lib.CIA1_DATA_DIR_A
        pla

        jsr readOnce
        cmp #0
        beq return
        sta lastValue

        ldx #MAX_DELAY
        loop:
            jsr readOnce
            cmp #0
            beq return
            dex
        bne loop
        rts

    readOnce:
        sta c64lib.CIA1_DATA_PORT_A
        lda c64lib.CIA1_DATA_PORT_B
        eor #$ff
    return:
        rts
    lastValue: .byte 0
    }

    readJoy: {
        lda #0
        sta c64lib.CIA1_DATA_DIR_A
        lda c64lib.CIA1_DATA_PORT_A
        eor #$ff
        rts
    }

    yes: {
        lda #1
        jsr answer
        lda gameCheatState
        ora cheatFlags, y
        sta gameCheatState
        jmp continue
    }
    no: {
        lda #0
        jsr answer
        jmp continue
    }

clearScreen: {
    ldx #0
    loop:
        lda #' '
        sta CM_SCREEN, x
        sta CM_SCREEN + 250, x
        sta CM_SCREEN + 500, x
        sta CM_SCREEN + 750, x
        lda #LIGHT_GRAY
        sta c64lib.COLOR_RAM, x
        lda #DARK_GRAY
        sta c64lib.COLOR_RAM + 250, x
        sta c64lib.COLOR_RAM + 500, x
        lda #LIGHT_GRAY
        sta c64lib.COLOR_RAM + 750, x
        inx
        cpx #250
    bne loop
    rts
}

.var cheatTexts = List().add(txtCheat0, txtCheat1, txtCheat2, txtCheat3, txtCheat4)

displayText: {
    c64lib_pushParamW(txtTitle0)
    c64lib_pushParamW(CM_SCREEN + 1*40 + 8)
    jsr outText
    c64lib_pushParamW(txtTitle1)
    c64lib_pushParamW(CM_SCREEN + 2*40 + 12)
    jsr outText

    .for(var i = 0; i < cheatTexts.size(); i++) {
        c64lib_pushParamW(cheatTexts.get(i))
        c64lib_pushParamW(CM_SCREEN + (7+2*i) * 40 + 3)
        jsr outText
        c64lib_pushParamW(txtYesNo)
        c64lib_pushParamW(CM_SCREEN + (7+2*i) * 40 + 34)
        jsr outText
    }

    c64lib_pushParamW(txtPress)
    c64lib_pushParamW(CM_SCREEN + 21*40 + 8)
    jsr outText

    c64lib_pushParamW(txtVersion)
    c64lib_pushParamW(CM_SCREEN + 24*40 + 30)
    jsr outText
   
    rts
}
// A - color, Y - line number
highlightLine: {
    pha
    lda linesCols.lo, y
    sta address
    lda linesCols.hi, y
    sta address + 1
    pla
    ldx #0
    loop: 
        sta address:$ffff, x
        inx
        cpx #40
    bne loop
    rts
}

// A - zero no, non zero yes, Y - line number
answer: {
    pha
    clc
    lda linesChars.lo, y
    adc #34
    sta address
    lda linesChars.hi, y
    adc #0
    sta address + 1
    pla
    beq !+
        c64lib_pushParamW(txtYes)
    jmp !++
    !:
        c64lib_pushParamW(txtNo)
    !:
    
    c64lib_pushParamWInd(address)
    jsr outText
    rts

    address: .word 0
}

linesChars: .lohifill 5, CM_SCREEN + (7+2*i)*40
linesCols:  .lohifill 5, c64lib.COLOR_RAM + (7+2*i)*40

cheatFlags: .byte $04, $02, $20, $10, $08

txtTitle0: .text "Tony: Born for Adventure"; .byte $ff
txtTitle1: .text "official trainer"; .byte $ff

txtCheat0: .text "Infinite lives?"; .byte $ff
txtCheat1: .text "Resistant to boulders?"; .byte $ff
txtCheat2: .text "Resistant to spikes?"; .byte $ff
txtCheat3: .text "Resistant to nasties?"; .byte $ff
txtCheat4: .text "Pass thru closed doors?"; .byte $ff

txtPress:  .text "RETURN or FIRE to start"; .byte $ff

txtYesNo:  .text "y/N"; .byte $ff
txtYes:    .text "Yes"; .byte $ff
txtNo:     .text "No "; .byte $ff

txtVersion:
.if(cmdLineVars.containsKey("version")) {
    .text "v"; .text cmdLineVars.get("version")
} else {
    .text "no version"
}
.byte $ff;
}
