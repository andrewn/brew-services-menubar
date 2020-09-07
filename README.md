brew-services-menubar
===

> An OS X menu item for starting and stopping homebrew services.

This reads the [homebrew-services](https://github.com/Homebrew/homebrew-services) command, showing you the status of your services and allowing them to be started, stopped and restarted.

<img src="docs/screenshot.png" alt="Screenshot" width="197">

## Install

1. Make sure [homebrew-services](https://github.com/Homebrew/homebrew-services) is installed.
(Try running `brew services list`.)

### using Homebrew-Cask

2. `brew cask install brewservicesmenubar`

### manually

2. Download from the [Releases](https://github.com/andrewn/brew-services-menubar/releases) page.

## Usage

- Start a specific service by clicking its name
- Stop a specific running service (indicated with a tick) by clicking its name
- Hold the <kbd>Option</kbd> key to allow a single service to be restarted

## Configuration

By default looks for `/usr/local/bin/brew`. If this not correct for your setup,
you can customize it using:

```sh
defaults write andrewnicolaou.BrewServicesMenubar brewExecutable /usr/local/bin/brew
```

## Contributors

- Andrew Nicolaou (https://github.com/andrewn)
- Stéphan Kochen (https://github.com/stephank)
- Stefan Sundin (https://github.com/stefansundin)

## License

Icon is [Beer by Enemen from the Noun Project](https://thenounproject.com/search/?q=beer&i=783212).
