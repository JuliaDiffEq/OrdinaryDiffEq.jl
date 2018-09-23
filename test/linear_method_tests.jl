using OrdinaryDiffEq, Test, DiffEqDevTools, DiffEqOperators
u0 = rand(2)
A = DiffEqArrayOperator([2.0 -1.0; -1.0 2.0])
function (p::typeof(A))(::Type{Val{:analytic}},u0,p,t)
    exp(p.A*t)*u0
end

prob = ODEProblem(A,u0,(0.0,1.0))

x = rand(2)
@test A(0.0,x) == A*x

sol = solve(prob,LinearImplicitEuler())

dts = 1./2.^(8:-1:4) #14->7 good plot
sim  = test_convergence(dts,prob,LinearImplicitEuler())
@test abs(sim.𝒪est[:l2]-1) < 0.2

# using Plots; pyplot(); plot(sim)

B = ones(2)
L = AffineDiffEqOperator{Float64}((A,),(B,),rand(2))
prob = ODEProblem(L,u0,(0.0,1.0))
sol = solve(prob,LinearImplicitEuler())

B = DiffEqArrayOperator(ones(2,2))
L = AffineDiffEqOperator{Float64}((A,B),(),rand(2))
function (p::typeof(L))(::Type{Val{:analytic}},u0,p,t)
    exp((p.As[1].A+p.As[2].A)*t)*u0
end

# Midpoint splitting

prob = ODEProblem(L,u0,(0.0,1.0))
sol = solve(prob,MidpointSplitting(),dt=1/10)
# using Plots; pyplot; plot(sol)


## Midpoint splitting convergence
##
## We use the inhomogeneous Lorentz equation for an electron in a
## time-dependent field. To write this on matrix form and simplify
## comparison with the analytic solution, we introduce two dummy
## variables:
## 1) As the third component, a one is stored to allow the
##    inhomogeneous part to be expressed on matrix form.
## 2) As the fourth component, the initial time t_i is stored,
##    for use by the analytical formula.
## This wastes a lot of space, but simplifies the error analysis.
##
## We can then write the Lorentz equation as q̇ = [A + f(t)B]q.

f = t -> -sin(2pi*t)
F = t -> cos(2pi*t)/2pi # Primitive function of f(t)

A = DiffEqArrayOperator([0 1 0 0
                         0 0 0 0
                         0 0 0 0
                         0 0 0 0])

B = DiffEqArrayOperator([0 0 0 0
                         0 0 1 0
                         0 0 0 0
                         0 0 0 0], f)

H = AffineDiffEqOperator{Float64}((A,B),(),rand(4))
function (p::typeof(H))(::Type{Val{:analytic}},u0,p,t)
    x0,v0 = u0[1:2]
    ti = u0[end]
    x = x0 + (t-ti)*v0 - (f.(t)-f(ti))/(2pi)^2 - (t-ti)*F(ti)
    v = v0 + (F.(t)-F(ti))
    [x, v, 1, ti]
end

x0,v0,ti = rand(3)
prob = ODEProblem(H, [x0, v0, 1, ti], (ti, 5.))
dts = 1./2.^(10:-1:1)
sim  = test_convergence(dts,prob,MidpointSplitting())
@test abs(sim.𝒪est[:l2]-2) < 0.2
