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

.macro seq_setUp(delay, count, callBack, endCallBack) {
    seq_setUpExt(delay, count, callBack, endCallBack, false)
}

.macro seq_setUpExt(delay, count, callBack, endCallBack, recursive) {
    .if(!recursive) {
        jsr _seq_finalize
    }
    lda #<callBack
    sta _seq_callBack
    lda #>callBack
    sta _seq_callBack + 1

    lda #<endCallBack
    sta _seq_endCallback
    lda #>endCallBack
    sta _seq_endCallback + 1

    lda #delay
    sta _seq_delay
    sta _seq_delayCounter

    lda #count
    sta _seq_count
}

_seq_finalize: {
    lda _seq_count
    beq !+
        jsr jump
        jump: jmp (_seq_endCallback)
    !:
    lda #0
    sta _seq_count
    rts
}

seq_play: {
    lda _seq_count
    beq end // inactive
    dec _seq_delayCounter
    bne end
    lda _seq_delay
    sta _seq_delayCounter
    jsr _callback // delay reached, do callback
    dec _seq_count
    bne end
    jsr _end_callback // end of sequence reached, do callback
    end: rts
    _callback:      jmp (_seq_callBack)
    _end_callback:  jmp (_seq_endCallback)
}

// vars
_seq_delay:         .byte 0
_seq_delayCounter:  .byte 0
_seq_count:         .byte 0

// workaround, placed in extended 0 page to be safe from 6502 page wrap bug in JMP (xxxx)
.label _seq_callBack = $013F
.label _seq_endCallback = $0141

.print "_seq_endCallBack address = $" + toHexString(_seq_endCallback)

_seq_filler:        .byte 0
