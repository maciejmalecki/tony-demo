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

/*
    MEMORY LAYOUT (new - text hires mode)
    =============

    $A000 - $BFFF   8kb     Music Data
    $C000 - $C3FF   1kb     Screen page 0 $C000-$C31F used (screen data), $C3F7-$C3FF used (sprite pointers), 2 slots for sprites left
    $C400 - $C7FF   1kb     Screen page 1 $C720-$C7FF used (screen data + sprite pointers), all sprite slots taken
    $C800 - $CFFF   2kb     Level charset mem
    $D000 - $DFFF   2kb     Dashboard charset mem (limited) (few sprites may fit 10~12) 12 sprite slots left
    $E000 - $FFFF   8kb     Sprites data (127 sprites) // 1 slot left

    --------------------------------------
    sprites still needed:

    bat left:       4
    bat right:      4

    total:          8
 */

// VIC-2 layout
.label BITMAP_MEM           = $E000
.label SPRITES_MEM          = $E000 // up to 112 slots for sprite shapes (plus one "empty" sprite in slot 254)
.label SCREEN_MEM_0         = $C000 // plus 2 sprite slots starting from $C320
.label SCREEN_MEM_1         = $C400 // plus 12 free sprite slots starting from $C400

.label MUSIC_MEM = $A000

// additional graphic layout

.label TEXT_CHARSET_MEM     = $C800
.label TEXT_DASHBOARD_CHARS_MEM = $D000 // plus 12 free sprite slots starting from $D500
.label SPRITES_IN_ZONE_3 = 8
.label SPRITES_BANK3 = TEXT_DASHBOARD_CHARS_MEM + 2048 - SPRITES_IN_ZONE_3*64

.label CHARSET_MEM          = $B800 // 2kb = 256x8
.label MATERIALS_MEM        = $B400 // 1kb materials
.label DASHBOARD_CHAR_COUNT = 159

// font source location
.label FONT_BUFFER_MEM = $0340
.label ENDGAME_BUFFER_MEM = FONT_BUFFER_MEM + 37*8

.assert "Dashboard and sprite 3rd zone clash", TEXT_DASHBOARD_CHARS_MEM + DASHBOARD_CHAR_COUNT*8 < SPRITES_BANK3, true

// end game screen
.label ES_TOP = 5
.label ES_LEFT = 13

// animations
.label ANIM_WALK_LEFT = 0
.label ANIM_WALK_RIGHT = 1
.label ANIM_DUCK_LEFT = 2
.label ANIM_DUCK_RIGHT = 3
.label ANIM_IDLING_LEFT = 4
.label ANIM_IDLING_RIGHT = 5
.label ANIM_LADDER = 6
.label ANIM_JUMP_LEFT = 7
.label ANIM_JUMP_RIGHT = 8
.label ANIM_LADDER_STOP = 9
.label ANIM_DEATH_LEFT = 10
.label ANIM_DEATH_RIGHT = 11
.label ANIM_SKULL = 12
.label ANIM_BAT_VERTICAL = 13
.label ANIM_DEADMAN_LEFT = 14
.label ANIM_DEADMAN_RIGHT = 15
.label ANIM_BAT_LEFT = 16
.label ANIM_BAT_RIGHT = 17
.label ANIM_DUCK_QUICK_LEFT = 18
.label ANIM_DUCK_QUICK_RIGHT = 19

// player states
.label STATES_LEFT = 0
//.label STATES_RIGHT = %10000000
.label STATES_RIGHT = %10000000

