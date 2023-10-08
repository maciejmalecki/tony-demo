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

#import "common/lib/invoke-global.asm"
#import "chipset/lib/vic2-global.asm"
#import "chipset/lib/cia-global.asm"
#import "chipset/lib/mos6510-global.asm"
#import "copper64/lib/copper64-global.asm"

#import "_zero-page.asm"
#import "_constants.asm"
#import "_loader.asm"

.segmentdef Code [start=LDR_MAIN_START_ADDRESS]
.segmentdef Movable [startAfter="Code"]

.file [name="./tony.prg", segments="Code, Movable", modify="BasicUpstart", _start=LDR_MAIN_START_ADDRESS]

.var music = LoadSid("TonyLevelA000_V2.sid")


.label musicLocation = music.location
.label musicSize = music.size

.segment Code

start:
    jmp startAfter

copperList: // must fit into a single page
    c64lib_copperEntry(40, c64lib.IRQH_JSR, <doEachFrameTop, >doEachFrameTop)
    dashboardColor: c64lib_copperEntry(213, c64lib.IRQH_DASHBOARD_CUTOFF, SCHEME_CLASSIC_DARK, %00010100)
    c64lib_copperEntry(220, c64lib.IRQH_JSR, <doEachFrameVisual, >doEachFrameVisual)
    c64lib_copperLoop()
copperListEnd:

.assert "copper list(s) must fit into a single memory page", >copperList, >copperListEnd

startAfter:
    jsr detectNTSC
    sei
    c64lib_disableCIAInterrupts()
    c64lib_configureMemory(c64lib.RAM_IO_RAM)
    c64lib_setVICBank(3)
    cli
    jsr cheatMenu
    jsr blankScreen
    seq_setUp(0, 0, 0, 0)
    jsr init
    jsr startTitle
    jmp startLevel

init: {
    // set up C64
    sei
    c64lib_disableCIAInterrupts()
    c64lib_configureMemory(c64lib.RAM_RAM_RAM)
    jsr unpack
    c64lib_configureMemory(c64lib.RAM_IO_RAM)
    c64lib_setVICBank(0)
    cli
    // set up VIC-2
    lda #%00010111
    sta c64lib.CONTROL_1
    lda #%00001000
    sta c64lib.CONTROL_2
    lda #%00000010
    sta c64lib.MEMORY_CONTROL
    ldx #0
    stx colorScheme
    lda colorLights, x
    sta currentColor
    jsr setColors
    // NTSC counter
    lda #0
    sta ntscCounter

    // turn off decimal mode (just in case)
    cld
    jsr io_init

    // fill up buffers (remove when buffers goes back to the code segment!)
    lda #<roomCharsDecodingBuffer
    sta cleanBuffer.address
    lda #>roomCharsDecodingBuffer
    sta cleanBuffer.address + 1
    jsr cleanBuffer

    lda #<roomMaterialsBuffer
    sta cleanBuffer.address
    lda #>roomMaterialsBuffer
    sta cleanBuffer.address + 1
    jsr cleanBuffer

    rts

    cleanBuffer: {
        lda #0
        ldx #0
        loop:
            sta address:$ffff, x
            inx
            bne loop
        rts
    }
}

unpack: {

    c64lib_pushParamW(font)
    c64lib_pushParamW(FONT_BUFFER_MEM)
    c64lib_pushParamW(37*8)
    jsr copyLargeMemForward

    c64lib_pushParamW(gameEnd)
    c64lib_pushParamW(ENDGAME_BUFFER_MEM)
    c64lib_pushParamW(84*8)
    jsr copyLargeMemForward

    c64lib_pushParamW(firstSpriteBank)
    c64lib_pushParamW(SPRITES_MEM)
    c64lib_pushParamW(firstSpriteBankEnd - firstSpriteBank)
    jsr copyLargeMemForward

    jsr fillEmptySprite

    c64lib_pushParamW(dasboardCharset)
    c64lib_pushParamW(TEXT_DASHBOARD_CHARS_MEM)
    c64lib_pushParamW(DASHBOARD_CHAR_COUNT*8)
    jsr copyLargeMemForward

    c64lib_pushParamW(thirdSpriteBank) // bat h
    c64lib_pushParamW(SPRITES_BANK3)
    c64lib_pushParamW(thirdSpriteBankEnd - thirdSpriteBank)
    jsr copyLargeMemForward

    c64lib_pushParamW(secondSpriteBank) // deadman & batv
    c64lib_pushParamW(SCREEN_MEM_1)
    c64lib_pushParamW(secondSpriteBankEnd - secondSpriteBank)
    jsr copyLargeMemForward

    c64lib_pushParamW(musicData)
    c64lib_pushParamW(MUSIC_MEM)
    c64lib_pushParamW(musicSize)
    jsr copyLargeMemForward

    rts
}


setNTSC: {
    lda #1
    sta ntscFlag
    rts
}
detectNTSC: {
    lda #0
    sta ntscFlag
    c64lib_detectNtsc(0, setNTSC)
    rts
}


fillEmptySprite: {
    ldx #0
    lda #0
!:
    sta $ff80, x
    inx
    cpx #63
    bne !-

    rts
}

startTitle: {
    jsr hideEyes
    lda #1
    sta gameTitleScreen
    jsr aux_cleanBottomPart
    jsr setColors
    jsr exchangeFonts

    ldx #(MAX_TITLE_TEXT - 1)
    stx txtCounter

    c64lib_pushParamW(txtPressFire)
    c64lib_pushParamW(SCREEN_MEM_1 + 23*40 + 10)
    jsr outText
    jsr displayNext

    rts

    displayNext: {
        ldx txtCounter
        inx
        cpx #MAX_TITLE_TEXT
        bne !+
            ldx #0
        !:
        stx txtCounter

        lda txtPtrLo, x
        sta displayLine.lineAddr
        lda txtPtrHi, x
        sta displayLine.lineAddr + 1
        jsr displayLine

        seq_setUpExt(20, 6, doNothing, displayNext, true)

        rts
    }

    displayLine: {
        lda #0
        ldx #0
        loop:
            sta SCREEN_MEM_1 + 21*40, x
            inx
            cpx #40
        bne loop

        lda #<(SCREEN_MEM_1 + 21*40)
        clc
        adc lineAddr:$ffff
        sta screenLocation
        lda #>(SCREEN_MEM_1 + 21*40)
        adc #0
        sta screenLocation + 1

        clc
        lda lineAddr
        adc #1
        sta lineAddr1
        lda lineAddr + 1
        adc #0
        sta lineAddr1 + 1

        c64lib_pushParamWInd(lineAddr1)
        c64lib_pushParamWInd(screenLocation)
        jsr outText

        rts
        screenLocation: .word 0
        lineAddr1: .word 0
    }
}

startGame: {
    jsr blankScreen
    lda #0
    sta gameTitleScreen
    sta joyAccumulator
    sta joyDelayCounter
    sta joyPreviousValue
    jsr exchangeFonts
    jsr drawScreen
    jsr showEyes
    jsr showScreen
    rts
}

setColors: {
    ldy colorScheme
    ldx #0

    lda colorDarks, y
    sta c64lib.BORDER_COL
    sta c64lib.SPRITE_2_COLOR
    sta c64lib.SPRITE_7_COLOR
    sta eyesColor
loop1:
    .for (var i = 0; i <= 3; i++) {
        sta c64lib.COLOR_RAM + i*200, x
    }
    inx
    cpx #200
    bne loop1

    ldx #0
    lda colorLights, y
    // sta c64lib.BG_COL_0
loop2:
    sta c64lib.COLOR_RAM + 800, x
    inx
    cpx #200
    bne loop2
    ldx #0
loop3:
    cpx #2
    beq !+
        sta c64lib.SPRITE_0_COLOR, x
    !:
    inx
    cpx #7
    bne loop3
    rts
}

exchangeFonts: {
    sei
    c64lib_configureMemory(c64lib.RAM_RAM_RAM)
    ldx #0
    loop:
        ldy FONT_BUFFER_MEM, x
        lda TEXT_DASHBOARD_CHARS_MEM, x
        sta FONT_BUFFER_MEM, x
        tya
        sta TEXT_DASHBOARD_CHARS_MEM, x

        ldy FONT_BUFFER_MEM + 148, x
        lda TEXT_DASHBOARD_CHARS_MEM + 148, x
        sta FONT_BUFFER_MEM + 148, x
        tya
        sta TEXT_DASHBOARD_CHARS_MEM + 148, x

        inx
        cpx #148
    bne loop
    c64lib_configureMemory(c64lib.RAM_IO_RAM)
    cli
    rts
}

startLevel: {
    jsr initRoom
    jsr initGameState
    jsr resetRoomStates
    jsr chooseRoom
    jsr initStaticObjectsCharset
    jsr initStaticObjectsMaterials
    jsr drawPlayfield
    jsr initEffects
    jsr initPlayerPosition
    jsr ani_init
    jsr updatePlayerPosition
    jsr phys_init
    jsr checkBGCollision // TODO: to have collision flag initialized
    jsr initSound
    lda #<copperList
    sta COPPER_LIST_ADDR
    lda #>copperList
    sta COPPER_LIST_ADDR + 1
    jsr startCopper

    loop:
        cld
        jsr turnOneSnake
        jsr changeRoomIfNeeded
        lda objCollisionDetected
        cmp #$ff
        beq !+
            jsr handleObjCollision
        !:
        lda gameState
        cmp #STATE_GAMEOVER
        beq gameOver
        cmp #STATE_ENDOFGAME
        beq endOfGame
    jmp loop

    gameOver: {
        jsr commonEntry
        jsr aux_drawEndGameScreen

        c64lib_pushParamW(txtGameOver)
        c64lib_pushParamW(SCREEN_MEM_0 + 40*13 + 15)
        jsr outText

        c64lib_pushParamW(txtPressFireCnt)
        c64lib_pushParamW(SCREEN_MEM_0 + 40*15 + 9)
        jsr outText

        jmp commonOutry
    }

    endOfGame: {
        jsr commonEntry
        jsr aux_drawEndGameScreen

        c64lib_pushParamW(textEnd0)
        c64lib_pushParamW(SCREEN_MEM_0 + 40*12 + 14)
        jsr outText

        c64lib_pushParamW(textEnd1)
        c64lib_pushParamW(SCREEN_MEM_0 + 40*14 + 4)
        jsr outText

        c64lib_pushParamW(textEnd2)
        c64lib_pushParamW(SCREEN_MEM_0 + 40*15 + 11)
        jsr outText

        c64lib_pushParamW(txtPressFireCnt)
        c64lib_pushParamW(SCREEN_MEM_0 + 40*17 + 9)
        jsr outText

        jmp commonOutry
    }

    commonEntry: {
        jsr playboardFadeOut
        waitFor()

        lda #0
        sta c64lib.SPRITE_ENABLE
        jsr aux_copyEndGameData
        rts
    }

    commonOutry: {
        jsr playboardFadeIn
        waitFor()

        !:
            jsr io_scanJoy
            and #%00011111
            eor #%00011111
            sta io_oldJoy
            cmp #%00010000
        bne !-

        jsr playboardFadeOut
        waitFor()

        jsr stopCopper

        lda #0
        sta gameState
        lda #1
        sta gameTitleScreen

        jsr startTitle
        jmp startLevel
    }
}

resetRoomStates: {
    ldx #0
    lda #$ff
    !:
        sta level_roomStates, x
        inx
        cpx #30
        bne !-
    rts
}

