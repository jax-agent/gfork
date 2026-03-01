# gfork — Git local clone workflow for parallel feature development
# https://github.com/jax-agent/gfork
#
# Nushell version. Install:
#   curl -o ~/.config/nushell/gfork.nu \
#     https://raw.githubusercontent.com/jax-agent/gfork/main/gfork.nu
#
#   Then add to ~/.config/nushell/config.nu:
#     source ~/.config/nushell/gfork.nu

def gfork [
    feature: string,              # Feature name (becomes the clone folder suffix)
    source_branch?: string,       # Branch to clone from (default: current branch)
] {
    let repo_root = (do { git rev-parse --show-toplevel } | complete)
    if $repo_root.exit_code != 0 {
        error make { msg: "✗ Not inside a git repository." }
    }
    let root = ($repo_root.stdout | str trim)

    let branch = if $source_branch != null {
        $source_branch
    } else {
        (git rev-parse --abbrev-ref HEAD | str trim)
    }

    let repo_name = ($root | path basename)
    let parent_dir = ($root | path dirname)
    let dest = $"($parent_dir)/($repo_name)--($feature)"

    if ($dest | path exists) {
        error make { msg: $"✗ '($dest)' already exists. Choose a different name or delete it first." }
    }

    print $"⎇  Cloning '($branch)' → ($dest)"
    git clone --local $root $dest -b $branch --quiet

    print $"✓ Clone ready: ($dest)"
    print ""
    print $"  cd ($repo_name)--($feature)"
    print "  # Create feature branches freely — they merge back here"
    print $"  # When done: git push origin ($branch) → pull in original → rm -rf ($dest)"
}
