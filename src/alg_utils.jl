isautodifferentiable(alg::OrdinaryDiffEqAlgorithm) = true

isfsal(alg::OrdinaryDiffEqAlgorithm) = true
isfsal{MType,VType,fsal}(tab::ExplicitRKTableau{MType,VType,fsal}) = fsal
isfsal(alg::CompositeAlgorithm) = true # Every algorithm is assumed FSAL. Good assumption?
isfsal(alg::FunctionMap) = false
isfsal(alg::Rodas4) = false
isfsal(alg::Rodas42) = false
isfsal(alg::Rodas4P) = false
isfsal(alg::Vern7) = false
isfsal(alg::Vern8) = false
isfsal(alg::Vern9) = false

fsal_typeof(alg::OrdinaryDiffEqAlgorithm,rate_prototype) = typeof(rate_prototype)
#fsal_typeof(alg::LawsonEuler,rate_prototype) = Vector{typeof(rate_prototype)}
#fsal_typeof(alg::NorsettEuler,rate_prototype) = Vector{typeof(rate_prototype)}

isimplicit(alg::OrdinaryDiffEqAlgorithm) = false
isimplicit(alg::OrdinaryDiffEqAdaptiveImplicitAlgorithm) = true
isimplicit(alg::OrdinaryDiffEqImplicitAlgorithm) = true

isdtchangeable(alg::OrdinaryDiffEqAlgorithm) = true
isdtchangeable(alg::GenericIIF1) = false
isdtchangeable(alg::GenericIIF2) = false
isdtchangeable(alg::LawsonEuler) = false
isdtchangeable(alg::NorsettEuler) = false
isdtchangeable(alg::LawsonEulerKrylov) = false

ismultistep(alg::OrdinaryDiffEqAlgorithm) = false

isadaptive(alg::OrdinaryDiffEqAlgorithm) = false
isadaptive(alg::OrdinaryDiffEqAdaptiveAlgorithm) = true
isadaptive(alg::OrdinaryDiffEqCompositeAlgorithm) = isadaptive(alg.algs[1])

qmin_default(alg::OrdinaryDiffEqAlgorithm) = 1//5
qmin_default(alg::DP8) = 1//3

qmax_default(alg::OrdinaryDiffEqAlgorithm) = 10
qmax_default(alg::DP8) = 6

get_chunksize(alg::OrdinaryDiffEqAlgorithm) = error("This algorithm does not have a chunk size defined.")
get_chunksize{CS,AD}(alg::OrdinaryDiffEqAdaptiveImplicitAlgorithm{CS,AD}) = CS
get_chunksize{CS,AD}(alg::OrdinaryDiffEqImplicitAlgorithm{CS,AD}) = CS

alg_autodiff(alg::OrdinaryDiffEqAlgorithm) = error("This algorithm does not have an autodifferentiation option defined.")
alg_autodiff{CS,AD}(alg::OrdinaryDiffEqAdaptiveImplicitAlgorithm{CS,AD}) = AD
alg_autodiff{CS,AD}(alg::OrdinaryDiffEqImplicitAlgorithm{CS,AD}) = AD

alg_extrapolates(alg::OrdinaryDiffEqAlgorithm) = false
alg_extrapolates(alg::GenericImplicitEuler) = true
alg_extrapolates(alg::GenericTrapezoid) = true
alg_extrapolates(alg::ImplicitEuler) = true
alg_extrapolates(alg::LinearImplicitEuler) = true
alg_extrapolates(alg::Trapezoid) = true
alg_extrapolates(alg::ImplicitMidpoint) = true
alg_extrapolates(alg::TRBDF2) = true
alg_extrapolates(alg::SSPSDIRK2) = true
alg_extrapolates(alg::SDIRK2) = true
alg_extrapolates(alg::Kvaerno3) = true
alg_extrapolates(alg::Kvaerno4) = true
alg_extrapolates(alg::Kvaerno5) = true
alg_extrapolates(alg::KenCarp3) = true
alg_extrapolates(alg::KenCarp4) = true
alg_extrapolates(alg::KenCarp5) = true
alg_extrapolates(alg::Cash4) = true
alg_extrapolates(alg::Hairer4) = true
alg_extrapolates(alg::Hairer42) = true
alg_extrapolates(alg::IRKN4) = true
alg_extrapolates(alg::IRKN3) = true

alg_order(alg::OrdinaryDiffEqAlgorithm) = error("Order is not defined for this algorithm")
alg_adaptive_order(alg::OrdinaryDiffEqAdaptiveAlgorithm) = error("Algorithm is adaptive with no order")

alg_order(alg::FunctionMap) = 0
alg_order(alg::Euler) = 1
alg_order(alg::Heun) = 2
alg_order(alg::Ralston) = 2
alg_order(alg::LawsonEuler) = 1
alg_order(alg::NorsettEuler) = 1
alg_order(alg::SplitEuler) = 1
alg_order(alg::LawsonEulerKrylov) = 1
alg_order(alg::ETDRK4) = 4

alg_order(alg::SymplecticEuler) = 1
alg_order(alg::VelocityVerlet) = 2
alg_order(alg::VerletLeapfrog) = 2
alg_order(alg::PseudoVerletLeapfrog) = 2
alg_order(alg::McAte2) = 2
alg_order(alg::Ruth3) = 3
alg_order(alg::McAte3) = 3
alg_order(alg::McAte4) = 4
alg_order(alg::CandyRoz4) = 4
alg_order(alg::CalvoSanz4) = 4
alg_order(alg::McAte42) = 4
alg_order(alg::McAte5) = 5
alg_order(alg::Yoshida6) = 6
alg_order(alg::KahanLi6) = 6
alg_order(alg::McAte8) = 8
alg_order(alg::KahanLi8) = 8
alg_order(alg::SofSpa10) = 10

alg_order(alg::IRKN3) = 3
alg_order(alg::Nystrom4) = 4
alg_order(alg::Nystrom4VelocityIndependent) = 4
alg_order(alg::IRKN4) = 4
alg_order(alg::Nystrom5VelocityIndependent) = 5
alg_order(alg::DPRKN6) = 6
alg_order(alg::DPRKN8) = 8
alg_order(alg::DPRKN12) = 12
alg_order(alg::ERKN4) = 4
alg_order(alg::ERKN5) = 5

alg_order(alg::Midpoint) = 2
alg_order(alg::GenericIIF1) = 1
alg_order(alg::GenericIIF2) = 2
alg_order(alg::CarpenterKennedy2N54) = 4
alg_order(alg::SSPRK22) = 2
alg_order(alg::SSPRK33) = 3
alg_order(alg::SSPRK53) = 3
alg_order(alg::SSPRK63) = 3
alg_order(alg::SSPRK73) = 3
alg_order(alg::SSPRK83) = 3
alg_order(alg::SSPRK432) = 3
alg_order(alg::SSPRK932) = 3
alg_order(alg::SSPRK54) = 4
alg_order(alg::SSPRK104) = 4
alg_order(alg::RK4) = 4
alg_order(alg::ExplicitRK) = alg.tableau.order

alg_order(alg::BS3) = 3
alg_order(alg::BS5) = 5
alg_order(alg::OwrenZen3) = 3
alg_order(alg::OwrenZen4) = 4
alg_order(alg::OwrenZen5) = 5

alg_order(alg::DP5) = 5
alg_order(alg::DP5Threaded) = 5
alg_order(alg::Tsit5) = 5
alg_order(alg::DP8) = 8
alg_order(alg::Vern6) = 6
alg_order(alg::Vern7) = 7
alg_order(alg::Vern8) = 8
alg_order(alg::Vern9) = 9
alg_order(alg::TanYam7) = 7
alg_order(alg::TsitPap8) = 8
alg_order(alg::GenericImplicitEuler) = 1
alg_order(alg::GenericTrapezoid) = 2
alg_order(alg::ImplicitEuler) = 1
alg_order(alg::LinearImplicitEuler) = 1
alg_order(alg::MidpointSplitting) = 2
alg_order(alg::Trapezoid) = 2
alg_order(alg::ImplicitMidpoint) = 2
alg_order(alg::TRBDF2) = 2
alg_order(alg::SSPSDIRK2) = 2
alg_order(alg::SDIRK2) = 2
alg_order(alg::Kvaerno3) = 3
alg_order(alg::Kvaerno4) = 4
alg_order(alg::Kvaerno5) = 5
alg_order(alg::KenCarp3) = 3
alg_order(alg::KenCarp4) = 4
alg_order(alg::KenCarp5) = 5
alg_order(alg::Cash4) = 4
alg_order(alg::Hairer4) = 4
alg_order(alg::Hairer42) = 4
alg_order(alg::Feagin10) = 10
alg_order(alg::Feagin12) = 12
alg_order(alg::Feagin14) = 14

alg_order(alg::Rosenbrock23) = 2
alg_order(alg::Rosenbrock32) = 3
alg_order(alg::ROS3P) = 3
alg_order(alg::Rodas3) = 3
alg_order(alg::RosShamp4) = 4
alg_order(alg::Veldd4) = 4
alg_order(alg::Velds4) = 4
alg_order(alg::GRK4T) = 4
alg_order(alg::GRK4A) = 4
alg_order(alg::Ros4LStab) = 4
alg_order(alg::Rodas4) = 4
alg_order(alg::Rodas42) = 4
alg_order(alg::Rodas4P) = 4
alg_order(alg::Rodas5) = 5

alg_order(alg::CompositeAlgorithm) = alg_order(alg.algs[1])

alg_adaptive_order(alg::ExplicitRK) = alg.tableau.adaptiveorder
alg_adaptive_order(alg::OrdinaryDiffEqAlgorithm) = alg_order(alg)-1
alg_adaptive_order(alg::DP8) = 6
alg_adaptive_order(alg::Feagin10) = 8
alg_adaptive_order(alg::Feagin12) = 10
alg_adaptive_order(alg::Feagin14) = 12

alg_adaptive_order(alg::Rosenbrock23) = 3
alg_adaptive_order(alg::Rosenbrock32) = 2

alg_adaptive_order(alg::GenericImplicitEuler) = 0
alg_adaptive_order(alg::GenericTrapezoid) = 1
alg_adaptive_order(alg::ImplicitEuler) = 0
alg_adaptive_order(alg::Trapezoid) = 1
# this is actually incorrect and is purposefully decreased as this tends
# to track the real error much better
alg_adaptive_order(alg::ImplicitMidpoint) = 1
 # this is actually incorrect and is purposefully decreased as this tends
 # to track the real error much better

beta2_default(alg::OrdinaryDiffEqAlgorithm) = 2//(5alg_order(alg))
beta2_default(alg::FunctionMap) = 0
beta2_default(alg::DP8) = 0//1
beta2_default(alg::DP5) = 4//100
beta2_default(alg::DP5Threaded) = 4//100

beta1_default(alg::OrdinaryDiffEqAlgorithm,beta2) = 7//(10alg_order(alg))
beta1_default(alg::FunctionMap,beta2) = 0
beta1_default(alg::DP8,beta2) = typeof(beta2)(1//alg_order(alg)) - beta2/5
beta1_default(alg::DP5,beta2) = typeof(beta2)(1//alg_order(alg)) - 3beta2/4
beta1_default(alg::DP5Threaded,beta2) = typeof(beta2)(1//alg_order(alg)) - 3beta2/4

gamma_default(alg::OrdinaryDiffEqAlgorithm) = 9//10

qsteady_min_default(alg::OrdinaryDiffEqAlgorithm) = 1
qsteady_max_default(alg::OrdinaryDiffEqAlgorithm) = 1
qsteady_max_default(alg::OrdinaryDiffEqAdaptiveImplicitAlgorithm) = 6//5
# But don't re-use Jacobian if not adaptive: too risky and cannot pull back
qsteady_max_default(alg::OrdinaryDiffEqImplicitAlgorithm) = 1//1

FunctionMap_scale_by_time{scale_by_time}(alg::FunctionMap{scale_by_time}) = scale_by_time

# SSP coefficients
"""
    ssp_coefficient(alg)

Return the SSP coefficient of the ODE algorithm `alg`. If one time step of size
`dt` with `alg` can be written as a convex combination of explicit Euler steps
with step sizes `cᵢ * dt`, the SSP coefficient is the minimal value of `1/cᵢ`.

# Examples
```julia-repl
julia> ssp_coefficient(SSPRK104())
6
```
"""
ssp_coefficient(alg) = error("$alg is not a strong stability preserving method.")
ssp_coefficient(alg::Euler) = 1
ssp_coefficient(alg::SSPRK22) = 1
ssp_coefficient(alg::SSPRK33) = 1
ssp_coefficient(alg::SSPRK53) = 2.65
ssp_coefficient(alg::SSPRK63) = 3.518
ssp_coefficient(alg::SSPRK73) = 4.2879
ssp_coefficient(alg::SSPRK83) = 5.107
ssp_coefficient(alg::SSPRK432) = 2
ssp_coefficient(alg::SSPRK932) = 6
ssp_coefficient(alg::SSPRK54) = 1.508
ssp_coefficient(alg::SSPRK104) = 6

# We shouldn't do this probably.
#ssp_coefficient(alg::ImplicitEuler) = Inf
ssp_coefficient(alg::SSPSDIRK2) = 4
