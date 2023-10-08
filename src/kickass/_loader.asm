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

.label LDR_MAIN_PACKED_SIZE = 28000
.label LDR_INTRO_PACKED_SIZE = 10452//11500
.label LDR_SPLASH_PACKED_SIZE = 5300

.label LDR_MAIN_BEGIN = $A7F
.label LDR_MAIN_END = LDR_MAIN_BEGIN + LDR_MAIN_PACKED_SIZE + 10
.label LDR_INTRO_BEGIN = LDR_MAIN_END
.label LDR_INTRO_END = LDR_INTRO_BEGIN + LDR_INTRO_PACKED_SIZE
.label LDR_SPLASH_BEGIN = LDR_INTRO_END
.label LDR_SPLASH_END = LDR_SPLASH_BEGIN + LDR_SPLASH_PACKED_SIZE

.label LDR_MAIN_START_ADDRESS = $8C0
.label LDR_MAIN_UNPACK_START_ADDRESS = $D00
.label LDR_MAIN_UNPACK_SIZE = 58865

.label LDR_SPLASH_START_ADDRESS = LDR_SPLASH_BEGIN

.label LDR_INTRO_START_ADDRESS = LDR_INTRO_BEGIN
