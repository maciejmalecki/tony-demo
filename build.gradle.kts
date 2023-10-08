import com.github.c64lib.retroassembler.domain.AssemblerType
import com.github.c64lib.rbt.shared.domain.Color
import com.github.c64lib.rbt.shared.domain.Axis
import com.github.c64lib.rbt.shared.domain.OutputFormat

val versionTag: String? = project.findProperty("versionTag") as String?
val variant: String? = project.findProperty("variant") as String?

plugins {
    id("com.github.c64lib.retro-assembler") version "1.7.6"
    id("com.github.hierynomus.license") version "0.16.1"
}

retroProject {
    dialect = AssemblerType.KickAssembler
    dialectVersion = "5.25"
    libDirs = arrayOf(".ra/deps/c64lib", "build/charpad", "build/spritepad", "build/goattracker", "build/sprites", "build/goattracker", "src/music")
    includes = arrayOf(
        "src/kickass/tony.asm", 
        "src/kickass/splash-zzap.asm",
        "src/kickass/intro.asm"
        )
    outputFormat = OutputFormat.BIN
    val mutableValues = mutableMapOf<String, String>()
    versionTag?.let { mutableValues["version"] = it }
    variant?.let { mutableValues["variant"] = it }
    values = mutableValues.toMap()

    libFromGitHub("c64lib/common", "0.5.0")
    libFromGitHub("c64lib/chipset", "0.5.0")
    libFromGitHub("c64lib/copper64", "0.5.0")
    libFromGitHub("c64lib/text", "0.5.0")
}

license {
    header = file("LICENSE")
    excludes(listOf(".ra"))
    include("**/*.asm")
    mapping("asm", "SLASHSTAR_STYLE")
}

tasks.register<com.hierynomus.gradle.license.tasks.LicenseFormat>("licenseFormatAsm") {
    source = fileTree(".") {
        include("**/*.asm")
        exclude(".ra")
        exclude("**/exodecrunch.asm")
        exclude("build")
    }
}
tasks.register<com.hierynomus.gradle.license.tasks.LicenseCheck>("licenseAsm") {
    source = fileTree(".") {
        include("**/*.asm")
        exclude(".ra")
        exclude("**/exodecrunch.asm")
        exclude("build")
    }
}
tasks["licenseFormat"].dependsOn("licenseFormatAsm")

tasks.register<Exec>("exomize") {
    group = "build"
    description = "packs game with exomizer"
    commandLine("exomizer", "sfx", "sys", "src/kickass/tony.prg", "-o", "tonyz.prg")
}

tasks.register<Exec>("exomize-splash-mem") {
    group = "build"
    description = "packs splash screen part with exomizer"
    commandLine("exomizer", "mem", "-l", "none", "src/kickass/splash-zzap.bin@0xA0BD", "-o", "src/kickass/splash-zzap.z.bin")
}

tasks.register<Exec>("exomize-intro-mem") {
    group = "build"
    description = "packs splash screen part with exomizer"
    commandLine("exomizer", "mem", "-l", "none", "src/kickass/intro.bin@0x77e9", "-o", "src/kickass/intro.z.bin")
}

tasks.register<Exec>("exomize-tony-mem") {
    group = "build"
    description = "packs main game part with exomizer"
    commandLine("exomizer", "mem",  "-l", "none", "src/kickass/tony.prg@0x0D00,193", "-o", "src/kickass/tony.z.bin")
}

tasks.register<Exec>("build-link") {
    group = "build"
    description = "links the whole game"
    commandLine("java", "-jar",  ".ra/asms/ka/5.25/KickAss.jar", 
    "-libdir", ".ra/deps/c64lib",
    "src/kickass/tony-loader.asm")
}

tasks.register<Copy>("link") {
    from("src/kickass/tony-loader.prg")
    from("src/kickass/tony.d64")
    into(".")
    rename("tony-loader.prg", "tony-$versionTag$variant.prg")
    rename("tony.d64", "tony-$versionTag$variant.d64")
}

tasks["link"].dependsOn("build-link")

tasks.matching { it.name == "build" }.configureEach {
    finalizedBy("exomize", "exomize-splash-mem", "exomize-tony-mem", "exomize-intro-mem")
}


