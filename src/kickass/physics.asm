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

#import "common/lib/math-global.asm"
#import "_constants.asm"

.segment Code

.label PHYS_WALK_STEP = 2
.label PHYS_CLIMB_STEP = 1
.label PHYS_FALL_STEP = 4

// jump parameters
.label PHYS_JUMP_LENGTH = 26

// collision parameters

.label PHYS_BOTTOM_ADJUSTMENT = 0
.label PHYS_LEFT_ADJUSTMENT = 0
.label PHYS_RIGHT_ADJUSTMENT = 0

.label PHYS_TOP_OF_LADDER_ADJUSTMENT = 1

_phys_begin:

phys_init: {
    lda phys_initialState
    sta physPlayerState
    jsr phys_forceTransitState
    lda #$ff
    // sta _phys_leftReminder
    // sta _phys_rightReminder
    // sta _phys_bottomReminder
    rts
}

/*
 * IN: A - command
 * USE: X, Y

 * assumption: phyPlayerBGCollision is up to date
 */
phys_commandPlayer: {
    sta actorPlayerCommand

    // default value
    ldx physPlayerState
    stx _phys_proposalState

    ldx #0
    stx _phys_stateChange
    
    _phys_command2state(CMD_WALK_LEFT, STATE_WALKING_LEFT, postState)
    _phys_command2state(CMD_WALK_RIGHT, STATE_WALKING_RIGHT, postState)
    _phys_command2state(CMD_JUMP_LEFT, STATE_JUMPING_LEFT, postState)
    _phys_command2state(CMD_JUMP_RIGHT, STATE_JUMPING_RIGHT, postState)
    _phys_command2state(CMD_DUCK_LEFT, STATE_DUCK_LEFT, postState)
    _phys_command2state(CMD_DUCK_RIGHT, STATE_DUCK_RIGHT, postState)
    _phys_ifCurrentStateJSR(STATE_WALKING_LEFT, idleFromWalkingLeft)
    _phys_ifCurrentStateJSR(STATE_WALKING_RIGHT, idleFromWalkingRight)
    
    tax
    lda physPlayerState
    and #STATES_RIGHT
    beq !+
        jmp facingRight
    !:
        txa
        // facing left
        _phys_ifStandsOnFloorOrLadder(duckLeft, climbDownLeft)
        _phys_ifStandsOnTopOfTheLadder(standsOnLadderLeft)
        _phys_ifStandsAtTheBottomOfTheLadder(climbUpLeft)
        _phys_command2state(CMD_JUMP, STATE_JUMPING_UP_FACING_LEFT, didJump)
        _phys_ifCurrentStateJSR(STATE_ON_LADDER_FACING_LEFT, idleFromLadderLeft)
        _phys_ifCurrentStateJSR(STATE_DUCK_LEFT, idleFromWalkingLeft)
        jmp postState
    facingRight:
        txa
        // facing right    
        _phys_ifStandsOnFloorOrLadder(duckRight, climbDownRight)
        _phys_ifStandsOnTopOfTheLadder(standsOnLadderRight)
        _phys_ifStandsAtTheBottomOfTheLadder(climbUpRight)
        _phys_command2state(CMD_JUMP, STATE_JUMPING_UP_FACING_RIGHT, didJump)
        _phys_ifCurrentStateJSR(STATE_ON_LADDER_FACING_RIGHT, idleFromLadderRight)
        _phys_ifCurrentStateJSR(STATE_DUCK_RIGHT, idleFromWalkingRight)

    postState:
        jsr _phys_checkProposalState

    rts // END OF ROUTINE

    didJump:
        jmp postState

    // vars

    // additional subroutines
    idleFromWalkingLeft: {
        _phys_command2stateAnd(CMD_IDLE, STATE_ON_GROUND_LEFT)
        rts
    }
    idleFromWalkingRight: {
        _phys_command2stateAnd(CMD_IDLE, STATE_ON_GROUND_RIGHT)
        rts
    }
    standsOnLadderLeft: {
        _phys_command2stateAnd(CMD_CLIMB_UP, STATE_ON_GROUND_LEFT)
        rts
    }
    standsOnLadderRight: {
        _phys_command2stateAnd(CMD_CLIMB_UP, STATE_ON_GROUND_RIGHT)
        rts
    }
    idleFromLadderLeft: {
        _phys_command2stateAnd(CMD_IDLE, STATE_ON_LADDER_STOPPED_FACING_LEFT)
        rts
    }
    idleFromLadderRight: {
        _phys_command2stateAnd(CMD_IDLE, STATE_ON_LADDER_STOPPED_FACING_RIGHT)
        rts
    }
    duckLeft: {
        _phys_command2stateAnd(CMD_CLIMB_DOWN, STATE_DUCK_LEFT)
        rts
    }
    duckRight: {
        _phys_command2stateAnd(CMD_CLIMB_DOWN, STATE_DUCK_RIGHT)
        rts
    }
    climbDownLeft: {
        _phys_command2stateAnd(CMD_CLIMB_DOWN, STATE_ON_LADDER_FACING_LEFT)
        rts
    }
    climbDownRight: {
        _phys_command2stateAnd(CMD_CLIMB_DOWN, STATE_ON_LADDER_FACING_RIGHT)
        rts
    }
    climbUpLeft: {
        _phys_command2stateAnd(CMD_CLIMB_UP, STATE_ON_LADDER_FACING_LEFT)
        rts
    }
    climbUpRight: {
        _phys_command2stateAnd(CMD_CLIMB_UP, STATE_ON_LADDER_FACING_RIGHT)
        rts
    }
}

