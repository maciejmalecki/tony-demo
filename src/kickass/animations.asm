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

.segment Code

.label ANI_PLAYER_ANIMATION_DELAY = 10
.label ANI_PLAYER_POSITION_X = 250
.label ANI_PLAYER_POSITION_Y = 80
// .label ANI_PLAYER_COLOR = LIGHT_COLOR

.label ANI_MODE_LOOP = 1
.label ANI_MODE_ONESHOT = 2
.label ANI_MODE_PINGPONG = 3

ani_init: {
    lda #0
    sta _aniPlayerPhase
    lda #ANI_PLAYER_ANIMATION_DELAY
    sta _aniPlayerDelay
    ldx #ANIM_IDLING_LEFT
    ldy #ANI_ACTOR_PLAYER
    jsr ani_setAnimation

    lda _aniAnimateAddrLo
    sta animateAddr
    lda _aniAnimateAddrHi
    sta animateAddr + 1
    jsr animateAddr: $ffff

    lda c64lib.SPRITE_ENABLE
    ora #%00000111
    sta c64lib.SPRITE_ENABLE

    lda #%00000100
    sta c64lib.SPRITE_EXPAND_Y

    rts
}

.macro ani_updatePlayerPosition(playerPositionX, playerPositionY) {
    clc
    lda playerPositionX
    adc #SPRITE_CORRECTION_X
    sta c64lib.SPRITE_0_X
    sta c64lib.SPRITE_1_X
    sta c64lib.SPRITE_2_X
    lda playerPositionX + 1
    adc #0
    beq !+
    lda c64lib.SPRITE_MSB_X
    ora #%00000111
    sta c64lib.SPRITE_MSB_X
    jmp !++
!:
    lda c64lib.SPRITE_MSB_X
    and #%11111000
    sta c64lib.SPRITE_MSB_X
!:
    clc
    lda playerPositionY
    adc #SPRITE_CORRECTION_Y
    sta c64lib.SPRITE_0_Y
    sta c64lib.SPRITE_2_Y
    clc
    adc #21
    sta c64lib.SPRITE_1_Y
    rts
}

// IN: X - actor code
ani_animatePlayer: {
    dec _aniPlayerDelayCounter, x
    bne waitDelay
        lda _aniPlayerDelay, x
        sta _aniPlayerDelayCounter, x
        inc _aniPlayerPhase, x
        lda _aniPlayerPhase, x
        cmp _aniPlayerLength, x
        bne continueSequence
            lda _aniPlayerMode, x
            cmp #ANI_MODE_ONESHOT
            beq oneShot
                lda #0
                sta _aniPlayerPhase, x
                jmp continueSequence
            oneShot:
                dec _aniPlayerPhase, x // hack
    continueSequence:
        lda _aniAnimateAddrLo, x
        sta animateAddr
        lda _aniAnimateAddrHi, x
        sta animateAddr + 1
        jsr animateAddr: $ffff
    waitDelay:
    rts
}

// IN: x - animation code, y - actor code (0 - Tony)
ani_setAnimation: {
    lda animationLo, x
    sta _aniAnimateAddrLo, y
    lda animationHi, x
    sta _aniAnimateAddrHi, y
    lda animationLength, x
    sta _aniPlayerLength, y
    lda animationDelay, x
    sta _aniPlayerDelay, y
    lda #1
    sta _aniPlayerDelayCounter, y
    lda animationMode, x
    sta _aniPlayerMode, y
    lda #0
    sta _aniPlayerPhase, y
    rts
}

animationLo:        .byte   <walkLeftAnimate,   <walkRightAnimate,      <duckLeftAnimate,   <duckRightAnimate   // 0 - 3
                    .byte   <idlingLeftAnimate, <idlingRightAnimate,    <ladderAnimate,     <jumpLeftAnimate    // 4 - 7
                    .byte   <jumpRightAnimate,  <ladderAnimate,         <deathLeftAnimate,  <deathRightAnimate  // 8 - 11
                    .byte   <skullAnimate,      <batVerticalAnimate,    <deadmanLeftAnimate, <deadmanRightAnimate
                    .byte   <batLeftAnimate,    <batRightAnimate,       <duckLeftQAnimate,  <duckRightQAnimate

animationHi:        .byte   >walkLeftAnimate,   >walkRightAnimate,      >duckLeftAnimate,   >duckRightAnimate
                    .byte   >idlingLeftAnimate, >idlingRightAnimate,    >ladderAnimate,     >jumpLeftAnimate
                    .byte   >jumpRightAnimate,  >ladderAnimate,         >deathLeftAnimate,  >deathRightAnimate
                    .byte   >skullAnimate,      >batVerticalAnimate,    >deadmanLeftAnimate, >deadmanRightAnimate
                    .byte   >batLeftAnimate,    >batRightAnimate,       >duckLeftQAnimate,  >duckRightQAnimate

animationLength:    .byte   4,                  4,                      3,                  3
                    .byte   6,                  6,                      2,                  2
                    .byte   2,                  1,                      5,                  5
                    .byte   7,                  7,                      4,                  4
                    .byte   4,                  4,                      1,                  1

