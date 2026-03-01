# gfork — Git local clone workflow for parallel feature development
# https://github.com/jax-agent/gfork
#
# Nushell version. Install:
#   curl -o ~/.config/nushell/gfork.nu \
#     https://raw.githubusercontent.com/jax-agent/gfork/main/gfork.nu
#
#   Then add to ~/.config/nushell/config.nu:
#     source ~/.config/nushell/gfork.nu

# Base directory for all clones
def _gfork_base [] {
    $env.GFORK_DIR? | default $"($env.HOME)/.gfork"
}

# Resolve dest path from feature name or full clone name
def _gfork_dest [name: string] {
    let repo_root_r = (do { git rev-parse --show-toplevel } | complete)
    if $repo_root_r.exit_code != 0 {
        error make { msg: "✗ Not inside a git repository." }
    }
    let root = ($repo_root_r.stdout | str trim)
    let repo_name = ($root | path basename)
    let base = (_gfork_base)

    if ($name | str starts-with $"($repo_name)--") {
        $"($base)/($name)"
    } else {
        $"($base)/($repo_name)--($name)"
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
    let base = (_gfork_base)
    let dest = $"($base)/($repo_name)--($feature)"

    if ($dest | path exists) {
        error make { msg: $"✗ '($dest)' already exists. Choose a different name or delete it first." }
    }

    mkdir $base
    print $"⎇  Cloning '($branch)' → ($dest)"
    git clone --local $root $dest -b $branch --quiet

    print $"✓ Clone ready: ($dest)"
    print ""
    print $"  gfork-cd ($feature)"
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
def gfork-update [
    --force(-f)  # Reinstall even if already up to date
] {
    let base_url = "https://raw.githubusercontent.com/jax-agent/gfork/main"
    let api_url = "https://api.github.com/repos/jax-agent/gfork/commits/main"
    let config_dir = ($env.XDG_CONFIG_HOME? | default $"($env.HOME)/.config")
    let dest = $"($config_dir)/nushell/gfork.nu"
    let vfile = $"($config_dir)/nushell/.gfork_version"

    print "⟳  Checking for updates..."

    let latest_sha = (do {
        http get $api_url | get sha | str substring 0..6
    } | default "")

    let local_sha = if ($vfile | path exists) { open $vfile | str trim } else { "" }

    if ($latest_sha | str length) > 0 and $latest_sha == $local_sha and not $force {
        print $"✓ Already up to date \($latest_sha\)"
        print "  Use 'gfork-update --force' to reinstall anyway."
        return
    }

    if $force and $latest_sha == $local_sha {
        print $"  Forcing reinstall of ($latest_sha)..."
    }

    http get $"($base_url)/gfork.nu" | save --force $dest

    if ($latest_sha | str length) > 0 {
        $latest_sha | save --force $vfile
        print $"✓ Updated to ($latest_sha)"
    } else {
        print "✓ Updated to latest"
    }
    print "  Run 'exec nu' or open a new tab to reload."
}

# List all gfork clones (filtered to current repo if inside one)
def gfork-ls [] {
    let base = (_gfork_base)

    if not ($base | path exists) {
        print "No clones yet. Run 'gfork <feature-name>' to create one."
        return
    }

    let repo_root_r = (do { git rev-parse --show-toplevel } | complete)
    let repo_name = if $repo_root_r.exit_code == 0 {
        ($repo_root_r.stdout | str trim | path basename)
    } else { "" }

    let all_clones = (ls $base | where type == dir | get name)

    let clones = if ($repo_name | str length) > 0 {
        $all_clones | where { |d| ($d | path basename) | str starts-with $"($repo_name)--" }
    } else {
        $all_clones
    }

    if ($clones | length) == 0 {
        if ($repo_name | str length) > 0 {
            print $"No clones found for '($repo_name)'. \(All clones in ($base)\)"
        } else {
            print $"No clones found in ($base)."
        }
    } else {
        for d in $clones {
            let b = ($d | path basename)
            let feature = ($b | str replace -r ".*--" "")
            print $"  ($b)  \(gfork-cd ($feature)\)"
        }
    }
}
