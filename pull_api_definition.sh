#!/bin/bash
#
# SPDX-FileCopyrightText: 2025 STRATO GmbH
# SPDX-License-Identifier: AGPL-3.0-or-later
#

set -euo pipefail

# =============================================================================
# Constants
# =============================================================================

readonly REQUIRED_CLI_APPS=(curl jq sed git)
readonly OUTPUT_FILE="openapi.json"
readonly API_PATH="/nextcloud/api-docs/Addon%20API"

# Sanitization values applied to the downloaded spec
readonly API_TITLE="IONOS Nextcloud PSS Addons API"
readonly API_DESCRIPTION="PHP API client for the IONOS Nextcloud PSS Addons API"
readonly HOST_PLACEHOLDER="https://API_HOST"

# GitHub repo slug used as fallback when the git remote is unavailable
readonly GITHUB_REPO="IONOS-Productivity/ionos-ncpss-addons-api-client"

# Files staged and committed after a spec update
readonly -a STAGE_PATHS=(docs/ lib/ test/ .openapi-generator/ openapi.json README.md)

# grep -E pattern that excludes generated/vendored paths from git status output
readonly GIT_IGNORE_PATTERN='^.. (vendor/|vendor-bin/|node_modules/)'

# Prefix used when generating feature branch names
readonly BRANCH_PREFIX="feat/api-update-"

# =============================================================================
# Color Support
# =============================================================================

# Respect NO_COLOR convention; disable when not writing to a terminal
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
	readonly C_RED=$'\e[0;31m'
	readonly C_YELLOW=$'\e[1;33m'
	readonly C_GREEN=$'\e[0;32m'
	readonly C_CYAN=$'\e[0;36m'
	readonly C_BOLD=$'\e[1m'
	readonly C_DIM=$'\e[2m'
	readonly C_RESET=$'\e[0m'
else
	readonly C_RED='' C_YELLOW='' C_GREEN='' C_CYAN='' C_BOLD='' C_DIM='' C_RESET=''
fi

# =============================================================================
# Global Variables
# =============================================================================

temp_file=""
create_branch=false
branch_name=""
base_branch="main"

# =============================================================================
# Utility Functions
# =============================================================================

# Cleanup temporary files on exit
cleanup() {
	if [[ -n "${temp_file}" && -f "${temp_file}" ]]; then
		rm -f "${temp_file}"
	fi
}
trap cleanup EXIT

# Print error message and exit
die() {
	printf "${C_RED}${C_BOLD}[✗] ERROR: %s${C_RESET}\n" "$*" >&2
	exit 1
}

# Print warning message
warn() {
	printf "${C_YELLOW}[!] WARNING: %s${C_RESET}\n" "$*" >&2
}

# Print info message
info() {
	printf "${C_CYAN}[i]${C_RESET} %s\n" "$*"
}

# Print success message
success() {
	printf "${C_GREEN}[✓]${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$*"
}

# Print a titled section header box
print_header() {
	local title=$1
	echo ""
	printf "${C_BOLD}┌──────────────────────────────────────────────────────────────────┐${C_RESET}\n"
	printf "${C_BOLD}│${C_RESET} %-64s ${C_BOLD}│${C_RESET}\n" "${title}"
	printf "${C_BOLD}└──────────────────────────────────────────────────────────────────┘${C_RESET}\n"
}

# Ask yes/no question with default answer
# Usage: ask_yes_no "Question?" "Y" or ask_yes_no "Question?" "N"
ask_yes_no() {
	local question=$1
	local default=${2:-Y}
	local prompt="${C_BOLD}[Y/n]${C_RESET}"

	if [[ "${default}" == "N" ]]; then
		prompt="${C_BOLD}[y/N]${C_RESET}"
	fi

	printf "%s %b " "${question}" "${prompt}"
	read -r -n 1 REPLY
	echo

	if [[ "${default}" == "Y" ]]; then
		[[ ! ${REPLY} =~ ^[Nn]$ ]]
	else
		[[ ${REPLY} =~ ^[Yy]$ ]]
	fi
}

