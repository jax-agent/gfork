# gfork — Git local clone workflow for parallel feature development
# https://github.com/jax-agent/gfork
#
# Fish shell version. Install:
#   curl -o ~/.config/fish/functions/gfork.fish \
#     https://raw.githubusercontent.com/jax-agent/gfork/main/gfork.fish

function gfork --description "Create an isolated local git clone for feature development"
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
    echo "  # Create feature branches freely — they merge back here"
    echo "  # When done: git push origin $source_branch → pull in original → rm -rf $dest"
end
