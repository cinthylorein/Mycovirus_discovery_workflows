#!/usr/bin/env bash
set -euo pipefail

# User can set these before running:
#   export PIPELINE_ROOT=/somewhere/MVoPvirome
#   export PROJECT=MVoP_pipeline
PIPELINE_ROOT="${PIPELINE_ROOT:-/workspace/$USER/Virus_discovery_workflows/MVoPvirome}"
PROJECT="${PROJECT:-MVoP_pipeline}"
EMAIL="${EMAIL:-mvop.mycoviromeonline@gmail.com}"

PROJECT_DIR="${PIPELINE_ROOT}/${PROJECT}"

echo "Setting up project at: $PROJECT_DIR"
echo "Using PIPELINE_ROOT=$PIPELINE_ROOT"
echo "Using PROJECT=$PROJECT"
echo "Using EMAIL=$EMAIL"

# Create folders (portable)
mkdir -p "${PROJECT_DIR}"/{scripts,config,accession_lists,adapters,logs,blast_results,annotation,mapping,contigs,fastqc,environments,raw_reads,trimmed_reads,tmp}

# Install config into the project (Slurm jobs will source THIS copy)
cp -f "$(dirname "$0")/pipeline.env" "${PROJECT_DIR}/config/pipeline.env"

# Optional: personalize email in the installed config (only if you want it there)
# (You can also keep email separate; leaving this simple)
export EMAIL="${EMAIL:-mvop.mycoviromeonline@gmail.com}"

# Ensure EMAIL is present exactly once in the installed config
grep -v '^export EMAIL=' "${PROJECT_DIR}/config/pipeline.env" > "${PROJECT_DIR}/config/pipeline.env.tmp"
mv "${PROJECT_DIR}/config/pipeline.env.tmp" "${PROJECT_DIR}/config/pipeline.env"
echo "export EMAIL=\"${EMAIL}\"" >> "${PROJECT_DIR}/config/pipeline.env"

# Copy scripts into project/scripts
# Assumes you run setup from inside the cloned repo and Scripts/ contains the workflow scripts
cp -f "$(dirname "$0")/"*.sh "${PROJECT_DIR}/scripts/" || true
cp -f "$(dirname "$0")/"*.slurm "${PROJECT_DIR}/scripts/" 2>/dev/null || true

# Copy adapters/environments if they exist in repo top-level folders
REPO_ROOT="$(cd -- "$(dirname "$0")/.." && pwd)"
if [[ -d "${REPO_ROOT}/adapters" ]]; then
  cp -rf "${REPO_ROOT}/adapters/." "${PROJECT_DIR}/adapters/"
fi
if [[ -d "${REPO_ROOT}/environments" ]]; then
  cp -rf "${REPO_ROOT}/environments/." "${PROJECT_DIR}/environments/"
fi

echo "Setup complete."
echo "Config installed at: ${PROJECT_DIR}/config/pipeline.env"
echo "Next: run wrappers from ${PROJECT_DIR}/scripts after editing PIPELINE_ROOT/PROJECT if needed."