#!/bin/bash

# ====================================================================================
# Terraform Automation Script
#
# This script finds all subdirectories containing Terraform files (.tf) within the
# current directory and its subdirectories, while excluding specified paths.
# It then runs a series of standard Terraform commands in each of those directories.
#
# Commands executed in each directory:
#   1. terraform init: Initializes a working directory containing Terraform configuration files.
#   2. terraform fmt: Rewrites the configuration files to a canonical format.
#   3. terraform validate: Checks if the configuration is valid.
#
# Prerequisites:
#   - Terraform must be installed and available in your system's PATH.
#   - The script must be run from the root of your repository.
# ====================================================================================

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Section 1: Configuration & Pre-flight checks ---

# --- IMPORTANT: Configure directories to exclude here ---
# To exclude a directory, add its path (relative to the script) to this array.
# For example, to exclude the "./3-eks/ingress-controller" directory, you would
# set this as: EXCLUDE_DIRS=("*/3-eks/ingress-controller*")
EXCLUDE_DIRS=("*/3-eks/ingress-controller*")

# Check if the 'terraform' command is available.
if ! command -v terraform &> /dev/null
then
    echo "Error: 'terraform' command not found."
    echo "Please install Terraform and ensure it is in your system's PATH."
    exit 1
fi

echo "Terraform found. Starting repository traversal..."
echo ""

# --- Section 2: Find all Terraform directories ---

# Build the exclusion string for the find command
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
    echo "No directories with Terraform files (.tf) were found."
    exit 0
fi

# --- Section 3: Iterate and run Terraform commands ---

for dir in $terraform_directories; do
    echo "======================================================================"
    echo "Entering directory: $dir"
    echo "======================================================================"

    # Change into the directory.
    cd "$dir"

    # Run terraform init
    echo "-> Running 'terraform init'..."
    terraform init

    # Run terraform fmt
    echo ""
    echo "-> Running 'terraform fmt'..."
    terraform fmt

    # Run terraform validate
    echo ""
    echo "-> Running 'terraform validate'..."
    terraform validate

    echo ""
    echo "-> Running 'terraform aply -auto-approve'..."
    terraform apply -auto-approve    

    # Run terraform plan (Optional)
    # Uncomment the following block if you want to also run 'terraform plan'.
    # Note: 'terraform plan' requires AWS credentials and a configured backend.
    # echo ""
    # echo "-> Running 'terraform plan'..."
    # terraform plan

    # Change back to the previous directory.
    cd - > /dev/null

    echo ""
done

echo "======================================================================"
echo "Script finished successfully. All Terraform directories have been processed."
echo "======================================================================"

