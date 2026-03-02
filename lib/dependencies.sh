#!/usr/bin/env bash
# Dependency management and DAG (Directed Acyclic Graph) operations

# Component dependency map
# Format: ["component"]="space-separated dependencies"
declare -A COMPONENT_DEPS=(
  ["git"]=""
  ["shell"]=""
  ["vfox"]="shell"
  ["cloud"]=""
)

# Component descriptions for interactive prompts
declare -A COMPONENT_DESC=(
  ["vfox"]="Version manager for Node.js, Python, Java (replaces nvm, pyenv, sdkman)"
  ["cloud"]="Cloud CLIs: AWS, Azure, Google Cloud (for AI integration)"
)

# Get dependencies for a component
get_dependencies() {
  local component="$1"
  echo "${COMPONENT_DEPS[$component]:-}"
}

# Get all components that depend on the given component (reverse lookup)
get_dependents() {
  local target="$1"
  local dependents=()
  
  for component in "${!COMPONENT_DEPS[@]}"; do
    local deps="${COMPONENT_DEPS[$component]}"
    if [[ " $deps " == *" $target "* ]]; then
      dependents+=("$component")
    fi
  done
  
  echo "${dependents[@]}"
}

# Get all transitive dependencies of a component
get_all_dependencies() {
  local component="$1"
  local -A visited
  local result=()
  
  _collect_deps() {
    local comp="$1"
    local deps
    deps=$(get_dependencies "$comp")
    
    for dep in $deps; do
      if [[ -z "${visited[$dep]:-}" ]]; then
        visited["$dep"]=1
        result+=("$dep")
        _collect_deps "$dep"
      fi
    done
  }
  
  _collect_deps "$component"
  echo "${result[@]}"
}

# Detect cycles in the dependency graph using DFS
detect_cycles() {
  local -A color  # white=0, gray=1, black=2
  local -a path
  local cycle_found=0
  
  # Initialize all nodes as white
  for component in "${!COMPONENT_DEPS[@]}"; do
    color["$component"]=0
  done
  
  _dfs_visit() {
    local node="$1"
    
    # Mark as gray (visiting)
    color["$node"]=1
    path+=("$node")
    
    local deps
    deps=$(get_dependencies "$node")
    
    for dep in $deps; do
      if [[ "${color[$dep]:-0}" -eq 1 ]]; then
        # Gray node found - cycle detected
        err "Dependency cycle detected: ${path[*]} -> $dep"
        cycle_found=1
        return 1
      elif [[ "${color[$dep]:-0}" -eq 0 ]]; then
        if ! _dfs_visit "$dep"; then
          return 1
        fi
      fi
    done
    
    # Mark as black (visited)
    color["$node"]=2
    path=("${path[@]:0:${#path[@]}-1}")
    return 0
  }
  
  # Visit all nodes
  for component in "${!COMPONENT_DEPS[@]}"; do
    if [[ "${color[$component]}" -eq 0 ]]; then
      path=()
      if ! _dfs_visit "$component"; then
        return 1
      fi
    fi
  done
  
  if [[ $cycle_found -eq 1 ]]; then
    return 1
  fi
  
  debug "No cycles detected in dependency graph"
  return 0
}

# Resolve dependencies and return components in installation order (topological sort)
resolve_dependencies() {
  local components=("$@")
  local -A visited
  local -a result
  
  _visit() {
    local node="$1"
    
    if [[ -n "${visited[$node]:-}" ]]; then
      return 0
    fi
    
    visited["$node"]=1
    
    local deps
    deps=$(get_dependencies "$node")
    
    for dep in $deps; do
      _visit "$dep"
    done
    
    result+=("$node")
  }
  
  # Visit each requested component
  for component in "${components[@]}"; do
    _visit "$component"
  done
  
  echo "${result[@]}"
}

# Check if a dependency is installed
check_dependency_installed() {
  local dep="$1"
  
  # Source common.sh for read_component_status
  local status
  status=$(read_component_status "$dep")
  
  if [[ "$status" == "ok" ]] || [[ "$status" == "imported" ]]; then
    return 0
  fi
  
  return 1
}

# Verify all dependencies of a component are installed
verify_dependencies() {
  local component="$1"
  local deps
  deps=$(get_dependencies "$component")
  
  for dep in $deps; do
    if ! check_dependency_installed "$dep"; then
      err "Missing dependency for $component: $dep"
      warn "Please install '$dep' first or use --interactive mode"
      return 1
    fi
  done
  
  return 0
}

# Get list of optional components
get_optional_components() {
  local optionals=()
  
  # Essential components (git, shell) are not optional
  for component in "${!COMPONENT_DEPS[@]}"; do
    if [[ "$component" != "git" ]] && [[ "$component" != "shell" ]]; then
      optionals+=("$component")
    fi
  done
  
  echo "${optionals[@]}"
}

# Get component description
get_component_description() {
  local component="$1"
  echo "${COMPONENT_DESC[$component]:-No description available}"
}