phys_forceTransitState: {
    sta physPlayerStateAllowed
    jmp phys_transitState
}

phys_transitState: {
    lda physPlayerStateAllowed
    cmp physPlayerState
    beq !+
        ldx #1
        stx _phys_stateChange
        jsr _phys_state2animation
    !:
    lda physPlayerState
    and #%01111111
    cmp #STATE_JUMPING_LEFT
    beq resetJumpPhase
    cmp #STATE_JUMPING_UP_FACING_LEFT
    beq resetJumpPhase
    jmp setState
    resetJumpPhase:
        lda physPlayerStateAllowed
        and #%01111111
        cmp #STATE_JUMPING_LEFT
        beq setState
        cmp #STATE_JUMPING_UP_FACING_LEFT
        beq setState
        lda #$ff
        sta _phys_jumpPhase
    setState:
    lda physPlayerStateAllowed
    sta physPlayerState
    rts
}

_phys_state2animation: {

    lda physPlayerState
    and #%01111111
    cmp #STATE_DUCK_LEFT
    bne !+
        lda physPlayerStateAllowed
        _phys_state2animation(STATE_DUCK_LEFT, ANIM_DUCK_QUICK_LEFT, postAnim)
        _phys_state2animation(STATE_DUCK_RIGHT, ANIM_DUCK_QUICK_RIGHT, postAnim)
    !:

    lda physPlayerStateAllowed // not yet in physPlayerState

    _phys_state2animation(STATE_DUCK_LEFT, ANIM_DUCK_LEFT, postAnim)
    _phys_state2animation(STATE_DUCK_RIGHT, ANIM_DUCK_RIGHT, postAnim)
    _phys_state2animation(STATE_FALLING_DOWN_FACING_LEFT, ANIM_JUMP_LEFT, postAnim)
    _phys_state2animation(STATE_FALLING_DOWN_FACING_RIGHT, ANIM_JUMP_RIGHT, postAnim)
    _phys_state2animation(STATE_JUMPING_LEFT, ANIM_JUMP_LEFT, postAnim)
    _phys_state2animation(STATE_JUMPING_RIGHT, ANIM_JUMP_RIGHT, postAnim)
    _phys_state2animation(STATE_JUMPING_UP_FACING_LEFT, ANIM_JUMP_LEFT, postAnim)
    _phys_state2animation(STATE_JUMPING_UP_FACING_RIGHT, ANIM_JUMP_RIGHT, postAnim)
    _phys_state2animation(STATE_ON_GROUND_LEFT, ANIM_IDLING_LEFT, postAnim)
    _phys_state2animation(STATE_ON_GROUND_RIGHT, ANIM_IDLING_RIGHT, postAnim)
    _phys_state2animation(STATE_ON_LADDER_FACING_LEFT, ANIM_LADDER, postAnim)
    _phys_state2animation(STATE_ON_LADDER_FACING_RIGHT, ANIM_LADDER, postAnim)
    _phys_state2animation(STATE_WALKING_LEFT, ANIM_WALK_LEFT, postAnim)
    _phys_state2animation(STATE_WALKING_RIGHT, ANIM_WALK_RIGHT, postAnim)
    _phys_state2animation(STATE_ON_LADDER_STOPPED_FACING_LEFT, ANIM_LADDER_STOP, postAnim)
    _phys_state2animation(STATE_ON_LADDER_STOPPED_FACING_RIGHT, ANIM_LADDER_STOP, postAnim)
    _phys_state2animation(STATE_DEATH_LEFT, ANIM_DEATH_LEFT, postAnim)
    _phys_state2animation(STATE_DEATH_RIGHT, ANIM_DEATH_RIGHT, postAnim)
    
    postAnim:
    rts
}

// actual command in A; use X
.macro _phys_command2state(command, state, endLabel) {
    cmp #command
    bne !+
        ldx #state
        stx _phys_proposalState
        jmp endLabel
    !:    
}
.macro _phys_command2stateAnd(command, state) {
    cmp #command
    bne !+
        ldx #state
        stx _phys_proposalState
    !:    
}