.label STATE_ON_GROUND_LEFT = 0
.label STATE_WALKING_LEFT = 1   // white
.label STATE_ON_LADDER_FACING_LEFT = 2 // red
.label STATE_DUCK_LEFT = 3 // cyan
.label STATE_JUMPING_LEFT = 4 // purple
.label STATE_JUMPING_UP_FACING_LEFT = 5 // green
.label STATE_FALLING_DOWN_FACING_LEFT = 6 // blue
.label STATE_ON_LADDER_STOPPED_FACING_LEFT = 7 // yellow
.label STATE_DEATH_LEFT = 8
.label STATE_ON_GROUND_RIGHT = STATES_RIGHT + 0 // orange
.label STATE_WALKING_RIGHT = STATES_RIGHT + 1 // brown
.label STATE_ON_LADDER_FACING_RIGHT = STATES_RIGHT + 2 // pink
.label STATE_DUCK_RIGHT = STATES_RIGHT + 3 // dark grey
.label STATE_JUMPING_RIGHT = STATES_RIGHT + 4 //mid grey
.label STATE_JUMPING_UP_FACING_RIGHT = STATES_RIGHT + 5 // light green
.label STATE_FALLING_DOWN_FACING_RIGHT = STATES_RIGHT + 6 // light blue
.label STATE_ON_LADDER_STOPPED_FACING_RIGHT = STATES_RIGHT + 7 // light grey
.label STATE_DEATH_RIGHT = STATES_RIGHT + 8

// player actor commands
.label CMD_IDLE = 0
.label CMD_WALK_LEFT = 1
.label CMD_WALK_RIGHT = 2
.label CMD_CLIMB_UP = 3
.label CMD_CLIMB_DOWN = 4
.label CMD_JUMP_LEFT = 5
.label CMD_JUMP_RIGHT = 6
.label CMD_JUMP = 7
.label CMD_DUCK_LEFT = 8
.label CMD_DUCK_RIGHT = 9

// joy handling
.label JOY_MAX_DELAY = 3

// game state
.label STATE_INGAME = 0
.label STATE_GAMEOVER = 1
.label STATE_ENDOFGAME = 2

// player actor facing
.label FACING_LEFT = 1
.label FACING_RIGHT = 2

// player 2 BG collision flags (from material)
.label BG_CLSN_NONE         = 0
.label BG_CLSN_WALL         = %00000001
.label BG_CLSN_LADDER       = %00000010
.label BG_CLSN_KILLING      = %00000100
.label BG_CLSN_COLLECTIBLE  = %01000000
.label BG_CLSN_OBJ_MASK     = BG_CLSN_COLLECTIBLE
.label BG_CLSN_BOX_MASK     = BG_CLSN_LADDER + BG_CLSN_KILLING + BG_CLSN_COLLECTIBLE
.label BG_CLSN_BOX_NK_MASK  = BG_CLSN_LADDER + BG_CLSN_COLLECTIBLE
.label BG_CLSN_FLOOR_MASK   = BG_CLSN_WALL
.label BG_CLSN_FAR_MASK     = BG_CLSN_LADDER + BG_CLSN_WALL

.label SPRITE_CORRECTION_X  = 0
.label SPRITE_CORRECTION_Y  = 0

// extended collision flags (calculated)
.label BG_CLSE_WALL_LEFT    = %00000001
.label BG_CLSE_WALL_RIGHT   = %00000010
.label BG_CLSE_FLOOR_NEAR   = %00000100
.label BG_CLSE_FLOOR_FAR    = %00001000
.label BG_CLSE_LADDER_FAR   = %00010000
.label BG_CLSE_LADDER_TOP   = %01000000

// player collision offsets
.label CLSN_OFFSET_X = 7 // translation from sprite coordinates to screen coordinates (old 32)
.label CLSN_OFFSET_Y = 50-32-11 // translation from sprite coordinates to screen coords (old 50)
.label CLSN_COL_OFFSET_X = 3 // adjustment of collision detection in columns
.label CLSN_COL_OFFSET_Y = 4 // adjustment of collision detection in columns
.label CLSN_FLOOR_OFFSET_Y = 50
.label CLSN_FLOOR_COMPENSATION_Y = 4
.label CLSN_FIRST_COLUMN = 3 // first column to cut off collision detection
.label CLSN_LAST_COLUMN = 40 // last column to cut off collision detection
.label CLSN_FIRST_ROW = 2 // first row to cut off collision detection
.label CLSN_LAST_ROW = 20 // last row to cut of collision detection
.label CLSN_SPRITE_X_MAX = 4

