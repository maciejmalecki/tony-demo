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
        // --->
        and #%00011111
        eor #%00011111
        tax
        and #%00000001 // up
        beq !+
            lda physPlayerY
            sec
            sbc #1
            sta actorPlayerNextY
        !:
        txa
        and #%00000010 // down
        beq !+
            lda physPlayerY
            clc
            adc #1
            sta actorPlayerNextY
        !:
        txa 
        and #%00000100 // left
        beq !+
            sec
            lda physPlayerX
            sbc #1
            sta actorPlayerNextX
            lda physPlayerX + 1
            sbc #0
            sta actorPlayerNextX + 1
        !:
        txa 
        and #%00001000 // right
        beq !+
            clc
            lda physPlayerX
            adc #1
            sta actorPlayerNextX
            lda physPlayerX + 1
            adc #0
            sta actorPlayerNextX + 1
        !:

    waitForRaster:
        lda c64lib.RASTER
        cmp #60
    bne waitForRaster


        jsr physUpdateActorPosition
        jsr updatePlayerPosition
