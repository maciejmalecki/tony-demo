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

#import "../../_constants.asm"
#import "../../_load-util.asm"
#import "../../_objects.asm"
#import "../../_compress.asm"

.label NO = 255

level_startRoom:        .byte 29
level_startPositionX:   .word 170
level_startPositionY:   .byte 70

// level_startRoom:        .byte 18
// level_startPositionX:   .word 300
// level_startPositionY:   .byte 70
level_startState:       .byte STATE_ON_GROUND_LEFT

.var _level_roomPtrs = List()
.var _level_roomExitsN = List()
.var _level_roomExitsE = List()
.var _level_roomExitsS = List()
.var _level_roomExitsW = List()
.var _level_usedCharsPtrs = List()
.var _level_usedCharsSize = List()
.var _level_objectsControlPtrs = List()
.var _level_objectsPositionXPtrs = List()
.var _level_objectsPositionYPtrs = List()
.var _level_movableObjectsValue2Ptrs = List()
.var _level_objectSizes = List()


// Montezuma's Castle - demo level
.macro _level_pack(name, exitN, exitE, exitS, exitW, staticObjects) {
    .var data = LoadBinary(name)
    
    roomStartAddress: compressRLE3(data, $ff)

    // define exit lists
    .eval _level_roomPtrs.add(roomStartAddress)
    .eval _level_roomExitsN.add(exitN)
    .eval _level_roomExitsE.add(exitE)
    .eval _level_roomExitsS.add(exitS)
    .eval _level_roomExitsW.add(exitW)

    // calculate used chars
    .var usedChars = Hashtable()
    .for (var i = 0; i < data.getSize(); i++) {
        .var charCode = data.get(i)
        .if (charCode != 0) {
            .eval usedChars.put(charCode, charCode)
        }
    }
    .var keys = usedChars.keys()
    .eval _level_usedCharsSize.add(keys.size() + 1)

    .print "Used chars for " + name + " = " + (keys.size() + 1)
    .assert "Room chars fits assumed buffer", (keys.size() + 1) <= MAX_BG_CHARS,  true

    usedCharsStartAddress: 
        .byte 0
        .fill keys.size(), usedChars.get(keys.get(i))

    .eval _level_usedCharsPtrs.add(usedCharsStartAddress)

    .var soControl = List()
    .var soPositionX = List()
    .var soPositionY = List()
    .var moValue2 = List()

    .for (var i = 0; i < staticObjects.size(); i++) {
        .var staticObject = staticObjects.get(i)
        .var control = staticObject.type + (staticObject.value << 4)
        .eval soControl.add(control)
        .eval soPositionX.add(staticObject.positionX)
        .eval soPositionY.add(staticObject.positionY)
        .if (isMovable(staticObject)) {
            .eval moValue2.add(staticObject.value2)
        }
    }

    _soControl: .fill soControl.size(), soControl.get(i)
    _soPositionX: .fill soPositionX.size(), soPositionX.get(i)
    _soPositionY: .fill soPositionY.size(), soPositionY.get(i)
    _soValue2: .fill moValue2.size(), moValue2.get(i)

    .eval _level_objectsControlPtrs.add(_soControl)
    .eval _level_objectsPositionXPtrs.add(_soPositionX)
    .eval _level_objectsPositionYPtrs.add(_soPositionY)
    .eval _level_movableObjectsValue2Ptrs.add(_soValue2)
    .eval _level_objectSizes.add(soControl.size())
}

// ROW 0 =====-----
chamberMap0_0: // 0 (DONE!)
    _level_pack("demo-level-map-0-0.bin", NO, 1, 4, NO, List().add(
        object(SO_DOOR, 0, 18, 14),
        object(SO_JEWEL, 0, 2, 15),
        object(SO_KEY, 0, 2, 13),
        object(SO_POTION, 0, 32, 10),
        objectExt(SO_BAT, 0, 6, 2, 9)
    ))
chamberMap1_0: // 1
    _level_pack("demo-level-map-1-0.bin", NO, 2, NO, 0, List().add(
        objectExt(SO_SKULL, 0, 15, 5, 44),
        objectExt(SO_DEAD, 0, 21, 16, 70)
    ))
