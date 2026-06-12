function restore-secrets
    set -l secrets_dir ~/.local/share/secrets
    set -l secrets_file $secrets_dir/fish.fish

    mkdir -p $secrets_dir

    if not bw login --check >/dev/null 2>&1
        echo "Logging in to Bitwarden..."
        bw login
    end

    echo "Unlocking vault..."
    set -gx BW_SESSION (bw unlock --raw)

    echo "Syncing vault..."
    bw sync

    echo "Downloading secrets..."
    bw get notes fish-secrets > $secrets_file

    chmod 600 $secrets_file

    echo "Secrets restored to $secrets_file"
end
