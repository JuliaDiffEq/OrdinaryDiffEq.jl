using OrdinaryDiffEq, Test, DiffEqOperators, Random, LinearAlgebra
@testset "Classical ExpRK" begin
    N = 20
    dt=0.1
    srand(0); u0 = rand(N)
    reltol = 1e-4
    dd = -2 * ones(N); du = ones(N-1)
    L = DiffEqArrayOperator(diagm(-1 => du, 0 => dd, 1 => du))
    krylov_f2 = (u,p,t) -> -0.1*u
    krylov_f2! = (du,u,p,t) -> du .= -0.1*u
    prob = SplitODEProblem(L,krylov_f2,u0,(0.0,1.0))
    prob_inplace = SplitODEProblem(L,krylov_f2!,u0,(0.0,1.0))

    Algs = [LawsonEuler,NorsettEuler,ETDRK2,ETDRK3,ETDRK4,HochOst4]
    for Alg in Algs
        sol = solve(prob, Alg(); dt=dt)
        sol_krylov = solve(prob, Alg(krylov=true, m=10); dt=dt, reltol=reltol)
        @test isapprox(sol.u,sol_krylov.u; rtol=reltol)

        sol_ip = solve(prob_inplace, Alg(); dt=dt)
        sol_ip_krylov = solve(prob_inplace, Alg(krylov=true, m=10); dt=dt, reltol=reltol)
        @test isapprox(sol.u,sol_krylov.u; rtol=reltol)

        println(Alg) # prevent Travis hanging
    end
end

@testset "EPIRK" begin
    N = 20
    srand(0); u0 = normalize(randn(N))
    # For the moment, use dense Jacobian
    dd = -2 * ones(N); du = ones(N-1)
    A = diagm(-1 => du, 0 => dd, 1 => du)
    _f = (u,p,t) -> A*u - u.^3
    _f_ip = (du,u,p,t) -> (mul!(du, A, u); du .-= u.^3)
    _jac = (u,p,t) -> A - 3 * diagm(0 => u.^2)
    _jac_ip = (J,u,p,t) -> begin
        copyto!(J, A)
        @inbounds for i = 1:N
            J[i, i] -= 3 * u[i]^2
        end
    end
    f = ODEFunction(_f; jac=_jac)
    f_ip = ODEFunction(_f_ip; jac=_jac_ip)
    prob = ODEProblem(f, u0, (0.0, 1.0))
    prob_ip = ODEProblem(f_ip, u0, (0.0, 1.0))

    dt = 0.05; tol=1e-5
    Algs = [Exp4, EPIRK4s3A, EPIRK4s3B, EXPRB53s3, EPIRK5P1, EPIRK5P2]
    for Alg in Algs
        sol = solve(prob, Alg(); dt=dt, reltol=tol)
        sol_ref = solve(prob, Tsit5(); reltol=tol)
        @test isapprox(sol(1.0), sol_ref(1.0); rtol=tol)

        sol = solve(prob_ip, Alg(); dt=dt, reltol=tol)
        sol_ref = solve(prob_ip, Tsit5(); reltol=tol)
        @test isapprox(sol(1.0), sol_ref(1.0); rtol=tol)
        println(Alg) # prevent Travis hanging
    end

    sol = solve(prob, EPIRK5s3(); dt=dt, reltol=tol)
    sol_ref = solve(prob, Tsit5(); reltol=tol)
    @test_broken isapprox(sol(1.0), sol_ref(1.0); rtol=tol)

    sol = solve(prob_ip, EPIRK5s3(); dt=dt, reltol=tol)
    sol_ref = solve(prob_ip, Tsit5(); reltol=tol)
    @test_broken isapprox(sol(1.0), sol_ref(1.0); rtol=tol)
    println(EPIRK5s3) # prevent Travis hanging
end