animationMode:      .byte   ANI_MODE_LOOP,      ANI_MODE_LOOP,          ANI_MODE_ONESHOT,   ANI_MODE_ONESHOT
                    .byte   ANI_MODE_LOOP,      ANI_MODE_LOOP,          ANI_MODE_LOOP,      ANI_MODE_ONESHOT
                    .byte   ANI_MODE_ONESHOT,   ANI_MODE_ONESHOT,       ANI_MODE_ONESHOT,   ANI_MODE_ONESHOT
                    .byte   ANI_MODE_LOOP,      ANI_MODE_LOOP,          ANI_MODE_LOOP,      ANI_MODE_LOOP
                    .byte   ANI_MODE_LOOP,      ANI_MODE_LOOP,          ANI_MODE_ONESHOT,   ANI_MODE_ONESHOT

animationDelay:     .byte   7,                  7,                      5,                  5
                    .byte   15,                 15,                     10,                 10
                    .byte   10,                 10,                     10,                 10
                    .byte   10,                 2,                      7,                  7
                    .byte   5,                  5,                      5,                  5

walkLeftAnimate:    _animate(walkLeftAnimationTL, walkLeftAnimationBL, walkLeftAnimationBG)
walkRightAnimate:   _animate(walkRightAnimationTL, walkRightAnimationBL, walkRightAnimationBG)
duckLeftAnimate:    _animate(duckLeftAnimationTL, duckLeftAnimationBL, duckLeftAnimationBG)
duckRightAnimate:   _animate(duckRightAnimationTL, duckRightAnimationBL, duckRightAnimationBG)
duckLeftQAnimate:   _animate(duckLeftAnimationQuickTL, duckLeftAnimationQuickBL, duckLeftAnimationQuickBG)
duckRightQAnimate:  _animate(duckRightAnimationQuickTL, duckRightAnimationQuickBL, duckRightAnimationQuickBG)
idlingLeftAnimate:  _animate(idlingLeftAnimationTL, idlingLeftAnimationBL, idlingLeftAnimationBG)
idlingRightAnimate: _animate(idlingRightAnimationTL, idlingRightAnimationBL, idlingRightAnimationBG)
ladderAnimate:      _animate(ladderAnimationTL, ladderAnimationBL, ladderAnimationBG)
jumpLeftAnimate:    _animate(jumpLeftAnimationTL, jumpLeftAnimationBL, jumpLeftAnimationBG)
jumpRightAnimate:   _animate(jumpRightAnimationTL, jumpRightAnimationBL, jumpRightAnimationBG)
deathLeftAnimate:   _animate(deathLeftAnimationTL, deathLeftAnimationBL, deathLeftAnimationBG)
deathRightAnimate:  _animate(deathRightAnimationTL, deathRightAnimationBL, deathRightAnimationBG)
skullAnimate:       _animateEnemy(skullAnimation)
batVerticalAnimate: _animateEnemy(batVerticalAnimation)
deadmanLeftAnimate: _animateEnemy(deadmanLeftAnimation)
deadmanRightAnimate: _animateEnemy(deadmanRightAnimation)
batLeftAnimate:     _animateEnemy(batLeftAnimation)
batRightAnimate:    _animateEnemy(batRightAnimation)

.macro _animate(tl, bl, bg) {
    ldx _aniPlayerPhase
    lda tl, x
    sta SCREEN_MEM_0 + 1016 + PLAYER_SPRITE_0
    lda bl, x 
    sta SCREEN_MEM_0 + 1016 + PLAYER_SPRITE_0 + 1
    lda bg, x
    sta SCREEN_MEM_0 + 1016 + PLAYER_SPRITE_0 + 2
    rts
}

// IN: X - actor code
.macro _animateEnemy(animation) {
    ldy _aniPlayerPhase, x
    lda animation, y
    sta SCREEN_MEM_0 + 1016 + PLAYER_SPRITE_0 + 2, x
    rts
}

// player sprite bank mapping
walkLeftAnimationTL: .fill 4, i*2 + PLAYER_BANK_WALK_LEFT
walkLeftAnimationBL: .fill 4, i*2 + 1 + PLAYER_BANK_WALK_LEFT
walkLeftAnimationBG: .fill 4, i + PLAYER_WALK_LEFT_BG

walkRightAnimationTL: .fill 4, i*2 + PLAYER_BANK_WALK_RIGHT
walkRightAnimationBL: .fill 4, i*2 + 1 + PLAYER_BANK_WALK_RIGHT
walkRightAnimationBG: .fill 4, i + PLAYER_WALK_RIGHT_BG

duckLeftAnimationTL: .fill 4, i*2 + PLAYER_DUCK_LEFT
duckLeftAnimationBL: .fill 4, i*2 + 1 + PLAYER_DUCK_LEFT
duckLeftAnimationBG: .fill 4, i + PLAYER_DUCK_LEFT_BG

duckLeftAnimationQuickTL: .byte PLAYER_DUCK_LEFT + 4
duckLeftAnimationQuickBL: .byte PLAYER_DUCK_LEFT + 5
duckLeftAnimationQuickBG: .byte PLAYER_DUCK_LEFT_BG + 2