.macro checkCopperHalt() {
    lda gameState
    beq !+
        rts
    !:
    lda roomChange
    cmp #$ff
    beq !+
        rts
    !:
}

doEachFrameTop: {
    cld

    lda #%00000010
    sta c64lib.MEMORY_CONTROL
    
    lda currentColor
    sta c64lib.BG_COL_0
    ldx #0
    !:
        cpx #2
        beq skip
            sta c64lib.SPRITE_0_COLOR, x
        skip:
        inx
        cpx #7
    bne !-
    lda eyesColor
    sta c64lib.SPRITE_7_COLOR

    c64lib_debugBorderEnd()
    jsr playMusic
    c64lib_debugBorderStart()

    checkCopperHalt()

    c64lib_debugBorderStart()

    // clear collision register
    lda c64lib.SPRITE_2S_COLLISION

    jsr io_scanJoy
    ldx gameTitleScreen
    bne !+
        jsr dispatchPlayerCommand
        jmp !++
    !:
        jsr handleTitleScreenCommand
    !:

    jsr phys_transitState
    jsr onStateChange

    jsr phys_executeState
    jsr onStateChange // TODO another problem: execute state transits state

    lda playerDying
    bne noAction1
        jsr checkBGCollision // TODO big problem this must be run twice per a loop

        lda physPlayerBGCollision
        and #BG_CLSN_KILLING
        beq !+
            lda playerDying
            bne !+
                jsr killPlayer
        !:
    noAction1:

    // check for die request (main -> raster thread communication)
    lda playerDieRequest
    beq !+
        lda #0
        sta playerDieRequest
        jsr killPlayer
    !:

    // killing for snakes
    lda gameCheatState
    and #CHEAT_SPRITE_INVINCIBLE
    bne skipActorCollisions

    lda actorCollisions
    beq !+
        // kill the enemy from the screen (only works for sprites)
        jsr findCollidingSprite
        cpx #MAX_SPRITES
        beq !+

        lda spriteMask, x
        eor #$ff
        and c64lib.SPRITE_ENABLE
        sta c64lib.SPRITE_ENABLE
    
        // update game state
        lda enemiesToObjects, x
        tax
        lda objMask, x
        eor #$ff
        ldx currentChamberNumber
        and level_roomStates, x
        sta level_roomStates, x

        // check potion in inventory
        ldy #SO_POTION
        jsr findItemInInventory
        cpx #INV_NOT_FOUND
        beq noPotion

        // use potion
        jsr blinkEyes
        jsr removeItemFromInventory

        // add points
        lda #<PTS_KILL
        ldx #>PTS_KILL
        jsr addGameScore

        lda c64lib.SPRITE_2S_COLLISION // clear collision register
        jmp !+

        // otherwise kill the player
        noPotion:
        lda playerDying
        bne !+
            jsr killPlayer

!:
    skipActorCollisions:

    // clear collisions
    lda #0
    sta actorCollisions

    // was in frame bottom
    lda playerDying
    bne !+
        jsr phys_blockMovement
        jsr checkBGCollision
    !:
    jsr onStateChange // and block movement transits state

    // update colX
    jsr phys_player2charX
    stx playerColX
    jsr phys_player2charY
    sty playerColY

    //  check bg object collisions
    lda physPlayerBGCollisionObj
    and #BG_CLSN_COLLECTIBLE
    beq !+
        jsr findObjCollision
        cpx #$ff
        beq !+
            lda objCollisionDetected
            cmp #$ff
            bne !+
                stx objCollisionDetected
    !:

    jsr checkForRoomChange

    // update enemy actors
    jsr runActors

    c64lib_debugBorderEnd()
    rts
}

findCollidingSprite: {
    ldx #0
    loop:
        lda actorCollisions
        and spriteMask, x
        bne !+
        inx
        cpx #MAX_SPRITES
        beq !+
        jmp loop
    !:
    rts
}

doEachFrameVisual: {
    cld
    // only visible stuff, to be executed out of the visible area
    jsr seq_play
    checkCopperHalt()

    c64lib_debugBorderStart()

    ldx #0
    jsr ani_animatePlayer
    ldx #0
    !:
        cpx enemiesCounter
        beq skip
        inx
        stx ZR_0
        jsr ani_animatePlayer
        ldx ZR_0
    jmp !-

    skip:

    c64lib_debugBorderStart()
    jsr updatePlayerPosition
    c64lib_debugBorderEnd()
    jsr playEffects
    jsr moveActors
    jsr actor_checkCollision

    c64lib_debugBorderEnd()
    rts
}

showEyes: {
    lda c64lib.SPRITE_MSB_X
    and #%01111111
    sta c64lib.SPRITE_MSB_X
    lda c64lib.SPRITE_ENABLE
    ora #%10000000
    sta c64lib.SPRITE_ENABLE

    lda eyesColor
    sta c64lib.SPRITE_7_COLOR
    lda #176
    sta c64lib.SPRITE_7_X
    lda #227
    sta c64lib.SPRITE_7_Y
    rts
}

hideEyes: {
    lda c64lib.SPRITE_ENABLE
    and #%01111111
    sta c64lib.SPRITE_ENABLE
    rts
}

blinkEyes: {
    lda #0
    sta fadeCounter
    seq_setUp(EYE_FADE_DELAY, 4, fadeInCallback, doNothing)
    rts
    fadeInCallback: {
        ldx fadeCounter
        lda fadeIn, x
        sta eyesColor
        inc fadeCounter
        rts
    }
}

killPlayer: {
    lda #1
    sta playerDying 
    jsr phys_die
    seq_setUp(DIE_DELAY, 10, doNothing, dieSequenceFinished)
    rts

    dieSequenceFinished: {
        jsr respawnPlayerPosition
        lda playerRespawnState
        cmp #STATE_JUMPING_LEFT
        bne !+
            lda #STATE_FALLING_DOWN_FACING_LEFT
        !:
        cmp #STATE_JUMPING_RIGHT
        bne !+
            lda #STATE_FALLING_DOWN_FACING_RIGHT
        !:
        jsr phys_forceTransitState
        jsr onStateChange
        jsr checkBGCollision
        lda #0
        sta playerDying
        lda gameCheatState
        and #CHEAT_INFINITE_LIVES
        bne infiniteLives
        dec gameLivesLeft
        bne !+
            lda #STATE_GAMEOVER
            sta gameState
        !:
        jsr drawLives
        infiniteLives:
        rts
    }
}

// out X -> found object id or $ff if none is found
findObjCollision: {
    clc
    lda playerColX
    adc #1
    sta normColLeft
    adc #3
    sta normColRight
    clc
    lda playerColY
    adc #1
    sta normRowTop
    adc #3
    sta normRowBottom

    ldx #0
    loop:
        ldy currentChamberNumber
        lda level_roomStates, y
        and objMask, x
        beq noCollision

        jsr getObjectControl
        and #%00001111
        cmp #SO_DOOR
        beq set4
        cmp #SO_DOORCODE
        beq set4
        lda #1
        sta addOtherSide.value
        
    continue:
        jsr getObjectPositionX
        sta objPos

        lda normColRight
        cmp objPos
        beq !+
            bcc noCollision     // Pla >> Obj
        !:

        jsr addOtherSide    // Obj := Obj + Epsilon

        lda normColLeft
        cmp objPos
        beq !+
            bcs noCollision             
        !:

        jsr getObjectPositionY
        sty objPos

        lda normRowBottom
        cmp objPos
        bcc noCollision

        jsr addOtherSide
        lda normRowTop

        cmp objPos

        beq !+
            bcs noCollision
        !:

        rts // found X -> object number
        noCollision:
            inx
            cpx staticObjectCount
            beq !+
                cpx #8
                bne loop
            !:
    ldx #$ff
    rts
    set4: {
        lda #4
        sta addOtherSide.value
        jmp continue
    }
    addOtherSide: {
        clc
        lda objPos
        adc value:#1
        sta objPos
        rts
    }
    normColLeft:    .byte 0
    normColRight:   .byte 0
    normRowTop:     .byte 0
    normRowBottom:  .byte 0
    objPos:         .byte 0
}

// in X -> obj id to be handled
handleObjCollision: {
    ldx objCollisionDetected
    jsr getObjectControl
    and #%00001111
    cmp #SO_KEY
    bne !+
        jmp handleKey
    !:
    cmp #SO_JEWEL
    bne !+
        jmp handleJewel
    !:
    cmp #SO_POTION
    bne !+
        jmp handlePotion
    !:
    cmp #SO_KEYCODE
    bne !+
        jmp handleKeyCode
    !:
    cmp #SO_SNAKE_L
    bne !+
        jmp handleSnake
    !:
    cmp #SO_SNAKE_R
    bne !+
        jmp handleSnake
    !:
    cmp #SO_DOOR
    bne !+
        jmp handleDoor
    !:
    cmp #SO_DOORCODE
    bne !+
        jmp handleDoorCode
    !:
    lda #$ff
    sta objCollisionDetected
    rts
    handleKey:
        txa
        pha
        jsr collectItemToInventory
        pla
        tax
        bcc !+
            lda #$ff
            sta objCollisionDetected
            jmp doNothing
        !:
        jmp wipeOut
    handleJewel:
        txa
        pha
        jsr collectItemToInventory
        lda #<PTS_JEWEL
        ldx #>PTS_JEWEL
        jsr addGameScore
        pla
        tax
        jmp wipeOut
    handlePotion:
        txa
        pha
        jsr collectItemToInventory
        bcc !+
            pla
            tax
            lda #$ff
            sta objCollisionDetected
            jmp doNothing
        !:
        lda #<PTS_POTION
        ldx #>PTS_POTION
        jsr addGameScore
        pla
        tax
        jmp wipeOut
    handleKeyCode:
        txa
        pha
        jsr collectItemToInventory
        pla
        tax
        bcc !+
            lda #$ff
            sta objCollisionDetected
            jmp doNothing
        !:
        jmp wipeOut
    handleSnake:
        txa
        pha
        // check potion in inventory
        ldy #SO_POTION
        jsr findItemInInventory
        cpx #INV_NOT_FOUND
        beq noPotion

        // use potion
        jsr blinkEyes
        jsr removeItemFromInventory

        // add points
        lda #<PTS_KILL
        ldx #>PTS_KILL
        jsr addGameScore

        jmp !+

        // otherwise kill the player
        noPotion:
        lda playerDying

        // TODO add cheat mode here!
        bne !+
            lda #1
            sta playerDieRequest
        !:

        pla
        tax
        jmp wipeOut
    handleDoor:
        txa
        pha
        ldy #SO_KEY
        jsr findItemInInventory
        cpx #INV_NOT_FOUND
        beq notFound
        jsr removeItemFromInventory
        pla
        tax
        jmp wipeOutDoor
    handleDoorCode:
        txa
        pha
        ldy #SO_KEYCODE
        jsr findItemInInventory
        cpx #INV_NOT_FOUND
        beq notFound
        jsr removeItemFromInventory
        pla
        tax
        jsr wipeOutDoor
        lda #STATE_ENDOFGAME
        sta gameState
        rts
    notFound:
        pla
        tax // deliberately takes next rts
    doNothing:
        rts

    wipeOutCommon: {
        // turn off object in the state
        ldy currentChamberNumber
        lda level_roomStates, y
        eor objMask, x
        sta level_roomStates, y

        // wipe out the object from screen
        lda #<wipeOutData
        sta MAIN_SOURCE_PTR
        lda #>wipeOutData
        sta MAIN_SOURCE_PTR + 1
        rts
    }
    wipeOut: {
        jsr wipeOutCommon

        jsr getObjectPositionY
        jsr getObjectPositionX

        jsr draw2x2m
        lda #$ff
        sta objCollisionDetected
        rts
    }
    wipeOutDoor: {
        jsr wipeOutCommon

        jsr getObjectPositionY
        sty storeY
        jsr getObjectPositionX
        sta storeX

        jsr draw2x2m
        lda storeX
        ldy storeY
        iny 
        iny
        jsr draw2x2m
        inc storeX
        inc storeX
        lda storeX
        ldy storeY
        jsr draw2x2m
        lda storeX
        ldy storeY
        iny
        iny
        jsr draw2x2m

        lda #$ff
        sta objCollisionDetected
        rts
        storeX: .byte 0
        storeY: .byte 0
    }
    wipeOutData: .fill 4, 0 // 2x2 wipeout block
}

