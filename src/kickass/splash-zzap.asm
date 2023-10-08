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

#import "_loader.asm"
#import "common/lib/invoke-global.asm"
#import "chipset/lib/vic2-global.asm"
#import "chipset/lib/cia-global.asm"
#import "chipset/lib/mos6510-global.asm"

.label BITMAP_LOCATION = $E000
.label BITMAP_LOCATION_ENC = %00001000
.label SCREEN_MEM_0 = $DC00
.label SCREEN_MEM_0_ENC = %01110000

*=LDR_SPLASH_START_ADDRESS "Splashscreen"

.macro loadResource(suffix) {
    .var name = "zzap"
    .if(cmdLineVars.containsKey("variant")) {
        .eval name = cmdLineVars.get("variant")
    }
    .import binary "splash-screen-" + name + "." + suffix + ".bin"
}

.function colors() {
    .var colors = LIGHT_GREY * 16 + BLACK
    .return colors
}

jsr init
jsr initGraphic
jsr displayImage

loop: 
    // scan for space
    lda #0
    sta c64lib.CIA1_DATA_DIR_B
    lda #$ff
    sta c64lib.CIA1_DATA_DIR_A
    lda #%01111111
    sta c64lib.CIA1_DATA_PORT_A
    lda c64lib.CIA1_DATA_PORT_B
    and #%00010000
    eor #%00010000
    bne end
    // scan for joy A fire
    lda #0
    sta c64lib.CIA1_DATA_DIR_A
    lda c64lib.CIA1_DATA_PORT_A
    eor #$ff
    and #%00010000
    cmp #%00010000
    beq end
    jmp loop
end:
rts

init: {
    sei
    c64lib_disableCIAInterrupts()
    c64lib_configureMemory(c64lib.RAM_IO_RAM)
    c64lib_setVICBank(0)
    cli

    rts
}

initGraphic: {
    lda #BLACK
    sta c64lib.BORDER_COL
    lda #%00001000
    sta c64lib.CONTROL_2
    lda #(SCREEN_MEM_0_ENC + BITMAP_LOCATION_ENC)
    sta c64lib.MEMORY_CONTROL
    rts
}

setColors: {
    ldx #0
    loop:
        sta SCREEN_MEM_0, x
        sta SCREEN_MEM_0 + 250, x
        sta SCREEN_MEM_0 + 500, x
        sta SCREEN_MEM_0 + 750, x
        inx
        cpx #250
    bne loop
    rts
}

displayImage: {
    ldy #0
    outerLoop:
        sty outerY
        ldy #0
        innerLoop:
            jsr ldaMapLoByte
            jsr ldxMapHiByte
            jsr setCharsetOffset
            jsr ldaCharsetOffsetLo
            sta ldaCharsetByte.address
            jsr ldaCharsetOffsetHi
            sta ldaCharsetByte.address + 1

            ldx #0
            copyCharLoop:
                jsr ldaCharsetByte
                jsr staBitmapByte
                inx
                cpx #8
            bne copyCharLoop
            jsr incBitmapPtr
            iny
            cpy #4
        bne innerLoop
        ldy outerY
        iny
        cpy #250
    bne outerLoop

    sei
    c64lib_configureMemory(c64lib.RAM_RAM_RAM)
    lda #colors()
    jsr setColors
    c64lib_configureMemory(c64lib.RAM_IO_RAM)
    sei
    lda #%00111011
    sta c64lib.CONTROL_1

    rts

    outerY: .byte 0

    ldaMapLoByte: {
        lda address:mapLo
        inc address
        bne !+
            inc address + 1
        !:
        rts
    }
    ldxMapHiByte: {
        ldx address:mapHi
        inc address
        bne !+
            inc address + 1
        !:
        rts
    }
    setCharsetOffset: {
        sta storeA
        clc
        adc #<charsetOffsets.lo
        sta ldaCharsetOffsetLo.address
        txa
        adc #>charsetOffsets.lo
        sta ldaCharsetOffsetLo.address + 1
        clc
        lda storeA
        adc #<charsetOffsets.hi
        sta ldaCharsetOffsetHi.address
        txa
        adc #>charsetOffsets.hi
        sta ldaCharsetOffsetHi.address + 1
        rts
        storeA: .byte 0
    }
    ldaCharsetOffsetLo: {
        lda address:$ffff
        rts
    }
    ldaCharsetOffsetHi: {
        lda address:$ffff
        rts
    }
    ldaCharsetByte: {
        lda address:$FFFF, x
        rts
    }
    staBitmapByte: {
        sta address:BITMAP_LOCATION, x
        rts
    }
    incBitmapPtr: {
        clc
        lda staBitmapByte.address
        adc #8
        sta staBitmapByte.address
        lda staBitmapByte.address + 1
        adc #0
        sta staBitmapByte.address + 1
        rts
    }
}

charset:
    loadResource("charset")
    // .import binary "splash-screen-zzap.charset.bin"
charsetEnd:
mapLo:
    loadResource("maplo")
    // .import binary "splash-screen-zzap.maplo.bin"
mapLoEnd:
mapHi:
    loadResource("maphi")
    // .import binary "splash-screen-zzap.maphi.bin"
mapHiEnd:
charsetOffsets: .lohifill (charsetEnd - charset)/8, charset + i*8
charsetOffsetsEnd:

.print (charsetEnd - charset)/8
.print (charsetOffsetsEnd - charsetOffsets)