// actual state in A; use X
.macro _phys_state2animation(state, animation, endLabel) {
    cmp #state
    bne !+
        ldx #animation
        stx physPlayerAnimation
        jmp endLabel
    !:
}

// use X
.macro _phys_ifCurrentStateJSR(state, jumpTo) {
    ldx physPlayerState
    cpx #state
    bne !+
        jsr jumpTo
    !:
}

// use X
.macro _phys_ifCurrentCommandJSR(command, jumpTo) {
    ldx actorPlayerCommand
    cpx #command
    bne !+
        jsr jumpTo
    !:
}

.macro _phys_ifStandsOnTopOfTheLadder(jumpTo) {
    sta saveA
    lda physPlayerBGCollisionExt
    and #BG_CLSE_LADDER_FAR
    beq end
        lda saveA
        jsr jumpTo
    end:
        lda saveA
    jmp !+
        saveA: .byte 0
    !:
}

.macro _phys_ifStandsAtTheBottomOfTheLadder(jumpTo) {
    sta saveA
    lda physPlayerBGCollision
    and #BG_CLSN_LADDER
    beq !+
        lda saveA
        jsr jumpTo
    !:
        lda saveA
    jmp !+
        saveA: .byte 0
    !:
}

// use X
// duck, climbDown
.macro _phys_ifStandsOnFloorOrLadder(jumpToFloor, jumpToLadder) {
    sta saveA

    lda physPlayerBGCollision
    and #BG_CLSN_LADDER
    bne !+
        lda physPlayerBGCollisionExt
        and #BG_CLSE_LADDER_FAR
        beq notOnLadder
    !:
    lda physPlayerBGCollisionExt
    and #BG_CLSE_FLOOR_NEAR // was FAR (TODO)
    bne !+
        lda physPlayerBGCollisionExt // does not work too well, it allows to duck even if not directly on the floor
        and #BG_CLSE_FLOOR_FAR
        beq onLadderButNotOnFloor
        // lda physPlayerBGCollision
        // and #BG_CLSN_LADDER
        lda physPlayerState
        and #STATE_ON_LADDER_FACING_LEFT
        bne onLadderButNotOnFloor
    !:
    jmp onFloorButNotOnLadder

    saveA: .byte 0
    
    onLadderButNotOnFloor:
        lda saveA
        jsr jumpToLadder
        jmp end

    onFloorButNotOnLadder: // <- tutaj TODO błąd z drabiną
        lda saveA
        jsr jumpToFloor
        jmp end

    notOnLadder:
        lda physPlayerBGCollisionExt
        and #BG_CLSE_FLOOR_FAR
        bne onFloorButNotOnLadder
        lda saveA
    end:
}

phys_blockMovement: {
    lda physPlayerBGCollisionExt
    _phys_ifCurrentStateJSR(STATE_WALKING_LEFT, onWalkingLeft)
    _phys_ifCurrentStateJSR(STATE_JUMPING_LEFT, onJumpingLeft)
    _phys_ifCurrentStateJSR(STATE_JUMPING_UP_FACING_LEFT, onJumpingLeft)
    _phys_ifCurrentStateJSR(STATE_FALLING_DOWN_FACING_LEFT, onFallingDown)
    _phys_ifCurrentStateJSR(STATE_WALKING_RIGHT, onWalkingRight)
    _phys_ifCurrentStateJSR(STATE_JUMPING_RIGHT, onJumpingRight)
    _phys_ifCurrentStateJSR(STATE_JUMPING_UP_FACING_RIGHT, onJumpingRight)
    _phys_ifCurrentStateJSR(STATE_FALLING_DOWN_FACING_RIGHT, onFallingDown)
    _phys_ifCurrentStateJSR(STATE_ON_LADDER_FACING_LEFT, onClimbingDown)
    _phys_ifCurrentStateJSR(STATE_ON_LADDER_FACING_RIGHT, onClimbingDown)
    end: 
        jsr physUpdateActorPosition
        rts

    onWalkingLeft: {
        and #BG_CLSE_WALL_LEFT
        beq !+
                jsr physResetActorPositionX
        !:
        jmp end
    }
    onWalkingRight: {
        and #BG_CLSE_WALL_RIGHT
        beq !+
            jsr physResetActorPositionX
        !:
        jmp end
    }
    onClimbingDown: {
        and #BG_CLSE_FLOOR_NEAR
        beq !+
            jsr physResetActorPositionY
            jsr _phys_adjustToLowerBounds
            jsr _phys_transitToAfterLanding
        !:
        jmp end
    }
    onFallingDown: {
        and #(BG_CLSE_FLOOR_NEAR + BG_CLSE_LADDER_TOP)
        beq !+
            jsr physResetActorPositionY
            jsr _phys_adjustToLowerBounds
            jsr _phys_transitToAfterLanding
        !:
        jmp end
    }
    onJumpingLeft: {
        and #(BG_CLSE_FLOOR_NEAR + BG_CLSE_LADDER_TOP)
        beq !+
            lda _phys_jumpPhase
            cmp #(PHYS_JUMP_LENGTH / 2)
            bcc !+
                jsr physResetActorPositionY
                jsr _phys_adjustToLowerBounds
                // jsr _phys_transitToAfterLanding
        !:
        lda physPlayerBGCollisionExt
        jmp onWalkingLeft
    }
    onJumpingRight: {
        and #(BG_CLSE_FLOOR_NEAR + BG_CLSE_LADDER_TOP)
        beq !+
            lda _phys_jumpPhase
            cmp #(PHYS_JUMP_LENGTH / 2)
            bcc !+
                jsr physResetActorPositionY
                jsr _phys_adjustToLowerBounds
                // jsr _phys_transitToAfterLanding
        !:
        lda physPlayerBGCollisionExt
        jmp onWalkingRight
    }
}