chamberMap2_0: // 2
    _level_pack("demo-level-map-2-0.bin", NO, 3, NO, 1, List().add(
        objectExt(SO_DEAD, 0, 5, 16, 110),
        // objectExt(SO_DEAD, 0, )
        objectExt(SO_SKULL, 0, 18, 1, 0),
        object(SO_JEWEL, 0, 24, 7),
        object(SO_KEY, 0, 24, 5),
        object(SO_SNAKE_L, 0, 29, 7),

        object(SO_FLAME_1, 0, 15, 1),
        object(SO_FLAME_2, 0, 16, 1),
        object(SO_FLAME_1, 0, 21, 1),
        object(SO_FLAME_2, 0, 22, 1)
    ))
chamberMap3_0: // 3 (DONE!)
    _level_pack("demo-level-map-3-0.bin", NO, NO, NO, 2, 
        List().add(
            object(SO_DOORCODE, 0, 3, 5), 
            object(SO_SNAKE_R, 0, 11, 7), 
            object(SO_DOOR, 0, 17, 5), 
            object(SO_DOOR, 0, 21, 5),
            object(SO_DOOR, 0, 21, 14),
            object(SO_JEWEL, 0, 29, 15), 

            object(SO_PIKES, 0, 3, 16), 
            object(SO_PIKES, 5, 5, 16), 
            object(SO_PIKES, 7, 7, 16), 
            object(SO_PIKES, 0, 9, 16), 
            object(SO_PIKES, 3, 11, 16), 
            object(SO_FLAME_1, 0, 33, 12), 
            object(SO_FLAME_2, 0, 34, 12)
        ))

// ROW 1 =====-----
chamberMap0_1: // 4 (DONE!)
    _level_pack("demo-level-map-0-1.bin", 0, 5, NO, NO, List().add(
        object(SO_POTION, 0, 13, 11),
        object(SO_DOOR, 0, 28, 3),
        object(SO_DOOR, 0, 34, 3),
        object(SO_SNAKE_L, 0, 35, 15),
        objectExt(SO_BAT, 0, 12, 7, 8)
    ))
chamberMap1_1: // 5 (DONE!)
    _level_pack("demo-level-map-1-1.bin", NO, 6, 10, 4, 
        List().add(
            object(SO_JEWEL, 0, 31, 8), 
            object(SO_KEY, 0, 33, 8),
            objectExt(SO_BAT_VERTICAL, 8, 21, 2, 2*30),
            objectExt(SO_DEAD, 0, 23, 17, 50),

            object(SO_PIKES, 0, 18, 7)
        ))
chamberMap2_1: // 6 (DONE!)
    _level_pack("demo-level-map-2-1.bin", NO, 7, 11, 5, 
        List().add(
            object(SO_DOOR, 0, 18, 15),
            object(SO_JEWEL, 0, 27, 17),
            object(SO_POTION, 0, 31, 7),

            object(SO_PIKES, 0, 12, 9),
            object(SO_PIKES, 0, 16, 8)
        ))
chamberMap3_1: // 7 (DONE)
    _level_pack("demo-level-map-3-1.bin", NO, 8, 12, 6, 
        List().add(
            object(SO_JEWEL, 0, 12, 10), 
            object(SO_POTION, 0, 12, 12),
            objectExt(SO_BAT_VERTICAL, 8, 17, 4, 2*30),
            object(SO_SNAKE_R, 0, 20, 12),

            object(SO_FLAME_1, 0, 1, 6), 
            object(SO_FLAME_2, 0, 2, 6), 
            object(SO_FLAME_2, 0, 36, 3), 
            object(SO_FLAME_1, 0, 37, 3)
            ))
chamberMap4_1: // 8 (DONE!)
    _level_pack("demo-level-map-4-1.bin", NO, NO, 13, 7, 
        List().add(
            object(SO_SNAKE_R, 0, 22, 16), 
            object(SO_KEY, 0, 10, 9), 
            object(SO_KEY, 0, 17, 11),
            objectExt(SO_SKULL, 0, 4, 5, 0),
            objectExt(SO_SKULL, 0, 34, 5, 0),
            objectExt(SO_BAT, 0, 11, 5, 2),

            object(SO_FLAME_1, 0, 1, 5), 
            object(SO_FLAME_2, 0, 2, 5), 
            object(SO_FLAME_1, 0, 7, 5), 
            object(SO_FLAME_2, 0, 8, 5),
            object(SO_FLAME_1, 0, 31, 5), 
            object(SO_FLAME_2, 0, 32, 5), 
            object(SO_FLAME_1, 0, 37, 5), 
            object(SO_FLAME_2, 0, 38, 5)
        )
    )