initGameState: {
    lda #INITIAL_LIVES
    sta gameLivesLeft
    lda #$00
    sta gameScore
    sta gameScore + 1
    sta gameScore + 2
    sta gameInventory
    sta gameInventory + 1
    sta gameInventory + 2
    sta gameInventory + 3
    rts
}

// IN: A score low, ZR_0 score hi
addGameScore: {
    sed
    clc
    adc gameScore
    sta gameScore
    txa
    adc gameScore + 1
    sta gameScore + 1
    lda #0
    adc gameScore + 2
    sta gameScore + 2
    cld
    jmp drawScore
}

// in: X item to be removed
removeItemFromInventory: {
    loop:
        lda gameInventory + 1, x
        sta gameInventory, x
        inx
        cpx #4
    bne loop
    lda #0
    sta gameInventory + 3
    jsr drawInventory
    rts
}

// in: Y item code to be found
// out: X found potion or 4 if not found
findItemInInventory: {
    sty itemCode
    ldx #0
    loop:
        lda gameInventory, x
        cmp itemCode:#SO_POTION
        beq end
        inx
        cpx #4
        beq end
        jmp loop
    end:
    rts
}

// in: A item type; out: X found item or 4 if not found
findLastItemInInvetory: {
    sta item
    ldx #4
    loop:
        dex
        lda gameInventory, x
        cmp item:#SO_POTION
        bne !+
            rts
        !:
        cpx #0
    bne loop
    ldx #4
    rts
}

collectItemToInventory: {
    jsr blinkEyes
    jsr getObjectControl
    and #%00001111
    sta item
    cmp #SO_POTION
    bne !+
        jmp findAndCollect
    !:
    cmp #SO_KEY
    bne !+++
        jsr findAndCollect
        bcs !+
            rts
        !:
        lda #SO_POTION
        jsr findLastItemInInvetory
        cpx #4
        bne !+
            rts
        !:
        jsr removeItemFromInventory
        jmp findAndCollect
    !:
    cmp #SO_KEYCODE
    bne !+++
        jsr findAndCollect
        bcs !+
            rts
        !:
        lda #SO_POTION
        jsr findLastItemInInvetory
        cpx #4
        bne !+
            lda #SO_KEY
            jsr findLastItemInInvetory
            cpx #4
            bne !+
                rts
        !:
        jsr removeItemFromInventory
        jmp findAndCollect
    !:
    clc
    rts

    findAndCollect: {
        jsr findFreeSlot
        cpx #4
        beq !+
            jmp collect
        !:
        sec
        rts
    }
    findFreeSlot: {
        ldx #0
        loop:
            lda gameInventory, x
            bne !+
                rts
            !:
            inx
            cpx #4
        bne loop
        rts
    }
    collect: {
        lda item
        sta gameInventory, x
        jsr drawInventory
        clc
        rts
    }
    item: .byte 0
}

runActors: {
    ldx #0
    cpx enemiesCounter
    bne !+
        rts
    !:

    loop:
        stx ZR_0
        lda enemiesToObjects, x
        tax
        jsr getObjectControl
        ldx ZR_0
        and #%00001111
        cmp #SO_SKULL
        bne !+
            jmp runSkull
        !:
        cmp #SO_BAT
        bne !+
            jmp runBat
        !:
        cmp #SO_BAT_VERTICAL
        bne !+
            jmp runSkull
        !:
        cmp #SO_DEAD
        bne !+
            jmp runDead
        !:
        continue:
        inx
        cpx enemiesCounter
    bne loop

    rts

    runSkull: {
        lda actorValue2, x
        bne !+
            jmp continue
        !:

        jsr incrementCounter
        lda actorModes
        and spriteMask, x
        beq !+
            lda #STEP_SKULLx1
            sta speed1
            sta speed2
            jmp !++
        !:
            lda #STEP_SKULLx2
            sta speed1
            sta speed2
        !:
        lda actorDirections
        and spriteMask, x
        beq moveDown
        // move up
            sec
            lda actorPositionY, x
            sbc speed1:#STEP_SKULLx2
            sta actorPositionY, x
            jmp continue
        moveDown:
            clc
            lda actorPositionY, x
            adc speed2:#STEP_SKULLx2
            sta actorPositionY, x
            jmp continue
    }

    // this one uses ZR_1 as additional accumulator (ZR_1 stores next Y adjustment value)
    runBat: {
        // set up path reading
        lda actorValue2, x
        stx storeX
        tax
        lda pathLengths, x
        sta fetchNext.cmpPathLength
        sta updateDirection.value
        lda pathsPtrsLo, x
        sta readPath.address
        lda pathsPtrsHi, x
        sta readPath.address + 1
        ldx storeX
        jsr updateDirection

        // check if decrunch
        lda actorDepackCounter, x
        beq nextForDecrunch
            // decrunch
            lda actorDepackValue, x
            sta ZR_1
            dec actorDepackCounter, x
            bne !+
                jmp nextForDecrunch
            !:
            jmp updatePositions

        nextForDecrunch:
            jsr fetchNext

        updatePositions:

        lda direction
        beq !+
            sec
            lda actorPositionY, x
            sbc ZR_1
            jmp !++
        !:
            clc
            lda ZR_1
            adc actorPositionY, x
        !:
        sta actorPositionY, x

        lda actorDirections
        and spriteMask, x
        beq moveRight
        // move left
            sec
            lda actorPositionX, x
            sbc #STEP_BAT
            sta actorPositionX, x
            jmp !+
        moveRight:
            clc
            lda actorPositionX, x
            adc #STEP_BAT
            sta actorPositionX, x
        !:
        jmp continue
        // vars
        storeX:     .byte 0
        direction:  .byte 0

        // subs
        readPath: {
            lda address:$ffff, x
            rts
        }

        fetchNext: {
            lda enemiesCounters, x
            cmp cmpPathLength:#$ff
            bne readNext
                lda actorDirections
                eor spriteMask, x
                sta actorDirections
                stx storeX
                lda actorDirections
                and spriteMask, x
                bne !+
                    txa
                    tay
                    iny
                    ldx #ANIM_BAT_RIGHT
                    jsr ani_setAnimation
                    jmp cont
                !:
                    txa
                    tay
                    iny
                    ldx #ANIM_BAT_LEFT
                    jsr ani_setAnimation
                cont:
                    ldx storeX
                    jsr updateDirection
                    jsr incEnemies // hack, but it works
                    jsr incEnemies
            readNext:
                stx storeX
                lda enemiesCounters, x
                jsr incEnemies
                jsr incEnemies
                tax
                jsr readPath
                ldy storeX
                sta actorDepackCounter, y
                inx
                jsr readPath
                sta actorDepackValue, y
                sta ZR_1
                ldx storeX
            rts
        }
        incEnemies: {
            instr:inc enemiesCounters, x
            rts
        }
        updateDirection: {
            lda actorDirections
            and spriteMask, x
            sta direction
            bne !+
                // right
                lda #INC_ABSX
                sta incEnemies.instr
                lda value:#0
                sta fetchNext.cmpPathLength
                jmp !++
            !:
                // left
                lda #DEC_ABSX
                sta incEnemies.instr
                lda #(-2) // hack, but it works!
                sta fetchNext.cmpPathLength
            !:
            rts
        }
    }

    runDead: {
        jsr incrementCounter
        bcc !++
            // direction changed
            stx storeX
            lda actorDirections
            and spriteMask, x
            bne !+
                txa
                tay
                iny
                ldx #ANIM_DEADMAN_RIGHT
                jsr ani_setAnimation
                jmp cont
            !:
                txa
                tay
                iny
                ldx #ANIM_DEADMAN_LEFT
                jsr ani_setAnimation
            cont:
                ldx storeX
        !:
        lda actorDirections
        and spriteMask, x
        beq moveRight
        // move left
            sec
            lda actorPositionX, x
            sbc #STEP_DEADMAN
            sta actorPositionX, x
            jmp continue
        moveRight:
            clc
            lda actorPositionX, x
            adc #STEP_DEADMAN
            sta actorPositionX, x
            jmp continue
        // vars
        storeX: .byte 0
    }

    incrementCounter: 
        clc
        inc enemiesCounters, x
        lda enemiesCounters, x
        cmp actorValue2, x
        bne !+
            lda #0
            sta enemiesCounters, x
            lda actorDirections
            eor spriteMask, x
            sta actorDirections
            sec
        !:
        rts
}

moveActors: {
    ldx #0
    cpx enemiesCounter
    bne !+
        rts
    !:

    loop:
        lda spriteYPos.lo, x
        sta posYAddr
        lda spriteYPos.hi, x
        sta posYAddr + 1
        lda spriteXPos.lo, x
        sta posXAddr
        lda spriteYPos.hi, x
        sta posXAddr + 1
        
        lda actorPositionY, x
        sta posYAddr:$ffff
        lda actorPositionX, x
        asl
        sta ZR_0
        jsr setMSB
        lda ZR_0
        sta posXAddr:$ffff
        inx
        cpx enemiesCounter
    bne loop
    rts

    setMSB: {
        bcc !+
            lda c64lib.SPRITE_MSB_X
            ora spriteMask, x
            sta c64lib.SPRITE_MSB_X
            rts
        !:
        lda spriteMask, x
        eor #$ff
        and c64lib.SPRITE_MSB_X
        sta c64lib.SPRITE_MSB_X
        rts
    }
    spriteXPos: .lohifill ANI_MAX_ACTORS, c64lib.SPRITE_3_X + 2*i
    spriteYPos: .lohifill ANI_MAX_ACTORS, c64lib.SPRITE_3_Y + 2*i
}

spriteMask: .byte %00001000, %00010000, %00100000, %01000000, %10000000
objMask:    .byte 1, 2, 4, 8, 16, 32, 64, 128

onStateChange: {
    lda _phys_stateChange
    beq !+
        ldx physPlayerAnimation
        ldy #ANI_ACTOR_PLAYER
        jsr ani_setAnimation
        lda #0
        sta _phys_stateChange
    !:
    rts
}

doNothing: {
    rts
}

doTriggerWait: {
    lda #0
    sta waitFor
    rts
}

drawScreen: {
    jsr drawDashboard
    jsr drawLives
    jsr drawScore
    jsr drawInventory
    rts
}

initRoom: {
    lda level_startRoom
    sta currentChamberNumber
    lda level_startState
    sta phys_initialState
    sta playerRespawnState
    lda #$ff
    sta roomChange
    sta objCollisionDetected
    sta drawCommand
    lda #0
    sta playerDieRequest // TODO should it be there?
    sta actorCollisions
    sta gameState
    rts
}

