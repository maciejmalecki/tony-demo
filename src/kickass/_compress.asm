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
#importonce 

.macro compressRLE3(binaryData, magic) {
    .var repetitionCount = 0
    .var lastByte = 256
    .var crunchedLength = 0
    .for(var i = 0; i < binaryData.getSize(); i++) {
        .var currentByte = binaryData.get(i)
        .if (currentByte == lastByte && repetitionCount < $FF) {
            .eval repetitionCount++
        } else {
            .if (lastByte != 256) {
                .if (repetitionCount == 1 && lastByte != magic) {
                    .byte lastByte
                    .eval crunchedLength++
                } else {
                    .if (repetitionCount == 2 && lastByte != magic) {
                        .byte lastByte, lastByte
                        .eval crunchedLength = crunchedLength + 2
                    } else {
                        .byte magic, lastByte, repetitionCount
                        .eval crunchedLength = crunchedLength + 3
                    }
                }
            }
            .eval lastByte = currentByte
            .eval repetitionCount = 1
        }
    }
    .if (repetitionCount == 1 && lastByte != magic) {
        .byte lastByte
        .eval crunchedLength++
    } else {
       .if (repetitionCount == 2 && lastByte != magic) {
            .byte lastByte, lastByte
            .eval crunchedLength = crunchedLength + 2
        } else {
            .byte magic, lastByte, repetitionCount
            .eval crunchedLength = crunchedLength + 3
        }
    }
    .byte magic, magic, 0 // end mark
    .eval crunchedLength = crunchedLength + 3
    .print "Crunched RLE3 from " + binaryData.getSize() + " to " + crunchedLength + " (" + round((crunchedLength/binaryData.getSize())*100) + "%)"
}

/*
 * Stack:
 *   source address (2 bytes)
 *   dest address (2 bytes)
 */
.macro decompressRLE3(magic) {

    c64lib_invokeStackBegin(returnPtr)
    c64lib_pullParamW(destination)
    c64lib_pullParamW(source)
    c64lib_invokeStackEnd(returnPtr)

    nextSequence:
        jsr loadSource // A - value or magic
        cpx #magic
        beq !+
            txa
            ldx #1
            jmp decrunch
        !:
        jsr loadSource
        txa // A - value
        jsr loadSource // X - repetitions
        cpx #0
        beq end // end mark
        decrunch:
            sta destination:$ffff
            inc destination
            bne !+
                inc destination + 1
            !:
            dex
        bne decrunch
    jmp nextSequence

    end:
    rts
    loadSource:
        ldx source:$ffff
        inc source
        bne !+
            inc source + 1
        !:
        rts
    // locals
    returnPtr: .word 0
}