// ROW 2 =====-----
chamberMap0_2: // 9 (DONE!)
    _level_pack("demo-level-map-0-2.bin", 4, 10, NO, NO, List().add(
        object(SO_DOOR, 0, 35, 2),
        object(SO_SNAKE_L, 0, 32, 17),
        objectExt(SO_SKULL, 8, 23, 7, 2*38),
        object(SO_PIKES, 0, 26, 5),
        object(SO_PIKES, 6, 28, 5)
    ))
chamberMap1_2: // 10 (DONE!)
    _level_pack("demo-level-map-1-2.bin", 5, 11, 15, 9, List().add(
        object(SO_DOOR, 0, 28, 2),
        object(SO_KEY, 0, 14, 4),
        object(SO_JEWEL, 0, 14, 17),
        object(SO_SNAKE_R, 0, 8, 17),
        objectExt(SO_DEAD, 0, 27, 14, 45)
    ))
chamberMap2_2: // 11 (DONE!)
    _level_pack("demo-level-map-2-2.bin", 6, 12, 16, 10, List().add(
            object(SO_KEY, 0, 12, 4),
            object(SO_JEWEL, 0, 16, 15),
            object(SO_JEWEL, 0, 15, 13), 
            object(SO_JEWEL, 0, 17, 13),
            objectExt(SO_SKULL, 0, 10, 8, 30),
            objectExt(SO_BAT, 0, 27, 1, 3),

            object(SO_PIKES, 0, 18, 5), 
            object(SO_PIKES, 5, 20, 5)
    ))
chamberMap3_2: // 12 (DONE!)
    _level_pack("demo-level-map-3-2.bin", 7, 13, 17, 11, 
        List().add(
            object(SO_POTION, 0, 7, 10),
            object(SO_SNAKE_R, 0, 21, 12)
        ))
chamberMap4_2: // 13 (DONE!)
    _level_pack("demo-level-map-4-2.bin", 8, NO, NO, 12, 
        List().add(
                object(SO_POTION, 0, 30, 8),
                objectExt(SO_BAT, 0, 7, 3, 1),

                object(SO_FLAME_1, 0, 5, 17), 
                object(SO_FLAME_2, 0, 6, 17), 
                object(SO_FLAME_1, 0, 7, 17), 
                object(SO_FLAME_2, 0, 8, 17)
            ))

// ROW 3 =====-----
chamberMap0_3: // 14 (DONE!)
    _level_pack("demo-level-map-0-3.bin", NO, 15, 19, NO, 
        List().add(
            objectExt(SO_SKULL, 0, 13, 4, 40),
            objectExt(SO_SKULL, 4, 22, 4, 40),
            objectExt(SO_SKULL, 7, 31, 4, 40)
        ))
chamberMap1_3: // 15 (DONE!)
    _level_pack("demo-level-map-1-3.bin", 10, 16, NO, 14, 
        List().add(
            object(SO_KEY, 0, 18, 8),
            objectExt(SO_BAT, 0, 4, 2, 4),

            object(SO_PIKES, 0, 25, 11)
        ))
chamberMap2_3: // 16 (DONE!)
    _level_pack("demo-level-map-2-3.bin", NO, 17, NO, 15, 
        List().add(
            object(SO_SNAKE_R, 0, 24, 14), 
            object(SO_SNAKE_R, 0, 24, 4),
            object(SO_POTION, 0, 3, 4), 
            object(SO_JEWEL, 0, 5, 2), 
            object(SO_DOOR, 0, 2, 10)
            ))
chamberMap3_3: // 17 (DONE!)
    _level_pack("demo-level-map-3-3.bin", 12, 18, NO, 16, 
        List().add(
            objectExt(SO_SKULL, 0, 10, 2, 40),

            object(SO_PIKES, 9, 27, 14),
            object(SO_PIKES, 0, 4, 14), 
            object(SO_PIKES, 6, 6, 14)
            ))