chooseRoom: {
    ldx currentChamberNumber
    // set chamber map
    lda level_roomPtr.lo, x
    sta chamberMapAddr
    lda level_roomPtr.hi, x
    sta chamberMapAddr + 1
    // set static objects
    lda level_objectControlPtr.lo, x
    sta getObjectControl.address
    sta setObjectControl.address
    lda level_objectControlPtr.hi, x
    sta getObjectControl.address + 1
    sta setObjectControl.address + 1

    lda level_objectPositionXPtr.lo, x
    sta getObjectPositionX.address
    lda level_objectPositionXPtr.hi, x
    sta getObjectPositionX.address + 1

    lda level_objectPositionYPtr.lo, x
    sta getObjectPositionY.address
    lda level_objectPositionYPtr.hi, x
    sta getObjectPositionY.address + 1
    
    lda level_objectSizes, x
    sta staticObjectCount
    // set additional moveable object data
    lda level_movableObjectValue2Ptr.lo, x
    sta getObjectValue2.address
    lda level_movableObjectValue2Ptr.hi, x
    sta getObjectValue2.address + 1

    rts
}

checkForRoomChange: {
    ldx currentChamberNumber
    lda #ROOM_NORTH_LIMIT
    cmp physPlayerY
    bcs transitN
    lda physPlayerY
    cmp #ROOM_SOUTH_LIMIT
    bcs transitS
    lda physPlayerX + 1
    bne checkE
        lda #ROOM_WEST_LIMIT
        cmp physPlayerX
        bcs transitW
        rts
    checkE:
        lda physPlayerX
        cmp #ROOM_EAST_LIMIT
        bcs transitE
    rts
    transitN: {
        lda #ROOM_TRANSIT_DIRECTION_NORTH
        sta roomChangeDirection
        lda level_roomExitsN, x
        jmp end
    }
    transitE: {
        lda #ROOM_TRANSIT_DIRECTION_EAST
        sta roomChangeDirection
        lda level_roomExitsE, x
        jmp end
    }
    transitS: {
        lda #ROOM_TRANSIT_DIRECTION_SOUTH
        sta roomChangeDirection
        lda level_roomExitsS, x
        jmp end
    }
    transitW: {
        lda #ROOM_TRANSIT_DIRECTION_WEST
        sta roomChangeDirection
        lda level_roomExitsW, x
        jmp end
    }
    end: 
    sta roomChange
    rts
}

showEnemies: {
    lda c64lib.SPRITE_ENABLE
    and #%10000111
    sta c64lib.SPRITE_ENABLE
    lda enemiesCounter
    cmp #0
    bne !+
        rts
    !:
    ldx #0
    loop:
        stx ZR_0
        lda enemiesToObjects, x
        tax

        cpx #8
        bcs !+
        ldy currentChamberNumber
        lda level_roomStates, y
        and objMask, x
        bne !+
            jmp continueHidden
        !:
        jsr getObjectControl
        and #%00001111
        cmp #SO_SKULL
        bne !+
            jmp doSkull
        !:
        cmp #SO_BAT_VERTICAL
        bne !+
            jmp doBatVertical
        !:
        cmp #SO_DEAD
        bne !+
            jmp doDeadman
        !:
        cmp #SO_BAT
        bne !+
            jmp doBat
        !:
        continue:
        ldx ZR_0
        lda c64lib.SPRITE_ENABLE
        ora spriteMask, x
        sta c64lib.SPRITE_ENABLE
        continueHidden:
        ldx ZR_0
        inx
        cpx enemiesCounter
    bne loop

    rts

    doSkull: {
        ldy ZR_0
        iny
        ldx #ANIM_SKULL
        jsr ani_setAnimation
        jmp continue
    }

    doBatVertical: {
        ldy ZR_0
        iny
        ldx #ANIM_BAT_VERTICAL
        jsr ani_setAnimation
        jmp continue
    }

    doDeadman: {
        ldy ZR_0
        iny
        ldx #ANIM_DEADMAN_RIGHT
        jsr ani_setAnimation
        jmp continue
    }

    doBat: {
        ldy ZR_0
        lda #0
        sta actorDepackValue, y
        sta actorDepackCounter, y
        iny
        ldx #ANIM_BAT_RIGHT
        jsr ani_setAnimation
        jmp continue
    }
}

nextColorScheme: {
    lda c64lib.CONTROL_1
    and #%11101111
    sta c64lib.CONTROL_1
    ldx colorScheme
    inx
    cpx #MAX_COLOR_SCHEME
    bne !+
        ldx #0
    !:
    stx colorScheme
    lda colorLights, x
    sta currentColor
    sta fadeIn
    lda colorDarks, x
    sta fadeIn + 3
    sta fadeOut
    sta dashboardColor + 2
    jsr setColors
    lda c64lib.CONTROL_1
    ora #%00010000
    sta c64lib.CONTROL_1
    rts
}

changeRoomIfNeeded: {
    lda roomChange
    cmp #$ff
    bne !+
        jmp end
    !:
        lda #$ff
        sta playerColX
        // redraw room
        lda currentChamberNumber
        cmp #29 // title screen
        bne !+
            jsr startGame
        !:
        lda roomChange
        sta currentChamberNumber
        jsr chooseRoom

        jsr playboardFadeOut
        waitFor()

        
        jsr drawPlayfieldFading
        // set up enemies
        jsr hideEnemiesFaces
        jsr moveActors
        jsr showEnemies
        // reposition Tony
        lda roomChangeDirection
        cmp #ROOM_TRANSIT_DIRECTION_NORTH
        bne !+
            lda #ROOM_TRANSIT_NORTH
            sta physPlayerY
            jmp updatePosition
        !:
        cmp #ROOM_TRANSIT_DIRECTION_SOUTH
        bne !+
            lda #ROOM_TRANSIT_SOUTH
            sta physPlayerY
            jmp updatePosition
        !:
        cmp #ROOM_TRANSIT_DIRECTION_EAST
        bne !+
            lda #<ROOM_TRANSIT_EAST
            sta physPlayerX
            lda #>ROOM_TRANSIT_EAST
            sta physPlayerX + 1
            jmp updatePosition
        !:
        cmp #ROOM_TRANSIT_DIRECTION_WEST
        bne !+
            lda #<ROOM_TRANSIT_WEST
            sta physPlayerX
            lda #>ROOM_TRANSIT_WEST
            sta physPlayerX + 1
            jmp updatePosition
        !:
        jmp endTransit
        updatePosition: {
            jsr physResetActorPosition
            jsr updatePlayerPosition
        }

        lda physPlayerX
        sta playerRespawnPositionX
        lda physPlayerX + 1
        sta playerRespawnPositionX + 1
        lda physPlayerY
        sta playerRespawnPositionY
        lda physPlayerState
        sta playerRespawnState

        jsr playboardFadeIn
        waitFor()

        endTransit:
        lda #$ff
        sta roomChange
    end: rts
}

hideEnemiesFaces: {
    ldx #3
    lda #EMPTY_SPRITE
    !:
        sta SCREEN_MEM_0 + 1024 - 8, x
        inx
        cpx #8
    bne !-
    rts
}

initStaticObjectsCharset: {
    .for (var i = 0; i < 4; i++) {
        copyStaticCharset(level_potion + i*8, SOC_POTION + i)
        copyStaticCharset(level_jewel + i*8, SOC_JEWEL + i)
        copyStaticCharset(level_keycode + i*8, SOC_KEYCODE + i)
        copyStaticCharset(level_key + i*8, SOC_KEY + i)
        copyStaticCharset(level_snakeLeft + i*8, SOC_SNAKE_L + i)
        copyStaticCharset(level_snakeRight + i*8, SOC_SNAKE_R + i)
    }
    .for (var i = 0; i < 10; i++) {
        copyStaticCharset(level_pikes + i*8, SOC_PIKES + i)
    }
    .for (var i = 0; i < 16; i++) {
        copyStaticCharset(level_door + i*8, SOC_DOOR + i)
        copyStaticCharset(level_doorcode + i*8, SOC_DOORCODE + i)
    }
    copyStaticCharset(level_fire, SOC_FLAME_1)
    copyStaticCharset(level_fire + 8, SOC_FLAME_1 + 1)
    copyStaticCharset(level_fire + 32, SOC_FLAME_2)
    copyStaticCharset(level_fire + 32 + 8, SOC_FLAME_2 + 1)
    rts
}

initStonesCharset: {
    .for (var i = 0; i < 44; i++) {
        copyStaticCharset(level_stones + i*8, SOC_STONE + i)
    }
    lda gameCheatState
    and #CHEAT_STONE_INVINCIBLE
    bne !+
        jmp initStonesMaterials
    !:
}

initStonesMaterials: {
    ldx #SOC_STONE
    lda #0
    !:
        sta roomMaterialsBuffer, x
        inx
        cpx #(SOC_STONE + 44)
    bne !-
    lda gameCheatState
    and #CHEAT_STONE_INVINCIBLE
    bne !+
        lda #BG_CLSN_WALL
        ldx #(SOC_STONE + 12)
        sta roomMaterialsBuffer, x
        inx
        lda #BG_CLSN_KILLING
        jsr setMaterials
        inx
        lda #BG_CLSN_WALL
        sta roomMaterialsBuffer, x


        lda #BG_CLSN_WALL
        ldx #(SOC_STONE + 16)
        sta roomMaterialsBuffer, x
        inx
        lda #BG_CLSN_KILLING
        jsr setMaterials
        inx
        lda #BG_CLSN_WALL
        sta roomMaterialsBuffer, x

        lda #BG_CLSN_WALL
        ldx #(SOC_STONE + 34)
        sta roomMaterialsBuffer, x
        inx
        lda #BG_CLSN_KILLING
        jsr setMaterials
        inx
        lda #BG_CLSN_WALL
        sta roomMaterialsBuffer, x

        // chains 
        lda #BG_CLSN_KILLING
        ldx #(SOC_STONE + 0)
        jsr setMaterials
        inx
        jsr setMaterials
        ldx #(SOC_STONE + 20)
        jsr setMaterials
    !:
    rts
setMaterials: 
    sta roomMaterialsBuffer, x
    inx
    sta roomMaterialsBuffer, x
    rts
}

