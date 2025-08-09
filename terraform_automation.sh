#!/bin/bash

# ====================================================================================
# Terraform Automation Script with Robust Timestamped Logging
#
# This script finds all subdirectories containing Terraform files (.tf) within the
# current directory and its subdirectories, while excluding specified paths.
# It then runs a series of standard Terraform commands in each of those directories.
# All output is logged to a file and displayed on the console in real-time,
# with timestamps for each major step.
#
# Usage: ./terraform_automation.sh [command]
#   - command: 'apply' to create/update resources
#   - command: 'destroy' to destroy resources in reverse order
#
# ====================================================================================

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Section 1: Logging Setup ---

# Define the log directory and file.
LOG_DIR="logs"
LOG_FILE="$LOG_DIR/terraform_automation_$(date +"%Y-%m-%d_%H-%M-%S").log"

# Create the log directory. The -p flag prevents an error if it already exists.
mkdir -p "$LOG_DIR"

# Redirect stdout and stderr to the log file while also displaying it on the console.
# The 'exec' command replaces the current shell's file descriptors.
# 1>&2 ensures that all output goes to stderr, which is then handled by the tee.
exec > >(tee -a "$LOG_FILE") 2>&1

# Function to echo a message with a timestamp.
log_timestamped_message() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1"
}

log_timestamped_message "======================================================================"
log_timestamped_message "Terraform Automation Script Started on $(date)"
log_timestamped_message "======================================================================"
log_timestamped_message "Log file: $LOG_FILE"
log_timestamped_message ""

# --- Section 2: Configuration & Pre-flight checks ---

# Check for a command-line argument
if [ -z "$1" ]; then
    log_timestamped_message "Error: No command specified."
    echo "Usage: $0 [apply | destroy]"
    exit 1
fi

COMMAND=$1

if [ "$COMMAND" != "apply" ] && [ "$COMMAND" != "destroy" ]; then
    log_timestamped_message "Error: Invalid command '$COMMAND'."
    echo "Usage: $0 [apply | destroy]"
    exit 1
fi

# --- IMPORTANT: Configure directories to exclude here ---
# To exclude a directory, add its path (relative to the script) to this array.
# For example, to exclude the "./3-eks/ingress-controller" directory, you would
# set this as: EXCLUDE_DIRS=("*/3-eks/ingress-controller*")
EXCLUDE_DIRS=("*/3-eks/ingress-controller*")

# Check if the 'terraform' command is available.
if ! command -v terraform &> /dev/null
then
    log_timestamped_message "Error: 'terraform' command not found."
    echo "Please install Terraform and ensure it is in your system's PATH."
    exit 1
fi

# --- Section 3: Find and order all Terraform directories ---

log_timestamped_message "Finding all directories with Terraform files..."
echo ""

# Build the exclusion string for the find command.
EXCLUDE_FIND_ARGS=""
for dir in "${EXCLUDE_DIRS[@]}"; do
    EXCLUDE_FIND_ARGS+=" -not -path \"$dir\""
done

# Find all directories containing any file with a '.tf' extension,
# excluding the paths specified in EXCLUDE_DIRS.
# The `eval` is necessary to properly expand the `EXCLUDE_FIND_ARGS` variable.
# The `-print0` and `xargs -0` pattern is used to handle directories with spaces in their names.
terraform_directories=$(eval find . -type f -name "*.tf" $EXCLUDE_FIND_ARGS -print0 | xargs -0 -I {} dirname {} | sort -u)

# Check if any Terraform directories were found.
if [ -z "$terraform_directories" ]; then
    log_timestamped_message "No directories with Terraform files (.tf) were found."
    exit 0
fi

# Reverse the order if the command is 'destroy'.
if [ "$COMMAND" == "destroy" ]; then
    # Create a new array with the directories in reverse order.
    REVERSED_DIRS=()
    for dir in $terraform_directories; do
        REVERSED_DIRS=("$dir" "${REVERSED_DIRS[@]}")
    done
    terraform_directories="${REVERSED_DIRS[@]}"
fi

# --- Section 4: Display the execution order ---

log_timestamped_message "======================================================================"
log_timestamped_message "Terraform will execute the '$COMMAND' command in the following order:"
log_timestamped_message "======================================================================"
i=1
for dir in $terraform_directories; do
    log_timestamped_message "$i. $dir"
    i=$((i+1))
done
log_timestamped_message "======================================================================"
echo ""

# --- Section 5: Iterate and run Terraform commands ---

for dir in $terraform_directories; do
    log_timestamped_message "======================================================================"
    log_timestamped_message "Entering directory: $dir"
    log_timestamped_message "======================================================================"

    # Change into the directory.
    cd "$dir"

    # Run terraform init
    log_timestamped_message "-> Running 'terraform init'..."
    terraform init

    # Run terraform fmt
    echo ""
    log_timestamped_message "-> Running 'terraform fmt'..."
    terraform fmt

    # Run terraform validate
    echo ""
    log_timestamped_message "-> Running 'terraform validate'..."
    terraform validate

    if [ "$COMMAND" == "apply" ]; then
        echo ""
        log_timestamped_message "-> Running 'terraform apply -auto-approve'..."
        terraform apply -auto-approve
    elif [ "$COMMAND" == "destroy" ]; then
        echo ""
        log_timestamped_message "-> Running 'terraform destroy -auto-approve'..."
        terraform destroy -auto-approve
    fi
    
    # Change back to the root directory.
    cd - > /dev/null

    echo ""
done

log_timestamped_message "======================================================================"
log_timestamped_message "Script finished successfully. All Terraform directories have been processed."
log_timestamped_message "======================================================================"