_phys_adjustToLowerBounds: {
    sec
    lda actorPlayerNextY
    sbc #CLSN_FLOOR_OFFSET_Y
    and #%00000111
    sec
    sta saveA
    lda #8
    sbc saveA
    sec
    sbc #CLSN_FLOOR_COMPENSATION_Y
    clc
    adc actorPlayerNextY
    sta actorPlayerNextY
    rts
    saveA: .byte 0
}


phys_executeState: {
    _phys_ifCurrentStateJSR(STATE_WALKING_LEFT, performCheckFreeFall)
    _phys_ifCurrentStateJSR(STATE_WALKING_RIGHT, performCheckFreeFall)
    _phys_ifCurrentStateJSR(STATE_ON_GROUND_LEFT, performCheckFreeFall)
    _phys_ifCurrentStateJSR(STATE_ON_GROUND_RIGHT, performCheckFreeFall)
    _phys_ifCurrentStateJSR(STATE_ON_LADDER_STOPPED_FACING_LEFT, performStoppedLadderCheckFreeFall)
    _phys_ifCurrentStateJSR(STATE_ON_LADDER_STOPPED_FACING_RIGHT, performStoppedLadderCheckFreeFall)

    _phys_ifCurrentStateJSR(STATE_WALKING_LEFT, performWalkingLeft)
    _phys_ifCurrentStateJSR(STATE_WALKING_RIGHT, performWalkingRight)
    _phys_ifCurrentStateJSR(STATE_ON_LADDER_FACING_LEFT, performClimbing)
    _phys_ifCurrentStateJSR(STATE_ON_LADDER_FACING_RIGHT, performClimbing)
    _phys_ifCurrentStateJSR(STATE_JUMPING_UP_FACING_LEFT, performJump)
    _phys_ifCurrentStateJSR(STATE_JUMPING_UP_FACING_RIGHT, performJump)
    _phys_ifCurrentStateJSR(STATE_JUMPING_LEFT, performJumpLeft)
    _phys_ifCurrentStateJSR(STATE_JUMPING_RIGHT, performJumpRight)
    _phys_ifCurrentStateJSR(STATE_FALLING_DOWN_FACING_LEFT, performFallingDown)
    _phys_ifCurrentStateJSR(STATE_FALLING_DOWN_FACING_RIGHT, performFallingDown)
    rts

    performCheckFreeFall: {
        // TODO: it does not belong here, this checks if state should transit, and does not execute the sate
        lda physPlayerBGCollisionExt
        and #(BG_CLSE_FLOOR_FAR + BG_CLSE_LADDER_FAR)
        bne !+
            // no floor nor ladder below, fall down
            jsr _phys_transitToFallingDown
        !:
        lda physPlayerBGCollisionExt
        and #BG_CLSE_FLOOR_FAR
        bne doNotFall // floor below, do not fall
            lda physPlayerBGCollision
            and #BG_CLSN_LADDER
            beq !+ // no ladder behind, do not fall
                jsr _phys_transitToFallingDown
            !:
        doNotFall:
        rts
    }
    performStoppedLadderCheckFreeFall: {
        lda physPlayerBGCollision
        and #BG_CLSN_LADDER
        bne doNotFall
        lda physPlayerBGCollision
        and #(BG_CLSE_LADDER_FAR + BG_CLSE_LADDER_TOP + BG_CLSE_FLOOR_FAR)
        bne doNotFall
        jsr _phys_transitToFallingDown
        doNotFall: rts
    }

    performWalkingLeft: {
        sec
        lda physPlayerX
        sbc #PHYS_WALK_STEP
        sta actorPlayerNextX
        lda physPlayerX + 1
        sbc #0
        sta actorPlayerNextX + 1
        rts
    }
    performWalkingRight: {
        clc
        lda physPlayerX
        adc #PHYS_WALK_STEP
        sta actorPlayerNextX
        lda physPlayerX + 1
        adc #0
        sta actorPlayerNextX + 1
        rts
    }
    performJumpLeft: {
        jsr performJump
        lda _phys_jumpPhase
        cmp #$ff
        beq !+
            sec
            lda physPlayerX
            sbc #PHYS_WALK_STEP
            sta actorPlayerNextX
            lda physPlayerX + 1
            sbc #0
            sta actorPlayerNextX + 1
        !:
        rts
    }
    performJumpRight: {
        jsr performJump
        lda _phys_jumpPhase
        cmp #$ff
        beq !+
            clc
            lda physPlayerX
            adc #PHYS_WALK_STEP
            sta actorPlayerNextX
            lda physPlayerX + 1
            adc #0
            sta actorPlayerNextX + 1
        !:
        rts
    }
    performJump: {
        // initialize jump direction if not yet done
        ldy _phys_jumpPhase
        iny
        sec
        lda physPlayerY
        sbc _phys_jumpYScheme, y
        sta actorPlayerNextY
        cpy #(PHYS_JUMP_LENGTH-1)
        bne !+
            ldy #$ff
            jsr _phys_transitToFallingDown
        !:
        sty _phys_jumpPhase
        rts
    }
    performFallingDown: {
        clc
        lda physPlayerY
        adc #PHYS_FALL_STEP
        sta actorPlayerNextY
        lda #$ff
        sta _phys_jumpPhase
        rts
    }
    performClimbing: {
        // TODO this is also problematic: it checks collision, so collision must be refreshed before
        _phys_ifCurrentCommandJSR(CMD_CLIMB_UP, up)
        _phys_ifCurrentCommandJSR(CMD_CLIMB_DOWN, down)
        rts
        up: {
            lda physPlayerBGCollision
            and #BG_CLSN_LADDER
            bne climbUp
            lda physPlayerBGCollisionExt
            and #BG_CLSE_LADDER_FAR
            bne climbUp
            jmp finalize
            climbUp:
                lda #ANIM_LADDER
                sta physPlayerAnimation
                sec
                lda physPlayerY
                sbc #PHYS_CLIMB_STEP
                sta actorPlayerNextY
                jsr adjustLadder
            finalize:
                rts
        }
        down: {
            lda physPlayerBGCollision
            and #BG_CLSN_LADDER
            bne goDown
                lda physPlayerBGCollisionExt
                and #BG_CLSE_LADDER_FAR
                beq !+
            goDown:
                // go down the ladder
                lda #ANIM_LADDER
                sta physPlayerAnimation
                clc
                lda physPlayerY
                adc #PHYS_CLIMB_STEP
                sta actorPlayerNextY
                jsr adjustLadder
                rts
            !:
            lda physPlayerBGCollisionExt
            and #BG_CLSE_FLOOR_FAR
            bne !+
                jsr _phys_transitToFallingDown
            !:
            rts
        }
    }
    adjustLadder: {
        lda actorLadderAdjustedX
        cmp #$ff
        beq end
            asl
            asl
            asl
            sta actorPlayerNextX
            lda #0
            bcc !+
                lda #1
            !: sta actorPlayerNextX + 1 // adds up the carry flag (a bit shifted out by asl) to the next byte (or not, if no carry is set)
            // compensate for sprite width
            clc
            lda actorPlayerNextX
            adc #12
            sta actorPlayerNextX
            lda actorPlayerNextX + 1
            adc #0
            sta actorPlayerNextX + 1
        end:
        rts
    }
}