chamberMap4_3: // 18 (START!, DONE!)
    _level_pack("demo-level-map-4-3.bin", NO, NO, NO, 17, 
        List().add(
            object(SO_POTION, 0, 14, 8), 
            object(SO_SNAKE_L, 0, 23, 6), 
            object(SO_JEWEL, 0, 30, 13),
            // object(SO_KEY, 0, 10, 16),
            // object(SO_KEY, 0, 12, 16),
            // object(SO_KEY, 0, 14, 16),
            // object(SO_KEYCODE, 0, 16, 16),
            objectExt(SO_BAT, 0, 18, 10, 0),

            object(SO_PIKES, 0, 3, 16)
        ))

// ROW 4 =====-----
chamberMap0_4: // 19 (DONE!)
    _level_pack("demo-level-map-0-4.bin", 14, 20, NO, NO, 
        List().add(
            object(SO_SNAKE_R, 0, 34, 6), 
            object(SO_SNAKE_R, 0, 34, 16),
            objectExt(SO_DEAD, 0, 15, 6, 70),
            objectExt(SO_SKULL, 8, 20, 9, 26*2),
            objectExt(SO_SKULL, 8 + 7, 26, 9, 26*2),
            objectExt(SO_SKULL, 8 + 4, 32, 9, 2*26)
        ))
chamberMap1_4: // 20 (DONE!)
    _level_pack("demo-level-map-1-4.bin", NO, 21, 25, 19, 
        List().add(
            object(SO_SNAKE_R, 0, 10, 6), 
            object(SO_SNAKE_R, 0, 10, 16),
            object(SO_POTION, 0, 14, 5), 
            object(SO_JEWEL, 0, 16, 5), 
            object(SO_KEY, 0, 18, 5),
            object(SO_KEY, 0, 27, 5),
            objectExt(SO_SKULL, 8, 4, 9, 2*26),

            object(SO_PIKES, 0, 28, 16)
        ))
chamberMap2_4: // 21 (DONE!)
    _level_pack("demo-level-map-2-4.bin", NO, 22, NO, 20, 
        List().add(
            object(SO_JEWEL, 0, 11, 5), 
            object(SO_SNAKE_R, 0, 33, 7),
            objectExt(SO_SKULL, 0, 11, 10, 0),
            objectExt(SO_BAT_VERTICAL, 0, 24, 2, 40),

            object(SO_FLAME_1, 0, 8, 10), 
            object(SO_FLAME_2, 0, 9, 10),
            object(SO_FLAME_2, 0, 14, 10), 
            object(SO_FLAME_1, 0, 15, 10)
        ))
chamberMap3_4: // 22 (DONE!)
    _level_pack("demo-level-map-3-4.bin", NO, 23, NO, 21, 
        List().add(
            object(SO_JEWEL, 0, 19, 15), 
            object(SO_JEWEL, 0, 18, 13), 
            object(SO_JEWEL, 0, 20, 13),
            objectExt(SO_BAT, 0, 1, 1, 5),
            objectExt(SO_DEAD, 0, 21, 16, 60),

            object(SO_STONE, 0, 20, 0), 
            object(SO_STONE, 2, 27, 0), 
            object(SO_STONE, 4, 34, 0)
            ))

chamberMap4_4: // 23 (DONE!)
    _level_pack("demo-level-map-4-4.bin", NO, NO, 28, 22, 
        List().add(
            object(SO_FLAME_1, 0, 26, 15), 
            object(SO_FLAME_2, 9, 27, 15),
            object(SO_KEY, 0, 15, 15),
            objectExt(SO_DEAD, 0, 5, 16, 30),

            object(SO_STONE, 0, 5, 0), 
            object(SO_STONE, 2, 13, 0), 
            object(SO_STONE, 4, 20, 0)
            ))

