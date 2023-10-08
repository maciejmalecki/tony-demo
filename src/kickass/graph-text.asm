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
#import "common/lib/math-global.asm"
#import "_constants.asm"
#import "_zero-page.asm"
#import "_compress.asm"

.segment Code

_grab_decompress: decompressRLE3($ff)

.macro grab_drawPlayfield(chamberMapPtr) {
    c64lib_pushParamWInd(chamberMapPtr)
    c64lib_pushParamW(SCREEN_MEM_0)
    jsr _grab_decompress
    rts
}

.macro grab_drawDashboard(dashboardMap, copyLargeMemForward) {
    c64lib_pushParamW(dashboardMap)
    c64lib_pushParamW(SCREEN_MEM_1 + 20*40)
    c64lib_pushParamW(4*40)
    jsr copyLargeMemForward

    // set empty sprite for dashboard screen mem
    ldx #7
    lda #EMPTY_SPRITE
    loop:
        sta SCREEN_MEM_1 + 1023 - 8, x
        dex
    bne loop
    lda #DASHBOARD_EYES
    sta SCREEN_MEM_1 + 1023
    rts
}

// in: Y - y coord (row), A - x coord (col), SOURCE_PTR
// destroys: A, X, Y
.macro grab_draw1x2(chamberLines) {
    tax
    clc
    adc chamberLines.lo, y
    sta target1
    lda #0
    adc chamberLines.hi, y
    sta target1 + 1

    iny
    txa
    clc
    adc chamberLines.lo, y
    sta target2
    lda #0
    adc chamberLines.hi, y
    sta target2 + 1

    ldy #0
    lda (SOURCE_PTR), y
    sta target1: $ffff
    iny
    lda (SOURCE_PTR), y
    sta target2: $ffff
    rts
}

// in: Y - y coord (row), A - x coord (col), SOURCE_PTR
// destroys: A, X, Y
.macro grab_draw2x2(chamberLines, ptrAddress) {
    tax
    clc
    adc chamberLines.lo, y
    sta target1
    lda #0
    adc chamberLines.hi, y
    sta target1 + 1

    iny
    txa
    clc
    adc chamberLines.lo, y
    sta target2
    lda #0
    adc chamberLines.hi, y
    sta target2 + 1

    ldy #0
    ldx #0
    lda (ptrAddress), y
    jsr sta1
    iny
    inx
    lda (ptrAddress), y
    jsr sta1
    iny
    ldx #0
    lda (ptrAddress), y
    jsr sta2
    iny
    inx
    lda (ptrAddress), y
    jmp sta2

    sta1:
        sta target1: $ffff, x
        rts
    sta2:
        sta target2: $ffff, x
        rts
}

// in: Y - y coord (row), A - x coord (col), X - height, SOURCE_PTR, ZR_0 - width
// destroys: A, X, Y, DEST_PTR
.macro grab_drawRect(chamberLines) {
    clc
    adc chamberLines.lo, y
    sta DEST_PTR
    lda #0
    adc chamberLines.hi, y
    sta DEST_PTR + 1
    stx height
    ldx ZR_0
    stx width

    ldx #0
    nextRow:
        ldy #0
        nextChar:
            lda (SOURCE_PTR), y
            sta (DEST_PTR), y
            iny
            cpy width:#$00
        bne nextChar
        clc
        lda DEST_PTR
        adc #40
        sta DEST_PTR
        lda DEST_PTR + 1
        adc #0
        sta DEST_PTR + 1
        clc
        lda SOURCE_PTR
        adc #4
        sta SOURCE_PTR
        lda SOURCE_PTR + 1
        adc #0
        sta SOURCE_PTR + 1
        inx
        cpx height:#$00
    bne nextRow
    rts
}

/*
 * in:
 *    SOURCE_PTR, DEST_PTR
 *
 * 96 cycles
 */
.macro grab_copyBitmapChar(doRts) {
    ldy #0 // 2
    .for (var i = 0; i < 8; i++) {
        lda (SOURCE_PTR),y // 5
        sta (DEST_PTR),y  // 5
        .if (i < 7) {
            iny // 2
        }
    }
    .if (doRts) {
        rts // 6
    }
}