initStaticObjectsMaterials: {
    // killing for pikes
    lda gameCheatState
    and #CHEAT_PIKES_INVINCIBLE
    bne !++
        ldx #(SOC_PIKES + 2)
        lda #BG_CLSN_KILLING
        !:
            sta roomMaterialsBuffer, x
            inx
            cpx #(SOC_PIKES + 10)
        bne !-
    !:
    // killing for flames
    lda #BG_CLSN_KILLING
    ldx #(SOC_FLAME_1 + 2)
    sta roomMaterialsBuffer, x
    inx
    sta roomMaterialsBuffer, x
    ldx #(SOC_FLAME_2 + 2)
    sta roomMaterialsBuffer, x
    inx
    sta roomMaterialsBuffer, x
    // killing for snakes
    lda gameCheatState
    // and #CHEAT_SNAKE_INVINCIBLE
    and #CHEAT_SPRITE_INVINCIBLE
    bne !++
        ldx #(SOC_SNAKE_R + 2)
        lda #BG_CLSN_COLLECTIBLE
        !:
            sta roomMaterialsBuffer, x
            sta roomMaterialsBuffer + 4, x
            inx
            cpx #(SOC_SNAKE_R + 4)
        bne !-
    !:
    // blocking for doors
    lda gameCheatState
    and #CHEAT_PASS_THRU_DOORS
    bne !+++
        ldx #SOC_DOOR
        lda #(BG_CLSN_COLLECTIBLE)
        !:
            sta roomMaterialsBuffer, x
            inx
            cpx #(SOC_DOOR + 16)
        bne !-
        ldx #SOC_DOOR
        lda #(BG_CLSN_WALL + BG_CLSN_COLLECTIBLE)
        !:
            inx
            sta roomMaterialsBuffer, x
            inx
            sta roomMaterialsBuffer, x
            inx
            inx
            cpx #(SOC_DOOR + 16)
        bne !-
    !:
    // blocking for door code
    ldx #SOC_DOORCODE
    lda #(BG_CLSN_COLLECTIBLE)
    !:
        sta roomMaterialsBuffer, x
        inx
        cpx #(SOC_DOORCODE + 16)
    bne !-
    // collectibles
    ldx #SOC_KEY
    lda #BG_CLSN_COLLECTIBLE
    !:
        sta roomMaterialsBuffer, x
        inx
        cpx #(SOC_JEWEL + 4)
    bne !-
    ldx #SOC_KEYCODE
    lda #BG_CLSN_COLLECTIBLE
    !:
        sta roomMaterialsBuffer, x
        inx
        cpx #(SOC_KEYCODE + 4)
    bne !-
    ldx #SOC_POTION
    lda #BG_CLSN_COLLECTIBLE
    !:
        sta roomMaterialsBuffer, x
        inx
        cpx #(SOC_POTION + 4)
    bne !-

    rts
}

.macro copyStaticCharset(obj, charsetPos) {
    lda #<obj
    sta SOURCE_PTR
    lda #>obj
    sta SOURCE_PTR + 1
    ldx #charsetPos
    jsr copyStaticCharsetDest
}

copyStaticCharsetDest: {
    lda targetCharset.lo, x
    sta DEST_PTR
    lda targetCharset.hi, x
    sta DEST_PTR + 1
    jmp copyBitmapChar
}

decodeRoom: {
    ldx currentChamberNumber
    lda level_usedCharsCount, x
    sta comparePrt
    lda level_usedCharsPtr.lo, x
    sta unpackSourcePtr
    lda level_usedCharsPtr.hi, x
    sta unpackSourcePtr + 1

    ldx #0
    unpackCharMapperLoop:
        ldy unpackSourcePtr:$ffff, x // Y - original char code, X - new char code
        txa
        sta roomCharsDecodingBuffer, y
        // translate materials
        lda materials, y
        sta roomMaterialsBuffer, x
        // copy character data
        lda sourceCharset.lo, y
        sta SOURCE_PTR
        lda sourceCharset.hi, y
        sta SOURCE_PTR + 1

        lda targetCharset.lo, x
        sta DEST_PTR
        lda targetCharset.hi, x
        sta DEST_PTR + 1

        jsr copyBitmapChar

        inx
        cpx comparePrt:#00
    bne unpackCharMapperLoop
    rts
}

translateRoom: {
    ldx #0
    loop:
        .for (var i = 0; i <= 3; i++) 
        {
            ldy SCREEN_MEM_0 + i*200, x
            lda roomCharsDecodingBuffer, y
            sta SCREEN_MEM_0 + i*200, x
        }
        inx
        cpx #200
    bne loop
    rts
}

playboardFadeIn: {
    lda #2
    sta fadeCounter
    lda #1
    sta waitFor
    seq_setUp(FADE_DELAY, 3, fadeInCallback, doTriggerWait)
    rts
    fadeInCallback: {
        ldx fadeCounter
        lda fadeIn, x
        sta currentColor
        dec fadeCounter
        rts
    }
}

playboardFadeOut: {
    lda #2
    sta fadeCounter
    lda #1
    sta waitFor
    seq_setUp(FADE_DELAY, 3, fadeOutCallback, doTriggerWait)
    rts
    fadeOutCallback: {
        ldx fadeCounter
        lda fadeOut, x
        sta currentColor
        dec fadeCounter
        rts
    }
}

drawDashboard: grab_drawDashboard(dashboardMap, copyLargeMemForward)

drawLives: {
    ldx #0
    ldy colorScheme
    !:
        lda #DASHBOARD_LIFE_CHAR
        sta SCREEN_MEM_1 + 20*40 + DASHBOARD_LIFE_INDICATOR_POS, x
        lda colorBright, y
        cpx gameLivesLeft
        bcc !+
            lda colorDimmed, y
        !:
        sta c64lib.COLOR_RAM + 20*40 + DASHBOARD_LIFE_INDICATOR_POS, x
        inx
        cpx #DASHBOARD_MAX_LIVES
    bne !--
    rts
}

drawInventory: {
    ldx colorScheme
    lda colorBright, x
    sta setBrightColor.value
    lda colorLights, x
    sta setLightColor.value
    ldx #0
    stx ptr
    loop:
        lda gameInventory, x
        cmp #SO_KEY
        bne !+
            lda #<key
            sta fetchSourceChar.address
            lda #>key
            sta fetchSourceChar.address + 1
            jsr setBrightColor
            jmp next
        !:
        cmp #SO_POTION
        bne !+
            lda #<potion
            sta fetchSourceChar.address
            lda #>potion
            sta fetchSourceChar.address + 1
            jsr setBrightColor
            jmp next
        !:
        cmp #SO_KEYCODE
        bne !+
            lda #<keyCode
            sta fetchSourceChar.address
            lda #>keyCode
            sta fetchSourceChar.address + 1
            jsr setBrightColor
            jmp next
        !:
        lda #<empty
        sta fetchSourceChar.address
        lda #>empty
        sta fetchSourceChar.address + 1
        jsr setLightColor
        next:
            sta color
            txa
            pha
            ldx ptr

            ldy #0
            jsr fetchSourceChar
            sta SCREEN_MEM_1 + 40*20 + DASHBOARD_INVENTORY_START_CHAR, x
            lda color
            sta c64lib.COLOR_RAM + 40*20 + DASHBOARD_INVENTORY_START_CHAR, x
            inx
            iny
            jsr fetchSourceChar
            sta SCREEN_MEM_1 + 40*20 + DASHBOARD_INVENTORY_START_CHAR, x
            lda color
            sta c64lib.COLOR_RAM + 40*20 + DASHBOARD_INVENTORY_START_CHAR, x
            dex
            iny
            jsr fetchSourceChar
            sta SCREEN_MEM_1 + 40*20 + DASHBOARD_INVENTORY_START_CHAR1, x
            lda color
            sta c64lib.COLOR_RAM + 40*20 + DASHBOARD_INVENTORY_START_CHAR1, x
            inx
            iny
            jsr fetchSourceChar
            sta SCREEN_MEM_1 + 40*20 + DASHBOARD_INVENTORY_START_CHAR1, x
            lda color
            sta c64lib.COLOR_RAM + 40*20 + DASHBOARD_INVENTORY_START_CHAR1, x

            clc
            lda ptr
            adc #3
            sta ptr

            pla
            tax
        inx
        cpx #4
    beq !+
    jmp loop
    !:
    rts

    fetchSourceChar: {
        lda address:$ffff, y
        rts
    }
    setBrightColor: {
        lda value:#0
        rts
    }
    setLightColor: {
        lda value:#0
        rts
    }
    empty:      .byte 132, 133, 138, 139
    keyCode:    .byte 155, 156, 157, 158
    potion:     .byte 136, 137, 142, 143
    key:        .byte 134, 135, 140, 141
    ptr:        .byte 0
    color:      .byte 0
}

drawScore: {
    ldx #0
    ldy colorScheme
    lda colorDimmed, y
    sta ZR_0
    .for(var i = 0; i < 3; i++) {
        lda gameScore + 2 - i
        lsr
        lsr
        lsr
        lsr
        pha
        beq !+
            lda colorBright, y
            sta ZR_0
        !:
        pla
        jsr drawDigit
        
        lda gameScore + 2 - i
        and #%00001111
        pha
        beq !+
            lda colorBright, y
            sta ZR_0
        !:
        pla
        jsr drawDigit
    }
    rts
    drawDigit: 
        clc
        adc #DASHBOARD_NUMBER_START_CHAR
        sta SCREEN_MEM_1 + 20*40 + DASHBOARD_SCORE_INDICATOR_POS, x
        lda ZR_0
        sta c64lib.COLOR_RAM + 20*40 + DASHBOARD_SCORE_INDICATOR_POS, x
        inx
        rts
}

drawPlayfield: {
    ldy colorScheme
    lda colorDarks, y
    sta c64lib.BG_COL_0
    jsr drawPlayfieldFading
    ldy colorScheme
    lda colorLights, y
    sta c64lib.BG_COL_0
    sta currentColor
    rts
   
}

drawPlayfieldFading: {
    jsr decodeRoom
    jsr _draw_playfield
    jsr translateRoom
    lda currentChamberNumber
    // TODO: currently rooms with stones are hardcoded in this place!
    cmp #22
    beq copyInStones
    cmp #23
    beq copyInStones
    jmp skipStones
    copyInStones:
        jsr initStonesCharset
    skipStones:
    jsr initObjects
    jsr moveActors // TODO itchy?!
    jsr showEnemies
    rts
}

_draw_playfield: {
    doDraw: grab_drawPlayfield(chamberMapAddr)
}

