# judock.jl (The Final, Corrected, Single-Process Sequential Version)

# --- Initialize Packages ---
using Pkg
Pkg.add(["Genie", "TOML", "CSV", "DataFrames", "Dates", "PythonCall", "Conda"])
using Genie, Genie.Router, Genie.Renderer.Json, Genie.Renderer.Html
using TOML, Dates, CSV, DataFrames
using PythonCall
using Conda

# --- Load our pipeline module ---
# This line assumes the JULIA_PYTHONCALL_EXE environment variable is set
include("src/judock_pipeline.jl")
using .judock_pipeline

# --- Application Configuration ---
const ROOT_DIR = pwd()
const USER_HOME = homedir()
const INPUT_DIR = joinpath(USER_HOME, "juDock_input")
const OUTPUT_DIR = joinpath(USER_HOME, "juDock_output")
const MODELS_DIR = joinpath(ROOT_DIR, "models")
const RESULTS_ARCHIVE = joinpath(USER_HOME, "juDock_results")
const LOG_DIR = joinpath(ROOT_DIR, "public", "logs")

const PIPELINE_STATE = Ref(Dict{Symbol, Any}(
    :is_running => false, :current_ligand => "None", :current_step => "Idle",
    :ligand_count => "0 / 0", :overall_progress => 0
))
const JOB_LOCK = ReentrantLock()

# --- Web Routes ---
route("/") do; serve_static_file("index.html"); end

route("/list-models") do
    if !isdir(MODELS_DIR); return json([]); end
    models = filter(x -> isdir(joinpath(MODELS_DIR, x)), readdir(MODELS_DIR))
    return json(models)
end

route("/start-pipeline", method = "POST") do
    lock(JOB_LOCK) do; if PIPELINE_STATE[][:is_running]; return json(Dict("success" => false, "message" => "Pipeline is already running.")); end; end
    
    payload = Genie.Requests.jsonpayload()
    model_name = get(payload, "model", "17-beta-HSD")
    
    ligand_files = filter(f -> endswith(f, ".sdf"), readdir(INPUT_DIR))
    if isempty(ligand_files); return json(Dict("success" => false, "message" => "Input directory is empty.")); end
    
    timestamp = Dates.format(now(), "yyyy-mm-dd_HHMMSS")
    current_results_dir = joinpath(RESULTS_ARCHIVE, "judock_run_$(timestamp)")
    mkpath(current_results_dir)

    # --- CRITICAL FIX 1: Set state to running BEFORE the async block starts ---
    lock(JOB_LOCK) do
        PIPELINE_STATE[] = Dict(:is_running => true, :current_ligand => "Initializing", :current_step => "Starting...", :ligand_count => "0 / $(length(ligand_files))", :overall_progress => 0)
    end

    @async begin
        # --- CRITICAL FIX 2: Sleep immediately so the server can send the "Started" message to the browser ---
        sleep(0.2) 

        final_results = DataFrame()
        total_ligands = length(ligand_files)

        for (i, ligand_file) in enumerate(ligand_files)
            ligand_id = replace(ligand_file, ".sdf" => "")
            full_path = joinpath(INPUT_DIR, ligand_file)
            
            lock(JOB_LOCK) do
                PIPELINE_STATE[][:current_ligand] = ligand_id
                PIPELINE_STATE[][:ligand_count] = "$i / $total_ligands"
            end
            
            open(joinpath(LOG_DIR, "$(ligand_id).log"), "w+") do log_io
                try
                    update_func = (status, progress) -> begin
                        lock(JOB_LOCK) do
                            PIPELINE_STATE[][:current_step] = status
                            PIPELINE_STATE[][:overall_progress] = floor(Int, ((i-1)/total_ligands * 100) + (progress/total_ligands))
                        end
                        # --- CRITICAL FIX 3: Give the server a millisecond to breathe and answer the frontend's status polls ---
                        sleep(0.05) 
                    end
                    
                    result_dict = process_single_ligand(full_path, model_name, log_io, update_func)
                    push!(final_results, result_dict, cols=:union)
                catch e
                    println(log_io, "!!! PIPELINE FAILED for $ligand_id: $e")
                end
            end
            
            # --- CRITICAL FIX 4: Breathe between ligands ---
            sleep(0.1)
        end

        if !isempty(final_results)
            sort!(final_results, :dockscore, rev=true)
            final_report_path = joinpath(current_results_dir, "final_report.csv")
            CSV.write(final_report_path, final_results)
            println("--- Final report saved to $(final_report_path) ---")
        end
        
        lock(JOB_LOCK) do
            PIPELINE_STATE[][:current_step] = "Finalizing Output..."
            PIPELINE_STATE[][:overall_progress] = 100
        end
        
        sleep(1.5) 

        lock(JOB_LOCK) do
            PIPELINE_STATE[] = Dict(:is_running => false, :current_ligand => "None", :current_step => "Finished", :ligand_count => "$total_ligands / $total_ligands", :overall_progress => 100)
        end
        println("--- Pipeline run finished ---")
    end

    return json(Dict("success" => true, "message" => "Pipeline started!"))
end

route("/get-status") do; lock(JOB_LOCK) do; return json(PIPELINE_STATE[]); end; end

route("/list-results") do
    if !isdir(RESULTS_ARCHIVE); return json([]); end
    folders = filter(x -> isdir(joinpath(RESULTS_ARCHIVE, x)), readdir(RESULTS_ARCHIVE))
    sort!(folders, by = x -> stat(joinpath(RESULTS_ARCHIVE, x)).mtime, rev=true)
    return json(folders)
end

route("/get-result-data/:folder") do
    folder = params(:folder)
    report_path = joinpath(RESULTS_ARCHIVE, folder, "final_report.csv")
    if !isfile(report_path); return json(Dict("success" => false, "message" => "Report file not found.")); end
    df = CSV.read(report_path, DataFrame)
    json_data = [Dict(names(row) .=> values(row)) for row in eachrow(df)]
    return json(Dict("success" => true, "data" => json_data))
end

# --- Server Startup ---
println("\n======================================================")
println("          juDock - An ML-based Docking Predictor")
println("           Developed by: Dr. Benedict Christopher Paul")
println("                  www.drpaul.cc")
println("======================================================")
println("\nInitializing directories...")
mkpath(INPUT_DIR); mkpath(OUTPUT_DIR); mkpath(MODELS_DIR); mkpath(RESULTS_ARCHIVE)
mkpath(joinpath(ROOT_DIR, "public", "logs"))
println("Starting juDock web server on http://localhost:8000")
Genie.config.server_host = "0.0.0.0"
Genie.up(8000, async=false)