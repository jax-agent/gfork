# gfork — Git local clone workflow for parallel feature development
# https://github.com/jax-agent/gfork
#
# Fish shell version. Install:
#   curl -o ~/.config/fish/functions/gfork.fish \
#     https://raw.githubusercontent.com/jax-agent/gfork/main/gfork.fish

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
            _gfork_update
            return
        case -h --help help
            _gfork_help
            return
    end

    # Default: create a clone
    if test (count $argv) -lt 1
        echo "Usage: gfork <feature-name> [source-branch]"
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
    set parent_dir (dirname $repo_root)
    set dest $parent_dir/$repo_name--$feature

    if test -d $dest
        echo "✗ '$dest' already exists. Choose a different name or delete it first."
        return 1
    end

    echo "⎇  Cloning '$source_branch' → $dest"
    git clone --local $repo_root $dest -b $source_branch --quiet
    or return 1

    echo "✓ Clone ready: $dest"
    echo ""
    echo "  cd "(basename $dest)
    echo "  # When done: gfork rm $feature"
end

function _gfork_dest --argument-names name
    set repo_root (git rev-parse --show-toplevel 2>/dev/null)
    if test $status -ne 0
        echo "✗ Not inside a git repository." >&2
        return 1
    end
    set repo_name (basename $repo_root)
    set parent_dir (dirname $repo_root)

    if string match -q "$repo_name--*" $name
        echo $parent_dir/$name
    else
        echo $parent_dir/$repo_name--$name
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
    set repo_root (git rev-parse --show-toplevel 2>/dev/null)
    if test $status -ne 0
        echo "✗ Not inside a git repository."
        return 1
    end
    set repo_name (basename $repo_root)
    set parent_dir (dirname $repo_root)

    set found 0
    for d in $parent_dir/$repo_name--*/
        if test -d $d
            set feature (string replace -r ".*--" "" (string trim --right --chars=/ $d))
            echo "  "(basename (string trim --right --chars=/ $d))"  (gfork cd $feature)"
            set found 1
        end
    end

    if test $found -eq 0
        echo "No clones found for '$repo_name'."
    end
end

function _gfork_update
    set base_url "https://raw.githubusercontent.com/jax-agent/gfork/main"
    set api_url "https://api.github.com/repos/jax-agent/gfork/commits/main"

    echo "⟳  Checking for updates..."

    set latest_sha ""
    if command -q curl
        set latest_sha (curl -fsSL $api_url 2>/dev/null | grep '"sha"' | head -1 | sed 's/.*"sha": "\([^"]*\)".*/\1/' | cut -c1-7)
    end

    set dest (status fish-path | path dirname | path join functions gfork.fish)
    if not test -f $dest
        set dest "$HOME/.config/fish/functions/gfork.fish"
    end

    curl -fsSL "$base_url/gfork.fish" -o $dest
    or begin; echo "✗ Update failed." >&2; return 1; end

    if test -n "$latest_sha"
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
    echo "  gfork <feature-name> [branch]   Create a clone (default: current branch)"
    echo "  gfork cd <feature-name>         cd into an existing clone"
    echo "  gfork rm <feature-name>         Delete a clone (with confirmation)"
    echo "  gfork ls                        List clones for this repo"
    echo "  gfork update                    Update gfork to the latest version"
    echo ""
    echo "Examples:"
    echo "  gfork auth-refactor             Create myrepo--auth-refactor/"
    echo "  gfork cd auth-refactor          Jump into it"
    echo "  gfork rm auth-refactor          Clean it up when done"
end