_phys_transitToAfterLanding: {
    lda physPlayerState
    and #STATES_RIGHT
    ora #STATE_ON_GROUND_LEFT
    sta _phys_proposalState
    jsr _phys_checkProposalState
    lda physPlayerStateAllowed
    jsr phys_transitState
    rts
}

_phys_transitToFallingDown: {
    lda physPlayerState
    and #STATES_RIGHT
    ora #STATE_FALLING_DOWN_FACING_LEFT
    sta _phys_proposalState
    jsr _phys_checkProposalState
    lda physPlayerStateAllowed
    jsr phys_transitState
    rts
}

phys_die: {
    lda physPlayerState
    and #STATES_RIGHT
    ora #STATE_DEATH_LEFT
    sta _phys_proposalState
    jsr _phys_checkProposalState
    lda physPlayerStateAllowed
    jsr phys_transitState
    rts
}

/*
 * Out: X normalized X position, A original X position
 */
phys_player2charX: {
    // normalize X
    sec
    lda actorPlayerNextX
    sbc #CLSN_OFFSET_X
    sta tempX
    lda actorPlayerNextX + 1
    sbc #0
    sta tempX + 1
    // translate to char position
    lda tempX
    lsr
    lsr
    lsr
    tax
    lda tempX + 1
    beq !+
        txa
        ora #%00100000
        tax
    !:
    txa
    .for(var i = 0; i < CLSN_COL_OFFSET_X; i++) {
        dex
        beq stopDex
    }
    stopDex:
    rts
    // local vars
    tempX: .word 0
}