preprocess {

    // TONY's assets

    goattracker {
      getInput().set(file("src/music/humbug2.sng"))
      getUseBuildDir().set(true)
      music {
        getOutput().set(file("humbug2.sid"))
        bufferedSidWrites = true
        sfxSupport = true
        storeAuthorInfo = false
        playerMemoryLocation = 0xA0
      }
    }

    goattracker {
      getInput().set(file("src/music/sanction.sng"))
      getUseBuildDir().set(true)
      music {
        getOutput().set(file("sanction.sid"))
        bufferedSidWrites = true
        sfxSupport = true
        storeAuthorInfo = false
        playerMemoryLocation = 0xA0
      }
    }

    goattracker {
      getInput().set(file("src/music/funktest.sng"))
      getUseBuildDir().set(true)
      music {
        getOutput().set(file("funktest.sid"))
        bufferedSidWrites = true
        sfxSupport = true
        storeAuthorInfo = false
        playerMemoryLocation = 0xE0
      }
    }

    charpad {
        getInput().set(file("src/charpad/belka-nowa-20023-v5.ctm"))
        getUseBuildDir().set(true)
        outputs {
            charset {
                output = file("dashboard-charset.bin")
            }
            map {
                interleaver {
                    output = file("dashboard-map.bin")
                }
                interleaver {
                }
            }
        }
    }

    spritepad {
        getInput().set(file("src/spritepad/eyes.spd"))
        getUseBuildDir().set(true)
        outputs {
            sprites {
                output = file("eyes.bin")
            }
        }
    }

    charpad {
        getInput().set(file("src/charpad/font.ctm"))
        getUseBuildDir().set(true)
        outputs {
            charset {
                output = file("font.bin")
            }
        }
    }

    charpad {
        getInput().set(file("src/charpad/game-end.ctm"))
        getUseBuildDir().set(true)
        outputs {
            charset {
                output = file("game-end.bin")
            }
        }
    }

    charpad {
        // getInput().set(file("src/charpad/demo-level.ctm"))
        getInput().set(file("src/charpad/castle_map.ctm"))
        getUseBuildDir().set(true)
        outputs {
            charset {
                output = file("demo-level-charset.bin")
            }
            charsetMaterials {
                output = file("demo-level-materials.bin")
            }
            for (x in 0..4) {
                for (y in 0..5) {
                    map {
                        left = x*40
                        top = y*20
                        right = (x + 1)*40
                        bottom = (y + 1)*20

                        interleaver {
                            output = file("demo-level-map-$x-$y.bin")
                        }
                        interleaver {
                        }
                    }
                }
            }
        }
    }

    // to override title screen
    charpad {
        getInput().set(file("src/charpad/demo-level.ctm"))
        getUseBuildDir().set(true)
        outputs {
            map {
                left = 4*40
                top = 0*20
                right = (4 + 1)*40
                bottom = (0 + 1)*20

                interleaver {
                    output = file("demo-level-map-4-0.bin")
                }
                interleaver {
                }
            }
        }
    }

    // Main character's sprites
    image {
        getInput().set(file("src/spritepad/tony chodzenie 4 klatki.png"))
        getUseBuildDir().set(true)
        split {
            width = 32
            height = 32
            extend {
                newWidth = 48
                newHeight = 42
                fillColor = Color(0, 0, 0, 255)
                split {
                    width = 24
                    height = 21
                    sprite {
                        getOutput().set(file("sprites/tony-walk-right.bin"))
                    }
                }
            }
        }
    }

    image {
        getInput().set(file("src/spritepad/tony chodzenie 4 klatki.bg.png"))
        getUseBuildDir().set(true)
        split {
            width = 32
            height = 32
            extend {
                newWidth = 48
                newHeight = 42
                fillColor = Color(0, 0, 0, 255)
                reduceResolution {
                    reduceY = 2
                    split {
                        width = 24
                        height = 21
                        sprite {
                            getOutput().set(file("sprites/tony-walk-right.bg.bin"))
                        }
                    }
                }
            }
        }
    }


    image {
        getInput().set(file("src/spritepad/tony chodzenie 4 klatki.png"))
        getUseBuildDir().set(true)
        cut {
            width = 32*4 - 7
            flip {
                axis = Axis.Y
                extend {
                    newWidth = 32*4
                    split {
                        width = 32
                        height = 32
                        extend {
                            newWidth = 48
                            newHeight = 42
                            fillColor = Color(0, 0, 0, 255)
                            split {
                                width = 24
                                height = 21
                                sprite {
                                    getOutput().set(file("sprites/tony-walk-left.bin"))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    image {
        getInput().set(file("src/spritepad/tony chodzenie 4 klatki.bg.png"))
        getUseBuildDir().set(true)
        cut {
            width = 32*4 - 7
            flip {
                axis = Axis.Y
                extend {
                    newWidth = 32*4
                    split {
                        width = 32
                        height = 32
                        extend {
                            newWidth = 48
                            newHeight = 42
                            fillColor = Color(0, 0, 0, 255)
                            reduceResolution {
                                reduceY = 2
                                split {
                                    width = 24
                                    height = 21
                                    sprite {
                                        getOutput().set(file("sprites/tony-walk-left.bg.bin"))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    image {
        getInput().set(file("src/spritepad/tony kucanie 4 klatki.png"))
        getUseBuildDir().set(true)
        split {
            width = 32
            height = 32
            extend {
                newWidth = 48
                newHeight = 42
                fillColor = Color(0, 0, 0, 255)
                split {
                    width = 24
                    height = 21
                    sprite {
                        getOutput().set(file("sprites/tony-duck-left.bin"))
                    }
                }
            }
        }
    }

    image {
        getInput().set(file("src/spritepad/tony kucanie 4 klatki.bg.png"))
        getUseBuildDir().set(true)
        split {
            width = 32
            height = 32
            extend {
                newWidth = 48
                newHeight = 42
                fillColor = Color(0, 0, 0, 255)
                reduceResolution {
                    reduceY = 2
                    split {
                        width = 24
                        height = 21
                        sprite {
                            getOutput().set(file("sprites/tony-duck-left.bg.bin"))
                        }
                    }
                }
            }
        }
    }

    image {
        getInput().set(file("src/spritepad/tony kucanie 4 klatki.png"))
        getUseBuildDir().set(true)
        cut {
            width = 32*4 - 7
            flip {
                axis = Axis.Y
                extend {
                    newWidth = 32*4
                    split {
                        width = 32
                        height = 32
                        extend {
                            newWidth = 48
                            newHeight = 42
                            fillColor = Color(0, 0, 0, 255)
                            split {
                                width = 24
                                height = 21
                                sprite {
                                    getOutput().set(file("sprites/tony-duck-right.bin"))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    image {
        getInput().set(file("src/spritepad/tony kucanie 4 klatki.bg.png"))
        getUseBuildDir().set(true)
        cut {
            width = 32*4 - 7
            flip {
                axis = Axis.Y
                extend {
                    newWidth = 32*4
                    split {
                        width = 32
                        height = 32
                        extend {
                            newWidth = 48
                            newHeight = 42
                            fillColor = Color(0, 0, 0, 255)
                            reduceResolution {
                                reduceY = 2
                                split {
                                    width = 24
                                    height = 21
                                    sprite {
                                        getOutput().set(file("sprites/tony-duck-right.bg.bin"))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    image {
        getInput().set(file("src/spritepad/tony spoczynek 4klatki.png"))
        getUseBuildDir().set(true)
        split {
            width = 32
            height = 32
            extend {
                newWidth = 48
                newHeight = 42
                fillColor = Color(0, 0, 0, 255)
                split {
                    width = 24
                    height = 21
                    sprite {
                        getOutput().set(file("sprites/tony-idling-left.bin"))
                    }
                }
            }
        }
    }

    image {
        getInput().set(file("src/spritepad/tony spoczynek 4klatki.bg.png"))
        getUseBuildDir().set(true)
        split {
            width = 32
            height = 32
            extend {
                newWidth = 48
                newHeight = 42
                fillColor = Color(0, 0, 0, 255)
                reduceResolution {
                    reduceY = 2
                    split {
                        width = 24
                        height = 21
                        sprite {
                            getOutput().set(file("sprites/tony-idling-left.bg.bin"))
                        }
                    }
                }
            }
        }
    }

    image {
        getInput().set(file("src/spritepad/tony spoczynek 4klatki.png"))
        getUseBuildDir().set(true)
        cut {
            width = 32*4 - 7
            flip {
                axis = Axis.Y
                extend {
                    newWidth = 32*4
                    split {
                        width = 32
                        height = 32
                        extend {
                            newWidth = 48
                            newHeight = 42
                            fillColor = Color(0, 0, 0, 255)
                            split {
                                width = 24
                                height = 21
                                sprite {
                                    getOutput().set(file("sprites/tony-idling-right.bin"))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    image {
        getInput().set(file("src/spritepad/tony spoczynek 4klatki.bg.png"))
        getUseBuildDir().set(true)
        cut {
            width = 32*4 - 7
            flip {
                axis = Axis.Y
                extend {
                    newWidth = 32*4
                    split {
                        width = 32
                        height = 32
                        extend {
                            newWidth = 48
                            newHeight = 42
                            fillColor = Color(0, 0, 0, 255)
                            reduceResolution {
                                reduceY = 2
                                split {
                                    width = 24
                                    height = 21
                                    sprite {
                                        getOutput().set(file("sprites/tony-idling-right.bg.bin"))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    image {
        getInput().set(file(("src/spritepad/tony_drabina.png")))
        getUseBuildDir().set(true)
       
        split {
            width = 32
            height = 32
            extend {
                newWidth = 48
                newHeight = 42
                fillColor = Color(0, 0, 0, 255)
                split {
                    width = 24
                    height = 21
                    sprite {
                        getOutput().set(file("sprites/tony-ladder.bin"))
                    }
                }
            }
        }
    }

    image {
        getInput().set(file(("src/spritepad/tony_drabina.bg.png")))
        getUseBuildDir().set(true)
       
        split {
            width = 32
            height = 32
            extend {
                newWidth = 48
                newHeight = 42
                fillColor = Color(0, 0, 0, 255)
                reduceResolution {
                    reduceY = 2
                    split {
                        width = 24
                        height = 21
                        sprite {
                            getOutput().set(file("sprites/tony-ladder.bg.bin"))
                        }
                    }
                }
            }
        }
    }

    image {
        getInput().set(file(("src/spritepad/tony skok 2 klatki.png")))
        getUseBuildDir().set(true)
       
        split {
            width = 32
            height = 32
            extend {
                newWidth = 48
                newHeight = 42
                fillColor = Color(0, 0, 0, 255)
                split {
                    width = 24
                    height = 21
                    sprite {
                        getOutput().set(file("sprites/tony-jump-right.bin"))
                    }
                }
            }
        }
    }

    image {
        getInput().set(file(("src/spritepad/tony skok 2 klatki.bg.png")))
        getUseBuildDir().set(true)
       
        split {
            width = 32
            height = 32
            extend {
                newWidth = 48
                newHeight = 42
                fillColor = Color(0, 0, 0, 255)
                reduceResolution {
                    reduceY = 2
                    split {
                        width = 24
                        height = 21
                        sprite {
                            getOutput().set(file("sprites/tony-jump-right.bg.bin"))
                        }
                    }
                }
            }
        }
    }


    image {
        getInput().set(file("src/spritepad/tony skok 2 klatki.png"))
        getUseBuildDir().set(true)
       
        cut {
            width = 32*2 - 6
            flip {
                axis = Axis.Y
                extend {
                    newWidth = 32*2
                    split {
                        width = 32
                        height = 32
                        extend {
                            newWidth = 48
                            newHeight = 42
                            fillColor = Color(0, 0, 0, 255)
                            split {
                                width = 24
                                height = 21
                                sprite {
                                    getOutput().set(file("sprites/tony-jump-left.bin"))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    image {
        getInput().set(file("src/spritepad/tony skok 2 klatki.bg.png"))
        getUseBuildDir().set(true)
       
        cut {
            width = 32*2 - 6
            flip {
                axis = Axis.Y
                extend {
                    newWidth = 32*2
                    split {
                        width = 32
                        height = 32
                        extend {
                            newWidth = 48
                            newHeight = 42
                            fillColor = Color(0, 0, 0, 255)
                            reduceResolution {
                                reduceY = 2
                                split {
                                    width = 24
                                    height = 21
                                    sprite {
                                        getOutput().set(file("sprites/tony-jump-left.bg.bin"))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    image {
        getInput().set(file("src/spritepad/tony smierc lewo 5klatek.png"))
        getUseBuildDir().set(true)

        split {
            width = 32
            height = 32
            extend {
                newWidth = 48
                newHeight = 42
                fillColor = Color(0, 0, 0, 255)
                split {
                    width = 24
                    height = 21
                    sprite {
                        getOutput().set(file("sprites/tony-death-left.bin"))
                    }
                }
            }
        }
    }

    image {
        getInput().set(file("src/spritepad/tony smierc lewo 5klatek.bg.png"))
        getUseBuildDir().set(true)

        split {
            width = 32
            height = 32
            extend {
                newWidth = 48
                newHeight = 42
                fillColor = Color(0, 0, 0, 255)
                reduceResolution {
                    reduceY = 2
                    split {
                        width = 24
                        height = 21
                        sprite {
                            getOutput().set(file("sprites/tony-death-left.bg.bin"))
                        }
                    }
                }
            }
        }
    }

    image {
        getInput().set(file("src/spritepad/tony smierc prawo 5klatek.png"))
        getUseBuildDir().set(true)

        split {
            width = 32
            height = 32
            extend {
                newWidth = 48
                newHeight = 42
                fillColor = Color(0, 0, 0, 255)
                split {
                    width = 24
                    height = 21
                    sprite {
                        getOutput().set(file("sprites/tony-death-right.bin"))
                    }
                }
            }
        }
    }

    image {
        getInput().set(file("src/spritepad/tony smierc prawo 5klatek.bg.png"))
        getUseBuildDir().set(true)

        split {
            width = 32
            height = 32
            extend {
                newWidth = 48
                newHeight = 42
                fillColor = Color(0, 0, 0, 255)
                reduceResolution {
                    reduceY = 2
                    split {
                        width = 24
                        height = 21
                        sprite {
                            getOutput().set(file("sprites/tony-death-right.bg.bin"))
                        }
                    }
                }
            }
        }
    }

    // skull
    image {
        getInput().set(file("src/spritepad/czaszka pionowa.png"))
        getUseBuildDir().set(true)

        split {
            width = 16
            height = 21
            extend {
                newWidth = 24
                newHeight = 21
                fillColor = Color(0, 0, 0, 255)
                split {
                    width = 24
                    height = 21
                    sprite {
                        getOutput().set(file("sprites/skull.bin"))
                    }
                }
            }
        }
    }

    // bat vertical
    image {
        getInput().set(file("src/spritepad/nietoperek pionowy.png"))
        getUseBuildDir().set(true)

        split {
            width = 16
            height = 16
            extend {
                newWidth = 24
                newHeight = 21
                fillColor = Color(0, 0, 0, 255)
                split {
                    width = 24
                    height = 21
                    sprite {
                        getOutput().set(file("sprites/bat-vertical.bin"))
                    }
                }
            }
        }
    }

    // deadman
    image {
        // getInput().set(file("src/spritepad/Sprite-trupek.png"))
        getInput().set(file("src/spritepad/trupek zamek.png"))
        getUseBuildDir().set(true)

        flip {
            axis = Axis.Y
            split {
                width = 16
                height = 16
                extend {
                    newWidth = 24
                    newHeight = 21
                    fillColor = Color(0, 0, 0, 255)
                    split {
                        width = 24
                        height = 21
                        sprite {
                            getOutput().set(file("sprites/deadman-left.bin"))
                        }
                    }
                }
            }
        }
    }

    image {
        // getInput().set(file("src/spritepad/Sprite-trupek.png"))
        getInput().set(file("src/spritepad/trupek zamek.png"))
        getUseBuildDir().set(true)

        split {
            width = 16
            height = 16
            extend {
                newWidth = 24
                newHeight = 21
                fillColor = Color(0, 0, 0, 255)
                split {
                    width = 24
                    height = 21
                    sprite {
                        getOutput().set(file("sprites/deadman-right.bin"))
                    }
                }
            }
        }
    }

    image {
        getInput().set(file("src/spritepad/nietoperz new 4 klatki 16x16b.png"))
        getUseBuildDir().set(true)

        split {
            width = 16
            height = 16
            extend {
                newWidth = 24
                newHeight = 21
                fillColor = Color(0, 0, 0, 255)
                split {
                    width = 24
                    height = 21
                    sprite {
                        getOutput().set(file("sprites/bat-left.bin"))
                    }
                }
            }
        }
    }

    image {
        getInput().set(file("src/spritepad/nietoperz new 4 klatki 16x16b.png"))
        getUseBuildDir().set(true)

        flip {
            axis = Axis.Y
            split {
                width = 16
                height = 16
                extend {
                    newWidth = 24
                    newHeight = 21
                    fillColor = Color(0, 0, 0, 255)
                    split {
                        width = 24
                        height = 21
                        sprite {
                            getOutput().set(file("sprites/bat-right.bin"))
                        }
                    }
                }
            }
        }
    }

    // flames
    image {
        getInput().set(file("src/spritepad/ogien.png"))
        getUseBuildDir().set(true)
        split {
            width = 16
            height = 16
            cut {
                left = 5
                extend {
                    newWidth = 16
                    fillColor = Color(0, 0, 0, 255)
                    split {
                        width = 8
                        height = 16
                        bitmap {
                            getOutput().set(file("sprites/fire.bin"))
                        }
                    }
                }
            }
        }
    }

    // door
    image {
        getInput().set(file("src/spritepad/drzwi_.png"))
        getUseBuildDir().set(true)
        extend {
            bitmap {
                getOutput().set(file("sprites/door.bin"))
            }
        }
    }

    // door code
    image {
        // getInput().set(file("src/spritepad/drzwi_zamek kod2.png"))
        getInput().set(file("src/spritepad/drzwi_klucz_piramida_zamek.png"))
        getUseBuildDir().set(true)
        extend {
            bitmap {
                getOutput().set(file("sprites/doorcode.bin"))
            }
        }
    }

    // key
    image {
        getInput().set(file("src/spritepad/klucz.png"))
        getUseBuildDir().set(true)
        extend {
            bitmap {
                getOutput().set(file("sprites/key.bin"))
            }
        }
    }

    // keycode
    image {
        getInput().set(file("src/spritepad/klucz_kod.png"))
        getUseBuildDir().set(true)
        split {
            width = 16
            height = 16
            extend {
                bitmap {
                    getOutput().set(file("sprites/keycode.bin"))
                }
            }
        }
    }

    // potion
    image {
        getInput().set(file("src/spritepad/miksturka 4klatki.png"))
        getUseBuildDir().set(true)
        split {
            width = 16
            height = 16
            extend {
                bitmap {
                    getOutput().set(file("sprites/potion.bin"))
                }
            }
        }
    }

    // jewel
    image {
        getInput().set(file("src/spritepad/klejnot maly maska.png"))
        getUseBuildDir().set(true)
        split {
            width = 16
            height = 16
            extend {
                bitmap {
                    getOutput().set(file("sprites/jewel.bin"))
                }
            }
        }
    }

    // pikes
    image {
        getInput().set(file("src/spritepad/pale 1.png"))
        getUseBuildDir().set(true)
        split {
            width = 8
            height = 8
            extend {
                bitmap {
                    getOutput().set(file("sprites/pikes.bin"))
                }
            }
        }
    }

    // stones
    image {
        getInput().set(file("src/spritepad/glazy_sprite.png"))
        getUseBuildDir().set(true)
        split {
            width = 8
            height = 8
            extend {
                bitmap {
                    getOutput().set(file("sprites/stones.bin"))
                }
            }
        }
    }

    // snake right
    image {
        getInput().set(file("src/spritepad/waz-Sheet-4-klatki.png"))
        getUseBuildDir().set(true)
        split {
            width = 16
            height = 16
            extend {
                bitmap {
                    getOutput().set(file("sprites/snake-right.bin"))
                }
            }
        }
    }

    // snake left
    image {
        getInput().set(file("src/spritepad/waz-Sheet-4-klatki.png"))
        getUseBuildDir().set(true)
        split {
            width = 16
            height = 16
            flip {
                axis = Axis.Y
                bitmap {
                    getOutput().set(file("sprites/snake-left.bin"))
                }
            }
        }
    }

    // SPLASHSCREEN(S) assets
    charpad {
        getInput().set(file("src/charpad/splash-screen-zzap.ctm"))
        getUseBuildDir().set(true)
        outputs {
            charset {
                output = file("splash-screen-zzap.charset.bin")
            }
            map {
                interleaver {
                    output = file("splash-screen-zzap.maplo.bin")
                }
                interleaver {
                    output = file("splash-screen-zzap.maphi.bin")
                }
            }
        }
    }

    charpad {
        getInput().set(file("src/charpad/splash-screen-e.ctm"))
        getUseBuildDir().set(true)
        outputs {
            charset {
                output = file("splash-screen-e.charset.bin")
            }
            map {
                interleaver {
                    output = file("splash-screen-e.maplo.bin")
                }
                interleaver {
                    output = file("splash-screen-e.maphi.bin")
                }
            }
        }
    }

    // INTRO assets
    charpad {
        getInput().set(file("src/charpad/intro-font.ctm"))
        getUseBuildDir().set(true)
        outputs {
            charset {
                output = file("intro-font.charset.bin")
            }
        }
    }

    charpad {
        getInput().set(file("src/charpad/historia3.ctm"))
        getUseBuildDir().set(true)
        outputs {
            charset {
                output = file("intro.charset.bin")
            }
            map {
                interleaver {
                    output = file("intro.maplo.bin")
                }
                interleaver {
                    output = file("intro.maphi.bin")
                }
            }
        }
    }
}