initObjects: {
    ldx #0 // TODO something is wrong here, why this initalization must be also below?
    stx snakeCounter
    stx pikesCounter
    stx stonesCounter
    stx stoneCurrent
    stx enemiesCounter
    stx actorDirections
    stx actorModes

    ldx staticObjectCount
    bne !+
        jmp end
    !:
    ldx #0 // TODO ???!
    stx snakeCounter
    stx pikesCounter
    stx stonesCounter
    loop:
        stx storeX
        jsr getObjectPositionY
        sty storeY
        jsr getObjectControl
        and #%00001111
        sta control

        // moveable
        cmp #SO_SKULL
        bne !+
            jmp doVerticalEnemy
        !:
        cmp #SO_BAT_VERTICAL
        bne !+
            jmp doVerticalEnemy
        !:
        cmp #SO_DEAD
        bne !+
            jmp doDeadman
        !:
        cmp #SO_BAT
        bne !+
            jmp doBat
        !:

        ldx storeX
        cpx #8
        bcs !+
        ldy currentChamberNumber
        lda level_roomStates, y
        and objMask, x
        bne !+
            // do not display, turned off
            jmp continue
        !:

        ldy storeY
        lda control
        cmp #SO_FLAME_1
        bne !+
            jmp drawFlame1
        !:
        cmp #SO_FLAME_2
        bne !+
            jmp drawFlame2
        !:
        cmp #SO_POTION
        bne !+
            jmp drawPotion
        !:
        cmp #SO_JEWEL
        bne !+
            jmp drawJewel
        !:
        cmp #SO_KEYCODE
        bne !+
            jmp drawKeyCode
        !:
        cmp #SO_KEY
        bne !+
            jmp drawKey
        !:
        cmp #SO_DOOR
        bne !+
            jmp drawDoor
        !:
        cmp #SO_DOORCODE
        bne !+
            jmp drawDoorCode
        !:
        cmp #SO_SNAKE_L
        bne !+
            txa
            ldx snakeCounter
            sta snakesToObjects, x
            inc snakeCounter
            tax
            jsr drawSnakeL
            jmp continue
        !:
        cmp #SO_SNAKE_R
        bne !+
            txa
            ldx snakeCounter
            sta snakesToObjects, x
            inc snakeCounter
            tax
            jsr drawSnakeR
            jmp continue
        !:
        cmp #SO_PIKES
        bne !+
            txa
            ldx pikesCounter
            sta pikesToObjects, x
            tax
            sta ZR_0
            jsr getObjectControl
            lsr
            lsr
            lsr
            lsr
            ldx pikesCounter
            sta pikesCounters, x
            inc pikesCounter
            ldx #0
            jsr drawPikes
            jmp continue
        !:
        cmp #SO_STONE
        bne !+
            txa
            ldx stonesCounter
            sta stonesToObjects, x
            tax
            sta ZR_0
            jsr getObjectControl
            lsr
            lsr
            lsr
            lsr
            ldx stonesCounter
            sta stonesCounters, x
            inc stonesCounter
            ldx #0
            jsr drawStone
            jmp continue
        !:
        continue:
            ldx storeX
            inx
            cpx staticObjectCount
    beq !+
        jmp loop
    !:
    end: rts

    control: .byte 0
    storeX: .byte 0
    storeY: .byte 0

    doVerticalEnemy: {
        txa
        stx ZR_0
        ldx enemiesCounter
        sta enemiesToObjects, x
        tax
        jsr getObjectControl
        sta objectControlStore
        and #%10000000 // TODO cannot use this bit
        beq !+
            ldx enemiesCounter
            lda actorModes
            ora spriteMask, x
            sta actorModes
            lda #LSR
            sta multiply
            jmp !++
        !:
            lda #NOP
            sta multiply
        !:
        lda objectControlStore
        and #%01110000
        lsr
        sta phaseShiftStore // TODO works only for step = 2
        lsr
        ldx enemiesCounter
        sta enemiesCounters, x
        jsr getObjectValue2
        sta actorValue2, x
        // set starting coords
        jsr setStartingCoords
        clc
        lda phaseShiftStore
        multiply: nop
        adc actorPositionY, x
        sta actorPositionY, x
        inc enemiesCounter
        jmp continue
        // local vars
        phaseShiftStore: .byte 0
        objectControlStore: .byte 0
    }

    doDeadman: {
        txa
        stx ZR_0
        ldx enemiesCounter
        sta enemiesToObjects, x
        tax
        jsr getObjectControl
        and #%01110000
        lsr
        lsr
        sta phaseShiftStore
        ldx enemiesCounter
        sta enemiesCounters, x
        jsr getObjectValue2
        sta actorValue2, x
        // set starting coords
        jsr setStartingCoords
        clc
        lda phaseShiftStore
        adc actorPositionX, x
        sta actorPositionX, x
        inc enemiesCounter
        jmp continue
        // local vars
        phaseShiftStore: .byte 0
    }

    doBat: {
        txa
        stx ZR_0
        ldx enemiesCounter
        sta enemiesToObjects, x
        tax
        jsr getObjectControl
        and #%01110000
        lsr
        lsr
        sta phaseShiftStore
        ldx enemiesCounter
        sta enemiesCounters, x
        jsr getObjectValue2
        sta actorValue2, x
        // set starting coords
        jsr setStartingCoords
        clc
        lda phaseShiftStore
        adc actorPositionX, x
        sta actorPositionX, x
        // TODO set Y according to the path
        inc enemiesCounter
        jmp continue
        // local vars
        phaseShiftStore: .byte 0
    }

    setStartingCoords: {
        lda enemiesToObjects, x
        tax
        jsr getObjectPositionX
        ldx enemiesCounter
        asl
        asl
        clc
        adc #12
        sta actorPositionX, x
        lda enemiesToObjects, x
        tax
        jsr getObjectPositionY
        tya
        asl
        asl
        asl
        clc
        adc #54
        ldx enemiesCounter
        sta actorPositionY, x
        rts
    }

    // TODO temporary
    flame1: .byte SOC_FLAME_1, SOC_FLAME_1 + 1
    flame2: .byte SOC_FLAME_2, SOC_FLAME_2 + 1
    potion: .fill 4, SOC_POTION + i
    jewel:  .fill 4, SOC_JEWEL + i
    keyCode: .fill 4, SOC_KEYCODE + i
    key: .fill 4, SOC_KEY + i
    door: .fill 16, SOC_DOOR + i
    doorCode: .fill 16, SOC_DOORCODE + i

    drawFlame1: 
        lda #<flame1
        sta SOURCE_PTR
        lda #>flame1
        jsr _drawRest1x2
        jmp continue
    drawFlame2:
        lda #<flame2
        sta SOURCE_PTR
        lda #>flame2
        jsr _drawRest1x2
        jmp continue
    drawPotion:
        lda #<potion
        sta SOURCE_PTR
        lda #>potion
        jsr _drawRest2x2
        jmp continue
    drawJewel:
        lda #<jewel
        sta SOURCE_PTR
        lda #>jewel
        jsr _drawRest2x2
        jmp continue
    drawKeyCode:
        lda #<keyCode
        sta SOURCE_PTR
        lda #>keyCode
        jsr _drawRest2x2
        jmp continue
    drawKey:
        lda #<key
        sta SOURCE_PTR
        lda #>key
        jsr _drawRest2x2
        jmp continue
    drawDoor:
        lda #<door
        sta SOURCE_PTR
        lda #>door
        jsr _drawDoor
        jmp continue
    drawDoorCode:
        lda #<doorCode
        sta SOURCE_PTR
        lda #>doorCode
        jsr _drawDoor
        jmp continue
    _drawRest1x2:
        sta SOURCE_PTR + 1
        jsr getObjectPositionX
        jmp draw1x2
}

_drawDoor: {
    sta SOURCE_PTR + 1
    lda #4
    sta ZR_0
    jsr getObjectPositionX
    ldx #4
    jmp drawRect
}

_drawRest2x2: {
    sta SOURCE_PTR + 1
    jsr getObjectPositionX
    jmp draw2x2
}

_drawRest2x2m: {
    sta MAIN_SOURCE_PTR + 1
    jsr getObjectPositionX
    jmp draw2x2m
}

drawSnakeL: {
    lda #<snakeL
    sta SOURCE_PTR
    lda #>snakeL
    jsr _drawRest2x2
    rts
}
drawSnakeLm: {
    lda #<snakeL
    sta MAIN_SOURCE_PTR
    lda #>snakeL
    jsr _drawRest2x2m
    rts
}
snakeL: .fill 4, SOC_SNAKE_L + i

drawSnakeR: {
    lda #<snakeR
    sta SOURCE_PTR
    lda #>snakeR
    jsr _drawRest2x2
    rts
}
drawSnakeRm: {
    lda #<snakeR
    sta MAIN_SOURCE_PTR
    lda #>snakeR
    jsr _drawRest2x2m
    rts
}
snakeR: .fill 4, SOC_SNAKE_R + i

drawPikes: {
    lda pikesLo, x
    sta SOURCE_PTR
    lda pikesHi, x
    ldx ZR_0
    jsr _drawRest2x2
    rts
    pikesLo: .byte <pikes0, <pikes1, <pikes2, <pikes3
    pikesHi: .byte >pikes0, >pikes1, >pikes2, >pikes3 
    pikes0: .byte SOC_NULL, SOC_NULL, SOC_PIKES, SOC_PIKES + 1
    pikes1: .byte SOC_NULL, SOC_NULL, SOC_PIKES + 2, SOC_PIKES + 3
    pikes2: .byte SOC_PIKES + 2, SOC_PIKES + 3, SOC_PIKES + 4, SOC_PIKES + 5
    pikes3: .byte SOC_PIKES + 6, SOC_PIKES + 7, SOC_PIKES + 8, SOC_PIKES + 9
}

drawStone: {
    lda stoneLo, x
    sta SOURCE_PTR
    lda stoneHi, x
    sta SOURCE_PTR + 1
    lda #9
    sta ZR_1
    ldx ZR_0
    lda #4
    sta ZR_0
    jsr getObjectPositionX
    ldx ZR_1
    jsr drawRect
    rts
    stoneLo: .byte <stone0, <stone1, <stone2, <stone3, <stone4, <stone5
    stoneHi: .byte >stone0, >stone1, >stone2, >stone3, >stone4, >stone5
    stone0: // ok
        .byte SOC_NULL, SOC_STONE, SOC_STONE + 1, SOC_NULL
        .byte SOC_NULL, SOC_STONE, SOC_STONE + 1, SOC_NULL
        .byte SOC_NULL, SOC_STONE, SOC_STONE + 1, SOC_NULL
        .byte SOC_NULL, SOC_STONE, SOC_STONE + 1, SOC_NULL
        .byte SOC_NULL, SOC_STONE + 2, SOC_STONE + 3, SOC_NULL
        .fill 16, SOC_STONE + 4 + i
    stone1: // ok
        .byte SOC_NULL, SOC_STONE + 20, SOC_STONE + 21, SOC_NULL
        .byte SOC_NULL, SOC_STONE + 20, SOC_STONE + 21, SOC_NULL
        .byte SOC_NULL, SOC_STONE + 20, SOC_STONE + 21, SOC_NULL
        .byte SOC_NULL, SOC_STONE + 20, SOC_STONE + 21, SOC_NULL
        .fill 20, SOC_STONE + 22 + i
    stone2: // ok
        .byte SOC_NULL, SOC_STONE, SOC_STONE + 1, SOC_NULL
        .byte SOC_NULL, SOC_STONE, SOC_STONE + 1, SOC_NULL
        .byte SOC_NULL, SOC_STONE, SOC_STONE + 1, SOC_NULL
        .byte SOC_NULL, SOC_STONE + 2, SOC_STONE + 3, SOC_NULL
        .fill 16, SOC_STONE + 4 + i
        .fill 4, SOC_NULL
    stone3: // ok
        .byte SOC_NULL, SOC_STONE + 20, SOC_STONE + 21, SOC_NULL
        .byte SOC_NULL, SOC_STONE + 20, SOC_STONE + 21, SOC_NULL
        .fill 20, SOC_STONE + 22 + i
        .fill 8, SOC_NULL
    stone4: // ok
        .byte SOC_NULL, SOC_STONE + 2, SOC_STONE + 3, SOC_NULL
        .fill 16, SOC_STONE + 4 + i
        .fill 16, SOC_NULL
    stone5: // ok
        .fill 16, SOC_STONE + 26 + i
        .fill 20, SOC_NULL
}

turnOneSnake: {
    ldy playerColX
    cpy #$ff
    bne !+
        // playerColX not yet ready, skip
        rts
    !:
    ldy #0
    cpy snakeCounter
    bne !+
        rts
    !:
    loop:
        // check is snake is still alive
        ldx snakesToObjects, y
        lda objMask, x
        ldx currentChamberNumber
        and level_roomStates, x
        beq continue

        ldx snakesToObjects, y
        jsr getObjectPositionX
        cmp playerColX
        bcc playerLeftToSnake
            jmp turnRight
        playerLeftToSnake:
            jmp turnLeft
    continue:
        iny
        cpy snakeCounter
        bne loop
    rts
    turnLeft: {
        ldx snakesToObjects, y
        jsr getObjectControl
        and #%00001111
        cmp #SO_SNAKE_L
        beq !+
            jmp continue
        !:
        lda #SO_SNAKE_R
        jsr setObjectControl
        // draw snake
        jsr getObjectPositionY
        jsr drawSnakeRm
        rts
    }
    turnRight: {
        ldx snakesToObjects, y
        jsr getObjectControl
        and #%00001111
        cmp #SO_SNAKE_R
        beq !+
            jmp continue
        !:
        lda #SO_SNAKE_L
        jsr setObjectControl
        // draw snake
        jsr getObjectPositionY
        jsr drawSnakeLm
        rts
    }
}