/*
 * Out: Y normalized Y position, A original Y position
 */
phys_player2charY: {
    sec
    lda actorPlayerNextY
    sbc #CLSN_OFFSET_Y
    // translate to char position
    lsr
    lsr
    lsr
    tay
    .for(var i = 0; i < CLSN_COL_OFFSET_Y; i++) {
        dey
        beq stopDey
    }
    stopDey:
    rts
}

.macro phys_checkBGCollisionExt2(materials, chamberLines) {
    lda #$ff
    sta actorLadderAdjustedX
    sta ladder0
    sta ladder1

    lda #0
    sta physPlayerBGCollision
    sta physPlayerBGCollisionExt
    sta physPlayerBGCollisionObj

    // calculate other end of X
    _phys_div8_16(actorPlayerNextX, 0, -2, leftColBound)
    _phys_div8_16(actorPlayerNextX, 0 + 8, -2, rightColBound)

    // calculate other end of Y
    _phys_div8_8(actorPlayerNextY, 0, -6, topRowBound)
    lda topRowBound
    sta storeTopRowBound

    ldx leftColBound
    jsr checkAll
    lda storeTopRowBound
    sta topRowBound
    ldx rightColBound
    jsr checkAll

    // adjust position to the ladder
    lda ladder0
    cmp rightColBound
    bne !+
        // |-
        sta actorLadderAdjustedX
        inc actorLadderAdjustedX
        jmp end
    !:
    cmp leftColBound
    bne !++
        // |--| or -|
        lda ladder1
        cmp rightColBound
        bne !+
            // |--|
            sta actorLadderAdjustedX
            jmp end
        !:
        // -|
        lda ladder0
        sta actorLadderAdjustedX
    !:

    end: rts

    checkAll: {
        lda #BG_CLSN_BOX_MASK
        sta loadMaterialBox.mask
        .for (var i = 0; i < 3; i++) {
            lda topRowBound
            bmi !+ // row #i
                cmp #CLSN_LAST_ROW
                beq end
                tay
                jsr loadMaterialBox
            !:
            inc topRowBound
        }
        lda #BG_CLSN_BOX_NK_MASK
        sta loadMaterialBox.mask
        lda topRowBound
        bmi !+ // row #3
            cmp #CLSN_LAST_ROW
            beq end
            tay
            jsr loadMaterialFloorNear
            ldy topRowBound
            jsr loadMaterialBox
        !:
        inc topRowBound
        lda topRowBound
        bmi !+ // row #4 ("far")
            cmp #CLSN_LAST_ROW
            beq end
            tay
            jsr loadMaterialFar
        !:
        end: rts
    }
    loadMaterialBox: {
        lda chamberLines.lo, y
        sta address
        lda chamberLines.hi, y
        sta address + 1
        lda address:$ffff, x
        tay
        lda materials, y
        and mask:#BG_CLSN_BOX_MASK
        ora physPlayerBGCollision
        sta physPlayerBGCollision
        lda materials, y
        and #BG_CLSN_OBJ_MASK
        ora physPlayerBGCollisionObj
        sta physPlayerBGCollisionObj
        rts
    }
    loadMaterialFloorNear: {
        lda chamberLines.lo, y
        sta address
        lda chamberLines.hi, y
        sta address + 1
        lda address:$ffff, x
        tay
        lda materials, y
        and #BG_CLSN_FLOOR_MASK
        beq !+
            ora physPlayerBGCollision
            sta physPlayerBGCollision
            lda #(BG_CLSE_FLOOR_NEAR + BG_CLSE_WALL_LEFT + BG_CLSE_WALL_RIGHT) // TODO bug #101 - wall collision recognized as floor
            ora physPlayerBGCollisionExt
            sta physPlayerBGCollisionExt
        !:
        lda materials, y
        and #BG_CLSN_LADDER
        beq !+
            lda physPlayerBGCollision
            and #BG_CLSN_LADDER
            bne !+
            lda #BG_CLSE_LADDER_TOP
            ora physPlayerBGCollisionExt
            sta physPlayerBGCollisionExt
        !:
        jsr loadMaterialLadder
        rts
    }
    loadMaterialLadder: {
        ldy topRowBound
        jsr checkLadder
        inx
        ldy topRowBound
        jsr checkLadder
        dex
        rts
    }
    loadMaterialFar: {
        lda chamberLines.lo, y
        sta address
        lda chamberLines.hi, y
        sta address + 1
        lda address:$ffff, x
        tay
        lda materials, y
        and #BG_CLSN_LADDER
        beq !+
            lda #BG_CLSE_LADDER_FAR
            ora physPlayerBGCollisionExt
            sta physPlayerBGCollisionExt
        !:
        lda materials, y
        and #BG_CLSN_WALL
        beq !+
            lda #BG_CLSE_FLOOR_FAR
            ora physPlayerBGCollisionExt
            sta physPlayerBGCollisionExt
        !:
        jsr loadMaterialLadder
        rts
    }
    checkLadder: {
        lda chamberLines.lo, y
        sta address
        lda chamberLines.hi, y
        sta address + 1
        lda address:$ffff, x
        tay
        lda materials, y
        and #BG_CLSN_LADDER
        beq noLadder
            lda ladder0
            cmp #$ff
            bne !+
                stx ladder0
                jmp noLadder
            !:
            lda ladder1
            cmp #$ff
            bne !+
                stx ladder1
            !:
        noLadder:
        rts
    }
    // vars
    leftColBound:               .byte 0
    rightColBound:              .byte 0
    topRowBound:                .byte 0
    bottomRowBound:             .byte 0
    storeTopRowBound:           .byte 0
    ladder0:                    .byte 0
    ladder1:                    .byte 0
}