// ROW 5 =====-----
chamberMap0_5: // 24 (DONE!)
    _level_pack("demo-level-map-0-5.bin", NO, 25, NO, NO, 
        List().add(
            object(SO_KEYCODE, 0, 4, 4),
            object(SO_KEY, 0, 3, 7), 
            object(SO_KEY, 0, 5, 7), 
            object(SO_POTION, 0, 11, 8), 
            object(SO_JEWEL, 0, 19, 9),
            objectExt(SO_BAT, 0, 10, 4, 6),

            object(SO_FLAME_1, 0, 7, 16), 
            object(SO_FLAME_2, 0, 8, 16), 

            object(SO_FLAME_1, 0, 14, 16),
            object(SO_FLAME_2, 0, 15, 16), 
            object(SO_FLAME_1, 0, 16, 16), 

            object(SO_FLAME_2, 0, 22, 16), 
            object(SO_FLAME_1, 0, 23, 16),

            object(SO_FLAME_1, 0, 29, 16), 
            object(SO_FLAME_2, 0, 30, 16), 

            object(SO_FLAME_1, 0, 36, 16),
            object(SO_FLAME_2, 0, 37, 16)
        ))
chamberMap1_5: // 25 (DONE!)
    _level_pack("demo-level-map-1-5.bin", 20, 26, NO, 24, List().add(
        objectExt(SO_BAT_VERTICAL, 8, 5, 1, 60),
        objectExt(SO_BAT_VERTICAL, 8, 26, 3, 90),
        object(SO_PIKES, 0, 8, 8),
        object(SO_PIKES, 10, 14, 8)
    ))
chamberMap2_5: // 26 (DONE!)
    _level_pack("demo-level-map-2-5.bin", NO, 27, NO, 25, List().add(
        objectExt(SO_BAT_VERTICAL, 0, 7, 5, 40),
        objectExt(SO_BAT_VERTICAL, 7, 16, 5, 40),
        objectExt(SO_BAT_VERTICAL, 4, 25, 5, 40),
        objectExt(SO_BAT_VERTICAL, 0, 33, 8, 40),
        object(SO_KEY, 0, 21, 10),

        object(SO_FLAME_1, 0, 7, 17),
        object(SO_FLAME_2, 0, 8, 17),
        object(SO_FLAME_1, 0, 9, 17),
        object(SO_FLAME_2, 0, 10, 17),
        object(SO_FLAME_1, 0, 11, 17),
        object(SO_FLAME_1, 0, 23, 17),
        object(SO_FLAME_2, 0, 24, 17),
        object(SO_FLAME_1, 0, 25, 17),
        object(SO_FLAME_2, 0, 26, 17),
        object(SO_FLAME_1, 0, 27, 17)
    ))
chamberMap3_5: // 27 (DONE!)
    _level_pack("demo-level-map-3-5.bin", NO, 28, NO, 26, List().add(
        object(SO_DOOR, 0, 3, 13),
        objectExt(SO_BAT, 0, 7, 8, 7),
        objectExt(SO_SKULL, 0, 32, 1, 40),
        objectExt(SO_BAT_VERTICAL, 8 + 7, 35, 1, 2*40),

        object(SO_FLAME_1, 0, 8, 17),
        object(SO_FLAME_2, 0, 9, 17),
        object(SO_FLAME_1, 0, 16, 17),
        object(SO_FLAME_2, 0, 17, 17),
        object(SO_FLAME_1, 0, 23, 17),
        object(SO_FLAME_2, 0, 24, 17)
    ))
chamberMap4_5: // 28 (DONE!)
    _level_pack("demo-level-map-4-5.bin", 23, NO, NO, 27, List().add(
        object(SO_SNAKE_L, 0, 20, 9),
        object(SO_DOOR, 0, 26, 7),
        objectExt(SO_SKULL, 8+0, 3, 1, 2*40),
        objectExt(SO_SKULL, 8+7, 8, 1, 2*40),
        objectExt(SO_BAT_VERTICAL, 8+4, 13, 1, 2*40)
    ))

