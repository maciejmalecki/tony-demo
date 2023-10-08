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
// #define VISUAL_DEBUG


#import "_loader.asm"
#import "_zero-page.asm"
#import "_load-util.asm"
#import "common/lib/invoke-global.asm"
#import "chipset/lib/vic2-global.asm"
#import "chipset/lib/cia-global.asm"
#import "chipset/lib/mos6510-global.asm"
#import "copper64/lib/copper64-global.asm"

/* VIC bank memory map

    $C000 - start

    $DC00 - BITMAP_SCREEN_MEM   d07 = %0111
    $E000 - start of bitmap area
    $E640 - end of upper bitmap

    $E800 - CHARSET_MEM         d05 = %101
    $EB00 - SCREEN_MEM_0        d11 = %1011
    $F000 - SCREEN_MEM_1        d12 = %1100
    $F400 - BITMAP_SCREEN_MEM   d13 = %1101

    $F880 - shall be cleared
    $F9C0 - begin of lower bitmap
    $FFFF - end

*/

.label MUSIC_LOCATION = $E000

.label BITMAP_LOCATION = $C000
.label BITMAP_LOCATION_ENC = 0
.label BITMAP_BOTTOM_PART_OFFSET = 15*40*8
.label BOTTOM_CLEARED_AREA = BITMAP_LOCATION + 4*40*8 + BITMAP_BOTTOM_PART_OFFSET

.label BITMAP_SCREEN_MEM = $FC00
.label BITMAP_SCREEN_MEM_ENC = %11110000
.label SCREEN_MEM_0 = $C800
.label SCREEN_MEM_0_ENC = %00100000
.label SCREEN_MEM_1 = $CC00
.label SCREEN_MEM_1_ENC = %00110000
.label CHARSET_MEM = $D000
.label CHARSET_MEM_ENC = %00000100

.label TEXT_COLOR = LIGHT_GREY
.label BG_COLOR = BLACK
.label DELAY = 4
.label DELAY_NTSC = 5

.label TOP_ROW = 5
.label BOTTOM_ROW = 18

.label INITIAL_TOP_FOR_0 = SCREEN_MEM_0 + 40*TOP_ROW
.label INITIAL_TOP_FOR_1 = SCREEN_MEM_1 + 40*TOP_ROW
.label NEW_LINE_ADDRESS_0 = SCREEN_MEM_0 + 40*BOTTOM_ROW
.label NEW_LINE_ADDRESS_1 = SCREEN_MEM_1 + 40*BOTTOM_ROW

.label EOL = $FF
.label EOT = $FE
.label SPACE = 32

.label INIT_SCROLL = 7

.label SCROLL_1 = 5
.label SCROLL_2 = 4
.label FETCH_NEXT_LINE = 6
.label SWITCH_PAGE = 3

// .var music = LoadSid("funktest.sid")
.var music = LoadSid("tonyintroe000_1.sid")

*=LDR_INTRO_START_ADDRESS "Intro"

// *= $0801 "Basic Upstart"
// BasicUpstart(start)
// *= $0810 "Main"

start:
    jmp skip
    copperList: // must fit into a single page
        vscroll: c64lib_copperEntry(90/*50+5*8*/, c64lib.IRQH_VSCROLL, %10011000 + INIT_SCROLL, (SCREEN_MEM_0_ENC + CHARSET_MEM_ENC))
        c64lib_copperEntry(98, c64lib.IRQH_BG_RASTER_BAR, <fadeIn, >fadeIn)
        c64lib_copperEntry(120, c64lib.IRQH_JSR, <playMusic, >playMusic)
        c64lib_copperEntry(195, c64lib.IRQH_BG_RASTER_BAR, <fadeOut, >fadeOut)
        vscroll2: c64lib_copperEntry(202/*50+19*8*/, c64lib.IRQH_VSCROLL, %10111011, (BITMAP_SCREEN_MEM_ENC + BITMAP_LOCATION_ENC))
        c64lib_copperEntry(230, c64lib.IRQH_JSR, <doEachFrameTop, >doEachFrameTop)
        c64lib_copperLoop()
    copperListEnd:

    skip:
    jsr detectNTSC

    jsr init

    sei
    c64lib_configureMemory(c64lib.RAM_RAM_RAM)
    jsr unpack
    jsr displayImage
    c64lib_configureMemory(c64lib.RAM_IO_RAM)
    cli

    jsr initGraphic
    jsr switchPage
    jsr initMusic

    lda #<copperList
    sta COPPER_LIST_ADDR
    lda #>copperList
    sta COPPER_LIST_ADDR + 1
    jsr startCopper

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
    jsr stopCopper
    lda #0
    sta $D404
    sta $D40B
    sta $D412
    rts