.macro _phys_div8_8(valueAddress, addValueBefore, addValueAfter, targetAddress) {
    lda valueAddress
    .if (addValueBefore != 0) {
        clc
        adc #addValueBefore
    }
    lsr
    lsr
    lsr
    .if (addValueAfter != 0) {
        clc
        adc #addValueAfter
    }
    sta targetAddress
}

.macro _phys_div8_16(valueAddress, addValueBefore, addValueAfter, targetAddress) {
    clc
    lda valueAddress
    adc #addValueBefore
    sta _phys_div8_16_temp
    lda valueAddress + 1
    adc #0
    sta _phys_div8_16_temp + 1

    lda _phys_div8_16_temp + 1
    ror
    lda _phys_div8_16_temp
    ror
    lsr
    lsr
    .if (addValueAfter != 0) {
        clc
        adc #addValueAfter
    }
    sta targetAddress
    jmp !+
        // local var
        _phys_div8_16_temp: .word 0
    !:
}

physUpdateActorPositionX: {
    lda actorPlayerNextX
    sta physPlayerX
    lda actorPlayerNextX + 1
    sta physPlayerX + 1
    rts
}

physUpdateActorPositionY: {
    lda actorPlayerNextY
    sta physPlayerY
    rts
}

physUpdateActorPosition: {
    jsr physUpdateActorPositionX
    jsr physUpdateActorPositionY
    rts
}

physResetActorPositionX: {
    lda physPlayerX
    sta actorPlayerNextX
    lda physPlayerX + 1
    sta actorPlayerNextX + 1
    rts
}

physResetActorPositionY: {
    lda physPlayerY
    sta actorPlayerNextY
    rts
}

physResetActorPosition: {
    jsr physResetActorPositionX
    jsr physResetActorPositionY
    rts
}

/*
   Checks if state transition in _phys_proposalState is allowed from current state.
   If yes, physPlayerStateAllowed will contain new state, if not, it contains current state.
   Compare these two to determine if transition is allowed
 */
