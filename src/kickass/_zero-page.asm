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
#importonce 

// universal source/dest pointer for copy operations via indirect indexed
.label SOURCE_PTR = $07         // $07, $08 2 bytes
.label DEST_PTR = $0F           // $0F, $10 2 bytes
.label GOATTRACKER = $FC        // zeropage register for goattracker
.label MAIN_SOURCE_PTR = $2B    // $2B, $2C 2 bytes source ptr for main thread
// universal counter
.label COUNTER = $02
// cheat status
.label gameCheatState = $2D
// NTSC flag
.label ntscFlag = $2E
// used by Copper64
.label COPPER_LIST_ADDR = $03    // $03, $04 - 2 bytes
.label COPPER_LIST_PTR  = $05    // $05      - 1 byte
// general purpose extra regs
.label ZR_0 = $12
.label ZR_1 = $14

