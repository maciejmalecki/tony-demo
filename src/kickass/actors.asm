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
#import "chipset/lib/vic2-global.asm"

// X is an movable actor position (without main player), not object position
getObjectValue2: {
    lda address:$ffff, x
    rts
}

actor_checkCollision: {
    lda c64lib.SPRITE_2S_COLLISION
    and #%01111000
    sta actorCollisions
    rts
}

// vars
actorPositionX:     .fill ANI_MAX_ACTORS, 0
actorPositionY:     .fill ANI_MAX_ACTORS, 0
actorValue2:        .fill ANI_MAX_ACTORS, 0
actorDepackValue:   .fill ANI_MAX_ACTORS, 0
actorDepackCounter: .fill ANI_MAX_ACTORS, 0
actorDirections:    .byte 0                     // direction flag: 0 - left/down, 1 right/up
actorModes:         .byte 0
actorCollisions:    .byte 0
