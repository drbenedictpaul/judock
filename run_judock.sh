#!/bin/bash

# Define User Directories
INPUT_DIR="$HOME/juDock_input"
RESULTS_DIR="$HOME/juDock_results"

echo "======================================================"
echo "      juDock v1.0 - AI-Powered Virtual Screening      "
echo "======================================================"
echo ""
echo "Setting up environment..."

# Create directories if they don't exist
if [ ! -d "$INPUT_DIR" ]; then
    mkdir -p "$INPUT_DIR"
    echo " -> Created input directory: $INPUT_DIR"
else
    echo " -> Input directory found: $INPUT_DIR"
fi

if [ ! -d "$RESULTS_DIR" ]; then
    mkdir -p "$RESULTS_DIR"
    echo " -> Results directory: $RESULTS_DIR"
else
    echo " -> Results directory found: $RESULTS_DIR"
fi

echo ""
echo "------------------------------------------------------"
echo "INSTRUCTIONS:"
echo "1. Please place your ligand files (.sdf) into:"
echo "   $INPUT_DIR"
echo ""
echo "2. Once files are placed, press ENTER to start the server."
echo "------------------------------------------------------"
read -p "Press Enter to continue..."

echo ""
echo "Starting juDock Server..."
echo "Open your web browser to: http://localhost:8000"
echo "Press Ctrl+C to stop."
echo ""

# Run the Docker container
docker run -it --rm \
  -p 8000:8000 \
  -v "$INPUT_DIR":/root/juDock_input:z \
  -v "$RESULTS_DIR":/root/juDock_results:z \
  judock:v1
