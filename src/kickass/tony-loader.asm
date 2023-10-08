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
#import "chipset/lib/vic2-global.asm"
#import "chipset/lib/cia-global.asm"
#import "chipset/lib/mos6510-global.asm"
#import "common/lib/invoke-global.asm"

.var tonyFile = LoadBinary("tony.prg")
.var tonyZFile = LoadBinary("tony.z.bin")
.var splashZFile = LoadBinary("splash-zzap.z.bin")

.assert "Main unpacked size mismatch", LDR_MAIN_UNPACK_SIZE, tonyFile.getSize()
.assert "Main packed size mismatch", LDR_MAIN_PACKED_SIZE, tonyZFile.getSize()
.assert "Splash packed size mismatch", LDR_SPLASH_PACKED_SIZE, splashZFile.getSize()

.file [name="./tony-loader.prg", segments="Code", modify="BasicUpstart", _start=$0810]
.disk [filename="./tony.d64", name="TONY", id="10"]
{
    [name="TONY BORN FOR   ", type="prg", segments="BasicUpstart, Code"],
    [name="       ADVENTURE", type="del"],
    [name="                ", type="del"],

	[name=(@"\$20\$20\$20\$20\$20\$A8\$A6\$A6\$A6\$20\$20\$20\$20\$20\$20\$20"), type="del"],
	[name=(@"\$20\$20\$20\$20\$A8\$A6\$A6\$A6\$A6\$A6\$20\$20\$20\$20\$20\$20"), type="del"],
	[name=(@"\$20\$20\$20\$20\$A6\$D2\$C6\$C3\$C3\$C3\$C3\$C4\$C4\$C5\$C5\$20"), type="del"],
	[name=(@"\$20\$C6\$C4\$F7\$A3\$20\$A4\$C6\$C3\$C4\$C3\$C6\$20\$A4\$CE\$20"), type="del"],
	[name=(@"\$20\$C4\$C6\$C6\$D2\$D2\$2D\$2D\$D6\$D6\$2D\$C0\$C5\$20\$20\$20"), type="del"],
	[name=(@"\$20\$20\$20\$20\$20\$2D\$2D\$D6\$D7\$D7\$D6\$2D\$20\$20\$20\$20"), type="del"],
	[name=(@"\$20\$20\$20\$20\$20\$D6\$D6\$D6\$D6\$D6\$D6\$2D\$20\$20\$20\$20"), type="del"],
	[name=(@"\$20\$20\$20\$20\$20\$20\$D6\$CA\$C3\$D6\$D6\$20\$20\$20\$20\$20"), type="del"],
	[name=(@"\$20\$20\$20\$20\$20\$20\$20\$D6\$D6\$D6\$20\$20\$20\$20\$20\$20"), type="del"],
	[name=(@"\$20\$20\$20\$20\$D6\$2D\$2D\$2D\$2D\$2D\$2D\$20\$20\$20\$20\$20"), type="del"],
	[name=(@"\$20\$20\$20\$D6\$D6\$2D\$D6\$D6\$D6\$D6\$2D\$D6\$D6\$20\$20\$20"), type="del"],
	[name=(@"\$20\$20\$D6\$D6\$20\$20\$20\$D6\$D6\$D6\$D6\$2D\$D6\$D6\$20\$20"), type="del"],
	[name=(@"\$20\$20\$20\$D6\$D6\$D6\$20\$2D\$2D\$2D\$2D\$20\$20\$20\$20\$20"), type="del"],
	[name=(@"\$20\$20\$20\$20\$D6\$D6\$20\$2D\$D6\$D6\$D6\$20\$20\$20\$20\$20"), type="del"],
	[name=(@"\$20\$20\$20\$20\$20\$20\$20\$D6\$D6\$2D\$D6\$20\$20\$20\$20\$20"), type="del"],
	[name=(@"    \$20\$20\$20\$D6\$20\$20\$D6\$D6\$20\$20\$20\$20"), type="del"],
	[name=(@"VOID\$20\$20\$20\$D6\$D6\$20\$20\$D6\$D6\$20\$20\$20\$20"), type="del"],
    [name=" '23            ", type="del"]
}
.segmentdef BasicUpstart [start=$0801]
.segmentdef Code [start=$0810]
.segment BasicUpstart
    BasicUpstart(start)
