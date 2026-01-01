# Nunchux Demo
# Run: vhs demo.tape

Output demo.gif
Set Width 1600
Set Height 800
Set FontSize 16
Set FontFamily "CaskaydiaMono Nerd Font"
Set Theme "Catppuccin Mocha"
Set Padding 0

# Start in tmux
Hide
Type "tmux new-session -s 'nunchux demo'"
Enter
Sleep 1s
Show

# Open nunchux and select notes
Sleep 500ms
Ctrl+Space
Sleep 1s
Type "notes"
Sleep 500ms
Enter
Sleep 3.5s

# Close nvim
Type ":q"
Enter
Sleep 500ms

# Open nunchux again, filter for system submenu
Ctrl+Space
Sleep 1.5s
Type "system"
Sleep 500ms
Enter
Sleep 1s

# Open btop from system submenu
Type "btop"
Sleep 500ms
Enter
Sleep 3s

# Quit btop
Type "q"
Sleep 800ms

# Open nunchux again, show config directory browser
Ctrl+Space
Sleep 1s
Type "config"
Sleep 500ms
Enter
Sleep 1.5s

# Search for nunchux config file and open it
Type "nunchux/config"
Sleep 500ms
Enter
Sleep 1.5s

# Quit nvim
Type ":q"
Enter
Sleep 500ms

# Open files (yazi) to browse to datamadsen
Ctrl+Space
Sleep 1s
Type "files"
Sleep 500ms
Enter
Sleep 1.5s

# Navigate in yazi to ../datamadsen
Type "h"
Sleep 500ms
Type "k"
Sleep 200ms
Type "k"
Sleep 200ms
Type "l"
Sleep 500ms

# Quit yazi (should cd to the directory)
Type "q"
Sleep 800ms

# Show there's a justfile
Type "# nunchux shows just recipes in the menu"
Ctrl+C
Sleep 500ms
Type "ls justfile"
Enter
Sleep 1.5s

# Open nunchux to show justfile support
Ctrl+Space
Sleep 1.5s

# Navigate to a just recipe
Down
Sleep 150ms
Down
Sleep 150ms
Down
Sleep 150ms
Down
Sleep 150ms
Down
Sleep 150ms
Down
Sleep 150ms
Down
Sleep 150ms
Down
Sleep 150ms
Down
Sleep 150ms
Down
Sleep 150ms
Down
Sleep 150ms
Down
Sleep 1500ms
Enter
Sleep 2s

# While building, open nunchux and launch hacker news
Ctrl+Space
Sleep 1s
Type "hacker"
Sleep 500ms
Enter
Sleep 5s

# Select a story
Type "j"
Sleep 200ms
Type "j"
Sleep 200ms
Type "j"
Sleep 200ms
Type "j"
Sleep 200ms
Type "j"
Sleep 200ms
Type "j"
Sleep 200ms
Type "j"
Sleep 200ms
Enter
Sleep 2000ms
Type "j"
Sleep 5s

# Thanks for watching
Type "q"
Sleep 500ms
Ctrl+Space
Sleep 1s
Type "bye"
Sleep 500ms
Enter
Sleep 4s
