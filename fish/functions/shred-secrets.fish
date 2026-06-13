function shred-secrets
    set -l secrets_dir ~/.local/share/secrets
    set -l secrets_file $secrets_dir/fish.fish

    if not test -e $secrets_file
        echo "No secrets file at $secrets_file"
        return 0
    end

    shred -u -v -z -n 3 $secrets_file
    rmdir $secrets_dir 2>/dev/null

    echo "Securely shredded $secrets_file"
end