# Generate branch name from version and timestamp
generate_branch_name() {
	local version=$1
	local version_clean
	local timestamp

	# Replace non-alphanumeric characters (except . and -) with underscore
	version_clean="${version//[^a-zA-Z0-9.-]/_}"
	timestamp=$(date +%Y%m%d%H%M%S)
	echo "${BRANCH_PREFIX}${version_clean}-${timestamp}"
}

# Check if branch exists locally or remotely
# Returns 0 if exists, 1 if not
# Returns two values: branch_exists_local, branch_exists_remote
check_branch_exists() {
	local branch=$1
	local branch_exists_local branch_exists_remote

	branch_exists_local=$(git branch --list "${branch}" | wc -l)
	branch_exists_remote=$(git branch -r --list "origin/${branch}" | wc -l)

	echo "${branch_exists_local} ${branch_exists_remote}"
}

# Display where a branch exists
show_branch_locations() {
	local branch_exists_local=$1
	local branch_exists_remote=$2
	if [[ ${branch_exists_local} -gt 0 ]]; then
		echo "    - Found locally"
	fi
	if [[ ${branch_exists_remote} -gt 0 ]]; then
		echo "    - Found on remote (origin)"
	fi
}

# Show usage information
show_help() {
	cat <<-EOF
		${C_BOLD}┌──────────────────────────────────────────────────────────────────┐
		│ API Definition Update Script                                    │
		└──────────────────────────────────────────────────────────────────┘${C_RESET}

		${C_BOLD}USAGE:${C_RESET}
		  ./pull_api_definition.sh <host> [base_branch]

		${C_BOLD}ARGUMENTS:${C_RESET}
		  ${C_CYAN}host${C_RESET}         The host where the API spec is hosted (including port if needed)
		  ${C_CYAN}base_branch${C_RESET}  The base branch to use (default: main)

		${C_BOLD}EXAMPLES:${C_RESET}
		  ${C_DIM}# Update from a specific API host${C_RESET}
		  ./pull_api_definition.sh api.example.lan:10443

		  ${C_DIM}# Use a different base branch${C_RESET}
		  ./pull_api_definition.sh api.example.lan:10443 mk/dev/some_other_base_branch

		  ${C_DIM}# With authentication${C_RESET}
		  export API_SPEC_USER=<user> API_SPEC_PASSWORD=<pass>
		  ./pull_api_definition.sh api.example.lan:10443

		  ${C_DIM}# Allow insecure SSL (for testing only)${C_RESET}
		  export ALLOW_INSECURE_SSL=1
		  ./pull_api_definition.sh api.example.lan:10443

	EOF
}

