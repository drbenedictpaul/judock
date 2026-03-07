# Use the official Julia image as the base
FROM julia:1.10

# Set working directory inside the container
WORKDIR /app

# Install basic system utilities
RUN apt-get update && apt-get install -y \
    build-essential \
    unzip \
    wget \
    && rm -rf /var/lib/apt/lists/*

# --- STEP 1: INSTALL JULIA PACKAGES ---
RUN julia -e 'using Pkg; Pkg.add(["Genie", "TOML", "CSV", "DataFrames", "Dates", "PythonCall", "Conda", "Distributed"]); Pkg.precompile();'

# --- STEP 2: SETUP PYTHON ENVIRONMENT ---
RUN julia -e 'using Pkg; using Conda; \
    const ENV_NAME = :plip_env_julia; \
    Conda.add("scikit-learn", ENV_NAME; channel="conda-forge"); \
    Conda.add("rdkit", ENV_NAME; channel="conda-forge"); \
    Conda.add("joblib", ENV_NAME; channel="conda-forge"); \
    Conda.add("numpy", ENV_NAME; channel="conda-forge");'

# --- STEP 3: CONFIGURE ENVIRONMENT VARIABLES (CORRECTED) ---
# We now include 'x86_64' in the path, which is standard for this image.
ENV JULIA_PYTHONCALL_EXE="/root/.julia/conda/3/x86_64/envs/plip_env_julia/bin/python"

# --- STEP 4: COPY APPLICATION CODE ---
COPY . /app

# Ensure directories exist
RUN mkdir -p /root/juDock_input \
    && mkdir -p /root/juDock_output \
    && mkdir -p /root/juDock_results \
    && mkdir -p /app/public/logs

# Expose the Genie port
EXPOSE 8000

# Start the application
CMD ["julia", "judock.jl"]
