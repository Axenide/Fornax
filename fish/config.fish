set -U fish_greeting

fish_add_path -g $HOME/.cache/.bun/bin
fish_add_path -g $HOME/.bun/bin
fish_add_path -g $HOME/.local/share/go/bin
starship init fish | source
source (dirname (status -f))/aliases.fish
source (dirname (status -f))/ffmpeg.fish
source (dirname (status -f))/env.fish
zoxide init fish | source


function conda-on
    eval /home/adriano/.local/share/miniforge3/bin/conda "shell.fish" "hook" | source
end