draw1x2: grab_draw1x2(chamberLines)
draw2x2: grab_draw2x2(chamberLines, SOURCE_PTR)
draw2x2m: grab_draw2x2(chamberLines, MAIN_SOURCE_PTR)
drawRect: grab_drawRect(chamberLines)

copyBitmapChar: grab_copyBitmapChar(true)

initEffects: {
    lda #0
    sta effectCounter
    sta efxFlame1Phase
    sta efxJewelPhase
    sta efxSnakePhase
    lda #2
    sta efxFlame2Phase
    rts
}

playEffects: {
    inc effectCounter
    lda #MAX_EFFECTS
    cmp effectCounter
    bne !+
        lda #0
        sta effectCounter
    !:
    lda effectCounter
    _checkEfx(EFX_ANIM_FLAME, animFlame)
    _checkEfx(EFX_ANIM_SNAKE, animSnake)
    _checkEfx(EFX_ANIM_JEWEL, animJewel)
    _checkEfx(EFX_RUN_PIKES_1, runPikes)
    _checkEfx(EFX_RUN_STONE_1, runStones)
    _checkEfx(EFX_RUN_STONE_2, runStones)
    _checkEfx(EFX_RUN_STONE_3, runStones)
    _checkEfx(EFX_RUN_PIKES_2, runPikes)
    end: rts

    animJewel: {
        // set source 1
        inc efxJewelPhase
        lda efxJewelPhase
        cmp #4
        bne !+
            lda #0
            sta efxJewelPhase
        !:
        lda efxJewelPhase
        asl
        asl
        asl
        asl
        asl
        
        // do jewel
        ldx #SOC_JEWEL
        copyChar(level_jewel)
        copyChar(level_jewel + 8)
        copyChar(level_jewel + 16)
        copyChar(level_jewel + 24)

        // do keycode
        ldx #SOC_KEYCODE
        copyChar(level_keycode)
        copyChar(level_keycode + 8)
        copyChar(level_keycode + 16)
        copyChar(level_keycode + 24)

        rts
    }
    animSnake: {
        // set source 1
        inc efxSnakePhase
        lda efxSnakePhase
        cmp #4
        bne !+
            lda #0
            sta efxSnakePhase
        !:
        lda efxSnakePhase
        asl
        asl
        asl
        asl
        asl
        
        // do snake L
        ldx #SOC_SNAKE_L
        copyChar(level_snakeLeft)
        copyChar(level_snakeLeft + 8)
        copyChar(level_snakeLeft + 16)
        copyChar(level_snakeLeft + 24)

        // do snake R
        ldx #SOC_SNAKE_R
        copyChar(level_snakeRight)
        copyChar(level_snakeRight + 8)
        copyChar(level_snakeRight + 16)
        copyChar(level_snakeRight + 24)
        rts
    }
    animFlame: {
        inc efxFlame1Phase
        lda efxFlame1Phase
        cmp #4
        bne !+
            lda #0
            sta efxFlame1Phase
        !:
        lda efxFlame1Phase
        asl
        asl
        asl
        asl

        // set flame 1
        ldx #SOC_FLAME_1
        copyChar(level_fire)
        copyChar(level_fire + 8)
        
        asl

        // set potion
        ldx #SOC_POTION
        copyChar(level_potion)
        copyChar(level_potion + 8)
        copyChar(level_potion + 16)
        copyChar(level_potion + 24)

        // set flame 2
        inc efxFlame2Phase
        lda efxFlame2Phase
        cmp #4
        bne !+
            lda #0
            sta efxFlame2Phase
        !:
        lda efxFlame2Phase
        asl
        asl
        asl
        asl
        ldx #SOC_FLAME_2
        copyChar(level_fire)
        copyChar(level_fire + 8)

        rts
    }
    runPikes: {
        lda pikesCounter
        cmp #0
        bne !+
            rts
        !:
        ldx #0
        loop:
            lda pikesCounters, x
            cmp #PIKES_MAX_FRAME
            bne !+
                lda #0
                sta pikesCounters, x
            !:
            stx storeX
            lda pikesToObjects, x
            tax
            jsr getObjectPositionY
            sta ZR_0
            ldx storeX
            lda pikesCounters, x
            ldx #$ff
            cmp #PIKES_PHASE_0
            bne !+
                ldx #0
            !:
            cmp #PIKES_PHASE_1
            bne !+
                ldx #1
            !:
            cmp #PIKES_PHASE_2
            bne !+
                ldx #2
            !:
            cmp #PIKES_PHASE_3
            bne !+
                ldx #3
            !:
            cpx #$ff
            beq !+
                jsr drawPikes
            !:
            ldx storeX
            inc pikesCounters, x
            inx
            cpx pikesCounter
        bne loop
        rts
        // local vars
        storeX: .byte 0
    }
    runStones: {
        lda stonesCounter
        cmp #0
        bne !+
            rts
        !:
        ldx stoneCurrent
        cpx stonesCounter
        bcc continue
            jmp increment
        continue:

        lda stonesCounters, x
        cmp #STONES_MAX_FRAME
        bne !+
            lda #0
            sta stonesCounters, x
        !:
        stx storeX
        lda stonesToObjects, x
        sta ZR_0
        tax
        jsr getObjectPositionY
        ldx storeX
        lda stonesCounters, x
        ldx #$ff
        cmp #STONES_PHASE_0
        bne !+
            ldx #0
        !:
        cmp #STONES_PHASE_1
        bne !+
            ldx #1
        !:
        cmp #STONES_PHASE_2
        bne !+
            ldx #2
        !:
        cmp #STONES_PHASE_3
        bne !+
            ldx #3
        !:
        cmp #STONES_PHASE_4
        bne !+
            ldx #4
        !:
        cmp #STONES_PHASE_5
        bne !+
            ldx #5
        !:
        cmp #STONES_PHASE_3d
        bne !+
            ldx #4
        !:
        cpx #$ff
        beq !+
            jsr drawStone
        !:
        ldx storeX
        inc stonesCounters, x
    increment:
        inx
        cpx #3
        bne !+
            ldx #0
        !:
        stx stoneCurrent
        rts
        // local vars
        storeX: .byte 0
    }
}

.macro copyChar(sourceAddr) {
    pha
    clc
    adc #<sourceAddr
    sta SOURCE_PTR
    lda #0
    adc #>sourceAddr
    sta SOURCE_PTR + 1
    jsr _copyChar
    inx
    pla
}

_copyChar: {
    // set target
    lda targetCharset.lo, x
    sta DEST_PTR
    lda targetCharset.hi, x
    sta DEST_PTR + 1
    // copy 1st char
    jmp copyBitmapChar
}

.macro _checkEfx(efx, jumpTo) {
    cmp #efx
    bne !+
    jmp jumpTo
    !:
}

.macro waitFor() {
    !: 
        lda waitFor
    bne !-
}

copyLargeMemForward: {
    #import "common/lib/sub/copy-large-mem-forward.asm"
}
outText: {
    #import "text/lib/sub/out-text.asm"
}

initPlayerPosition: {
    lda level_startPositionX
    sta physPlayerX
    sta playerRespawnPositionX
    lda level_startPositionX + 1
    sta physPlayerX + 1
    sta playerRespawnPositionX + 1
    lda level_startPositionY
    sta physPlayerY
    sta playerRespawnPositionY
    jsr physResetActorPosition
    lda #0
    sta playerDying
    rts
}

respawnPlayerPosition: {
    lda playerRespawnPositionX
    sta physPlayerX
    lda playerRespawnPositionX + 1
    sta physPlayerX + 1
    lda playerRespawnPositionY
    sta physPlayerY
    jsr physResetActorPosition
    rts
}

updatePlayerPosition: ani_updatePlayerPosition(physPlayerX, physPlayerY)

handleTitleScreenCommand: {
    and #%00011111
    eor #%00011111
    cmp #%00000001
    beq joyUp
    cmp #%00010000
    beq joyFire
    sta io_oldJoy
    rts
    
    joyUp:
        // change color scheme
        cmp io_oldJoy
        sta io_oldJoy
        beq !+
            jsr nextColorScheme
        !:
        rts
    joyFire:
        // start the game
        cmp io_oldJoy
        sta io_oldJoy
        beq !+
            seq_setUp(1, 60, walkLeft, doNothing)    
        !:
        rts
    walkLeft:
        lda #CMD_WALK_LEFT
        jsr phys_commandPlayer
        rts
}

joyHandlingForBorg: {
    sta storeA
    cmp #0
    bne !+
        sta joyAccumulator
        sta joyPreviousValue
        sta joyDelayCounter
    !:
    and #%00010000
    bne !+
        lda storeA
        and #%11101111
        sta joyPreviousValue
        sta joyAccumulator
    !:
    lda storeA
    sta joyAccumulator
    cmp joyPreviousValue
    beq !+
        inc joyDelayCounter
    !:
    lda joyDelayCounter
    cmp #JOY_MAX_DELAY
    bne !+
        lda joyAccumulator
        sta joyPreviousValue
        lda #0
        sta joyDelayCounter
    !:
    lda joyPreviousValue
    rts
    storeA: .byte 0
}

dispatchPlayerCommand: {
    // fix #110, do not move if room in change
    ldy roomChange
    cpy #$ff
    beq !+
        lda #CMD_IDLE
        jmp doCommand
    !:
    ldy #0
    ldx physPlayerState
    cpx #STATE_ON_LADDER_FACING_LEFT
    bne !+
        ldy #1
    !:
    cpx #STATE_ON_LADDER_FACING_RIGHT
    bne !+
        ldy #1
    !:
    and #%00011111
    eor #%00011111
    jsr joyHandlingForBorg
    cmp #%00001000 // right
    beq joyRight
    cmp #%00000100 // left
    beq joyLeft 
    cmp #%00000010 // down
    beq joyDown
    cmp #%00000001 // up
    beq joyUp
    cmp #%00010000 // fire
    beq joyFire
    cmp #%00010100 // fire and left
    beq joyFireLeft
    cmp #%00011000 // fire and right
    beq joyFireRight
    cmp #%00010010 // fire, down
    beq joyDown
    cmp #%00010001 // fire, up
    beq joyUp
    cpy #1
    beq !+ 
        // not on ladder
        cmp #%00001001 // right-up
        beq joyUp
        cmp #%00000101 // left-up
        beq joyUp
        cmp #%00001010  // right-dn
        beq joyRightDown
        cmp #%00000110 // left-down
        beq joyLeftDown
        cmp #%00010110 // fire, left and down
        beq joyFireLeft 
        cmp #%00010101 // fire, left and up
        beq joyFireLeft
        cmp #%00011010 // fire, right and fown
        beq joyFireRight
        cmp #%00011001 // fire, right and up
        beq joyFireRight
        jmp idle
    !: 
        // on ladder
        cmp #%00001001 // right-up
        beq joyUp
        cmp #%00000101 // left-up
        beq joyUp
        cmp #%00001010  // right-dn
        beq joyDown
        cmp #%00000110 // left-down
        beq joyDown
        cmp #%00010110 // fire, left and down
        beq joyDown
        cmp #%00010101 // fire, left and up
        beq joyUp
        cmp #%00011010 // fire, right and down
        beq joyDown
        cmp #%00011001 // fire, right and up
        beq joyUp
    idle:
    lda #CMD_IDLE
    jmp doCommand
joyRight:
    lda #CMD_WALK_RIGHT
    jmp doCommand
joyLeft:
    lda #CMD_WALK_LEFT
    jmp doCommand
joyDown:
    lda #CMD_CLIMB_DOWN
    jmp doCommand
joyUp:
    lda #CMD_CLIMB_UP
    jmp doCommand
joyFire:
    lda #CMD_JUMP
    jmp doCommand
joyFireLeft:
    lda #CMD_JUMP_LEFT
    jmp doCommand
joyFireRight:
    lda #CMD_JUMP_RIGHT
    jmp doCommand
joyLeftDown:
    lda physPlayerState
    cmp #STATE_DUCK_RIGHT
    bne !+
        lda #CMD_DUCK_LEFT
        jmp !++
    !:
    lda #CMD_CLIMB_DOWN
    !:
    jmp doCommand
joyRightDown:
    lda physPlayerState
    cmp #STATE_DUCK_LEFT
    bne !+
        lda #CMD_DUCK_RIGHT
        jmp !++
    !:
    lda #CMD_CLIMB_DOWN
    !:
    lda #CMD_DUCK_RIGHT
    jmp doCommand
doCommand:
    sta io_oldJoy
    jsr phys_commandPlayer
    rts
}