init: {
    sei
    c64lib_disableCIAInterrupts()
    c64lib_configureMemory(c64lib.RAM_IO_RAM)
    c64lib_setVICBank(0)
    cli

    rts
}

unpack: {
    c64lib_pushParamW(fontBegin)
    c64lib_pushParamW(CHARSET_MEM)
    c64lib_pushParamW(fontEnd - fontBegin)
    jsr copyLargeMemForward

    c64lib_pushParamW(musicBegin)
    c64lib_pushParamW(MUSIC_LOCATION)
    c64lib_pushParamW(musicEnd - musicBegin)
    jsr copyLargeMemForward

    ldx #0
    lda #0
    !:
        sta BOTTOM_CLEARED_AREA, x
        sta BOTTOM_CLEARED_AREA + 160, x
        inx
        cpx #160
    bne !-

    rts
}

initGraphic: {
    lda #BLACK
    sta c64lib.BORDER_COL
    lda #TEXT_COLOR
    sta c64lib.BG_COL_0
    lda #%00001000
    sta c64lib.CONTROL_2
    lda #(SCREEN_MEM_0_ENC + CHARSET_MEM_ENC)
    sta c64lib.MEMORY_CONTROL
    lda #%10010011
    sta c64lib.CONTROL_1

    // set up color and screen ram
    ldx #0
    loop:
        lda #BG_COLOR
        sta c64lib.COLOR_RAM, x
        sta c64lib.COLOR_RAM + 250, x
        sta c64lib.COLOR_RAM + 500, x
        sta c64lib.COLOR_RAM + 750, x

        lda #SPACE
        sta SCREEN_MEM_0, x
        sta SCREEN_MEM_0 + 250, x
        sta SCREEN_MEM_0 + 500, x
        sta SCREEN_MEM_0 + 750, x

        sta SCREEN_MEM_1, x
        sta SCREEN_MEM_1 + 250, x
        sta SCREEN_MEM_1 + 500, x
        sta SCREEN_MEM_1 + 750, x

        lda #(TEXT_COLOR*16 + BG_COLOR)
        sta BITMAP_SCREEN_MEM, x
        sta BITMAP_SCREEN_MEM + 250, x
        sta BITMAP_SCREEN_MEM + 500, x
        sta BITMAP_SCREEN_MEM + 750, x

        inx
        cpx #250
    bne loop
    rts
}

initMusic: {
    lda #0
    ldx #0
    ldy #0
    jsr music.init
}

playMusic: {
    lda ntscFlag
    beq doPlay
        ldx ntscCounter
        inx
        stx ntscCounter
        cpx #6
        bne doPlay
        ldx #0
        stx ntscCounter
        rts
    doPlay:
        jsr music.play
    rts
}

setNTSC: {
    lda #1
    sta ntscFlag
    lda #c64lib.IRQH_VSCROLL_NTSC
    sta vscroll
    sta vscroll2
    lda #DELAY_NTSC
    sta doEachFrameTop.delay
    rts
}
detectNTSC: {
    lda #0
    sta ntscFlag
    c64lib_detectNtsc(0, setNTSC)
    rts
}

doEachFrameTop: {
    c64lib_debugBorderStart()

    inc delayCounter
    lda delayCounter
    cmp delay: #DELAY
    bne end
    lda #0
    sta delayCounter

    lda scrollY // TODO not needed
    cmp #SCROLL_2
    bne !+
        jsr shiftUp
        jmp cont
    !:
    cmp #SCROLL_1
    bne !+
        jsr shiftUp
        jmp cont
    !:
    cmp #FETCH_NEXT_LINE
    bne !+
        jsr fetchNextLine
        jmp cont
    !:
    lda scrollY
    cmp #SWITCH_PAGE
    bne !+
        jsr switchPage
    !:
    cont:
        lda vscroll + 2
        and #%11111000
        ora scrollY
        sta vscroll + 2

        dec scrollY
        lda scrollY
        cmp #$ff
        bne !+
            lda #7
            sta scrollY
        !:
    end:


    c64lib_debugBorderEnd()

    rts
}

