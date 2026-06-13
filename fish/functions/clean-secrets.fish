function clean-secrets
    set -l secrets_dir ~/.local/share/secrets
    set -l secrets_file $secrets_dir/fish.fish

    if not test -e $secrets_file
        echo "No secrets file at $secrets_file"
        return 0
    end

    rm -f $secrets_file
    rmdir $secrets_dir 2>/dev/null

    echo "Removed $secrets_file"
end