duckRightAnimationTL: .fill 4, i*2 + PLAYER_DUCK_RIGHT
duckRightAnimationBL: .fill 4, i*2 + 1 + PLAYER_DUCK_RIGHT
duckRightAnimationBG: .fill 4, i + PLAYER_DUCK_RIGHT_BG

duckRightAnimationQuickTL: .byte PLAYER_DUCK_RIGHT + 4
duckRightAnimationQuickBL: .byte PLAYER_DUCK_RIGHT + 5
duckRightAnimationQuickBG: .byte PLAYER_DUCK_RIGHT_BG + 2

idlingLeftAnimationTL: 
                        .fill 2, i*2 + PLAYER_IDLING_LEFT
                        .fill 2, i*2 + PLAYER_IDLING_LEFT
                        .fill 2, 4 + i*2 + PLAYER_IDLING_LEFT
idlingLeftAnimationBL: 
                        .fill 2, i*2 + 1 + PLAYER_IDLING_LEFT
                        .fill 2, i*2 + 1 + PLAYER_IDLING_LEFT
                        .fill 2, i*2 + 5 + PLAYER_IDLING_LEFT
idlingLeftAnimationBG: 
                        .fill 2, i + PLAYER_IDLING_LEFT_BG
                        .fill 2, i + PLAYER_IDLING_LEFT_BG
                        .fill 2, 2 + i + PLAYER_IDLING_LEFT_BG

idlingRightAnimationTL: 
                        .fill 2, 4 + i*2 + PLAYER_IDLING_RIGHT
                        .fill 2, 4 + i*2 + PLAYER_IDLING_RIGHT
                        .fill 2, i*2 + PLAYER_IDLING_RIGHT
idlingRightAnimationBL: 
                        .fill 2, i*2 + 5 + PLAYER_IDLING_RIGHT
                        .fill 2, i*2 + 5 + PLAYER_IDLING_RIGHT
                        .fill 2, i*2 + 1 + PLAYER_IDLING_RIGHT
idlingRightAnimationBG: 
                        .fill 2, 2 + i + PLAYER_IDLING_RIGHT_BG
                        .fill 2, 2 + i + PLAYER_IDLING_RIGHT_BG
                        .fill 2, i + PLAYER_IDLING_RIGHT_BG

ladderAnimationTL: .fill 2, i*2 + PLAYER_LADDER
ladderAnimationBL: .fill 2, i*2 + 1 + PLAYER_LADDER
ladderAnimationBG: .fill 2, i + PLAYER_LADDER_BG

jumpLeftAnimationTL: .fill 2, i*2 + PLAYER_JUMP_LEFT
jumpLeftAnimationBL: .fill 2, i*2 + 1 + PLAYER_JUMP_LEFT
jumpLeftAnimationBG: .fill 2, i + PLAYER_JUMP_LEFT_BG

jumpRightAnimationTL: .fill 2, i*2 + PLAYER_JUMP_RIGHT
jumpRightAnimationBL: .fill 2, i*2 + 1 + PLAYER_JUMP_RIGHT
jumpRightAnimationBG: .fill 2, i + PLAYER_JUMP_RIGHT_BG

deathLeftAnimationTL: .fill 5, i*2 + PLAYER_DEATH_LEFT
deathLeftAnimationBL: .fill 5, i*2 + 1 + PLAYER_DEATH_LEFT
deathLeftAnimationBG: .fill 5, i + PLAYER_DEATH_LEFT_BG

deathRightAnimationTL: .fill 5, i*2 + PLAYER_DEATH_RIGHT
deathRightAnimationBL: .fill 5, i*2 + 1 + PLAYER_DEATH_RIGHT
deathRightAnimationBG: .fill 5, i + PLAYER_DEATH_RIGHT_BG

// enemy animation sprite mappings
// skull
skullAnimation: .fill 4, i + ENEMY_SKULL
                .fill 3, 3 - i + ENEMY_SKULL

// bat vertical
batVerticalAnimation:
                .fill 4, i + ENEMY_BAT_VERTICAL
                .fill 3, 3 - i + ENEMY_BAT_VERTICAL

// deadman
deadmanLeftAnimation:
                .fill 4, i + ENEMY_DEADMAN_LEFT
deadmanRightAnimation:
                .fill 4, i + ENEMY_DEADMAN_RIGHT

// bat
batLeftAnimation:
                .fill 4, i + ENEMY_BAT_LEFT
batRightAnimation:
                .fill 4, i + ENEMY_BAT_RIGHT

// public vars
// - none -

// internal vars
_aniPlayerPhase:        .fill ANI_MAX_ACTORS, 0
_aniPlayerDelay:        .fill ANI_MAX_ACTORS, 0
_aniPlayerLength:       .fill ANI_MAX_ACTORS, 0
_aniPlayerMode:         .fill ANI_MAX_ACTORS, 0
_aniPlayerDelayCounter: .fill ANI_MAX_ACTORS, 0
_aniAnimateAddrLo:      .fill ANI_MAX_ACTORS, 0
_aniAnimateAddrHi:      .fill ANI_MAX_ACTORS, 0
