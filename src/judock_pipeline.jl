# src/judock_pipeline.jl
module judock_pipeline

export process_single_ligand

using PythonCall
using DataFrames
using CSV

const Chem = pyimport("rdkit.Chem")
const Descriptors = pyimport("rdkit.Chem.Descriptors")
const pyNone = pyimport("builtins").None
const np = pyimport("numpy")
const joblib = pyimport("joblib")

function calculate_dockscore(row)
    binding_score = -2.0 * row.Predicted_Binding_Affinity
    hbond_score = 0.5 * row.Predicted_Num_H_Bonds
    hydrophobic_score = 0.1 * row.Predicted_Num_Hydrophobic
    interaction_score = binding_score + hbond_score + hydrophobic_score

    penalty_score = 0.0
    if row.MolWt > 500.0; penalty_score -= 1.0; end
    if row.MolLogP > 5.0; penalty_score -= 1.0; end
    if row.NumRotatableBonds < 3; penalty_score -= 0.5; end

    return round(interaction_score + penalty_score, digits=2)
end

function assign_label(score::Float64)
    if score >= 15.0; return "Potential"; elseif score >= 12.0; return "Putative"; else; return "Not Active"; end
end

function process_single_ligand(ligand_sdf_path::String, model_name::String, log_io::IO, update_func::Function)
    ligand_id = replace(basename(ligand_sdf_path), ".sdf" => "")
    println(log_io, "--- Starting juDock Pipeline for $ligand_id ---")
    
    update_func("Converting & Calculating Descriptors", 10)
    
    model_dir = joinpath(pwd(), "models", model_name)
    model_file = joinpath(model_dir, "multi_output_model.joblib")
    if !isfile(model_file); error("Model file not found for target: $model_name"); end
    
    features = DataFrame()
    try
        suppl = Chem.SDMolSupplier(ligand_sdf_path)
        mol = first(suppl)
        if pyconvert(Bool, mol != pyNone)
            features = DataFrame(
                MolWt=[pyconvert(Float64, Descriptors.MolWt(mol))], HeavyAtomMolWt=[pyconvert(Float64, Descriptors.HeavyAtomMolWt(mol))],
                NumHeavyAtoms=[pyconvert(Int, Descriptors.HeavyAtomCount(mol))], NumAtoms=[pyconvert(Int, mol.GetNumAtoms())],
                MolLogP=[pyconvert(Float64, Descriptors.MolLogP(mol))], MolMR=[pyconvert(Float64, Descriptors.MolMR(mol))],
                TPSA=[pyconvert(Float64, Descriptors.TPSA(mol))], NumValenceElectrons=[pyconvert(Int, Descriptors.NumValenceElectrons(mol))],
                MaxAbsPartialCharge=[pyconvert(Float64, Descriptors.MaxAbsPartialCharge(mol))], MinAbsPartialCharge=[pyconvert(Float64, Descriptors.MinAbsPartialCharge(mol))],
                NumHDonors=[pyconvert(Int, Descriptors.NumHDonors(mol))], NumHAcceptors=[pyconvert(Int, Descriptors.NumHAcceptors(mol))],
                NumRotatableBonds=[pyconvert(Int, Descriptors.NumRotatableBonds(mol))], NumHeteroatoms=[pyconvert(Int, Descriptors.NumHeteroatoms(mol))],
                NumAromaticRings=[pyconvert(Int, Descriptors.NumAromaticRings(mol))], NumAliphaticRings=[pyconvert(Int, Descriptors.NumAliphaticRings(mol))],
                NumSaturatedRings=[pyconvert(Int, Descriptors.NumSaturatedRings(mol))], NumAromaticHeterocycles=[pyconvert(Int, Descriptors.NumAromaticHeterocycles(mol))],
                NumAliphaticHeterocycles=[pyconvert(Int, Descriptors.NumAliphaticHeterocycles(mol))], NumSaturatedHeterocycles=[pyconvert(Int, Descriptors.NumSaturatedHeterocycles(mol))],
                FractionCSP3=[pyconvert(Float64, Descriptors.FractionCSP3(mol))], BertzCT=[pyconvert(Float64, Descriptors.BertzCT(mol))],
                BalabanJ=[pyconvert(Float64, Descriptors.BalabanJ(mol))], HallKierAlpha=[pyconvert(Float64, Descriptors.HallKierAlpha(mol))],
                Kappa1=[pyconvert(Float64, Descriptors.Kappa1(mol))], Kappa2=[pyconvert(Float64, Descriptors.Kappa2(mol))],
                Kappa3=[pyconvert(Float64, Descriptors.Kappa3(mol))], Chi0n=[pyconvert(Float64, Descriptors.Chi0n(mol))],
                Chi1n=[pyconvert(Float64, Descriptors.Chi1n(mol))], Chi0v=[pyconvert(Float64, Descriptors.Chi0v(mol))]
            )
        else
            error("RDKit could not read molecule from SDF file.")
        end
    catch e
        println(log_io, "ERROR in RDKit descriptor calculation: $e"); rethrow(e)
    end
    
    update_func("Predicting Interactions & Affinity", 60)
    model = joblib.load(model_file)
    X_pred = np.asarray(Matrix(features))
    Y_pred = model.predict(X_pred)
    Y_pred_jl = pyconvert(Matrix, Y_pred)

    update_func("Calculating Final Dockscore", 90)
    result_row = hcat(features, DataFrame(
        Predicted_Binding_Affinity = Y_pred_jl[1, 1],
        Predicted_Num_H_Bonds = round(Int, Y_pred_jl[1, 3]),
        Predicted_Num_Hydrophobic = round(Int, Y_pred_jl[1, 4])
    ))
    score = calculate_dockscore(first(eachrow(result_row)))
    label = assign_label(score)

    update_func("Done", 100)
    return Dict(
        "Ligand_ID" => ligand_id, "dockscore" => score, "Activity" => label,
        "Predicted_Binding_Affinity" => round(Y_pred_jl[1, 1], digits=2),
        "Predicted_Num_H_Bonds" => round(Int, Y_pred_jl[1, 3])
    )
end

end # end module