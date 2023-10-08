# Tony: Born for Aventure (Demo version)
[![CircleCI](https://dl.circleci.com/status-badge/img/gh/maciejmalecki/tony-demo/tree/main.svg?style=shield)](https://dl.circleci.com/status-badge/redirect/gh/maciejmalecki/tony-demo/tree/main)
[![CircleCI](https://dl.circleci.com/status-badge/img/gh/maciejmalecki/tony-demo/tree/develop.svg?style=shield)](https://dl.circleci.com/status-badge/redirect/gh/maciejmalecki/tony-demo/tree/develop)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This is a complete, buildable source code of the game.
Tony: Born for Adventure is a flipped screen platformer developed for various retro platforms, including Amiga, Atari, ZX Spectrum and Commodore 64.
This is a Commodore 64 version.

## How to build the game
To build this game, you need to have a Java 15+ Runtime Environment installed.
Grab one from the following location: https://jdk.java.net/

You also need an Exomizer cruncher that can be obtained from: https://bitbucket.org/magli143/exomizer/wiki/downloads/exomizer-3.1.1.zip.
Ensure that `exomizer.exe` is on your PATH.

Once this is done, you can build the game with the following command, executed from the root of the project. 

```
gradlew build link
```

Once the building process finishes, you can find the game executable in the root directory: `tony-e.prg` and `tony-e.d64`.