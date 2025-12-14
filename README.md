# Beddu 💅🏻

A lightweight bash framework for interactive scripts with pretty output.

## Overview

**Beddu** is a minimalist bash library that makes your terminal scripts more interactive and visually appealing. It provides easy-to-use and intuitive functions for colorful text, spinners, progress indicators, and user interaction.

Your scripts will look something like this:

![Example](./demo/carbon.png)

And you will easily be able to build things like:

[![asciicast](https://asciinema.org/a/E4frqYZFk3XR38UkGYs5ASnKC.svg)](https://asciinema.org/a/E4frqYZFk3XR38UkGYs5ASnKC)

## Features

- **Text Formatting**: Bold, italic, underline and more
- **Color Support**: Basic colors and full ANSI 256 color support
- **User Interaction**: Ask for input, confirmations, and present menu choices
- **Visual Indicators**: Spinners, checkmarks, and error symbols
- **Line Manipulation**: Replace previous output for dynamic updates

## Installation and Usage

**Beddu** is meant to be sourced in your own script.

1. Download the latest release (currently: **v1.2.0**) of `beddu.sh` to your project:

```bash
$ curl -O https://raw.githubusercontent.com/mjsarfatti/beddu/refs/tags/v1.2.0/dist/beddu.sh
```

2. Source the `beddu.sh` file in your script:

```bash
#!/usr/bin/env bash
source "/path/to/beddu.sh"

# Now use beddu functions
pen bold blue "Hello, world!"
```

## Demo

To see it in action, clone the repository, then run `make demo`. This will run the same interactive demo that you can see in the video above (please note that a 12MB wikimedia.org random file will be downloaded during the demo to showcase the functionality - a prompt will let you delete it at the end):

```bash
$ git clone https://github.com/mjsarfatti/beddu.git
$ make demo
```

## Examples

More can be seen by looking at the [demo](./demo/demo.sh) file, but here is a quick overview:

### Text Formatting and Colors

```bash
# Basic formatting
pen bold "Bold text"
pen italic "Italic text"
pen underline "Underlined text"

# Colors
pen red "Red text"
pen green "Green text"
pen 39 "ANSI color code 39 (light blue)"

# Combined
pen bold red "Bold red text"

# Inline
pen "This is $(pen yellow "yellow"), and this is $(pen bold "bold")"
```

### Interactive Functions

```bash
# Kindly ask for input (empty answer is accepted)
seek name "What's your name?"
pen "Hello, $name!"

# Firmly ask for input (empty answer NOT accepted)
request name "No really, what's your name?"
pen "There you go, $name!"


# Yes/no confirmation (defaults to "yes")
if confirm "Continue?"; then
    pen green "Continuing..."
else
    pen red "Aborting."
fi

# Defaulting to "no"
if confirm --default-no "Are you sure?"; then
    pen green "Proceeding..."
else
    pen red "Cancelled."
fi

# Menu selection
choose color "Select a color:" "Red" "Green" "Blue"
pen "You selected: $color"
```

### Progress Indicators

```bash
# Show a progress spinner
spin "Working on it..."
sleep 2
check "Done!" # Automatically stops and replaces the spinner

# Replace lines dynamically
pen "This will be replaced..."
sleep 1
repen "Processing started..."
sleep 1
repen spin "Almost done..." # Let's add a spinner for good measure
sleep 1
check "Task completed!" # We can directly `check`, `warn`, or `throw` after a `spin` call - the message will always replace the spin line
```

## Function Reference

### Text Formatting

- `pen [OPTIONS] TEXT` - Output formatted text
  - `-n` - No newline after output
  - `bold`, `italic`, `underline` - Text styles
  - `black`, `red`, `green`, `yellow`, `blue`, `purple`, `cyan`, `white`, `grey`, `gray` - Color names
  - `0-255` - ANSI color codes

### User Interaction

- `seek [retval] PROMPT` - Get (optional) text input from user, saves the answer in `$retval`
- `request [retval] PROMPT` - Like above, but doesn't accept an empty response, saves the answer in `$retval`
- `confirm [OPTIONS] PROMPT` - Get yes/no input
  - `--default-yes` - Set default answer to "yes" (default behavior)
  - `--default-no` - Set default answer to "no"
- `choose [retval] PROMPT [OPTIONS...]` - Display a selection menu, saves the answer in `$retval`

### Progress Indicators

- `spin MESSAGE` - Show an animated spinner
- `check MESSAGE` - Show a success message (if called right after a spinner, it stops and replaces it)
- `warn MESSAGE` - Show a warning message (if called right after a spinner, it stops and replaces it)
- `throw MESSAGE` - Show an error message (if called right after a spinner, it stops and replaces it)
- `repen [OPTIONS] MESSAGE` - Like `pen`, but replace the previous line (it accepts all the same options)

## FAQ

### Q: It doesn't work on my computer?

A: **Beddu** requires bash v4+. If you are on a mac, you probably want to `brew install bash`. If your bash version checks out, please file an issue!

### Q: Can you add feature X?

A: Most likely, not (but never say never). This is meant to be a _minimal_ toolkit to quickly jot down simple interactive scripts, nothing more. If you are looking for something more complete check out [Gum](https://github.com/charmbracelet/gum) (bash), [Inquire](https://github.com/mikaelmello/inquire) (Rust), [Enquirer](https://github.com/enquirer/enquirer) (Node) or [Awesome Bash](https://github.com/awesome-lists/awesome-bash).

## License

[MIT](./LICENSE)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