_phys_checkProposalState: {
    lda physPlayerState
    sta physPlayerStateAllowed // by default negative - transition is not allowed

    _phys_allowTransit(STATE_ON_GROUND_LEFT, List().add(STATE_WALKING_RIGHT, STATE_WALKING_LEFT, STATE_ON_LADDER_FACING_LEFT, STATE_DUCK_LEFT, STATE_JUMPING_UP_FACING_LEFT, STATE_FALLING_DOWN_FACING_LEFT, STATE_DEATH_LEFT, STATE_JUMPING_LEFT, STATE_JUMPING_RIGHT))
    _phys_allowTransit(STATE_WALKING_LEFT, List().add(STATE_JUMPING_LEFT, STATE_DUCK_LEFT, STATE_FALLING_DOWN_FACING_LEFT, STATE_ON_LADDER_FACING_LEFT, STATE_ON_GROUND_LEFT, STATE_DEATH_LEFT, STATE_WALKING_RIGHT))
    _phys_allowTransit(STATE_ON_LADDER_FACING_LEFT, List().add(STATE_ON_GROUND_LEFT, STATE_ON_LADDER_STOPPED_FACING_LEFT, STATE_FALLING_DOWN_FACING_LEFT, STATE_DEATH_LEFT))
    _phys_allowTransit(STATE_DUCK_LEFT, List().add(STATE_ON_GROUND_LEFT, STATE_DEATH_LEFT, STATE_DUCK_RIGHT, STATE_JUMPING_LEFT))
    _phys_allowTransit(STATE_JUMPING_LEFT, List().add(STATE_FALLING_DOWN_FACING_LEFT, STATE_ON_GROUND_LEFT, STATE_DEATH_LEFT)) // TODO remove last state
    _phys_allowTransit(STATE_JUMPING_UP_FACING_LEFT, List().add(STATE_FALLING_DOWN_FACING_LEFT, STATE_ON_GROUND_LEFT, STATE_DEATH_LEFT)) // TODO remove last state
    _phys_allowTransit(STATE_FALLING_DOWN_FACING_LEFT, List().add(STATE_ON_GROUND_LEFT, STATE_DEATH_LEFT))
    _phys_allowTransit(STATE_ON_LADDER_STOPPED_FACING_LEFT, List().add(STATE_ON_LADDER_FACING_LEFT, STATE_DEATH_LEFT, STATE_FALLING_DOWN_FACING_LEFT))
    _phys_allowTransit(STATE_ON_GROUND_RIGHT, List().add(STATE_WALKING_LEFT, STATE_ON_LADDER_FACING_RIGHT, STATE_WALKING_RIGHT, STATE_DUCK_RIGHT, STATE_JUMPING_UP_FACING_RIGHT, STATE_FALLING_DOWN_FACING_RIGHT, STATE_DEATH_RIGHT, STATE_JUMPING_RIGHT, STATE_JUMPING_LEFT))
    _phys_allowTransit(STATE_WALKING_RIGHT, List().add(STATE_ON_GROUND_RIGHT, STATE_JUMPING_RIGHT, STATE_ON_LADDER_FACING_RIGHT, STATE_FALLING_DOWN_FACING_RIGHT, STATE_DUCK_RIGHT, STATE_DEATH_RIGHT, STATE_WALKING_LEFT))
    _phys_allowTransit(STATE_ON_LADDER_FACING_RIGHT, List().add(STATE_ON_GROUND_RIGHT, STATE_ON_LADDER_STOPPED_FACING_RIGHT, STATE_FALLING_DOWN_FACING_RIGHT, STATE_DEATH_RIGHT))
    _phys_allowTransit(STATE_DUCK_RIGHT, List().add(STATE_ON_GROUND_RIGHT, STATE_DEATH_RIGHT, STATE_DUCK_LEFT, STATE_JUMPING_RIGHT))
    _phys_allowTransit(STATE_JUMPING_RIGHT, List().add(STATE_FALLING_DOWN_FACING_RIGHT, STATE_ON_GROUND_RIGHT, STATE_DEATH_RIGHT)) // TODO remove last state
    _phys_allowTransit(STATE_JUMPING_UP_FACING_RIGHT, List().add(STATE_FALLING_DOWN_FACING_RIGHT, STATE_ON_GROUND_RIGHT, STATE_DEATH_RIGHT)) // TODO remove last state
    _phys_allowTransit(STATE_FALLING_DOWN_FACING_RIGHT, List().add(STATE_ON_GROUND_RIGHT, STATE_DEATH_RIGHT))
    _phys_allowTransit(STATE_ON_LADDER_STOPPED_FACING_RIGHT, List().add(STATE_ON_LADDER_FACING_RIGHT, STATE_DEATH_RIGHT, STATE_FALLING_DOWN_FACING_RIGHT))

    rts
}

.macro _phys_allowTransit(from, toStates) {
    lda physPlayerState
    cmp #from
    bne skip
    lda _phys_proposalState
    .for(var i = 0; i < toStates.size(); i++) {
        cmp #toStates.get(i)
        bne !+
            sta physPlayerStateAllowed
            jmp skip
        !:
    }
    skip:
}

// public vars
physPlayerX:            .word 0
physPlayerY:            .byte 0
physPlayerBGCollision:  .byte 0
physPlayerBGCollisionExt: .byte 0
physPlayerBGCollisionObj: .byte 0
physPlayerAnimation:    .byte ANIM_IDLING_RIGHT
physPlayerState:        .byte STATE_FALLING_DOWN_FACING_RIGHT 
physPlayerStateAllowed: .byte STATE_FALLING_DOWN_FACING_RIGHT
phys_initialState:       .byte 0

// internal vars
actorPlayerNextX:       .word 0
actorPlayerNextY:       .byte 0
actorPlayerCommand:     .byte CMD_IDLE
actorPlayerFacing:      .byte 0
actorAnimationChange:   .byte 0
actorLadderAdjustedX:   .byte 0 // char position, not pixel position!
_phys_jumpPhase:        .byte $ff
_phys_proposalState:    .byte 0
_phys_stateChange:      .byte 0 // TODO: make public
// _phys_leftReminder:     .byte $ff
// _phys_rightReminder:    .byte $ff

_phys_jumpYScheme:      .byte 4, 4, 4, 2, 2, 2, 1, 1, 1, 0, 1, 0, 1
                        .byte -1, 0, -1, 0, -1, -1, -1, -2, -2, -2, -4, -4, -4


_phys_end:

.print "Size of physics code = " + (_phys_end - _phys_begin) + " bytes"