// TITLE SCREEN
chamberMap4_0: // 29
    _level_pack("demo-level-map-4-0.bin", NO, NO, NO, 18, List().add(
        object(SO_SNAKE_L, 0, 31, 2),
        object(SO_SNAKE_L, 0, 27, 16),
        object(SO_SNAKE_L, 0, 15, 16),
        object(SO_SNAKE_L, 0, 11, 16),
        objectExt(SO_BAT, 0, 28, 8, 0),
        objectExt(SO_BAT, 0, 0, 9, 2),

        object(SO_FLAME_1, 0, 3, 14),
        object(SO_FLAME_2, 0, 4, 14),
        object(SO_FLAME_1, 0, 7, 14),
        object(SO_FLAME_2, 0, 8, 14),
        object(SO_FLAME_1, 0, 32, 14),
        object(SO_FLAME_2, 0, 33, 14),
        object(SO_FLAME_1, 0, 36, 14),
        object(SO_FLAME_2, 0, 37, 14)
    ))


materials: 
    .import binary "demo-level-materials.bin"

level_fire:
    #import "bitmaps/fire.asm"
level_door:
    #import "bitmaps/door.asm"
level_doorcode:
    #import "bitmaps/doorcode.asm"
level_key:
    #import "bitmaps/key.asm"
level_keycode:
    #import "bitmaps/keycode.asm"
level_potion:
    #import "bitmaps/potion.asm"
level_jewel:
    #import "bitmaps/jewel.asm"
level_snakeLeft:
    #import "bitmaps/snake-left.asm"
level_snakeRight:
    #import "bitmaps/snake-right.asm"
level_pikes:
    #import "bitmaps/pikes.asm"
level_stones:
    #import "bitmaps/stones.asm"
    

level_roomPtr:              .lohifill   _level_roomPtrs.size(),         _level_roomPtrs.get(i)
level_usedCharsPtr:         .lohifill   _level_usedCharsPtrs.size(),    _level_usedCharsPtrs.get(i)
level_usedCharsCount:       .fill       _level_usedCharsSize.size(),    _level_usedCharsSize.get(i)
level_roomExitsN:           .fill       _level_roomExitsN.size(),       _level_roomExitsN.get(i)
level_roomExitsE:           .fill       _level_roomExitsE.size(),       _level_roomExitsE.get(i)
level_roomExitsS:           .fill       _level_roomExitsS.size(),       _level_roomExitsS.get(i)
level_roomExitsW:           .fill       _level_roomExitsW.size(),       _level_roomExitsW.get(i)

level_objectControlPtr:     .lohifill   _level_objectsControlPtrs.size(),   _level_objectsControlPtrs.get(i)
level_objectPositionXPtr:   .lohifill   _level_objectsPositionXPtrs.size(), _level_objectsPositionXPtrs.get(i)
level_objectPositionYPtr:   .lohifill   _level_objectsPositionYPtrs.size(), _level_objectsPositionYPtrs.get(i) 
level_movableObjectValue2Ptr:
                            .lohifill   _level_movableObjectsValue2Ptrs.size(), _level_movableObjectsValue2Ptrs.get(i)

level_objectSizes:          .fill       _level_objectSizes.size(),          _level_objectSizes.get(i)

level_roomStates:           .fill       30, 0

path0:          .byte   16, 0, 4, 2, 6, 0, 2, -2, 16, 0 // 4-3
path1:          .byte   24, 2, 30, -1 // 4-2
path2:          .byte   26, 1, 30, -1 // 4-1
path3:          .byte   20, 1, 6, 2, 22, -2 // 2-2
path4:          .byte   18, 1, 24, 0, 18, -1 // 1-3
path5:          .byte   14, 0, 15, 2, 10, -2, 20, 0 // 3-4
path6:          .byte   20, 0, 10, 1, 10, -1, 20, 0, 10, -1 // 0-5
path7:          .byte   15, 1, 20, -1, 20, 1, 20, -1 // 3-5
path8:          .byte   10, 0, 20, 2, 10, -3, 5, 0 // 0-1
path9:          .byte   20, 1, 10, 0, 10, -1, 18, 0 // 0-0

pathsPtrsLo:    .byte <path0, <path1, <path2, <path3, <path4, <path5, <path6, <path7, <path8, <path9
pathsPtrsHi:    .byte >path0, >path1, >path2, >path3, >path4, >path5, >path6, >path7, >path8, >path9
pathLengths:    .byte 10, 4, 4, 6, 6, 8, 10, 8, 8, 8

demoLevelCharset: {
    loadNegated("demo-level-charset.bin")
}
demoLevelCharsetEnd:
