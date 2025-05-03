module QuantumObjectives

export KetInfidelityObjective
export UnitaryInfidelityObjective
export DensityMatrixPureStateInfidelityObjective
export UnitarySensitivityObjective
export UnitaryFreePhaseInfidelityObjective

using LinearAlgebra
using NamedTrajectories
using PiccoloQuantumObjects
using DirectTrajOpt

# --------------------------------------------------------- 
#                        Kets
# ---------------------------------------------------------

function ket_fidelity_loss(
    ψ̃::AbstractVector, 
    ψ_goal::AbstractVector{<:Complex{Float64}}
)
    ψ = iso_to_ket(ψ̃)
    return abs2(ψ_goal' * ψ)
end 

function KetInfidelityObjective(
    ψ̃_name::Symbol,
    traj::NamedTrajectory;
    Q=100.0
)
    ψ_goal = iso_to_ket(traj.goal[ψ̃_name])
    ℓ = ψ̃ -> abs(1 - ket_fidelity_loss(ψ̃, ψ_goal))
    return TerminalObjective(ℓ, ψ̃_name, traj; Q=Q)
end


# ---------------------------------------------------------
#                        Unitaries
# ---------------------------------------------------------

function unitary_fidelity_loss(
    Ũ⃗::AbstractVector{<:Real},
    U_goal::AbstractMatrix{<:Complex{<:Real}}
)
    U = iso_vec_to_operator(Ũ⃗)
    n = size(U, 1)
    return abs2(tr(U_goal' * U)) / n^2
end

function unitary_fidelity_loss(
    Ũ⃗::AbstractVector{<:Real},
    op::EmbeddedOperator
)
    U_goal = unembed(op)
    U = iso_vec_to_operator(Ũ⃗)[op.subspace, op.subspace]
    n = length(op.subspace)
    M = U_goal'U
    return 1 / (n * (n + 1)) * (abs(tr(M'M)) + abs2(tr(M))) 
end

function UnitaryInfidelityObjective(
    U_goal::AbstractPiccoloOperator,
    Ũ⃗_name::Symbol,
    traj::NamedTrajectory;
    Q=100.0
)
    ℓ = Ũ⃗ -> abs(1 - unitary_fidelity_loss(Ũ⃗, U_goal))
    return TerminalObjective(ℓ, Ũ⃗_name, traj; Q=Q)
end

function UnitaryFreePhaseInfidelityObjective(
    U_goal::Function,
    Ũ⃗_name::Symbol,
    θ_name::Symbol,
    traj::NamedTrajectory;
    Q=100.0
)
    d = traj.global_dims[θ_name]
    function ℓ(x)
        Ũ⃗, θ = x[1:end-d], x[end-d+1:end]
        return abs(1 - QuantumObjectives.unitary_fidelity_loss(Ũ⃗, U_goal(θ)))
    end
    return TerminalObjective(ℓ, Ũ⃗_name, traj; Q=Q, global_names=[θ_name])
end

# ---------------------------------------------------------
#                        Density Matrices
# ---------------------------------------------------------

function density_matrix_pure_state_infidelity_loss(
    ρ̃::AbstractVector, 
    ψ::AbstractVector{<:Complex{Float64}}
)
    ρ = iso_vec_to_density(ρ̃)
    ℱ = real(ψ' * ρ * ψ)
    return abs(1 - ℱ)
end

function DensityMatrixPureStateInfidelityObjective(
    ρ̃_name::Symbol,
    ψ_goal::AbstractVector{<:Complex{Float64}},
    traj::NamedTrajectory;
    Q=100.0
)
    ℓ = ρ̃ -> density_matrix_pure_state_infidelity_loss(ρ̃, ψ_goal)
    return TerminalObjective(ℓ, ρ̃_name, traj; Q=Q)
end

# ---------------------------------------------------------
#                        Sensitivity
# ---------------------------------------------------------

function unitary_fidelity_loss(
    Ũ⃗::AbstractVector{<:Real}
)
    U = iso_vec_to_operator(Ũ⃗)
    n = size(U, 1)
    return abs2(tr(U' * U)) / n^2
end

function UnitarySensitivityObjective(
    name::Symbol,
    traj::NamedTrajectory,
    times::AbstractVector{Int};
    Qs::AbstractVector{<:Float64}=fill(1.0, length(times)),
    scale::Float64=1.0,
)
    ℓ = Ũ⃗ -> scale^4 * unitary_fidelity_loss(Ũ⃗)

    return KnotPointObjective(
        ℓ,
        name,
        traj;
        Qs=Qs,
        times=times
    )
end


end