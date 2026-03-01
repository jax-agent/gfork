# gfork — Git local clone workflow for parallel feature development
# https://github.com/jax-agent/gfork
#
# Nushell version. Install:
#   curl -o ~/.config/nushell/gfork.nu \
#     https://raw.githubusercontent.com/jax-agent/gfork/main/gfork.nu
#
#   Then add to ~/.config/nushell/config.nu:
#     source ~/.config/nushell/gfork.nu

# Resolve dest path from feature name or full clone name
def _gfork_dest [name: string] {
    let repo_root_r = (do { git rev-parse --show-toplevel } | complete)
    if $repo_root_r.exit_code != 0 {
        error make { msg: "✗ Not inside a git repository." }
    }
    let root = ($repo_root_r.stdout | str trim)
    let repo_name = ($root | path basename)
    let parent_dir = ($root | path dirname)

    if ($name | str starts-with $"($repo_name)--") {
        $"($parent_dir)/($name)"
    } else {
        $"($parent_dir)/($repo_name)--($name)"
    }
}

# Create an isolated local git clone for parallel development
def gfork [
    feature: string,              # Feature name (or subcommand: cd / rm / ls)
    source_branch?: string,       # Branch to clone from (default: current branch)
] {
    # Subcommand: gfork ls
    if $feature == "ls" or $feature == "list" {
        gfork-ls
        return
    }

    let repo_root_r = (do { git rev-parse --show-toplevel } | complete)
    if $repo_root_r.exit_code != 0 {
        error make { msg: "✗ Not inside a git repository." }
    }
    let root = ($repo_root_r.stdout | str trim)

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
    print $"  # When done: gfork-rm ($feature)"
}

# cd into an existing gfork clone
def --env gfork-cd [
    name: string,  # Feature name or full clone name
] {
    let dest = (_gfork_dest $name)
    if not ($dest | path exists) {
        error make { msg: $"✗ Clone not found: ($dest)\n  Run 'gfork-ls' to see available clones." }
    }
    print $"→ ($dest)"
    cd $dest
}

# Delete a gfork clone (with confirmation)
def gfork-rm [
    name: string,  # Feature name or full clone name
] {
    let dest = (_gfork_dest $name)
    if not ($dest | path exists) {
        error make { msg: $"✗ Clone not found: ($dest)\n  Run 'gfork-ls' to see available clones." }
    }

    # Check for uncommitted changes
    let dirty = (do { git -C $dest status --porcelain } | complete)
    if ($dirty.stdout | str trim | str length) > 0 {
        print "⚠  Clone has uncommitted changes:"
        git -C $dest status --short
        print ""
    }

    # Check for unpushed commits
    let unpushed = (do { git -C $dest log --oneline "@{u}.." } | complete)
    if ($unpushed.stdout | str trim | str length) > 0 {
        print "⚠  Clone has unpushed commits:"
        print ($unpushed.stdout | str trim)
        print ""
    }

    let confirm = (input $"Delete '($dest)'? [y/N] ")
    if $confirm != "y" and $confirm != "Y" {
        print "Aborted."
        return
    }

    rm -rf $dest
    print $"✓ Deleted: ($dest)"
}

# Update gfork to the latest version from GitHub
def gfork-update [] {
    let base_url = "https://raw.githubusercontent.com/jax-agent/gfork/main"
    let api_url = "https://api.github.com/repos/jax-agent/gfork/commits/main"

    print "⟳  Checking for updates..."

    # Fetch latest SHA
    let latest_sha = (do {
        http get $api_url | get sha | str substring 0..6
    } | default "")

    # Find the installed nu file
    let dest = $"($env.XDG_CONFIG_HOME? | default $"($env.HOME)/.config")/nushell/gfork.nu"

    http get $"($base_url)/gfork.nu" | save --force $dest

    if ($latest_sha | str length) > 0 {
        print $"✓ Updated to ($latest_sha)"
    } else {
        print "✓ Updated to latest"
    }
    print "  Run 'exec nu' or open a new tab to reload."
}

# List all gfork clones for the current repo
def gfork-ls [] {
    let repo_root_r = (do { git rev-parse --show-toplevel } | complete)
    if $repo_root_r.exit_code != 0 {
        error make { msg: "✗ Not inside a git repository." }
    }
    let root = ($repo_root_r.stdout | str trim)
    let repo_name = ($root | path basename)
    let parent_dir = ($root | path dirname)

    let pattern = $"($parent_dir)/($repo_name)--*"
    let clones = (ls $"($parent_dir)/($repo_name)--*" 2>/dev/null | where type == dir | get name)

    if ($clones | length) == 0 {
        print $"No clones found for '($repo_name)'."
    } else {
        for d in $clones {
            let base = ($d | path basename)
            let feature = ($base | str replace $"($repo_name)--" "")
            print $"  ($base)  \(gfork-cd ($feature)\)"
        }
    }
}
