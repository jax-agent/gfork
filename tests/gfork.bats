#!/usr/bin/env bats
# gfork test suite — requires bats (https://github.com/bats-core/bats-core)
# Run: bats tests/gfork.bats

setup() {
  # Source gfork into the test shell
  source "$BATS_TEST_DIRNAME/../gfork.bash"

  # Create a temp directory as our workspace
  TEST_ROOT="$(mktemp -d)"

  # Point GFORK_DIR at a temp location so tests don't touch ~/.gfork
  export GFORK_DIR="$TEST_ROOT/.gfork"

  # Create a real git repo to work from
  ORIGIN="$TEST_ROOT/myrepo"
  mkdir -p "$ORIGIN"
  git -C "$ORIGIN" init -q
  git -C "$ORIGIN" config user.email "test@test.com"
  git -C "$ORIGIN" config user.name "Test"
  echo "hello" > "$ORIGIN/README.md"
  git -C "$ORIGIN" add .
  git -C "$ORIGIN" commit -q -m "init"

  # Move into the repo (gfork needs to be inside a git repo)
  cd "$ORIGIN"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

# ─── gfork create ────────────────────────────────────────────────────────────

@test "creates a clone in GFORK_DIR" {
  run gfork my-feature
  [ "$status" -eq 0 ]
  [ -d "$GFORK_DIR/myrepo--my-feature" ]
}

@test "output confirms clone path" {
  run gfork my-feature
  [[ "$output" == *"myrepo--my-feature"* ]]
}

@test "clone is a valid git repo" {
  gfork my-feature
  run git -C "$GFORK_DIR/myrepo--my-feature" rev-parse --git-dir
  [ "$status" -eq 0 ]
}

@test "clone has the same commits as origin" {
  gfork my-feature
  origin_hash="$(git -C "$TEST_ROOT/myrepo" rev-parse HEAD)"
  clone_hash="$(git -C "$GFORK_DIR/myrepo--my-feature" rev-parse HEAD)"
  [ "$origin_hash" = "$clone_hash" ]
}

@test "clone defaults to current branch" {
  run gfork my-feature
  clone_branch="$(git -C "$GFORK_DIR/myrepo--my-feature" rev-parse --abbrev-ref HEAD)"
  [ "$clone_branch" = "master" ] || [ "$clone_branch" = "main" ]
}

@test "clone uses specified branch" {
  git checkout -q -b dev
  echo "dev" > dev.txt
  git add . && git commit -q -m "dev commit"
  git checkout -q master 2>/dev/null || git checkout -q main

  run gfork dev-clone dev
  [ "$status" -eq 0 ]
  clone_branch="$(git -C "$GFORK_DIR/myrepo--dev-clone" rev-parse --abbrev-ref HEAD)"
  [ "$clone_branch" = "dev" ]
}

@test "fails if clone already exists" {
  gfork my-feature
  run gfork my-feature
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists"* ]]
}

@test "fails outside a git repo" {
  cd "$TEST_ROOT"
  run gfork some-feature
  [ "$status" -ne 0 ]
  [[ "$output" == *"Not inside a git repository"* ]]
}

@test "fails with no arguments" {
  run gfork
  [ "$status" -ne 0 ]
}

# ─── gfork ls ────────────────────────────────────────────────────────────────

@test "ls shows existing clones" {
  gfork feature-a
  gfork feature-b
  run gfork ls
  [ "$status" -eq 0 ]
  [[ "$output" == *"myrepo--feature-a"* ]]
  [[ "$output" == *"myrepo--feature-b"* ]]
}

@test "ls shows no clones message when none exist" {
  run gfork ls
  [ "$status" -eq 0 ]
  [[ "$output" == *"No clones"* ]]
}

@test "ls outside a git repo shows all clones" {
  gfork my-feature
  cd "$TEST_ROOT"
  run gfork ls
  [ "$status" -eq 0 ]
  [[ "$output" == *"myrepo--my-feature"* ]]
}

@test "custom GFORK_DIR is respected" {
  local custom_dir="$TEST_ROOT/custom-clones"
  GFORK_DIR="$custom_dir" gfork my-feature
  [ -d "$custom_dir/myrepo--my-feature" ]
}

# ─── gfork cd ────────────────────────────────────────────────────────────────

@test "cd changes into the clone directory" {
  gfork my-feature
  gfork cd my-feature
  [ "$(pwd)" = "$GFORK_DIR/myrepo--my-feature" ]
}

@test "cd accepts full clone name" {
  gfork my-feature
  gfork cd myrepo--my-feature
  [ "$(pwd)" = "$GFORK_DIR/myrepo--my-feature" ]
}

@test "cd fails if clone does not exist" {
  run gfork cd nonexistent
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "cd fails with no argument" {
  run gfork cd
  [ "$status" -ne 0 ]
}

# ─── gfork rm ────────────────────────────────────────────────────────────────

@test "rm deletes the clone after confirmation" {
  gfork my-feature
  run bash -c "echo y | bash -c 'GFORK_DIR=$GFORK_DIR source $(dirname "$BATS_TEST_DIRNAME")/gfork.bash && cd $TEST_ROOT/myrepo && gfork rm my-feature'"
  [ ! -d "$GFORK_DIR/myrepo--my-feature" ]
}

@test "rm aborts on N" {
  gfork my-feature
  run bash -c "echo N | bash -c 'GFORK_DIR=$GFORK_DIR source $(dirname "$BATS_TEST_DIRNAME")/gfork.bash && cd $TEST_ROOT/myrepo && gfork rm my-feature'"
  [ -d "$GFORK_DIR/myrepo--my-feature" ]
}

@test "rm warns about uncommitted changes" {
  gfork my-feature
  echo "dirty" > "$GFORK_DIR/myrepo--my-feature/dirty.txt"
  git -C "$GFORK_DIR/myrepo--my-feature" add dirty.txt

  run bash -c "echo N | bash -c 'GFORK_DIR=$GFORK_DIR source $(dirname "$BATS_TEST_DIRNAME")/gfork.bash && cd $TEST_ROOT/myrepo && gfork rm my-feature'"
  [[ "$output" == *"uncommitted"* ]]
}

@test "rm fails if clone does not exist" {
  run gfork rm nonexistent
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "rm fails with no argument" {
  run gfork rm
  [ "$status" -ne 0 ]
}

@test "rm accepts full clone name" {
  gfork my-feature
  run bash -c "echo y | bash -c 'GFORK_DIR=$GFORK_DIR source $(dirname "$BATS_TEST_DIRNAME")/gfork.bash && cd $TEST_ROOT/myrepo && gfork rm myrepo--my-feature'"
  [ ! -d "$GFORK_DIR/myrepo--my-feature" ]
}

# ─── gfork update ────────────────────────────────────────────────────────────

@test "update downloads and reports new version" {
  mkdir -p "$TEST_ROOT/.config/bash/functions"
  cp "$BATS_TEST_DIRNAME/../gfork.bash" "$TEST_ROOT/.config/bash/functions/gfork.bash"

  curl() {
    if [[ "$*" == *"api.github.com"* ]]; then
      echo '{"sha": "abc1234def"}'
    else
      local dest="${@: -1}"
      cp "$BATS_TEST_DIRNAME/../gfork.bash" "$dest"
    fi
  }
  export -f curl
  HOME="$TEST_ROOT" run gfork update
  [ "$status" -eq 0 ]
  [[ "$output" == *"Updated"* ]]
}

@test "update skips when already up to date" {
  mkdir -p "$TEST_ROOT/.config/bash/functions"
  cp "$BATS_TEST_DIRNAME/../gfork.bash" "$TEST_ROOT/.config/bash/functions/gfork.bash"
  echo "abc1234" > "$TEST_ROOT/.config/bash/functions/.gfork_version"

  curl() {
    if [[ "$*" == *"api.github.com"* ]]; then
      echo '{"sha": "abc1234def"}'
    fi
  }
  export -f curl
  HOME="$TEST_ROOT" run gfork update
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already up to date"* ]]
}

@test "update --force reinstalls when already up to date" {
  mkdir -p "$TEST_ROOT/.config/bash/functions"
  cp "$BATS_TEST_DIRNAME/../gfork.bash" "$TEST_ROOT/.config/bash/functions/gfork.bash"
  echo "abc1234" > "$TEST_ROOT/.config/bash/functions/.gfork_version"

  curl() {
    if [[ "$*" == *"api.github.com"* ]]; then
      echo '{"sha": "abc1234def"}'
    else
      local dest="${@: -1}"
      cp "$BATS_TEST_DIRNAME/../gfork.bash" "$dest"
    fi
  }
  export -f curl
  HOME="$TEST_ROOT" run gfork update --force
  [ "$status" -eq 0 ]
  [[ "$output" == *"Forcing reinstall"* ]]
  [[ "$output" == *"Updated"* ]]
}

@test "update -f is alias for --force" {
  mkdir -p "$TEST_ROOT/.config/bash/functions"
  cp "$BATS_TEST_DIRNAME/../gfork.bash" "$TEST_ROOT/.config/bash/functions/gfork.bash"
  echo "abc1234" > "$TEST_ROOT/.config/bash/functions/.gfork_version"

  curl() {
    if [[ "$*" == *"api.github.com"* ]]; then
      echo '{"sha": "abc1234def"}'
    else
      local dest="${@: -1}"
      cp "$BATS_TEST_DIRNAME/../gfork.bash" "$dest"
    fi
  }
  export -f curl
  HOME="$TEST_ROOT" run gfork update -f
  [ "$status" -eq 0 ]
  [[ "$output" == *"Updated"* ]]
}

# ─── gfork help ──────────────────────────────────────────────────────────────

@test "help prints usage" {
  run gfork help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "--help prints usage" {
  run gfork --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "help mentions update subcommand" {
  run gfork help
  [[ "$output" == *"update"* ]]
}