switchPage: {
    inc phase
    lda phase
    and #1
    beq zeroToOne
    oneToZero:
        lda #<NEW_LINE_ADDRESS_0
        sta fetchNextLine.address0
        lda #>NEW_LINE_ADDRESS_0
        sta fetchNextLine.address0 + 1
        lda #<(NEW_LINE_ADDRESS_0/* - 1*/)
        sta fetchNextLine.address1
        lda #>(NEW_LINE_ADDRESS_0/* - 1*/)
        sta fetchNextLine.address1 + 1

        lda #<(INITIAL_TOP_FOR_1 + 40)
        sta shiftUp.address0
        lda #>(INITIAL_TOP_FOR_1 + 40)
        sta shiftUp.address0 + 1
        lda #<INITIAL_TOP_FOR_0
        sta shiftUp.address1
        lda #>INITIAL_TOP_FOR_0
        sta shiftUp.address1 + 1

        lda vscroll + 3
        and #%00001111
        ora #SCREEN_MEM_1_ENC
        sta vscroll + 3
        rts
    zeroToOne:
        lda #<NEW_LINE_ADDRESS_1
        sta fetchNextLine.address0
        lda #>NEW_LINE_ADDRESS_1
        sta fetchNextLine.address0 + 1
        lda #<(NEW_LINE_ADDRESS_1/* - 1*/)
        sta fetchNextLine.address1
        lda #>(NEW_LINE_ADDRESS_1/* - 1*/)
        sta fetchNextLine.address1 + 1

        lda #<(INITIAL_TOP_FOR_0 + 40)
        sta shiftUp.address0
        lda #>(INITIAL_TOP_FOR_0 + 40)
        sta shiftUp.address0 + 1
        lda #<INITIAL_TOP_FOR_1
        sta shiftUp.address1
        lda #>INITIAL_TOP_FOR_1
        sta shiftUp.address1 + 1

        lda vscroll + 3
        and #%00001111
        ora #SCREEN_MEM_0_ENC
        sta vscroll + 3

        rts
}

shiftUp: {
    cmp #SCROLL_2
    beq !+
        // #0
        lda #(BOTTOM_ROW - 6)
        sta topRow
        lda #BOTTOM_ROW
        sta bottomRow
        jmp doShiftUp
    !:
        // #1
        lda #TOP_ROW
        sta topRow
        lda #(BOTTOM_ROW - 6)
        sta bottomRow
    doShiftUp:

    ldy topRow:#TOP_ROW
    loop:
        ldx #0
        !:
            lda address0:$ffff + 40, x // fixme
            sta address1:$ffff, x
            inx
            cpx #40
        bne !-

        clc
        lda address0
        adc #40
        sta address0
        lda address0 + 1
        adc #0
        sta address0 + 1

        clc
        lda address1
        adc #40
        sta address1
        lda address1 + 1
        adc #0
        sta address1 + 1

        iny
        cpy bottomRow:#BOTTOM_ROW
    bne loop
    rts
}

