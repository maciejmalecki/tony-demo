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

#import "common/lib/math-global.asm"
#import "_constants.asm"
#import "_zero-page.asm"

.segment Code

// to fast-access bitmap memory; each 320x8 chunk is split into two 160x8 to allows indexing by single byte
_bitmapOffsetsLo: .fill 25*2, <(BITMAP_MEM + i*8*20)
_bitmapOffsetsHi: .fill 25*2, >(BITMAP_MEM + i*8*20)
// ...and to fast calc indexing value
_chunkOffset: .fill 20, i*8

// to fast-access level charset;
_charsetOffsetsLo: .fill 256, <(CHARSET_MEM + i*8)
_charsetOffsetsHi: .fill 256, >(CHARSET_MEM + i*8)

// to fast-access dashboard charset;
_dashboardOffsetsLo: .fill DASHBOARD_CHAR_COUNT, <(DASHBOARD_MEM + i*8)
_dashboardOffsetsHi: .fill DASHBOARD_CHAR_COUNT, >(DASHBOARD_MEM + i*8)

.macro grab_drawPlayfield(chamberMap) {
    lda #4
    sta COUNTER

    ldx #0 // first row of playfield
    lda _bitmapOffsetsLo, x
    sta DEST_PTR
    lda _bitmapOffsetsHi, x
    sta DEST_PTR + 1

    lda #<chamberMap
    sta nextCharAddr
    lda #>chamberMap
    sta nextCharAddr + 1

    // start the loop
outer:
    lda #200
    sta saveCtr
inner:
    ldx nextCharAddr:$FFFF
    lda _charsetOffsetsLo, x
    sta SOURCE_PTR
    lda _charsetOffsetsHi, x
    sta SOURCE_PTR + 1

    _grab_copyBitmapChar(false)

    // incNextChar
    c64lib_add16(1, nextCharAddr)
    // inc next playfield pos
    c64lib_add16(8, DEST_PTR)

    dec saveCtr
    bne inner
    dec COUNTER
    bne outer

    rts
saveCtr: .byte 0
}

.macro grab_drawDashboard(dashboardMap) {
    lda #(4*40)
    sta COUNTER

    ldx #40 // first row of dashboard *2
    lda _bitmapOffsetsLo, x
    sta DEST_PTR
    lda _bitmapOffsetsHi, x
    sta DEST_PTR + 1

    lda #<dashboardMap
    sta nextCharAddr
    lda #>dashboardMap
    sta nextCharAddr + 1
    
    // start the loop
loop:
    ldx nextCharAddr:$FFFF
    lda _dashboardOffsetsLo, x
    sta SOURCE_PTR
    lda _dashboardOffsetsHi, x
    sta SOURCE_PTR + 1

    _grab_copyBitmapChar(false)

    // incNextChar
    c64lib_add16(1, nextCharAddr)
    // inc next dashboard pos
    c64lib_add16(8, DEST_PTR)

    dec COUNTER
    bne loop

    rts
}

grab_setColors: {
    ldx #0
    lda #$F0
loop:
    sta SCREEN_MEM_0, x
    sta SCREEN_MEM_0 + $100, x
    sta SCREEN_MEM_0 + $200, x
    sta SCREEN_MEM_0 + $300, x
    inx
    bne loop
    rts
}

/*
 * in:
 *    SOURCE_PTR, DEST_PTR
 *
 * 96 cycles
 */
.macro _grab_copyBitmapChar(doRts) {
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