.label MAX_SPRITES = 4 // currently only up to 4 sprites are allocated for nasties, this max is +1; 5th is used for blinking eyes

// room change limits
.label ROOM_NORTH_LIMIT = $33 - 16
.label ROOM_EAST_LIMIT = $157 - 16 - 5
.label ROOM_SOUTH_LIMIT = $fa - 16 - 4*8 - 5
.label ROOM_WEST_LIMIT = $18 - 5

// room transition position
.label ROOM_TRANSIT_ADJUSTMENT = 1
.label ROOM_TRANSIT_NORTH = ROOM_SOUTH_LIMIT - ROOM_TRANSIT_ADJUSTMENT
.label ROOM_TRANSIT_EAST = ROOM_WEST_LIMIT + ROOM_TRANSIT_ADJUSTMENT
.label ROOM_TRANSIT_SOUTH = ROOM_NORTH_LIMIT + ROOM_TRANSIT_ADJUSTMENT
.label ROOM_TRANSIT_WEST = ROOM_EAST_LIMIT - ROOM_TRANSIT_ADJUSTMENT
// room change directions
.label ROOM_TRANSIT_DIRECTION_NORTH = 1
.label ROOM_TRANSIT_DIRECTION_SOUTH = 2
.label ROOM_TRANSIT_DIRECTION_EAST = 3
.label ROOM_TRANSIT_DIRECTION_WEST = 4

// room compositions
.label MAX_BG_CHARS = 170

// fade effect
.label FADE_DELAY = 2
.label FLASH_DELAY = 1
.label EYE_FADE_DELAY = 3

// die effect
.label DIE_DELAY = 10
.label INITIAL_LIVES = DASHBOARD_MAX_LIVES

// dashboard handling
.label DASHBOARD_LIFE_CHAR = 130
.label DASHBOARD_LIFE_INDICATOR_POS = 70
.label DASHBOARD_NUMBER_START_CHAR = 120
.label DASHBOARD_SCORE_INDICATOR_POS = 110
// .label DASHBOARD_ENABLED_COLOR = BRIGHT_COLOR
// .label DASHBOARD_DISABLED_COLOR = DIMMED_COLOR
.label DASHBOARD_MAX_LIVES = 5
.label DASHBOARD_INVENTORY_START_CHAR = 40 + 2
.label DASHBOARD_INVENTORY_START_CHAR1 = 80 + 2

// Cheat flags
// .label CHEAT_SNAKE_INVINCIBLE   = $01
.label CHEAT_STONE_INVINCIBLE   = $02
.label CHEAT_INFINITE_LIVES     = $04
.label CHEAT_PASS_THRU_DOORS    = $08
.label CHEAT_SPRITE_INVINCIBLE  = $10
.label CHEAT_PIKES_INVINCIBLE   = $20

.label CHEAT_INITIAL = 0 // CHEAT_PASS_THRU_DOORS + CHEAT_SNAKE_INVINCIBLE + CHEAT_PIKES_INVINCIBLE + CHEAT_STONE_INVINCIBLE

// SPRITE NUMBER ALLOCATION
.label PLAYER_SPRITE_0      = 0

.label SPRITES_BANK_BEGIN = (SPRITES_MEM - SCREEN_MEM_0)/64

