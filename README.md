brew-services-menubar
===

An OS X menu item for starting and stopping homebrew services Edit.

This reads the [homebrew-services](https://github.com/Homebrew/homebrew-services) command 

![Screenshot](docs/screenshot.png)

## Install

1. Make sure [homebrew-services](https://github.com/Homebrew/homebrew-services) is installed.
(Try running `brew services list`.)

### using Homebrew-Cask

2. `brew cask install brewservicesmenubar`

### manually

2. Download from the [Releases](https://github.com/andrewn/brew-services-menubar/releases) page.

## Configuration

By default looks for `/usr/local/bin/brew`. If this not correct for your setup,
you can customize it using:

```sh
defaults write andrewnicolaou.BrewServicesMenubar brewExecutable /usr/local/bin/brew
```

## Contributors

- Andrew Nicolaou (https://github.com/andrewn)
- Stéphan Kochen (https://github.com/stephank)
- Stefan Sundin (https://github.com/stefansundin) - contributed Homebrew-Cask for easy installation

## License

Icon is [Beer by Enemen from the Noun Project](https://thenounproject.com/search/?q=beer&i=783212).
