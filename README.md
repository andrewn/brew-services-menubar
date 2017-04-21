brew-services-menubar
===

An OS X menu item for starting and stopping homebrew services Edit.

This reads the [homebrew-services](https://github.com/Homebrew/homebrew-services) command 

![Screenshot](docs/screenshot.png)

## Install

1. Install [homebrew-services](https://github.com/Homebrew/homebrew-services)
2. Download from the [Releases](https://github.com/andrewn/brew-services-menubar/releases) page.

By default looks for `/usr/local/bin/brew`. If this not correct for your setup,
you can customize it using:

```sh
defaults write andrewnicolaou.BrewServicesMenubar brewExecutable /usr/local/bin/brew
```

## Contributors

- Andrew Nicolaou (https://github.com/andrewn)

## License

Icon is [Beer by Enemen from the Noun Project](https://thenounproject.com/search/?q=beer&i=783212).