.segment Code

start:
    jmp continue
    copyMain:
        sei
        c64lib_configureMemory(c64lib.RAM_RAM_RAM)
        cli
        c64lib_pushParamW(LDR_MAIN_UNPACK_START_ADDRESS)
        c64lib_pushParamW(LDR_MAIN_START_ADDRESS)
        c64lib_pushParamW(LDR_MAIN_UNPACK_SIZE)
        jsr copyLargeMemBackward
        sei
        c64lib_configureMemory(c64lib.RAM_IO_RAM)
        cli
        jmp LDR_MAIN_START_ADDRESS
    copyLargeMemBackward:
        #import "common/lib/sub/copy-large-mem-backward.asm"
continue:
    jsr blankScreen
    lda #BLACK
    sta c64lib.BORDER_COL
    sta c64lib.BG_COL_0

    sei
    c64lib_disableCIAInterrupts()
    c64lib_configureMemory(c64lib.RAM_RAM_RAM)
    cli
    cld

    // SPLASH SCREEN!
    lda #<splashScreenEnd
    ldx #>splashScreenEnd
    jsr decrunch

    jsr LDR_SPLASH_START_ADDRESS

    // INTRO
    jsr blankScreen
    lda #<introEnd
    ldx #>introEnd
    jsr decrunch

    jsr LDR_INTRO_START_ADDRESS

    // MAIN GAME

    jsr blankScreen
    sei
    c64lib_configureMemory(c64lib.RAM_RAM_RAM)
    cli

    lda #<mainGameEnd
    ldx #>mainGameEnd
    jsr decrunch

    sei
    c64lib_configureMemory(c64lib.RAM_IO_RAM)
    cli

    lda #DARK_GREY
    sta c64lib.BORDER_COL

    jmp copyMain

blankScreen: {
    lda c64lib.CONTROL_1
    and #%11101111
    sta c64lib.CONTROL_1
    rts
}

decrunch:
    sta exod_get_crunched_byte.address
    stx exod_get_crunched_byte.address + 1
    jmp exod_decrunch

    exod_get_crunched_byte: {
        lda address
        bne !+
            lda c64lib.MOS_6510_IO
            sta ioValue
            c64lib_configureMemory(c64lib.RAM_IO_RAM)
            inc c64lib.BORDER_COL
            dec address + 1
            dec c64lib.BORDER_COL
            lda ioValue:#0
            sta c64lib.MOS_6510_IO
        !:
        dec address
        lda address:$ffff               
        rts                  
    }   
#import "exodecrunch.asm"


* = LDR_MAIN_BEGIN - 2 "MainGame"
mainGame:
.import binary "tony.z.bin"
mainGameEnd:

* = LDR_INTRO_BEGIN - 10 "Intro"
intro:
.import binary "intro.z.bin"
introEnd:

* = LDR_SPLASH_BEGIN - 2 "Splashscreen"
splashScreen:
.import binary "splash-zzap.z.bin"
splashScreenEnd:

.print "Loader summary"
.print "End of preable = $" + toHexString(continue)
.print "Splash start address = $" + toHexString(LDR_SPLASH_START_ADDRESS)
.print "Main unzipped size = " + LDR_MAIN_UNPACK_SIZE + " bytes"

.print "Main begin = $" + toHexString(LDR_MAIN_BEGIN)
.print "Intro begin = $" + toHexString(LDR_INTRO_BEGIN)
.print "Splash begin = $" + toHexString(LDR_SPLASH_BEGIN)

.print "Main zipped size = " + (mainGameEnd - mainGame) + " bytes"
.print "Intro packed size = " + (introEnd - intro) + " bytes"
.print "Splash zipped size = " + LDR_SPLASH_PACKED_SIZE + " bytes"


// .print "Loader splash start address = $" + toHexString(LOADER_SPLASH_START_ADDRESS)