fetchNextLine: {
    lda textDataPtr
    sta source
    lda textDataPtr + 1
    sta source + 1
    ldx #0
    loop:
        lda source:$FFFF, x
        cmp #EOL
        beq eol
        cmp #EOT
        beq eot
        sta address0: $ffff, x
        inx
    jmp loop
    rts
    eol:
        clc
        lda textDataPtr
        inx
        stx offset
        dex
        adc offset:#0
        sta textDataPtr
        lda textDataPtr + 1
        adc #0
        sta textDataPtr + 1
        jmp fillTillEnd
    eot:
        lda #<textData
        sta textDataPtr
        lda #>textData
        sta textDataPtr + 1
        jmp fillTillEnd
    fillTillEnd:
        lda #SPACE
        cpx #40
        beq quit
        !:
            sta address1: $ffff, x
            inx
            cpx #41
        bne !-
        quit: rts
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
        cpy #50
        beq goToBottom
        cpy #100
    bne outerLoop

    rts

    goToBottom:
        clc
        lda staBitmapByte.address
        adc #<BITMAP_BOTTOM_PART_OFFSET
        sta staBitmapByte.address
        lda staBitmapByte.address + 1
        adc #>BITMAP_BOTTOM_PART_OFFSET
        sta staBitmapByte.address + 1
        jmp outerLoop

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

copyLargeMemForward:
#import "common/lib/sub/copy-large-mem-forward.asm"

startCopper: c64lib_startCopper(COPPER_LIST_ADDR, COPPER_LIST_PTR, List().add(c64lib.IRQH_JSR, c64lib.IRQH_VSCROLL, c64lib.IRQH_VSCROLL_NTSC, c64lib.IRQH_BG_RASTER_BAR).lock())
stopCopper: c64lib_stopCopper()

fadeIn:         .byte BLACK, DARK_GREY, GREY, LIGHT_GREY, $ff
fadeOut:        .byte GREY, DARK_GREY, BLACK, $ff
phase:          .byte 0
textDataPtr:    .word textData
scrollY:        .byte INIT_SCROLL
delayCounter:   .byte 0
ntscCounter:    .byte 0

// data
.macro textNS(value) {
    .if (value.size() > 40) {
        .error "Text " + value + " is too long: " + value.size() + " characters"
    }
    .text value
    .byte EOL
}

.macro text(value) {
    textNS(value)
    .text ""
    .byte EOL
}

.macro textCNS(value) {
    .if (value.size() > 40) {
        .error "Text " + value + " is too long: " + value.size() + " characters"
    }
    .for (var i = 0; i < (40 - value.size())/2; i++) {
        .text " "
    }
    .text value
    .byte EOL
}

.macro textC(value) {
    textCNS(value)
    .text ""
    .byte EOL
}


textData:
    
    textCNS("Tony: Born for Adventure")
    textC("------------------------")
    text("")
    textC("This game is a tribute ")
    textC("to the legendary Tony Halik.")
    text("")
    text("Tony Halik (24 January 1921 -")
    text("- 23 May 1998) was a Polish traveller")
    text("and explorer.")
    text("")
    text("Halik was born in Torun, Poland.")
    text("During the Second World War, he joined")
    text("the French Resistance. He was awarded")
    text("the French War Cross for his actions.")
    text("")
    text("After the war, he worked as a correspon+")
    text("dent for NBC for over thirty years. He")
    text("made over four hundred documentary")
    text("films, wrote thirteen books and many")
    text("articles for the press.")
    text("")
    text("")
    textC("----")
    text("I was woken from my sleep by the sound")
    text("of a telephone, which I hadn't heard")
    text("for a long time. I had just returned")
    text("from the ancient city of Tula, where I")
    text("had been exploring ancient Toltec")
    text("structures. I instinctively picked up")
    text("the receiver and heard Margaret's sweet,")
    text("familiar voice.")
    text("")
    text(@"\"Tony, are you going to sleep all day?\"")
    text("")
    text(@"\"What time is it?\", I asked.")
    text("")
    text(@"\"We've been waiting for you in")
    text(@"the office for half an hour.\"")
    text("")
    text(@"\"Okay, I'll be right there. The plane")
    text("was late yesterday because of the storms")
    text(@"over Mexico. I'm on my way.\"")
    text("")
    text(@"\"Okay, Tony. I'm waiting. I'll make")
    text(@"your favourite coffee.\"")
    text("")
    text("The editors of the Washington News")
    text("always eagerly awaited my return from my")
    text("expeditions as a reporter and treasure")
    text("hunter, gathering information about")
    text("fascinating ancient sites. Describing")
    text("my adventures brought readers closer to")
    text("unknown civilizations.")
    text("")
    text(@"\"You're Tony, after all\" - the editor+")
    text("in+chief greeted me with a sincere")
    text("smile, and an ink+stained hand.")
    text("")
    text(@"\"Hello, Steve. I have some great")
    text("material for you on Toltec rituals.")
    text(@"You will love it.\"")
    text("")
    text(@"\"Okay, but there's some urgency, Tony\"")
    text("Steve arched his bushy eyebrows as he")
    text("spoke. I knew it was urgent.")
    text("")
    text(@"\"Your coffee, I hope you are well")
    text(@"rested before your new trip?\"")
    text("Margaret asked flirtatiously.")
    text("")
    text(@"\"A new expedition? I returned from")
    text(@"Mexico last night.\"")
    text("")
    text(@"\"Yes, Tony. There's no time to rest.")
    text("Other papers are sending their")
    text("reporters and we need to get this")
    text(@"material first\", Steve's voice sounded")
    text("like a father's command, full of firm+")
    text("ness and a friendly note of encourage+")
    text("ment.")
    text("")
    text("I love the coffee that Margaret makes.")
    text("I always associated the smell of coffee")
    text("and ink with home, because the newsroom")
    text("was my home. It was where I came back")
    text("from my travels and shared my")
    text("adventures.")
    text("")
    text(@"\"What is it, Steve?\"")
    text("")
    text(@"\"Do you know the story of how Miguel")
    text(@"discovered Montezuma I's treasure?\"")
    text("")
    text(@"\"Yes, everyone knows, although few")
    text(@"believe in the truth of these reports.\"")
    text("")
    text(@"\"That's the point. The director of")
    text("the Natural History Museum has")
    text("contacted Miguel, but he is more")
    text("interested in telling his story over")
    text("tequila than providing scientific")
    text("proof that he has indeed discovered")
    text("the Aztec ruler's treasure. Our readers")
    text(@"want proof too.\"")
    text("")
    text(@"\"Steve, I got back from Mesoamerica")
    text(@"yesterday. Should I fly back to Mexico?\"")
    text("")
    text(@"\"You're the best, Tony\", Margaret said,")
    text("handing me the envelope and winking")
    text("gently in my direction.")
    text("")
    text(@"\"The envelope contains a plane ticket")
    text(@"and some cash.\"")
    text("")
    text(@"\"When should I start a new journey?\"")
    text("")
    text(@"\"You'll have time to drink your coffee,")
    text(@"Tony\", Steve said, patting me on the")
    text("shoulder.")


    .for(var i = 0; i < 5; i ++)
    {
        text("")
    }
    

    textCNS("Tony: Born for Adventure")
    textC("------------------------")
    text("")
    textC("is brought to you by")
    textC("Monochrome Productions")
    text("")
    textC("Code")
    textC(@"Maciej Ma\$1Cecki")
    text("")
    textC("Concept & Graphics")
    textC(@"Rafa\$1C Dudek")
    text("")
    textC("Music")
    textC(@"Sami \"Mutetus\" Juntunen")
    text("")
    textC("Testing")
    textC("Federico Sesler")
    textC(@"Rafal \"Yogi\" Wypych")
    textC("Vladimir Jankovic")
    textC("Krzysztof Niedzwiecki")
    text("")
    textC("Special thanks to")
    textC(@"David \"Jazzcat\" Simmons")
    textC("Adam Szczepanski")
    text("")
    textC("Maciek's thanks to")
    textC(@"my girls Ania, Ola and Zuza \$40")
    textC("Komoda & Amiga plus crew")
    textC(@"Pawe\$1C Tukatsch")
    textC("Vladimir Jankovic")
    textC("Carrion, Gordian and Hornet")
    textC(@"Krzys and Olga \$25\$24")
    textC(@"... and Piotr \$1E\$1E\$1F")
    text("")
    text("")
    text("")
    text("")
    textC("---   # 2023 Monochrome   ---")
    text("")
    text("")
    text("")
    text("")
    textC("Tony Halik was here")
    
    .for(var i = TOP_ROW; i < BOTTOM_ROW; i++) {
        textNS("")
    }
    .byte EOT


fontBegin:
    loadNegated("intro-font.charset.bin")
fontEnd:
charset:
    .import binary "intro.charset.bin"
charsetEnd:
mapLo:
    .import binary "intro.maplo.bin"
mapLoEnd:
mapHi:
    .import binary "intro.maphi.bin"
mapHiEnd:
charsetOffsets: .lohifill (charsetEnd - charset)/8, charset + i*8
charsetOffsetsEnd:
musicBegin:
    .fill music.size, music.getData(i)
    // .fill 6050 - music.size, random()*255
musicEnd:


introEnd:

.function formatRange(title, from, to) {
    .return title + " = $" + toHexString(from) + " - $" + toHexString(to)
}


.print("Intro size = " + (introEnd - start) + " bytes")
.print("Music size = " + (musicEnd - musicBegin)  + " bytes")
.print (charsetEnd - charset)/8
.print (charsetOffsetsEnd - charsetOffsets)
.print "Bottom cleared area = $" + toHexString(BOTTOM_CLEARED_AREA)

.print formatRange("Bitmap:", BITMAP_LOCATION, BITMAP_LOCATION + 8*1024 - 1)
.print formatRange("Screen 0:", SCREEN_MEM_0, SCREEN_MEM_0 + 1024 - 1)
.print formatRange("Screen 1:", SCREEN_MEM_1, SCREEN_MEM_1 + 1024 - 1)
.print formatRange("Charset:", CHARSET_MEM, CHARSET_MEM + fontEnd - fontBegin)
.print formatRange("Clean up area:", BOTTOM_CLEARED_AREA, BOTTOM_CLEARED_AREA + 40*8 - 1)
.print formatRange("Music:", MUSIC_LOCATION, $FEFF)
.print formatRange("Bitmap screen:", BITMAP_SCREEN_MEM, BITMAP_SCREEN_MEM + 1024 - 1)
.print formatRange("Intro overall:", start, introEnd)
.print formatRange("Copper list:", copperList, copperListEnd)