.label PLAYER_BANK_WALK_LEFT = SPRITES_BANK_BEGIN
.label PLAYER_BANK_WALK_RIGHT = SPRITES_BANK_BEGIN + 8
.label PLAYER_DUCK_LEFT = SPRITES_BANK_BEGIN + 16
.label PLAYER_DUCK_RIGHT = SPRITES_BANK_BEGIN + 24
.label PLAYER_IDLING_LEFT = SPRITES_BANK_BEGIN + 32
.label PLAYER_IDLING_RIGHT = SPRITES_BANK_BEGIN + 40
.label PLAYER_LADDER = SPRITES_BANK_BEGIN + 48
.label PLAYER_JUMP_LEFT = SPRITES_BANK_BEGIN + 52
.label PLAYER_JUMP_RIGHT = SPRITES_BANK_BEGIN + 56
.label PLAYER_DEATH_LEFT = SPRITES_BANK_BEGIN + 60
.label PLAYER_DEATH_RIGHT = SPRITES_BANK_BEGIN + 70
.label PLAYER_WALK_LEFT_BG = SPRITES_BANK_BEGIN + 80
.label PLAYER_WALK_RIGHT_BG = SPRITES_BANK_BEGIN + 84
.label PLAYER_IDLING_LEFT_BG = SPRITES_BANK_BEGIN + 88
.label PLAYER_IDLING_RIGHT_BG = SPRITES_BANK_BEGIN + 92
.label PLAYER_DUCK_LEFT_BG = SPRITES_BANK_BEGIN + 96
.label PLAYER_DUCK_RIGHT_BG = SPRITES_BANK_BEGIN + 100
.label PLAYER_LADDER_BG = SPRITES_BANK_BEGIN + 104
.label PLAYER_JUMP_LEFT_BG = SPRITES_BANK_BEGIN + 106
.label PLAYER_JUMP_RIGHT_BG = SPRITES_BANK_BEGIN + 108
.label PLAYER_DEATH_LEFT_BG = SPRITES_BANK_BEGIN + 110
.label PLAYER_DEATH_RIGHT_BG = SPRITES_BANK_BEGIN + 115

.label ENEMY_SKULL = SPRITES_BANK_BEGIN + 120 // 4 frames
.label DASHBOARD_EYES = SPRITES_BANK_BEGIN + 124

.label SPRITES_2ND_BANK_BEGIN = (SCREEN_MEM_1 - SCREEN_MEM_0)/64 // capacity 12 shapes

.label ENEMY_BAT_VERTICAL = SPRITES_2ND_BANK_BEGIN
.label ENEMY_DEADMAN_LEFT = SPRITES_2ND_BANK_BEGIN + 4
.label ENEMY_DEADMAN_RIGHT = SPRITES_2ND_BANK_BEGIN + 8

.label SPRITES_3RD_BANK_BEGIN = (SPRITES_BANK3 - SCREEN_MEM_0)/64 // take last 8 slots to reserve caopacity for more dashboard chars
.label ENEMY_BAT_LEFT = SPRITES_3RD_BANK_BEGIN
.label ENEMY_BAT_RIGHT = SPRITES_3RD_BANK_BEGIN + 4

.label EMPTY_SPRITE = 254

// actors
.label ANI_MAX_ACTORS = 6
.label ANI_ACTOR_PLAYER = 0
.label ANI_NO_PATH_CRUNCH = $FF

// object types
.label SO_FLAME_1 = 1 // ac
.label SO_FLAME_2 = 2 // ac
.label SO_PIKES = 3 // aa
.label SO_SNAKE_L = 4 // aa/ac/ac
.label SO_STONE = 5 // aa
.label SO_JEWEL = 6 // ac
.label SO_KEY = 7 // -
.label SO_DOOR = 8 // -
.label SO_KEYCODE = 9 // -
.label SO_DOORCODE = 10 // -
.label SO_POTION = 11 // ac
.label SO_SNAKE_R = 12
.label SO_BAT = 13
.label SO_BAT_VERTICAL = 14
.label SO_SKULL = 15
.label SO_DEAD = 0 // ?

// movement steps
.label STEP_SKULLx2 = 2 // px
.label STEP_SKULLx1 = 1 // px
.label STEP_DEADMAN = 1 // px
.label STEP_BAT = 1 // px

// inventory
.label INV_NOT_FOUND = 4

