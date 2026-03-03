# gfork — Git local clone workflow for parallel feature development
# https://github.com/jax-agent/gfork
#
# Fish shell version. Install:
#   curl -o ~/.config/fish/functions/gfork.fish \
#     https://raw.githubusercontent.com/jax-agent/gfork/main/gfork.fish

function _gfork_base
    if set -q GFORK_DIR
        echo $GFORK_DIR
    else
        echo $HOME/.gfork
    end
end

function gfork --description "Isolated git clone workflow for parallel development"
    switch $argv[1]
        case cd
            _gfork_cd $argv[2]
            return
        case rm remove clean
            _gfork_rm $argv[2]
            return
        case ls list
            _gfork_ls
            return
        case update upgrade
            _gfork_update $argv[2..]
            return
        case -h --help help
            _gfork_help
            return
    end

    # Default: create a clone
    # Parse flags
    set use_local 0
    set parsed_args
    for arg in $argv
        if test "$arg" = "--local"
            set use_local 1
        else
            set parsed_args $parsed_args $arg
        end
    end
    set argv $parsed_args

    if test (count $argv) -lt 1
        echo "Usage: gfork <feature-name> [source-branch] [--local]"
        return 1
    end

    set feature $argv[1]

    set repo_root (git rev-parse --show-toplevel 2>/dev/null)
    if test $status -ne 0
        echo "✗ Not inside a git repository."
        return 1
    end

    if test (count $argv) -ge 2
        set source_branch $argv[2]
    else
        set source_branch (git rev-parse --abbrev-ref HEAD 2>/dev/null)
    end

    set repo_name (basename $repo_root)
    set base (_gfork_base)
    set dest $base/$repo_name--$feature

    if test -d $dest
        echo "✗ '$dest' already exists. Choose a different name or delete it first."
        return 1
    end

    mkdir -p $base

    # Always clone locally (fast, preserves .env / dotfiles / local config)
    # Then repoint origin to the real remote so pushes go straight to GitHub
    echo "⎇  Cloning '$source_branch' → $dest"
    git clone --local $repo_root $dest -b $source_branch --quiet
    or return 1

    if test $use_local -eq 0
        set remote_url ""
        for remote in origin upstream github
            set url (git -C $repo_root remote get-url $remote 2>/dev/null)
            if test $status -eq 0
                if not string match -qr '^/|^file://|^\./' -- $url
                    set remote_url $url
                    break
                end
            end
        end
        if test -z "$remote_url"
            for remote in (git -C $repo_root remote)
                set url (git -C $repo_root remote get-url $remote 2>/dev/null)
                if test $status -eq 0
                    if not string match -qr '^/|^file://|^\./' -- $url
                        set remote_url $url
                        break
                    end
                end
            end
        end
        if test -n "$remote_url"
            git -C $dest remote set-url origin $remote_url
            echo "   origin → $remote_url"
        else
            echo "⚠  No GitHub remote found — origin still points to local parent"
        end
    end

    echo "✓ Clone ready: $dest"
    echo ""
    echo "  gfork cd $feature"
    echo "  # When done: gfork rm $feature"
end

function _gfork_dest --argument-names name
    set repo_root (git rev-parse --show-toplevel 2>/dev/null)
    if test $status -ne 0
        echo "✗ Not inside a git repository." >&2
        return 1
    end
    set repo_name (basename $repo_root)
    set base (_gfork_base)

    if string match -q "$repo_name--*" $name
        echo $base/$name
    else
        echo $base/$repo_name--$name
    end
end

function _gfork_cd --argument-names name
    if test -z "$name"
        echo "Usage: gfork cd <feature-name>"
        return 1
    end
    set dest (_gfork_dest $name)
    or return 1

    if not test -d $dest
        echo "✗ Clone not found: $dest"
        echo "  Run 'gfork ls' to see available clones."
        return 1
    end

    echo "→ $dest"
    cd $dest
end

