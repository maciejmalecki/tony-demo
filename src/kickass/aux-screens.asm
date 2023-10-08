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


#import "_constants.asm"

aux_copyEndGameData: {
    ldx #0
    // copy and invert font
    loop:
        lda FONT_BUFFER_MEM, x
        eor #$ff
        sta TEXT_CHARSET_MEM, x
        lda FONT_BUFFER_MEM + 148, x
        eor #$ff
        sta TEXT_CHARSET_MEM + 148, x
        inx
        cpx #148
    bne loop
    // copy picture
    ldx #0
    loop2:
        lda ENDGAME_BUFFER_MEM, x
        sta TEXT_CHARSET_MEM + 2*148, x
        lda ENDGAME_BUFFER_MEM + 224, x
        sta TEXT_CHARSET_MEM + 2*148 + 224, x
        lda ENDGAME_BUFFER_MEM + 2*224, x
        sta TEXT_CHARSET_MEM + 2*148 + 2*224, x
        inx
        cpx #224
    bne loop2
    rts
}

aux_drawEndGameScreen: {
    // clear all
    ldx #0
    lda #0
    clearLoop:
        sta SCREEN_MEM_0, x
        sta SCREEN_MEM_0 + 200, x
        sta SCREEN_MEM_0 + 2*200, x
        sta SCREEN_MEM_0 + 3*200, x
        inx
        cpx #200
    bne clearLoop

    // draw picture
    lda #<(SCREEN_MEM_0 + 40*ES_TOP + ES_LEFT)
    sta picLoop.address
    lda #>(SCREEN_MEM_0 + 40*ES_TOP + ES_LEFT)
    sta picLoop.address + 1
    lda #37
    sta picLoop.value

    ldx #0
    ldy #0
    picLoop: {
        lda value:#0
        sta address:$ffff, x
        inc value
        inx
        cpx #14
        bne picLoop
        ldx #0
        clc
        lda address
        adc #40
        sta address
        lda address + 1
        adc #0
        sta address + 1
        iny
        cpy #6
        bne picLoop
    }

    rts
}

aux_cleanBottomPart: {
    ldx #0
    lda #0
    loop:
        sta SCREEN_MEM_1 + 20*40, x
        inx
        cpx #4*40
    bne loop
    rts
}