// static object charset slots
.label SOC_NULL         = 0 // empty char
.label SOC_RESERVED     = 254 // 2 bytes
.label SOC_FLAME_1      = 252 // 2 bytes
.label SOC_FLAME_2      = 250 // 2 bytes
.label SOC_PIKES        = 240 // 10 bytes
.label SOC_SNAKE_L      = 236 // 4 bytes
.label SOC_SNAKE_R      = 232 // 4 bytes
.label SOC_JEWEL        = 228 // 4 bytes
.label SOC_KEY          = 224 // 4 bytes
.label SOC_DOOR         = 208 // 16 bytes
.label SOC_KEYCODE      = 204 // 4 bytes
.label SOC_DOORCODE     = 188 // 16 bytes
.label SOC_POTION       = 184 // 4 bytes
.label SOC_STONE        = 142 // needs 42 bytes, overlaps with some level chars

.label MAX_SNAKES = 8
.label MAX_STONES = 3
.label MAX_PIKES = 8
.label EMPTY = 255

// effects
.label MAX_EFFECTS = 8

.label EFX_ANIM_FLAME = 0 // flame 1, flame 2, potion (32)
.label EFX_ANIM_SNAKE = 1 // snake L, snake R (32)
.label EFX_ANIM_JEWEL = 2 // jewel, mask (32)
.label EFX_RUN_PIKES_1 = 3
.label EFX_RUN_PIKES_2 = 7
.label EFX_RUN_STONE_1 = 4
.label EFX_RUN_STONE_2 = 5
.label EFX_RUN_STONE_3 = 6

// special pikes effects
.label PIKES_MAX_FRAME = 30
.label PIKES_PHASE_1 = PIKES_MAX_FRAME - 4
.label PIKES_PHASE_2 = PIKES_MAX_FRAME - 3
.label PIKES_PHASE_3 = PIKES_MAX_FRAME - 2
.label PIKES_PHASE_0 = PIKES_MAX_FRAME - 1

// special stones effects
.label STONES_MAX_FRAME = 20
.label STONES_PHASE_1 = 5
.label STONES_PHASE_2 = 6
.label STONES_PHASE_3 = 7
.label STONES_PHASE_4 = 8
.label STONES_PHASE_5 = 9
.label STONES_PHASE_3d = 16
//.label STONES_PHASE_1d = 16
.label STONES_PHASE_0 = 17

// points
.label PTS_JEWEL = $0200
.label PTS_POTION = $0100
.label PTS_KILL = $0050

// color schemes
// classic
.label SCHEME_CLASSIC_LIGHT = LIGHT_GREY
.label SCHEME_CLASSIC_DARK = BLACK
.label SCHEME_CLASSIC_BRIGHT = WHITE
.label SCHEME_CLASSIC_DIMMED = DARK_GREY
// amber
.label SCHEME_AMBER_LIGHT = YELLOW
.label SCHEME_AMBER_DARK = BLACK
.label SCHEME_AMBER_BRIGHT = YELLOW
.label SCHEME_AMBER_DIMMED = BLACK
// green
.label SCHEME_GREEN_LIGHT = GREEN
.label SCHEME_GREEN_DARK = BLACK
.label SCHEME_GREEN_BRIGHT = LIGHT_GREEN
.label SCHEME_GREEN_DIMMED = GREEN
// blue
.label SCHEME_BLUE_LIGHT = LIGHT_BLUE
.label SCHEME_BLUE_DARK = BLACK
.label SCHEME_BLUE_BRIGHT = CYAN
.label SCHEME_BLUE_DIMMED = LIGHT_BLUE
// c64
.label SCHEME_C64_LIGHT = LIGHT_BLUE
.label SCHEME_C64_DARK = BLUE
.label SCHEME_C64_BRIGHT = LIGHT_GREY
.label SCHEME_C64_DIMMED = LIGHT_BLUE
// c128
.label SCHEME_C128_LIGHT = LIGHT_GREEN
.label SCHEME_C128_DARK = DARK_GREY
.label SCHEME_C128_BRIGHT = YELLOW
.label SCHEME_C128_DIMMED = LIGHT_GREEN

.label MAX_COLOR_SCHEME = 6