# Check if required CLI applications are installed
check_requirements() {
	local missing_apps=()

	for app in "${REQUIRED_CLI_APPS[@]}"; do
		if ! command -v "${app}" >/dev/null 2>&1; then
			missing_apps+=("${app}")
		fi
	done

	if [[ ${#missing_apps[@]} -gt 0 ]]; then
		die "Missing required applications: ${missing_apps[*]}"
	fi
}

# =============================================================================
# Main Functions
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# Argument Parsing & Requirements
# ─────────────────────────────────────────────────────────────────────────────

# Parse command line arguments
parse_args() {
	if [[ $# -eq 0 ]]; then
		show_help
		exit 1
	fi

	# Set base_branch if provided as second argument
	if [[ $# -ge 2 ]]; then
		base_branch="$2"
		info "Using base branch: ${C_BOLD}${base_branch}${C_RESET}"
	fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Version Management
# ─────────────────────────────────────────────────────────────────────────────

# Get API version from local file
get_local_version() {
	if [[ -f "${OUTPUT_FILE}" ]]; then
		jq -r '.info.version' "${OUTPUT_FILE}" 2>/dev/null || echo ""
	else
		echo ""
	fi
}

# Get API version from origin/${base_branch}
get_origin_version() {
	local version=""

	# Try to get version from git remote first
	if git cat-file -e "origin/${base_branch}:${OUTPUT_FILE}" 2>/dev/null; then
		version=$(git show --no-pager "origin/${base_branch}:${OUTPUT_FILE}" 2>/dev/null | jq -r '.info.version' 2>/dev/null || echo "")
	fi

	# If git didn't work or returned empty, fallback to fetching from GitHub repository
	if [[ -z "${version}" || "${version}" == "null" ]]; then
		local github_url="https://raw.githubusercontent.com/${GITHUB_REPO}/refs/heads/${base_branch}/${OUTPUT_FILE}"
		version=$(curl -sf "${github_url}" 2>/dev/null | jq -r '.info.version' 2>/dev/null || echo "")
	fi

	echo "${version}"
}

# Get API version from downloaded spec
get_remote_version() {
	local spec_file=$1
	jq -r '.info.version' "${spec_file}" 2>/dev/null || echo ""
}

# Fetch latest changes from git origin
fetch_from_origin() {
	info "Fetching latest changes from origin..."
	if ! git fetch origin; then
		warn "git fetch origin failed, continuing..."
	fi
}

# Display version information
display_versions() {
	local current_version=$1
	local origin_version=$2

	info "Current local version:       ${C_BOLD}${current_version:-none}${C_RESET}"
	info "Origin/${base_branch} version: ${C_BOLD}${origin_version:-none}${C_RESET}"
}

# ─────────────────────────────────────────────────────────────────────────────
# API Specification Download & Processing
# ─────────────────────────────────────────────────────────────────────────────

# Download API specification from remote server
download_api_spec() {
	local api_spec_host=$1
	local api_spec_url="https://${api_spec_host}${API_PATH}"

	print_header "Downloading API Specification"
	echo "  URL: ${C_CYAN}${api_spec_url}${C_RESET}"
	echo ""

	temp_file=$(mktemp)

	local curl_opts="--progress-bar"
	if [[ "${ALLOW_INSECURE_SSL:-0}" == "1" ]]; then
		warn "Using --insecure. SSL certificate verification is DISABLED."
		warn "This is insecure and should only be used for trusted/internal servers."
		curl_opts="${curl_opts} --insecure"
	fi

	# shellcheck disable=SC2086
	if ! curl ${curl_opts} "${api_spec_url}" > "${temp_file}"; then
		die "Failed to download API spec"
	fi

	if [[ ! -f "${temp_file}" ]]; then
		die "Failed to download API spec"
	fi

	if grep -q "Bad credentials" "${temp_file}"; then
		die "Failed to download API spec: Bad credentials"
	fi
}

# Ask user if they want to create a new branch
handle_version_comparison() {
	local current_version=$1
	local origin_version=$2
	local remote_version=$3

	if [[ "${origin_version}" != "${remote_version}" ]]; then
		echo ""
		echo "Remote version (${C_BOLD}${remote_version}${C_RESET}) differs from origin/${base_branch} (${C_BOLD}${origin_version:-none}${C_RESET})"
		echo ""

		if ask_yes_no "Do you want to create a new branch from origin/${base_branch} for this update?" "Y"; then
			create_branch=true
			branch_name=$(generate_branch_name "${remote_version}")
		fi
	elif [[ "${current_version}" == "${remote_version}" ]]; then
		echo ""
		printf "${C_GREEN}API spec is up to date.${C_RESET} Local: ${C_BOLD}%s${C_RESET}  Remote: ${C_BOLD}%s${C_RESET}\n" \
			"${current_version}" "${remote_version}"

		if ! ask_yes_no "Do you want to overwrite the local API spec?" "N"; then
			info "Skipping update"
			exit 0
		fi
	fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Branch Management
# ─────────────────────────────────────────────────────────────────────────────

# Handle branch creation when branch already exists
handle_existing_branch() {
	local branch=$1
	local branch_exists_info
	local branch_exists_local
	local branch_exists_remote

	echo ""
	warn "Branch '${branch}' already exists"

	branch_exists_info=$(check_branch_exists "${branch}")
	read -r branch_exists_local branch_exists_remote <<< "${branch_exists_info}"
	show_branch_locations "${branch_exists_local}" "${branch_exists_remote}"

	echo ""
	echo "What would you like to do?"
	echo "  ${C_BOLD}1)${C_RESET} Switch to existing branch"
	echo "  ${C_BOLD}2)${C_RESET} Choose a different branch name"
	echo "  ${C_BOLD}3)${C_RESET} Abort"
	read -r -p "Enter your choice [1-3]: " -n 1 choice
	echo

	case ${choice} in
		1)
			switch_to_existing_branch "${branch}" "${branch_exists_local}" "${branch_exists_remote}"
			;;
		2)
			prompt_for_branch_name "${branch}"
			;;
		3)
			info "Aborting"
			exit 0
			;;
		*)
			die "Invalid choice. Aborting."
			;;
	esac
}

# Switch to an existing branch (local or remote)
switch_to_existing_branch() {
	local branch=$1
	local branch_exists_local=$2
	local branch_exists_remote=$3

	if [[ ${branch_exists_local} -gt 0 ]]; then
		info "Switching to existing local branch: ${C_BOLD}${branch}${C_RESET}"
		git checkout "${branch}" || die "Failed to switch to branch"
	else
		info "Checking out remote branch: ${C_BOLD}${branch}${C_RESET}"
		git checkout -b "${branch}" "origin/${branch}" || die "Failed to checkout remote branch"
	fi
}

# Prompt for a new branch name and validate it
prompt_for_branch_name() {
	local suggested_name=$1
	local new_name=""
	local current_suggestion="${suggested_name}"
	local branch_exists_info
	local branch_exists_local
	local branch_exists_remote

	while true; do
		echo ""
		info "Suggested branch name: ${C_BOLD}${current_suggestion}${C_RESET}"
		read -r -p "Enter new branch name (or press Enter to use suggested): " new_name

		# Use suggested name if user pressed Enter
		if [[ -z "${new_name}" ]]; then
			new_name="${current_suggestion}"
		fi

		# Check if the new branch name already exists
		branch_exists_info=$(check_branch_exists "${new_name}")
		read -r branch_exists_local branch_exists_remote <<< "${branch_exists_info}"

		if [[ ${branch_exists_local} -gt 0 || ${branch_exists_remote} -gt 0 ]]; then
			warn "Branch '${new_name}' already exists"
			show_branch_locations "${branch_exists_local}" "${branch_exists_remote}"
			echo ""

			if ! ask_yes_no "Try a different name?" "Y"; then
				die "Branch creation cancelled"
			fi

			# Generate a new suggestion with updated timestamp
			local base_name="${suggested_name%-*}"
			current_suggestion=$(generate_branch_name "${base_name}")
		else
			# Branch name is valid and doesn't exist
			branch_name="${new_name}"
			info "Creating new branch from latest origin/${base_branch}: ${C_BOLD}${branch_name}${C_RESET}"

			# Ensure we're creating from latest origin/base_branch
			if ! git checkout "origin/${base_branch}"; then
				die "Failed to checkout origin/${base_branch}"
			fi

			if ! git checkout -b "${branch_name}"; then
				die "Failed to create branch"
			fi

			success "Branch '${branch_name}' created from origin/${base_branch}"
			break
		fi
	done
}

# Create a new branch for the API update
create_update_branch() {
	local branch_exists_info
	local branch_exists_local
	local branch_exists_remote

	if [[ "${create_branch}" != "true" ]]; then
		return 0
	fi

	branch_exists_info=$(check_branch_exists "${branch_name}")
	read -r branch_exists_local branch_exists_remote <<< "${branch_exists_info}"

	if [[ ${branch_exists_local} -gt 0 || ${branch_exists_remote} -gt 0 ]]; then
		handle_existing_branch "${branch_name}"
	else
		info "Creating new branch from latest origin/${base_branch}: ${C_BOLD}${branch_name}${C_RESET}"

		# Ensure we're creating from latest origin/base_branch
		if ! git checkout "origin/${base_branch}"; then
			die "Failed to checkout origin/${base_branch}"
		fi

		if ! git checkout -b "${branch_name}"; then
			die "Failed to create branch"
		fi

		success "Branch '${branch_name}' created from origin/${base_branch}"
	fi
}

# Apply JQ transformation to output file
jq_transform() {
	local filter=$1
	jq "${filter}" "${OUTPUT_FILE}" > "${OUTPUT_FILE}.tmp"
	mv "${OUTPUT_FILE}.tmp" "${OUTPUT_FILE}"
}

# Sanitize the downloaded API specification
sanitize_api_spec() {
	local api_spec_host=$1

	print_header "Sanitizing API Specification"

	# Pretty print
	info "Pretty printing JSON..."
	jq_transform '.'

	# Sanitize host URL
	info "Sanitizing host URL: ${C_BOLD}https://${api_spec_host}${C_RESET} → ${C_BOLD}${HOST_PLACEHOLDER}${C_RESET}"
	sed -i "s|https://${api_spec_host}|${HOST_PLACEHOLDER}|g" "${OUTPUT_FILE}"

	# Sanitize title
	info "Sanitizing title..."
	jq_transform ".info.title = \"${API_TITLE}\""

	# Sanitize description
	info "Sanitizing description..."
	jq_transform ".info.description = \"${API_DESCRIPTION}\""

	# Sanitize contact
	info "Sanitizing contact..."
	jq_transform '.info.contact = {}'

	# Drop tags description
	info "Removing tags description..."
	jq_transform 'del(.tags[].description)'
}

# Ask user to regenerate PHP client
ask_regenerate_client() {
	echo ""
	if ask_yes_no "Do you want to run 'make php' to regenerate the PHP client?" "Y"; then
		info "Running 'make php'..."
		if make php; then
			success "PHP client generation completed successfully"
			return 0
		else
			die "PHP client generation failed"
		fi
	else
		info "Skipping 'make php'. You can run it manually later."
		return 1
	fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Git Commit Workflow
# ─────────────────────────────────────────────────────────────────────────────

# Show git status with untracked files
show_git_status() {
	print_header "Current Git Status"
	git status --short --untracked-files=all | grep -v -E "${GIT_IGNORE_PATTERN}"
	echo ""
}

# Guide user through staging changes
stage_changes() {
	local remote_version=$1

	show_git_status

	echo "The following changes will be staged:"
	for path in "${STAGE_PATHS[@]}"; do
		printf "  ${C_CYAN}·${C_RESET} %s\n" "${path}"
	done
	echo ""
	echo "Note: Other files will be ignored and not staged."
	echo ""

	if ! ask_yes_no "Do you want to stage these changes?" "Y"; then
		warn "Please stage your changes manually with 'git add <files>'"
		return 1
	fi

	info "Staging specific files..."
	git add "${STAGE_PATHS[@]}" 2>/dev/null || true

	# Show what was staged
	echo ""
	echo "Staged changes:"
	git status --short | grep -v -E "${GIT_IGNORE_PATTERN}"
	echo ""

	return 0
}

# Create conventional commit
create_commit() {
	local remote_version=$1
	local commit_msg="feat: update API client to version ${remote_version}"

	echo ""
	echo "Suggested commit message (conventional commits format):"
	printf "  ${C_BOLD}%s${C_RESET}\n" "${commit_msg}"
	echo ""

	if ask_yes_no "Do you want to use this commit message?" "Y"; then
		# Use the suggested message
		:
	else
		# Let user enter custom message
		echo ""
		echo "Enter your commit message (use conventional commits format):"
		echo "Examples: feat: ..., fix: ..., docs: ..., chore: ..."
		read -r -p "Commit message: " custom_msg

		if [[ -z "${custom_msg}" ]]; then
			warn "Empty commit message. Using default message."
		else
			commit_msg="${custom_msg}"
		fi
	fi

	info "Creating commit..."
	if git commit -m "${commit_msg}"; then
		success "Commit created successfully"
		echo ""
		git --no-pager log -1 --oneline
		echo ""
		return 0
	else
		warn "Failed to create commit"
		return 1
	fi
}

# Verify commit was created
verify_commit() {
	local status
	status=$(git status --short | grep -v -E "${GIT_IGNORE_PATTERN}")

	if [[ -z "${status}" ]]; then
		success "All changes have been committed"
		return 0
	else
		warn "There are still uncommitted changes:"
		git status --short | grep -v -E "${GIT_IGNORE_PATTERN}"
		return 1
	fi
}

# Handle commit workflow
handle_commit_workflow() {
	local remote_version=$1
	local client_regenerated=$2

	print_header "Commit Workflow"

	# Stage changes
	if ! stage_changes "${remote_version}"; then
		warn "Changes were not staged automatically."
		echo ""
		info "Please review and commit your changes manually:"
		info "  1. Review changes: git status"
		info "  2. Stage changes: git add <files> or git add -A"
		info "  3. Commit: git commit -m 'feat: update API client to version ${remote_version}'"
		return 1
	fi

	# Create commit
	if ! create_commit "${remote_version}"; then
		warn "Commit was not created."
		echo ""
		info "Please commit your changes manually:"
		info "  git commit -m 'feat: update API client to version ${remote_version}'"
		return 1
	fi

	# Verify commit
	if ! verify_commit; then
		warn "Some changes may not have been committed."
		info "Please review with: git status"
		return 1
	fi

	return 0
}

# =============================================================================
# Main Script
# =============================================================================

main() {
	parse_args "$@"
	check_requirements

	local api_spec_host=$1
	local current_version
	local origin_version
	local remote_version

	# Fetch latest from origin
	fetch_from_origin

	# Get version information
	current_version=$(get_local_version)
	origin_version=$(get_origin_version)

	# Display current versions
	display_versions "${current_version}" "${origin_version}"

	# Download API spec
	download_api_spec "${api_spec_host}"

	# Get remote version
	remote_version=$(get_remote_version "${temp_file}")
	info "Remote API version: ${C_BOLD}${remote_version}${C_RESET}"

	# Handle version comparison and branching
	handle_version_comparison "${current_version}" "${origin_version}" "${remote_version}"

	# Create branch if needed
	create_update_branch

	# Update local file
	info "Updating API spec to version ${C_BOLD}${remote_version}${C_RESET}"
	cp "${temp_file}" "${OUTPUT_FILE}"

	# Sanitize the spec
	sanitize_api_spec "${api_spec_host}"

	echo ""
	success "API definition updated and sanitized successfully"
	info "New version: ${C_BOLD}${remote_version}${C_RESET}"

	# Ask to regenerate client
	local client_regenerated=false
	if ask_regenerate_client; then
		client_regenerated=true
	fi

	# Show what would be committed
	print_header "Files to be Committed"
	git status --short --untracked-files=all | grep -v -E "${GIT_IGNORE_PATTERN}"
	echo ""

	# Handle commit workflow
	echo ""
	if ask_yes_no "Do you want to commit these changes now?" "Y"; then
		if handle_commit_workflow "${remote_version}" "${client_regenerated}"; then
			success "Changes committed successfully"

			# Offer to push
			echo ""
			if [[ "${create_branch}" == "true" ]]; then
				if ask_yes_no "Do you want to push branch '${branch_name}' to remote?" "N"; then
					info "Pushing to remote..."
					if git push -u origin "${branch_name}"; then
						success "Branch pushed successfully"
					else
						warn "Failed to push branch. You can push manually with:"
						warn "  git push -u origin ${branch_name}"
					fi
				fi
			fi
		else
			warn "Commit workflow incomplete. Please review and commit manually."
		fi
	else
		warn "Changes not committed."
		show_git_status
	fi

	# Final message
	print_header "Summary"
	success "Done!"
	if [[ "${create_branch}" == "true" ]]; then
		info "  Branch:   ${C_BOLD}${branch_name}${C_RESET}"
	fi
	info "  Version:  ${C_BOLD}${remote_version}${C_RESET}"
	info "  API spec: ${C_BOLD}${OUTPUT_FILE}${C_RESET}"
	if [[ "${client_regenerated}" == "true" ]]; then
		info "  PHP client regenerated"
	fi
	echo ""
}

main "$@"