function _gfork_rm --argument-names name
    if test -z "$name"
        echo "Usage: gfork rm <feature-name>"
        return 1
    end
    set dest (_gfork_dest $name)
    or return 1

    if not test -d $dest
        echo "✗ Clone not found: $dest"
        echo "  Run 'gfork ls' to see available clones."
        return 1
    end

    # Check for uncommitted changes
    set dirty (git -C $dest status --porcelain 2>/dev/null)
    if test -n "$dirty"
        echo "⚠  Clone has uncommitted changes:"
        git -C $dest status --short
        echo ""
    end

    # Check for unpushed commits
    set unpushed (git -C $dest log --oneline '@{u}..' 2>/dev/null)
    if test -n "$unpushed"
        echo "⚠  Clone has unpushed commits:"
        echo $unpushed
        echo ""
    end

    read --prompt-str "Delete '$dest'? [y/N] " confirm
    if test "$confirm" != y -a "$confirm" != Y
        echo "Aborted."
        return 0
    end

    rm -rf $dest
    echo "✓ Deleted: $dest"
end

function _gfork_ls
    set base (_gfork_base)

    if not test -d $base
        echo "No clones yet. Run 'gfork <feature-name>' to create one."
        return 0
    end

    set repo_name ""
    set repo_root (git rev-parse --show-toplevel 2>/dev/null)
    if test $status -eq 0
        set repo_name (basename $repo_root)
    end

    set found 0
    for d in $base/*/
        if not test -d $d
            continue
        end
        set base_name (basename (string trim --right --chars=/ $d))
        if test -n "$repo_name" && not string match -q "$repo_name--*" $base_name
            continue
        end
        set feature (string replace -r ".*--" "" $base_name)
        echo "  $base_name  (gfork cd $feature)"
        set found 1
    end

    if test $found -eq 0
        if test -n "$repo_name"
            echo "No clones found for '$repo_name'. (All clones in $base)"
        else
            echo "No clones found in $base."
        end
    end
    return 0
end

function _gfork_update
    set force 0
    for arg in $argv
        if test "$arg" = "--force" -o "$arg" = "-f"
            set force 1
        end
    end

    set base_url "https://raw.githubusercontent.com/jax-agent/gfork/main"
    set api_url "https://api.github.com/repos/jax-agent/gfork/commits/main"
    set dest "$HOME/.config/fish/functions/gfork.fish"
    set vfile "$HOME/.config/fish/functions/.gfork_version"

    echo "⟳  Checking for updates..."

    set latest_sha ""
    if command -q curl
        set latest_sha (curl -fsSL $api_url 2>/dev/null | grep '"sha"' | head -1 | sed 's/.*"sha": "\([^"]*\)".*/\1/' | cut -c1-7)
    end

    set local_sha ""
    if test -f $vfile
        set local_sha (cat $vfile)
    end

    if test -n "$latest_sha" -a "$latest_sha" = "$local_sha" -a $force -eq 0
        echo "✓ Already up to date ($latest_sha)"
        echo "  Use 'gfork update --force' to reinstall anyway."
        return 0
    end

    if test $force -eq 1 -a "$latest_sha" = "$local_sha"
        echo "  Forcing reinstall of $latest_sha..."
    end

    curl -fsSL "$base_url/gfork.fish" -o $dest
    or begin; echo "✗ Update failed." >&2; return 1; end

    if test -n "$latest_sha"
        echo $latest_sha > $vfile
        echo "✓ Updated to $latest_sha"
    else
        echo "✓ Updated to latest"
    end
    echo "  Run 'exec fish' to reload, or open a new tab."
end

function _gfork_help
    echo "gfork — isolated git clone workflow"
    echo ""
    echo "Usage:"
    echo "  gfork <feature-name> [branch] [--local]   Local clone (keeps .env/dotfiles) + origin repointed to GitHub"
    echo "  gfork cd <feature-name>         cd into an existing clone"
    echo "  gfork rm <feature-name>         Delete a clone (with confirmation)"
    echo "  gfork ls                        List clones (current repo, or all)"
    echo "  gfork update                    Update gfork to the latest version"
    echo "  gfork update --force            Reinstall even if already up to date"
    echo ""
    echo "Clones are stored in: "(if set -q GFORK_DIR; echo $GFORK_DIR; else; echo $HOME/.gfork; end)
    echo "Override with: set -x GFORK_DIR /your/path"
    echo ""
    echo "Examples:"
    echo "  gfork auth-refactor             Create myrepo--auth-refactor/"
    echo "  gfork cd auth-refactor          Jump into it"
    echo "  gfork rm auth-refactor          Clean it up when done"
end