initSound: {
    ldx #0
    ldy #0
    lda #0
    jsr music.init
    rts
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

blankScreen: {
    lda c64lib.CONTROL_1
    and #%11101111
    sta c64lib.CONTROL_1
    rts
}

showScreen: {
    lda c64lib.CONTROL_1
    ora #%00010000
    sta c64lib.CONTROL_1
    rts
}

#import "graph-text.asm"
#import "animations.asm"
#import "io.asm"
#import "physics.asm"
#import "sequencer.asm"
#import "static-objects.asm"
#import "actors.asm"
#import "aux-screens.asm"

checkBGCollision: phys_checkBGCollisionExt2(roomMaterialsBuffer, chamberLines)

startCopper: c64lib_startCopper(COPPER_LIST_ADDR, COPPER_LIST_PTR, List().add(c64lib.IRQH_JSR, c64lib.IRQH_DASHBOARD_CUTOFF).lock())
stopCopper: c64lib_stopCopper()

// vars
currentChamberNumber:       .byte 0
chamberMapAddr:             .word 0
staticObjectCount:          .byte 0
roomChange:                 .byte $ff
objCollisionDetected:       .byte $ff
drawCommand:                .byte $ff
playerDieRequest:           .byte 0
roomChangeDirection:        .byte 0
// roomCharsDecodingBuffer:    .fill 256, 0 // change to MAX_BG_CHARS
// roomMaterialsBuffer:        .fill 256, 0
.label roomCharsDecodingBuffer = $BF00
.label roomMaterialsBuffer     = $BE00
// to save extra 0.5kB this is allocated on upper music area, as music in demo level does not use full 8kB
joyDelayCounter:            .byte 0
joyAccumulator:             .byte 0
joyPreviousValue:           .byte 0
// ...to handle snakes
snakesToObjects:            .fill MAX_SNAKES, 0
snakeCounter:               .byte 0
// ...to handle pikes
pikesToObjects:             .fill MAX_PIKES, 0
pikesCounters:              .fill MAX_PIKES, 0
pikesCounter:               .byte 0
// ...to handle stones
stonesToObjects:            .fill MAX_STONES, 0
stonesCounters:             .fill MAX_STONES, 0
stonesCounter:              .byte 0
stoneCurrent:               .byte 0
// ...to handle enemies
enemiesCounter:             .byte 0
enemiesToObjects:           .fill ANI_MAX_ACTORS, 0
enemiesCounters:            .fill ANI_MAX_ACTORS, 0
// fade effect
currentColor:               .byte SCHEME_CLASSIC_LIGHT
fadeCounter:                .byte 0
// actual player position in columns
playerColX:                 .byte 0
playerColY:                 .byte 0
// speed tabs
sourceCharset:              .lohifill 256, demoLevelCharset + i*8
targetCharset:              .lohifill 256, TEXT_CHARSET_MEM + i*8
// auxiliary data structures
chamberLines:               .lohifill 20, SCREEN_MEM_0 + 40*i // indexed start of screen lines for faster collision detection
// color ramps
fadeOut:                    .byte SCHEME_CLASSIC_DARK, DARK_GREY, GREY
fadeIn:                     .byte SCHEME_CLASSIC_LIGHT, GREY, DARK_GREY, BLACK
waitFor:                    .byte 0
// effects & aux mechanics
effectCounter:              .byte 0
efxFlame1Phase:             .byte 0
efxFlame2Phase:             .byte 0
efxJewelPhase:              .byte 0
efxSnakePhase:              .byte 0
// player respawn
playerRespawnPositionX:     .byte 0, 0
playerRespawnPositionY:     .byte 0
playerRespawnState:         .byte 0
playerDying:                .byte 0
// game state
gameLivesLeft:              .byte 0
gameScore:                  .fill 3, 0
gameInventory:              .fill 4, 0
gameTitleScreen:            .byte 0
gameState:                  .byte 0
// NTSC handling
ntscCounter:                .byte 0
// eyes buffer
eyesColor:                  .byte BLACK
// color schemes
colorScheme:                .byte 0
colorLights:                .byte SCHEME_CLASSIC_LIGHT,     SCHEME_AMBER_LIGHT,     SCHEME_GREEN_LIGHT,     SCHEME_BLUE_LIGHT,     SCHEME_C64_LIGHT,   SCHEME_C128_LIGHT
colorDarks:                 .byte SCHEME_CLASSIC_DARK,      SCHEME_AMBER_DARK,      SCHEME_GREEN_DARK,      SCHEME_BLUE_DARK,      SCHEME_C64_DARK,    SCHEME_C128_DARK
colorBright:                .byte SCHEME_CLASSIC_BRIGHT,    SCHEME_AMBER_BRIGHT,    SCHEME_GREEN_BRIGHT,    SCHEME_BLUE_BRIGHT,    SCHEME_C64_BRIGHT,  SCHEME_C128_BRIGHT
colorDimmed:                .byte SCHEME_CLASSIC_DIMMED,    SCHEME_AMBER_DIMMED,    SCHEME_GREEN_DIMMED,    SCHEME_BLUE_DIMMED,    SCHEME_C64_DIMMED,  SCHEME_C128_DIMMED
// texts

.macro textC(value) {
    .byte (40-value.size())/2
    .text value
    .byte $ff
}

txtCounter:     .byte 0
txtLine0:       textC("tony@demo@version")
txtLine1:       textC("concept@and@graphics@by@rafal@dudek")
txtLine2:       textC("music@by@@sami@juntunen")
txtLine3:       textC("code@by@@maciej@malecki")
txtLine4:       textC("push@joy@up@to@change@colors")
txtPtrLo:       .byte <txtLine0, <txtLine1, <txtLine2, <txtLine3, <txtLine4
txtPtrHi:       .byte >txtLine0, >txtLine1, >txtLine2, >txtLine3, >txtLine4
txtPressFire:   .text "press@fire@to@start"; .byte $ff
txtGameOver:    .text "game@@over"; .byte $ff
txtPressFireCnt:    .text "press@fire@to@continue"; .byte $ff
textEnd0:       .text "see@you@soon"; .byte $ff
textEnd1:       .text "playing@whole@five@levels@of@tony"; .byte $ff
textEnd2:       .text "born@for@adventure"; .byte $ff

.label MAX_TITLE_TEXT = 5

dashboardMap: 
    .import binary "dashboard-map.bin"
endOfCode:

// temporarily...
levelDataStart:
    #import "level/demo/data.asm"
levelDataEnd:

endOfNonMovable:

.segment Movable

musicData:
    .fill music.size, music.getData(i)
    // .fill 8*1024 - music.size, random()*256 // filler to the whole 8kb
musicDataEnd:

_menuBegin:
#import "cheatmenu.asm"
_menuEnd:

.assert "Cheatmenu cannot overlap with IO memory", _menuEnd < $D000, true


dasboardCharset:
    .import binary "dashboard-charset.bin"
dashboardCharsetEnd:

font:
    .import binary "font.bin"
fontEnd:

gameEnd:
    loadNegated("game-end.bin")
gameEndEnd:

// second sprite bank
secondSpriteBank:
    #import "level/demo/bitmaps/bat-vertical.asm"
    #import "level/demo/bitmaps/deadman.asm"
secondSpriteBankEnd:
.assert "Second sprite bank overflown", (secondSpriteBankEnd - secondSpriteBank) <= 12*64, true

// third sprite bank
thirdSpriteBank:
    #import "level/demo/bitmaps/bat.asm"
thirdSpriteBankEnd:
.assert "Third sprite bank overflown", (thirdSpriteBankEnd - thirdSpriteBank) <= SPRITES_IN_ZONE_3*64, true

// first sprite bank
firstSpriteBank:
    tonySprites:
        #import "sprites/player.asm"
    tonySpritesEnd:

    skullSprites:
        #import "level/demo/bitmaps/skull.asm"
    skullSpritesEnd:

    .import binary "eyes.bin"
firstSpriteBankEnd:

.assert "First sprite bank overflown", (firstSpriteBankEnd - firstSpriteBank) <= 126*64, true

endOfTony:
.function formatRange(title, from, to) {
    .return title + " = $" + toHexString(from) + " - $" + toHexString(to)
}


.print ""
.print "----------------------------"
.print "Tony's memory usage summary:"
.print "----------------------------"
.print "Sprites slots used: " + (firstSpriteBankEnd - firstSpriteBank)/64
.print "Second sprites slots used: " + (secondSpriteBankEnd - secondSpriteBank)/64
.print "Code size: " + (endOfCode - start) + " bytes."
.print "Size of level data: " + (levelDataEnd - levelDataStart) + " bytes."
.print "Total size: " + (endOfTony - start) + " bytes."
.print "End of non movable: $" + toHexString(endOfNonMovable - 1)
.print "Beginning of music data: $" + toHexString(MUSIC_MEM)
.print "Bytes left: " + (MUSIC_MEM - endOfNonMovable)
.print "Bytes left: " + (MUSIC_MEM - endOfNonMovable)
.print "Copper list(s) size: " + (copperListEnd - copperList) + " bytes."
.print "Music location = $" + toHexString(music.location)
.print "Music original location = $" + toHexString(musicData) + " - $" + toHexString(musicDataEnd - 1)
.print "Music size = " + music.size
.print "Music init address = $" + toHexString(music.init)
.print "Music play address = $" + toHexString(music.play)
.print "Cheatmenu location $" + toHexString(_menuBegin) + " - $" + toHexString(_menuEnd - 1)

.print "--- movables ---"

.print formatRange("Movable music", musicData, musicDataEnd)
.print formatRange("Dashboard charset", dasboardCharset, dashboardCharsetEnd)
.print formatRange("Font", font, fontEnd)
.print formatRange("Game end", gameEnd, gameEndEnd)
.print formatRange("Second sprite bank", secondSpriteBank, secondSpriteBankEnd)
.print formatRange("Third sprite bank", thirdSpriteBank, thirdSpriteBankEnd)
.print formatRange("First sprite bank", firstSpriteBank, firstSpriteBankEnd)
