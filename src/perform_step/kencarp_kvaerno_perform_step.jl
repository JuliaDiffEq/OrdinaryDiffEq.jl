function initialize!(integrator, cache::Kvaerno3ConstantCache)
  integrator.kshortsize = 2
  integrator.k = typeof(integrator.k)(integrator.kshortsize)
  integrator.fsalfirst = integrator.f(integrator.uprev, integrator.p, integrator.t) # Pre-start fsal

  # Avoid undefined entries if k is an array of arrays
  integrator.fsallast = zero(integrator.fsalfirst)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
end

@muladd function perform_step!(integrator, cache::Kvaerno3ConstantCache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack uf,κ,tol = cache
  @unpack γ,a31,a32,a41,a42,a43,btilde1,btilde2,btilde3,btilde4,c3,α31,α32 = cache.tab

  # precalculations
  κtol = κ*tol

  γdt = γ*dt

  # calculate W
  uf.t = t
  if typeof(uprev) <: AbstractArray
    J = ForwardDiff.jacobian(uf,uprev)
    W = I - γdt*J
  else
    J = ForwardDiff.derivative(uf,uprev)
    W = 1 - γdt*J
  end

  # FSAL Step 1
  z₁ = dt*integrator.fsalfirst

  ##### Step 2

  # TODO: Add extrapolation for guess
  z₂ = z₁

  iter = 1
  tstep = t + 2*γdt
  tmp = uprev + γ*z₁
  u = tmp + γ*z₂
  b = dt*f(u, p, tstep) - z₂
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₂ = z₂ + dz

  η = max(cache.ηold,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = integrator.success_iter == 0 || η*ndz > κtol

  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₂
    b = dt*f(u, p, tstep) - z₂
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₂ = z₂ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 3

  # Guess is from Hermite derivative on z₁ and z₂
  z₃ = α31*z₁ + α32*z₂

  iter = 1
  tstep = t + c3*dt
  tmp = uprev + a31*z₁ + a32*z₂
  u = tmp + γ*z₃
  b = dt*f(u, p, tstep) - z₃
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₃ = z₃ + dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₃
    b = dt*f(u, p, tstep) - z₃
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₃ = z₃ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 4

  z₄ = a31*z₁ + a32*z₂ + γ*z₃ # use yhat as prediction

  iter = 1
  tstep = t + dt
  tmp = uprev + a41*z₁ + a42*z₂ + a43*z₃
  u = tmp + γ*z₄
  b = dt*f(u, p, tstep) - z₄
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₄ = z₄ + dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₄
    b = dt*f(u, p, tstep) - z₄
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₄ = z₄ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  u = tmp + γ*z₄

  ################################### Finalize

  cache.ηold = η
  cache.newton_iters = iter

  if integrator.opts.adaptive
    tmp = btilde1*z₁ + btilde2*z₂ + btilde3*z₃ + btilde4*z₄
    if integrator.alg.smooth_est # From Shampine
      est = W\tmp
    else
      est = tmp
    end
    atmp = calculate_residuals(est, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end

  integrator.fsallast = z₄./dt
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  integrator.u = u
end

function initialize!(integrator, cache::Kvaerno3Cache)
  integrator.kshortsize = 2
  integrator.fsalfirst = cache.fsalfirst
  integrator.fsallast = cache.k
  resize!(integrator.k, integrator.kshortsize)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  integrator.f(integrator.fsalfirst, integrator.uprev, integrator.p, integrator.t) # For the interpolation, needs k at the updated point
end

@muladd function perform_step!(integrator, cache::Kvaerno3Cache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack uf,du1,dz,z₁,z₂,z₃,z₄,k,b,J,W,jac_config,tmp,atmp,κ,tol = cache
  @unpack γ,a31,a32,a41,a42,a43,btilde1,btilde2,btilde3,btilde4,c3,α31,α32 = cache.tab

  # precalculations
  κtol = κ*tol

  γdt = γ*dt

  if has_invW(f)
    # skip calculation of inv(W) if step is repeated
    !repeat_step && f(Val{:invW},W,uprev,p,γdt,t) # W == inverse W
  else
    # skip calculation of J if step is repeated
    if repeat_step || (!integrator.last_stepfail && cache.newton_iters == 1 && cache.ηold < integrator.alg.new_jac_conv_bound)
      new_jac = false
    else # Compute a new Jacobian
      new_jac = true
      if has_jac(f)
        f(Val{:jac}, J, uprev, p, t)
      else
        uf.t = t
        jacobian!(J, uf, uprev, du1, integrator, jac_config)
      end
    end
    # skip calculation of W if step is repeated
    if !repeat_step && (integrator.iter < 1 || new_jac || abs(dt - (t-integrator.tprev)) > 100eps(typeof(integrator.t)))
      new_W = true
      mass_matrix = integrator.sol.prob.mass_matrix
      for j in 1:length(u), i in 1:length(u)
          @inbounds W[i,j] = mass_matrix[i,j]-γdt*J[i,j]
      end
    else
      new_W = false
    end
  end

  # FSAL Step 1
  @. z₁ = dt*integrator.fsalfirst

  ##### Step 2

  # TODO: Add extrapolation for guess
  @. z₂ = z₁

  # initial step of Newton iteration
  iter = 1
  tstep = t + 2*γdt
  @. tmp = uprev + γ*z₁
  @. u = tmp + γ*z₂
  f(k, u, p, tstep)
  @. b = dt*k - z₂
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),new_W)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₂ .+= dz

  η = max(cache.ηold,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = integrator.success_iter == 0 || η*ndz > κtol

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₂
    f(k, u, p, tstep)
    @. b = dt*k - z₂
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₂ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 3

  # Guess is from Hermite derivative on z₁ and z₂
  @. z₃ = α31*z₁ + α32*z₂

  # initial step of Newton iteration
  iter = 1
  tstep = t + c3*dt
  @. tmp = uprev + a31*z₁ + a32*z₂
  @. u = tmp + γ*z₃
  f(k, u, p, tstep)
  @. b = dt*k - z₃
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),false)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₃ .+= dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₃
    f(k, u, p, tstep)
    @. b = dt*k - z₃
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₃ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 4

  if typeof(cache) <: Kvaerno3Cache
    @. z₄ = a31*z₁ + a32*z₂ + γ*z₃ # use yhat as prediction
  elseif typeof(cache) <: KenCarp3Cache
    @unpack α41,α42 = cache.tab
    @. z₄ = α41*z₁ + α42*z₂
  end

  iter = 1
  tstep = t + dt
  @. tmp = uprev + a41*z₁ + a42*z₂ + a43*z₃
  @. u = tmp + γ*z₄
  f(k, u, p, tstep)
  @. b = dt*k - z₄
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),false)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₄ .+= dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₄
    f(k, u, p, tstep)
    @. b = dt*k - z₄
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₄ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  @. u = tmp + γ*z₄

  ################################### Finalize

  cache.ηold = η
  cache.newton_iters = iter

  if integrator.opts.adaptive
    @. dz = btilde1*z₁ + btilde2*z₂ + btilde3*z₃ + btilde4*z₄
    if integrator.alg.smooth_est # From Shampine
      if has_invW(f)
        A_mul_B!(vec(tmp),W,vec(dz))
      else
        cache.linsolve(vec(tmp),W,vec(dz),false)
      end
    else
      tmp .= dz
    end
    calculate_residuals!(atmp, tmp, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end

  @. integrator.fsallast = z₄/dt
end

function initialize!(integrator, cache::KenCarp3ConstantCache)
  integrator.kshortsize = 2
  integrator.k = typeof(integrator.k)(integrator.kshortsize)

  integrator.fsalfirst = integrator.f(integrator.uprev, integrator.p, integrator.t) # Pre-start fsal

  # Avoid undefined entries if k is an array of arrays
  integrator.fsallast = zero(integrator.fsalfirst)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
end

@muladd function perform_step!(integrator, cache::KenCarp3ConstantCache, repeat_step=false)
  @unpack t,dt,uprev,u,p = integrator
  @unpack uf,κ,tol = cache
  @unpack γ,a31,a32,a41,a42,a43,btilde1,btilde2,btilde3,btilde4,c3,α31,α32,ea21,ea31,ea32,ea41,ea42,ea43,eb1,eb2,eb3,eb4,ebtilde1,ebtilde2,ebtilde3,ebtilde4 = cache.tab

  if typeof(integrator.f) <: SplitFunction
    f = integrator.f.f1
    f2 = integrator.f.f2
  else
    f = integrator.f
  end

  # precalculations
  κtol = κ*tol

  γdt = γ*dt

  # calculate W
  uf.t = t
  if typeof(uprev) <: AbstractArray
    J = ForwardDiff.jacobian(uf,uprev)
    W = I - γdt*J
  else
    J = ForwardDiff.derivative(uf,uprev)
    W = 1 - γdt*J
  end

  if typeof(integrator.f) <: SplitFunction
    # Explicit tableau is not FSAL
    # Make this not compute on repeat
    z₁ = dt.*f(uprev, p, t)
  else
    # FSAL Step 1
    z₁ = dt*integrator.fsalfirst
  end

  ##### Step 2

  # TODO: Add extrapolation for guess
  z₂ = z₁

  iter = 1
  tstep = t + 2*γdt

  tmp = uprev + γ*z₁

  if typeof(integrator.f) <: SplitFunction
    # This assumes the implicit part is cheaper than the explicit part
    k1 = dt*integrator.fsalfirst - z₁
    tmp += ea21*k1
  end

  u = tmp + γ*z₂
  b = dt*f(u, p, tstep) - z₂
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₂ = z₂ + dz

  η = max(cache.ηold,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = integrator.success_iter == 0 || η*ndz > κtol

  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₂
    b = dt*f(u, p, tstep) - z₂
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₂ = z₂ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 3

  iter = 1
  tstep = t + c3*dt

  if typeof(integrator.f) <: SplitFunction
    z₃ = z₂
    u = tmp + γ*z₂
    k2 = dt*f2(u,p,t + 2γ*dt)
    tmp = uprev + a31*z₁ + a32*z₂ + ea31*k1 + ea32*k2
  else
    # Guess is from Hermite derivative on z₁ and z₂
    z₃ = α31*z₁ + α32*z₂
    tmp = uprev + a31*z₁ + a32*z₂
  end

  u = tmp + γ*z₃
  b = dt*f(u, p, tstep) - z₃
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₃ = z₃ + dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₃
    b = dt*f(u, p, tstep) - z₃
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₃ = z₃ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 4

  iter = 1
  tstep = t + dt

  if typeof(integrator.f) <: SplitFunction
    z₄ = z₂
    u = tmp + γ*z₃
    k3 = dt*f2( u,p,t+c3*dt)
    tmp = uprev + a41*z₁ + a42*z₂ + a43*z₃ + ea41*k1 + ea42*k2 + ea43*k3
  else
    @unpack α41,α42 = cache.tab
    z₄ = α41*z₁ + α42*z₂
    tmp = uprev + a41*z₁ + a42*z₂ + a43*z₃
  end

  u = tmp + γ*z₄
  b = dt*f(u, p, tstep) - z₄
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₄ = z₄ + dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₄
    b = dt*f(u, p, tstep) - z₄
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₄ = z₄ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  u = tmp + γ*z₄
  if typeof(integrator.f) <: SplitFunction
    k4 = dt*f2( u,p,t+dt)
    u = uprev + a41*z₁ + a42*z₂ + a43*z₃ + γ*z₄ + eb1*k1 + eb2*k2 + eb3*k3 + eb4*k4
  end

  ################################### Finalize

  cache.ηold = η
  cache.newton_iters = iter

  if integrator.opts.adaptive
    if typeof(integrator.f) <: SplitFunction
      tmp = btilde1*z₁  + btilde2*z₂  + btilde3*z₃ + btilde4*z₄ + ebtilde1*k1 + ebtilde2*k2 + ebtilde3*k3 + ebtilde4*k4
    else
      tmp = btilde1*z₁ + btilde2*z₂ + btilde3*z₃ + btilde4*z₄
    end
    if integrator.alg.smooth_est # From Shampine
      est = W\tmp
    else
      est = tmp
    end
    atmp = calculate_residuals(est, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end

  if typeof(integrator.f) <: SplitFunction
    integrator.k[1] = integrator.fsalfirst
    integrator.fsallast = integrator.f(u, p, t+dt)
    integrator.k[2] = integrator.fsallast
  else
    integrator.fsallast = z₄./dt
    integrator.k[1] = integrator.fsalfirst
    integrator.k[2] = integrator.fsallast
  end
  integrator.u = u
end

function initialize!(integrator, cache::KenCarp3Cache)
  integrator.kshortsize = 2
  integrator.fsalfirst = cache.fsalfirst
  integrator.fsallast = cache.k
  resize!(integrator.k, integrator.kshortsize)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast

  integrator.f(integrator.fsalfirst, integrator.uprev, integrator.p, integrator.t) # For the interpolation, needs k at the updated point
end

@muladd function perform_step!(integrator, cache::KenCarp3Cache, repeat_step=false)
  @unpack t,dt,uprev,u,p = integrator
  @unpack uf,du1,dz,z₁,z₂,z₃,z₄,k1,k2,k3,k4,k,b,J,W,jac_config,tmp,atmp,κ,tol = cache
  @unpack γ,a31,a32,a41,a42,a43,btilde1,btilde2,btilde3,btilde4,c3,α31,α32 = cache.tab
  @unpack ea21,ea31,ea32,ea41,ea42,ea43,eb1,eb2,eb3,eb4 = cache.tab
  @unpack ebtilde1,ebtilde2,ebtilde3,ebtilde4 = cache.tab

  if typeof(integrator.f) <: SplitFunction
    f = integrator.f.f1
    f2 = integrator.f.f2
  else
    f = integrator.f
  end

  # precalculations
  κtol = κ*tol

  γdt = γ*dt

  if has_invW(f)
    # skip calculation of inv(W) if step is repeated
    !repeat_step && f(Val{:invW},W,uprev,p,γdt,t) # W == inverse W
  else
    # skip calculation of J if step is repeated
    if repeat_step || (!integrator.last_stepfail && cache.newton_iters == 1 && cache.ηold < integrator.alg.new_jac_conv_bound)
      new_jac = false
    else # Compute a new Jacobian
      new_jac = true
      if has_jac(f)
        f(Val{:jac}, J, uprev, p, t)
      else
        uf.t = t
        jacobian!(J, uf, uprev, du1, integrator, jac_config)
      end
    end
    # skip calculation of W if step is repeated
    if !repeat_step && (integrator.iter < 1 || new_jac || abs(dt - (t-integrator.tprev)) > 100eps(typeof(integrator.t)))
      new_W = true
      mass_matrix = integrator.sol.prob.mass_matrix
      for j in 1:length(u), i in 1:length(u)
          @inbounds W[i,j] = mass_matrix[i,j]-γdt*J[i,j]
      end
    else
      new_W = false
    end
  end

  if typeof(integrator.f) <: SplitFunction
    # Explicit tableau is not FSAL
    # Make this not compute on repeat
    if !repeat_step && !integrator.last_stepfail
      f(z₁, integrator.uprev, p, integrator.t)
      z₁ .*= dt
    end
  else
    # FSAL Step 1
    @. z₁ = dt*integrator.fsalfirst
  end

  ##### Step 2

  # TODO: Add extrapolation for guess
  @. z₂ = z₁

  # initial step of Newton iteration
  iter = 1
  tstep = t + 2*γdt

  @. tmp = uprev + γ*z₁

  if typeof(integrator.f) <: SplitFunction
    # This assumes the implicit part is cheaper than the explicit part
    @. k1 = dt*integrator.fsalfirst - z₁
    @. tmp += ea21*k1
  end

  @. u = tmp + γ*z₂
  f(k, u, p, tstep)
  @. b = dt*k - z₂
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),new_W)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₂ .+= dz

  η = max(cache.ηold,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = integrator.success_iter == 0 || η*ndz > κtol

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₂
    f(k, u, p, tstep)
    @. b = dt*k - z₂
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₂ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 3

  # initial step of Newton iteration
  iter = 1
  tstep = t + c3*dt

  if typeof(integrator.f) <: SplitFunction
    z₃ .= z₂
    @. u = tmp + γ*z₂
    f2(k2, u, p, t + 2γ*dt); k2 .*= dt
    #@. tmp = uprev + a31*z₁ + a32*z₂ + ea31*k1 + ea32*k2
    for i in eachindex(tmp)
      @inbounds tmp[i] = uprev[i] + a31*z₁[i] + a32*z₂[i] + ea31*k1[i] + ea32*k2[i]
    end
  else
    # Guess is from Hermite derivative on z₁ and z₂
    @. z₃ = α31*z₁ + α32*z₂
    @. tmp = uprev + a31*z₁ + a32*z₂
  end

  @. u = tmp + γ*z₃
  f(k, u, p, tstep)
  @. b = dt*k - z₃
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),false)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₃ .+= dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₃
    f(k, u, p, tstep)
    @. b = dt*k - z₃
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₃ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 4

  iter = 1
  tstep = t + dt

  if typeof(integrator.f) <: SplitFunction
    z₄ .= z₂
    @. u = tmp + γ*z₃
    f2( k3, u,p,t+c3*dt); k3 .*= dt
    #@. tmp = uprev + a41*z₁ + a42*z₂ + a43*z₃ + ea41*k1 + ea42*k2 + ea43*k3
    for i in eachindex(tmp)
      @inbounds tmp[i] = uprev[i] + a41*z₁[i] + a42*z₂[i] + a43*z₃[i] + ea41*k1[i] + ea42*k2[i] + ea43*k3[i]
    end
  else
    @unpack α41,α42 = cache.tab
    @. z₄ = α41*z₁ + α42*z₂
    @. tmp = uprev + a41*z₁ + a42*z₂ + a43*z₃
  end

  @. u = tmp + γ*z₄
  f(k, u, p, tstep)
  @. b = dt*k - z₄
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),false)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₄ .+= dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₄
    f(k, u, p, tstep)
    @. b = dt*k - z₄
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₄ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  @. u = tmp + γ*z₄
  if typeof(integrator.f) <: SplitFunction
    f2( k4, u,p,t+dt); k4 .*= dt
    #@. u = uprev + a41*z₁ + a42*z₂ + a43*z₃ + γ*z₄ + eb1*k1 + eb2*k2 + eb3*k3 + eb4*k4
    for i in eachindex(u)
      u[i] = uprev[i] + a41*z₁[i] + a42*z₂[i] + a43*z₃[i] + γ*z₄[i] + eb1*k1[i] + eb2*k2[i] + eb3*k3[i] + eb4*k4[i]
    end
  end

  ################################### Finalize

  cache.ηold = η
  cache.newton_iters = iter

  if integrator.opts.adaptive
    if typeof(integrator.f) <: SplitFunction
      #@. dz = btilde1*z₁  + btilde2*z₂  + btilde3*z₃ + btilde4*z₄ + ebtilde1*k1 + ebtilde2*k2 + ebtilde3*k3 + ebtilde4*k4
      for i in eachindex(dz)
        @inbounds dz[i] = btilde1*z₁[i]  + btilde2*z₂[i]  + btilde3*z₃[i] + btilde4*z₄[i] + ebtilde1*k1[i] + ebtilde2*k2[i] + ebtilde3*k3[i] + ebtilde4*k4[i]
      end
    else
      @. dz = btilde1*z₁ + btilde2*z₂ + btilde3*z₃ + btilde4*z₄
    end
    if integrator.alg.smooth_est # From Shampine
      if has_invW(f)
        A_mul_B!(vec(tmp),W,vec(dz))
      else
        cache.linsolve(vec(tmp),W,vec(dz),false)
      end
    else
      tmp .= dz
    end
    calculate_residuals!(atmp, tmp, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end

  if typeof(integrator.f) <: SplitFunction
    integrator.f(integrator.fsallast,u,p,t+dt)
  else
    @. integrator.fsallast = z₄/dt
  end
end

function initialize!(integrator, cache::Kvaerno4ConstantCache)
  integrator.kshortsize = 2
  integrator.k = typeof(integrator.k)(integrator.kshortsize)
  integrator.fsalfirst = integrator.f(integrator.uprev,integrator.p,integrator.t) # Pre-start fsal

  # Avoid undefined entries if k is an array of arrays
  integrator.fsallast = zero(integrator.fsalfirst)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
end


@muladd function perform_step!(integrator, cache::Kvaerno4ConstantCache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack uf,κ,tol = cache
  @unpack γ,a31,a32,a41,a42,a43,a51,a52,a53,a54,c3,c4 = cache.tab
  @unpack α21,α31,α32,α41,α42 = cache.tab
  @unpack btilde1,btilde2,btilde3,btilde4,btilde5 = cache.tab

  # precalculations
  κtol = κ*tol

  γdt = γ*dt

  # calculate W
  uf.t = t
  if typeof(uprev) <: AbstractArray
    J = ForwardDiff.jacobian(uf,uprev)
    W = I - γdt*J
  else
    J = ForwardDiff.derivative(uf,uprev)
    W = 1 - γdt*J
  end

  ##### Step 1

  z₁ = dt*integrator.fsalfirst

  ##### Step 2

  # TODO: Add extrapolation choice
  z₂ = zero(u)

  # initial step of Newton iteration
  iter = 1
  tstep = t + 2*γdt
  tmp = uprev + γ*z₁
  u = tmp + γ*z₂
  b = dt*f(u, p, tstep) - z₂
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₂ = z₂ + dz

  η = max(cache.ηold,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = integrator.success_iter == 0 || η*ndz > κtol

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₂
    b = dt*f(u, p, tstep) - z₂
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₂ = z₂ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 3

  z₃ = α31*z₁ + α32*z₂

  # initial step of Newton iteration
  iter = 1
  tstep = t + c3*dt
  tmp = uprev + a31*z₁ + a32*z₂
  u = tmp + γ*z₃
  b = dt*f(u, p, tstep) - z₃
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₃ = z₃ + dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₃
    b = dt*f(u, p, tstep) - z₃
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₃ = z₃ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 4

  z₄ = α41*z₁ + α42*z₂

  # initial step of Newton iteration
  iter = 1
  tstep = t + c4*dt
  tmp = uprev + a41*z₁ + a42*z₂ + a43*z₃
  u = tmp + γ*z₄
  b = dt*f(u, p, tstep) - z₄
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₄ = z₄ + dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₄
    b = dt*f(u, p, tstep) - z₄
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₄ = z₄ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 5

  # Use yhat2 for prediction
  z₅ = a41*z₁ + a42*z₂ + a43*z₃ + γ*z₄

  # initial step of Newton iteration
  iter = 1
  tstep = t + dt
  tmp = uprev + a51*z₁ + a52*z₂ + a53*z₃ + a54*z₄
  u = tmp + γ*z₅
  b = dt*f(u, p, tstep) - z₅
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₅ = z₅ + dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₅
    b = dt*f(u, p, tstep) - z₅
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₅ = z₅ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  u = tmp + γ*z₅

  ################################### Finalize

  cache.ηold = η
  cache.newton_iters = iter

  if integrator.opts.adaptive
    tmp = btilde1*z₁ + btilde2*z₂ + btilde3*z₃ + btilde4*z₄ + btilde5*z₅
    if integrator.alg.smooth_est # From Shampine
      est = W\tmp
    else
      est = tmp
    end
    atmp = calculate_residuals(est, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end

  integrator.fsallast = z₅./dt
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  integrator.u = u
end

function initialize!(integrator, cache::Kvaerno4Cache)
  integrator.kshortsize = 2
  integrator.fsalfirst = cache.fsalfirst
  integrator.fsallast = cache.k
  resize!(integrator.k, integrator.kshortsize)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  integrator.f(integrator.fsalfirst, integrator.uprev, integrator.p, integrator.t) # For the interpolation, needs k at the updated point
end

@muladd function perform_step!(integrator, cache::Kvaerno4Cache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack uf,du1,dz,z₁,z₂,z₃,z₄,z₅,k,b,J,W,jac_config,tmp,atmp,κ,tol = cache
  @unpack γ,a31,a32,a41,a42,a43,a51,a52,a53,a54,c3,c4 = cache.tab
  @unpack α21,α31,α32,α41,α42 = cache.tab
  @unpack btilde1,btilde2,btilde3,btilde4,btilde5 = cache.tab

  # precalculations
  κtol = κ*tol

  γdt = γ*dt

  # calculate W
  if has_invW(f)
    # skip calculation of inv(W) if step is repeated
    !repeat_step && f(Val{:invW},W,uprev,p,γdt,t) # W == inverse W
  else
    # skip calculation of J if step is repeated
    if repeat_step || (!integrator.last_stepfail && cache.newton_iters == 1 && cache.ηold < integrator.alg.new_jac_conv_bound)
      new_jac = false
    else # Compute a new Jacobian
      new_jac = true
      if has_jac(f)
        f(Val{:jac}, J, uprev, p, t)
      else
        uf.t = t
        jacobian!(J, uf, uprev, du1, integrator, jac_config)
      end
    end
    # skip calculation of W if step is repeated
    if !repeat_step && (integrator.iter < 1 || new_jac || abs(dt - (t-integrator.tprev)) > 100eps(typeof(integrator.t)))
      new_W = true
      mass_matrix = integrator.sol.prob.mass_matrix
      for j in 1:length(u), i in 1:length(u)
          @inbounds W[i,j] = mass_matrix[i,j]-γdt*J[i,j]
      end
    else
      new_W = false
    end
  end

  ##### Step 1

  @. z₁ = dt*integrator.fsalfirst

  ##### Step 2

  # TODO: Allow other choices here
  z₂ .= zero.(u)

  # initial step of Newton iteration
  iter = 1
  tstep = t + 2*γdt
  @. tmp = uprev + γ*z₁
  @. u = tmp + γ*z₂
  f(k, u, p, tstep)
  @. b = dt*k - z₂
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),new_W)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₂ .+= dz

  η = max(cache.ηold,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = integrator.success_iter == 0 || η*ndz > κtol

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₂
    f(k, u, p, tstep)
    @. b = dt*k - z₂
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₂ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 3

  @. z₃ = α31*z₁ + α32*z₂

  # initial step of Newton iteration
  iter = 1
  tstep = t + c3*dt
  @. tmp = uprev + a31*z₁ + a32*z₂
  @. u = tmp + γ*z₃
  f(k, u, p, tstep)
  @. b = dt*k - z₃
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),false)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₃ .+= dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₃
    f(k, u, p, tstep)
    @. b = dt*k - z₃
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₃ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 4

  # Use constant z prediction
  @. z₄ = α41*z₁ + α42*z₂

  # initial step of Newton iteration
  iter = 1
  tstep = t + c4*dt
  @. tmp = uprev + a41*z₁ + a42*z₂ + a43*z₃
  @. u = tmp + γ*z₄
  f(k, u, p, tstep)
  @. b = dt*k - z₄
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),false)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₄ .+= dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₄
    f(k, u, p, tstep)
    @. b = dt*k - z₄
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₄ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 5

  # Use yhat prediction
  @. z₅ = a41*z₁ + a42*z₂ + a43*z₃ + γ*z₄

  # initial step of Newton iteration
  iter = 1
  tstep = t + dt
  @. tmp = uprev + a51*z₁ + a52*z₂ + a53*z₃ + a54*z₄
  @. u = tmp + γ*z₅
  f(k, u, p, tstep)
  @. b = dt*k - z₅
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),false)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₅ .+= dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₅
    f(k, u, p, tstep)
    @. b = dt*k - z₅
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₅ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  @. u = tmp + γ*z₅

  ################################### Finalize

  cache.ηold = η
  cache.newton_iters = iter

  if integrator.opts.adaptive
    @. dz = btilde1*z₁ + btilde2*z₂ + btilde3*z₃ + btilde4*z₄ + btilde5*z₅
    if integrator.alg.smooth_est # From Shampine
      if has_invW(f)
        A_mul_B!(vec(tmp),W,vec(dz))
      else
        cache.linsolve(vec(tmp),W,vec(dz),false)
      end
    else
      tmp .= dz
    end
    calculate_residuals!(atmp, tmp, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end

  @. integrator.fsallast = z₅/dt
end

function initialize!(integrator, cache::KenCarp4ConstantCache)
  integrator.kshortsize = 2
  integrator.k = typeof(integrator.k)(integrator.kshortsize)

  integrator.fsalfirst = integrator.f(integrator.uprev, integrator.p, integrator.t) # Pre-start fsal

  # Avoid undefined entries if k is an array of arrays
  integrator.fsallast = zero(integrator.fsalfirst)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
end

@muladd function perform_step!(integrator, cache::KenCarp4ConstantCache, repeat_step=false)
  @unpack t,dt,uprev,u,p = integrator
  @unpack uf,κ,tol = cache
  @unpack γ,a31,a32,a41,a42,a43,a51,a52,a53,a54,a61,a63,a64,a65,c3,c4,c5 = cache.tab
  @unpack α31,α32,α41,α42,α51,α52,α53,α54,α61,α62,α63,α64,α65 = cache.tab
  @unpack btilde1,btilde3,btilde4,btilde5,btilde6 = cache.tab
  @unpack ea21,ea31,ea32,ea41,ea42,ea43,ea51,ea52,ea53,ea54,ea61,ea62,ea63,ea64,ea65 = cache.tab
  @unpack eb1,eb3,eb4,eb5,eb6 = cache.tab
  @unpack ebtilde1,ebtilde3,ebtilde4,ebtilde5,ebtilde6 = cache.tab

  if typeof(integrator.f) <: SplitFunction
    f = integrator.f.f1
    f2 = integrator.f.f2
  else
    f = integrator.f
  end

  # precalculations
  κtol = κ*tol

  γdt = γ*dt

  # calculate W
  uf.t = t
  if typeof(uprev) <: AbstractArray
    J = ForwardDiff.jacobian(uf,uprev)
    W = I - γdt*J
  else
    J = ForwardDiff.derivative(uf,uprev)
    W = 1 - γdt*J
  end

  if typeof(integrator.f) <: SplitFunction
    # Explicit tableau is not FSAL
    # Make this not compute on repeat
    z₁ = dt.*f(uprev, p, t)
  else
    # FSAL Step 1
    z₁ = dt*integrator.fsalfirst
  end

  ##### Step 2

  # TODO: Add extrapolation choice
  z₂ = zero(u)

  # initial step of Newton iteration
  iter = 1
  tstep = t + 2*γdt
  tmp = uprev + γ*z₁

  if typeof(integrator.f) <: SplitFunction
    # This assumes the implicit part is cheaper than the explicit part
    k1 = dt*integrator.fsalfirst - z₁
    tmp += ea21*k1
  end

  u = tmp + γ*z₂
  b = dt*f(u, p, tstep) - z₂
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₂ = z₂ + dz

  η = max(cache.ηold,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = integrator.success_iter == 0 || η*ndz > κtol

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₂
    b = dt*f(u, p, tstep) - z₂
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₂ = z₂ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 3

  # initial step of Newton iteration
  iter = 1
  tstep = t + c3*dt

  if typeof(integrator.f) <: SplitFunction
    z₃ = z₂
    u = tmp + γ*z₂
    k2 = dt*f2(u,p,t+2γ*dt)
    tmp = uprev + a31*z₁ + a32*z₂ + ea31*k1 + ea32*k2
  else
    # Guess is from Hermite derivative on z₁ and z₂
    z₃ = α31*z₁ + α32*z₂
    tmp = uprev + a31*z₁ + a32*z₂
  end

  u = tmp + γ*z₃
  b = dt*f(u, p, tstep) - z₃
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₃ = z₃ + dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₃
    b = dt*f(u, p, tstep) - z₃
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₃ = z₃ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 4

  # initial step of Newton iteration
  iter = 1
  tstep = t + c4*dt

  if typeof(integrator.f) <: SplitFunction
    z₄ = z₂
    u = tmp + γ*z₃
    k3 = dt*f2( u,p,t+c3*dt)
    tmp = uprev + a41*z₁ + a42*z₂ + a43*z₃ + ea41*k1 + ea42*k2 + ea43*k3
  else
    z₄ = α41*z₁ + α42*z₂
    tmp = uprev + a41*z₁ + a42*z₂ + a43*z₃
  end

  u = tmp + γ*z₄
  b = dt*f(u, p, tstep) - z₄
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₄ = z₄ + dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₄
    b = dt*f(u, p, tstep) - z₄
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₄ = z₄ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 5

  # initial step of Newton iteration
  iter = 1
  tstep = t + c5*dt

  if typeof(integrator.f) <: SplitFunction
    z₅ = z₄
    u = tmp + γ*z₄
    k4 = dt*f2( u,p,t+c4*dt)
    tmp = uprev + a51*z₁ + a52*z₂ + a53*z₃ + a54*z₄ + ea51*k1 + ea52*k2 + ea53*k3 + ea54*k4
  else
    z₅ = α51*z₁ + α52*z₂ + α53*z₃ + α54*z₄
    tmp = uprev + a51*z₁ + a52*z₂ + a53*z₃ + a54*z₄
  end

  u = tmp + γ*z₅
  b = dt*f(u, p, tstep) - z₅
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₅ = z₅ + dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₅
    b = dt*f(u, p, tstep) - z₅
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₅ = z₅ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 5

  # initial step of Newton iteration
  iter = 1
  tstep = t + dt

  if typeof(integrator.f) <: SplitFunction
    z₆ = z₅
    u = tmp + γ*z₅
    k5 = dt*f2( u,p,t+c5*dt)
    tmp = uprev + a61*z₁ + a63*z₃ + a64*z₄ + a65*z₅ + ea61*k1 + ea62*k2 + ea63*k3 + ea64*k4 + ea65*k5
  else
    z₆ = α61*z₁ + α62*z₂ + α63*z₃ + α64*z₄ + α65*z₅
    tmp = uprev + a61*z₁ + a63*z₃ + a64*z₄ + a65*z₅
  end

  u = tmp + γ*z₆
  b = dt*f(u, p, tstep) - z₆
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₆ = z₆ + dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₆
    b = dt*f(u, p, tstep) - z₆
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₆ = z₆ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  u = tmp + γ*z₆
  if typeof(integrator.f) <: SplitFunction
    k6 = dt*f2( u,p,t+dt)
    u = uprev + a61*z₁ + a63*z₃ + a64*z₄ + a65*z₅ + γ*z₆ + eb1*k1 + eb3*k3 + eb4*k4 + eb5*k5 + eb6*k6
  end

  ################################### Finalize

  cache.ηold = η
  cache.newton_iters = iter

  if integrator.opts.adaptive
    if typeof(integrator.f) <: SplitFunction
      tmp = btilde1*z₁ + btilde3*z₃ + btilde4*z₄ + btilde5*z₅ + btilde6*z₆ + ebtilde1*k1 + ebtilde3*k3 + ebtilde4*k4 + ebtilde5*k5 + ebtilde6*k6
    else
      tmp = btilde1*z₁ + btilde3*z₃ + btilde4*z₄ + btilde5*z₅ + btilde6*z₆
    end
    if integrator.alg.smooth_est # From Shampine
      est = W\tmp
    else
      est = tmp
    end
    atmp = calculate_residuals(est, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end

  if typeof(integrator.f) <: SplitFunction
    integrator.k[1] = integrator.fsalfirst
    integrator.fsallast = integrator.f(u, p, t+dt)
    integrator.k[2] = integrator.fsallast
  else
    integrator.fsallast = z₆./dt
    integrator.k[1] = integrator.fsalfirst
    integrator.k[2] = integrator.fsallast
  end
  integrator.u = u
end

function initialize!(integrator, cache::KenCarp4Cache)
  integrator.kshortsize = 2
  integrator.fsalfirst = cache.fsalfirst
  integrator.fsallast = cache.k
  resize!(integrator.k, integrator.kshortsize)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  integrator.f(integrator.fsalfirst, integrator.uprev, integrator.p, integrator.t) # For the interpolation, needs k at the updated point
end

@muladd function perform_step!(integrator, cache::KenCarp4Cache, repeat_step=false)
  @unpack t,dt,uprev,u,p = integrator
  @unpack uf,du1,dz,z₁,z₂,z₃,z₄,z₅,z₆,k,b,J,W,jac_config,tmp,atmp,κ,tol = cache
  @unpack k1,k2,k3,k4,k5,k6 = cache
  @unpack γ,a31,a32,a41,a42,a43,a51,a52,a53,a54,a61,a63,a64,a65,c3,c4,c5 = cache.tab
  @unpack α31,α32,α41,α42,α51,α52,α53,α54,α61,α62,α63,α64,α65 = cache.tab
  @unpack btilde1,btilde3,btilde4,btilde5,btilde6 = cache.tab
  @unpack ea21,ea31,ea32,ea41,ea42,ea43,ea51,ea52,ea53,ea54,ea61,ea62,ea63,ea64,ea65 = cache.tab
  @unpack eb1,eb3,eb4,eb5,eb6 = cache.tab
  @unpack ebtilde1,ebtilde3,ebtilde4,ebtilde5,ebtilde6 = cache.tab

  if typeof(integrator.f) <: SplitFunction
    f = integrator.f.f1
    f2 = integrator.f.f2
  else
    f = integrator.f
  end

  # precalculations
  κtol = κ*tol

  γdt = γ*dt

  # calculate W
  if has_invW(f)
    # skip calculation of inv(W) if step is repeated
    !repeat_step && f(Val{:invW},W,uprev,p,γdt,t) # W == inverse W
  else
    # skip calculation of J if step is repeated
    if repeat_step || (!integrator.last_stepfail && cache.newton_iters == 1 && cache.ηold < integrator.alg.new_jac_conv_bound)
      new_jac = false
    else # Compute a new Jacobian
      new_jac = true
      if has_jac(f)
        f(Val{:jac}, J, uprev, p, t)
      else
        uf.t = t
        jacobian!(J, uf, uprev, du1, integrator, jac_config)
      end
    end
    # skip calculation of W if step is repeated
    if !repeat_step && (integrator.iter < 1 || new_jac || abs(dt - (t-integrator.tprev)) > 100eps(typeof(integrator.t)))
      new_W = true
      mass_matrix = integrator.sol.prob.mass_matrix
      for j in 1:length(u), i in 1:length(u)
          @inbounds W[i,j] = mass_matrix[i,j]-γdt*J[i,j]
      end
    else
      new_W = false
    end
  end

  ##### Step 1

  if typeof(integrator.f) <: SplitFunction
    # Explicit tableau is not FSAL
    # Make this not compute on repeat
    if !repeat_step && !integrator.last_stepfail
      f(z₁, integrator.uprev, p, integrator.t)
      z₁ .*= dt
    end
  else
    # FSAL Step 1
    @. z₁ = dt*integrator.fsalfirst
  end

  ##### Step 2

  # TODO: Allow other choices here
  z₂ .= zero.(u)

  # initial step of Newton iteration
  iter = 1
  tstep = t + 2*γdt

  @. tmp = uprev + γ*z₁

  if typeof(integrator.f) <: SplitFunction
    # This assumes the implicit part is cheaper than the explicit part
    @. k1 = dt*integrator.fsalfirst - z₁
    @. tmp += ea21*k1
  end

  @. u = tmp + γ*z₂
  f(k, u, p, tstep)
  @. b = dt*k - z₂
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),new_W)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₂ .+= dz

  η = max(cache.ηold,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = integrator.success_iter == 0 || η*ndz > κtol

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₂
    f(k, u, p, tstep)
    @. b = dt*k - z₂
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₂ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 3

  # initial step of Newton iteration
  iter = 1
  tstep = t + c3*dt

  if typeof(integrator.f) <: SplitFunction
    z₃ .= z₂
    @. u = tmp + γ*z₂
    f2(k2, u, p, t + 2γ*dt); k2 .*= dt
    # @. tmp = uprev + a31*z₁ + a32*z₂ + ea31*k1 + ea32*k2
    for i in eachindex(tmp)
      @inbounds tmp[i] = uprev[i] + a31*z₁[i] + a32*z₂[i] + ea31*k1[i] + ea32*k2[i]
    end
  else
    # Guess is from Hermite derivative on z₁ and z₂
    @. z₃ = α31*z₁ + α32*z₂
    @. tmp = uprev + a31*z₁ + a32*z₂
  end

  @. u = tmp + γ*z₃
  f(k, u, p, tstep)
  @. b = dt*k - z₃
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),false)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₃ .+= dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₃
    f(k, u, p, tstep)
    @. b = dt*k - z₃
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₃ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 4

  # initial step of Newton iteration
  iter = 1
  tstep = t + c4*dt

  if typeof(integrator.f) <: SplitFunction
    z₄ .= z₂
    @. u = tmp + γ*z₃
    f2( k3, u,p,t+c3*dt); k3 .*= dt
    #@. tmp = uprev + a41*z₁ + a42*z₂ + a43*z₃ + ea41*k1 + ea42*k2 + ea43*k3
    for i in eachindex(tmp)
      @inbounds tmp[i] = uprev[i] + a41*z₁[i] + a42*z₂[i] + a43*z₃[i] + ea41*k1[i] + ea42*k2[i] + ea43*k3[i]
    end
  else
    @. z₄ = α41*z₁ + α42*z₂
    @. tmp = uprev + a41*z₁ + a42*z₂ + a43*z₃
  end

  @. u = tmp + γ*z₄
  f(k, u, p, tstep)
  @. b = dt*k - z₄
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),false)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₄ .+= dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₄
    f(k, u, p, tstep)
    @. b = dt*k - z₄
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₄ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 5

  # initial step of Newton iteration
  iter = 1
  tstep = t + c5*dt

  if typeof(integrator.f) <: SplitFunction
    z₅ .= z₄
    @. u = tmp + γ*z₄
    f2( k4, u,p,t+c4*dt); k4 .*= dt
    #@. tmp = uprev + a51*z₁ + a52*z₂ + a53*z₃ + a54*z₄ + ea51*k1 + ea52*k2 + ea53*k3 + ea54*k4
    for i in eachindex(tmp)
      @inbounds tmp[i] = uprev[i] + a51*z₁[i] + a52*z₂[i] + a53*z₃[i] + a54*z₄[i] + ea51*k1[i] + ea52*k2[i] + ea53*k3[i] + ea54*k4[i]
    end
  else
    @. z₅ = α51*z₁ + α52*z₂ + α53*z₃ + α54*z₄
    #@. tmp = uprev + a51*z₁ + a52*z₂ + a53*z₃ + a54*z₄
    for i in eachindex(tmp)
      @inbounds tmp[i] = uprev[i] + a51*z₁[i] + a52*z₂[i] + a53*z₃[i] + a54*z₄[i]
    end
  end

  @. u = tmp + γ*z₅
  f(k, u, p, tstep)
  @. b = dt*k - z₅
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),false)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₅ .+= dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₅
    f(k, u, p, tstep)
    @. b = dt*k - z₅
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₅ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 6

  # initial step of Newton iteration
  iter = 1
  tstep = t + dt

  if typeof(integrator.f) <: SplitFunction
    z₆ .= z₅
    @. u = tmp + γ*z₅
    f2( k5, u,p,t+c5*dt); k5 .*= dt
    #@. tmp = uprev + a61*z₁ + a63*z₃ + a64*z₄ + a65*z₅ + ea61*k1 + ea62*k2 + ea63*k3 + ea64*k4 + ea65*k5
    for i in eachindex(tmp)
      @inbounds tmp[i] = uprev[i] + a61*z₁[i] + a63*z₃[i] + a64*z₄[i] + a65*z₅[i] + ea61*k1[i] + ea62*k2[i] + ea63*k3[i] + ea64*k4[i] + ea65*k5[i]
    end
  else
    #@. z₆ = α61*z₁ + α62*z₂ + α63*z₃ + α64*z₄ + α65*z₅
    #@. tmp = uprev + a61*z₁ + a63*z₃ + a64*z₄ + a65*z₅
    @tight_loop_macros for i in eachindex(u)
      @inbounds z₆[i] = α61*z₁[i] + α62*z₂[i] + α63*z₃[i] + α64*z₄[i] + α65*z₅[i]
      @inbounds tmp[i] = uprev[i] + a61*z₁[i] + a63*z₃[i] + a64*z₄[i] + a65*z₅[i]
    end
  end

  @. u = tmp + γ*z₆
  f(k, u, p, tstep)
  @. b = dt*k - z₆
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),false)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₆ .+= dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₆
    f(k, u, p, tstep)
    @. b = dt*k - z₆
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₆ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  @. u = tmp + γ*z₆
  if typeof(integrator.f) <: SplitFunction
    f2( k6, u,p,t+dt); k6 .*= dt
    @. u = uprev + a61*z₁ + a63*z₃ + a64*z₄ + a65*z₅ + γ*z₆ + eb1*k1 + eb3*k3 + eb4*k4 + eb5*k5 + eb6*k6
    for i in eachindex(u)
      u[i] = uprev[i] + a61*z₁[i] + a63*z₃[i] + a64*z₄[i] + a65*z₅[i] + γ*z₆[i] + eb1*k1[i] + eb3*k3[i] + eb4*k4[i] + eb5*k5[i] + eb6*k6[i]
    end
  end

  ################################### Finalize

  cache.ηold = η
  cache.newton_iters = iter

  if integrator.opts.adaptive
    if typeof(integrator.f) <: SplitFunction
      #@. dz = btilde1*z₁ + btilde3*z₃ + btilde4*z₄ + btilde5*z₅ + btilde6*z₆ + ebtilde1*k1 + ebtilde3*k3 + ebtilde4*k4 + ebtilde5*k5 + ebtilde6*k6
      for i in eachindex(u)
        @inbounds dz[i] = btilde1*z₁[i] + btilde3*z₃[i] + btilde4*z₄[i] + btilde5*z₅[i] + btilde6*z₆[i] + ebtilde1*k1[i] + ebtilde3*k3[i] + ebtilde4*k4[i] + ebtilde5*k5[i] + ebtilde6*k6[i]
      end
    else
      # @. dz = btilde1*z₁ + btilde3*z₃ + btilde4*z₄ + btilde5*z₅ + btilde6*z₆
      @tight_loop_macros for i in eachindex(u)
        @inbounds dz[i] = btilde1*z₁[i] + btilde3*z₃[i] + btilde4*z₄[i] + btilde5*z₅[i] + btilde6*z₆[i]
      end
    end

    if integrator.alg.smooth_est # From Shampine
      if has_invW(f)
        A_mul_B!(vec(tmp),W,vec(dz))
      else
        cache.linsolve(vec(tmp),W,vec(dz),false)
      end
    else
      tmp .= dz
    end
    calculate_residuals!(atmp, tmp, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end

  if typeof(integrator.f) <: SplitFunction
    integrator.f(integrator.fsallast,u,p,t+dt)
  else
    @. integrator.fsallast = z₆/dt
  end
end

function initialize!(integrator, cache::Kvaerno5ConstantCache)
  integrator.kshortsize = 2
  integrator.k = typeof(integrator.k)(integrator.kshortsize)
  integrator.fsalfirst = integrator.f(integrator.uprev, integrator.p, integrator.t) # Pre-start fsal

  # Avoid undefined entries if k is an array of arrays
  integrator.fsallast = zero(integrator.fsalfirst)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
end

@muladd function perform_step!(integrator, cache::Kvaerno5ConstantCache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack uf,κ,tol = cache
  @unpack γ,a31,a32,a41,a42,a43,a51,a52,a53,a54,a61,a63,a64,a65,a71,a73,a74,a75,a76,c3,c4,c5,c6 = cache.tab
  @unpack btilde1,btilde3,btilde4,btilde5,btilde6,btilde7 = cache.tab
  @unpack α31,α32,α41,α42,α43,α51,α52,α53,α61,α62,α63 = cache.tab

  # precalculations
  κtol = κ*tol

  γdt = γ*dt

  # calculate W
  uf.t = t
  if typeof(uprev) <: AbstractArray
    J = ForwardDiff.jacobian(uf,uprev)
    W = I - γdt*J
  else
    J = ForwardDiff.derivative(uf,uprev)
    W = 1 - γdt*J
  end

  ##### Step 1

  z₁ = dt*integrator.fsalfirst

  ##### Step 2

  # TODO: Add extrapolation choice
  z₂ = zero(u)

  # initial step of Newton iteration
  iter = 1
  tstep = t + 2*γdt
  tmp = uprev + γ*z₁
  u = tmp + γ*z₂
  b = dt*f(u, p, tstep) - z₂
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₂ = z₂ + dz

  η = max(cache.ηold,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = integrator.success_iter == 0 || η*ndz > κtol

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₂
    b = dt*f(u, p, tstep) - z₂
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₂ = z₂ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 3

  z₃ = α31*z₁ + α32*z₂

  # initial step of Newton iteration
  iter = 1
  tstep = t + c3*dt
  tmp = uprev + a31*z₁ + a32*z₂
  u = tmp + γ*z₃
  b = dt*f(u, p, tstep) - z₃
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₃ = z₃ + dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₃
    b = dt*f(u, p, tstep) - z₃
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₃ = z₃ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 4

  z₄ = α41*z₁ + α42*z₂ + α43*z₃

  # initial step of Newton iteration
  iter = 1
  tstep = t + c4*dt
  tmp = uprev + a41*z₁ + a42*z₂ + a43*z₃
  u = tmp + γ*z₄
  b = dt*f(u, p, tstep) - z₄
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₄ = z₄ + dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₄
    b = dt*f(u, p, tstep) - z₄
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
      if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₄ = z₄ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 5

  z₅ = α51*z₁ + α52*z₂ + α53*z₃

  # initial step of Newton iteration
  iter = 1
  tstep = t + c5*dt
  tmp = uprev + a51*z₁ + a52*z₂ + a53*z₃ + a54*z₄
  u = tmp + γ*z₅
  b = dt*f(u, p, tstep) - z₅
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₅ = z₅ + dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₅
    b = dt*f(u, p, tstep) - z₅
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₅ = z₅ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 6

  z₆ = α61*z₁ + α62*z₂ + α63*z₃

  # initial step of Newton iteration
  iter = 1
  tstep = t + c6*dt
  tmp = uprev + a61*z₁ + a63*z₃ + a64*z₄ + a65*z₅
  u = tmp + γ*z₆
  b = dt*f(u, p, tstep) - z₆
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₆ = z₆ + dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₆
    b = dt*f(u, p, tstep) - z₆
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₆ = z₆ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 7

  # Prediction from embedding
  z₇ = a61*z₁ + a63*z₃ + a64*z₄ + a65*z₅ + γ*z₆

  # initial step of Newton iteration
  iter = 1
  tstep = t + dt
  tmp = uprev + a71*z₁ + a73*z₃ + a74*z₄ + a75*z₅ + a76*z₆
  u = tmp + γ*z₇
  b = dt*f(u, p, tstep) - z₇
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₇ = z₇ + dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₇
    b = dt*f(u, p, tstep) - z₇
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₇ = z₇ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  u = tmp + γ*z₇

  ################################### Finalize

  cache.ηold = η
  cache.newton_iters = iter

  if integrator.opts.adaptive
    tmp = btilde1*z₁ + btilde3*z₃ + btilde4*z₄ + btilde5*z₅ + btilde6*z₆ + btilde7*z₇
    if integrator.alg.smooth_est # From Shampine
      est = W\tmp
    else
      est = tmp
    end
    atmp = calculate_residuals(est, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end

  integrator.fsallast = z₇./dt
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  integrator.u = u
end

function initialize!(integrator, cache::Kvaerno5Cache)
  integrator.kshortsize = 2
  integrator.fsalfirst = cache.fsalfirst
  integrator.fsallast = cache.k
  resize!(integrator.k, integrator.kshortsize)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  integrator.f(integrator.fsalfirst, integrator.uprev, integrator.p, integrator.t) # For the interpolation, needs k at the updated point
end

@muladd function perform_step!(integrator, cache::Kvaerno5Cache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack uf,du1,dz,z₁,z₂,z₃,z₄,z₅,z₆,z₇,k,b,J,W,jac_config,tmp,atmp,κ,tol = cache
  @unpack γ,a31,a32,a41,a42,a43,a51,a52,a53,a54,a61,a63,a64,a65,a71,a73,a74,a75,a76,c3,c4,c5,c6 = cache.tab
  @unpack btilde1,btilde3,btilde4,btilde5,btilde6,btilde7 = cache.tab
  @unpack α31,α32,α41,α42,α43,α51,α52,α53,α61,α62,α63 = cache.tab

  # precalculations
  κtol = κ*tol

  γdt = γ*dt

  # calculate W
  if has_invW(f)
    # skip calculation of inv(W) if step is repeated
    !repeat_step && f(Val{:invW},W,uprev,p,γdt,t) # W == inverse W
  else
    # skip calculation of J if step is repeated
    if repeat_step || (!integrator.last_stepfail && cache.newton_iters == 1 && cache.ηold < integrator.alg.new_jac_conv_bound)
      new_jac = false
    else # Compute a new Jacobian
      new_jac = true
      if has_jac(f)
        f(Val{:jac}, J, uprev, p, t)
      else
        uf.t = t
        jacobian!(J, uf, uprev, du1, integrator, jac_config)
      end
    end
    # skip calculation of W if step is repeated
    if !repeat_step && (integrator.iter < 1 || new_jac || abs(dt - (t-integrator.tprev)) > 100eps(typeof(integrator.t)))
      new_W = true
      mass_matrix = integrator.sol.prob.mass_matrix
      for j in 1:length(u), i in 1:length(u)
          @inbounds W[i,j] = mass_matrix[i,j]-γdt*J[i,j]
      end
    else
      new_W = false
    end
  end

  ##### Step 1

  @. z₁ = dt*integrator.fsalfirst

  ##### Step 2

  # TODO: Allow other choices here
  z₂ .= zero.(u)

  # initial step of Newton iteration
  iter = 1
  tstep = t + 2*γdt
  @. tmp = uprev + γ*z₁
  @. u = tmp + γ*z₂
  f(k, u, p, tstep)
  @. b = dt*k - z₂
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),new_W)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₂ .+= dz

  η = max(cache.ηold,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = integrator.success_iter == 0 || η*ndz > κtol

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₂
    f(k, u, p, tstep)
    @. b = dt*k - z₂
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₂ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 3

  @. z₃ = α31*z₁ + α32*z₂

  # initial step of Newton iteration
  iter = 1
  tstep = t + c3*dt
  @. tmp = uprev + a31*z₁ + a32*z₂
  @. u = tmp + γ*z₃
  f(k, u, p, tstep)
  @. b = dt*k - z₃
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),false)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₃ .+= dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₃
    f(k, u, p, tstep)
    @. b = dt*k - z₃
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₃ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 4

  # Use constant z prediction
  @. z₄ = α41*z₁ + α42*z₂ + α43*z₃

  # initial step of Newton iteration
  iter = 1
  tstep = t + c4*dt
  @. tmp = uprev + a41*z₁ + a42*z₂ + a43*z₃
  @. u = tmp + γ*z₄
  f(k, u, p, tstep)
  @. b = dt*k - z₄
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),false)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₄ .+= dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₄
    f(k, u, p, tstep)
    @. b = dt*k - z₄
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₄ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 5

  @. z₅ = α51*z₁ + α52*z₂ + α53*z₃

  # initial step of Newton iteration
  iter = 1
  tstep = t + c5*dt
  @. tmp = uprev + a51*z₁ + a52*z₂ + a53*z₃ + a54*z₄
  @. u = tmp + γ*z₅
  f(k, u, p, tstep)
  @. b = dt*k - z₅
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),false)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₅ .+= dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₅
    f(k, u, p, tstep)
    @. b = dt*k - z₅
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₅ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 6

  @. z₆ = α61*z₁ + α62*z₂ + α63*z₃

  # inital step of Newton iteration
  iter = 1
  tstep = t + c6*dt
  @. tmp = uprev + a61*z₁ + a63*z₃ + a64*z₄ + a65*z₅
  @. u = tmp + γ*z₆
  f(k, u, p, tstep)
  @. b = dt*k - z₆
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),false)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₆ .+= dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₆
    f(k, u, p, tstep)
    @. b = dt*k - z₆
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₆ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 7

  # Prediction is embedded method
  # @. z₇ = a61*z₁ + a63*z₃ + a64*z₄ + a65*z₅ + γ*z₆
  @tight_loop_macros for i in eachindex(u)
    @inbounds z₇[i] = a61*z₁[i] + a63*z₃[i] + a64*z₄[i] + a65*z₅[i] + γ*z₆[i]
  end

  # initial step of Newton iteration
  iter = 1
  tstep = t + dt
  # @. tmp = uprev + a71*z₁ + a73*z₃ + a74*z₄ + a75*z₅ + a76*z₆
  @tight_loop_macros for i in eachindex(u)
    @inbounds tmp[i] = uprev[i] + a71*z₁[i] + a73*z₃[i] + a74*z₄[i] + a75*z₅[i] + a76*z₆[i]
  end
  @. u = tmp + γ*z₇
  f(k, u, p, tstep)
  @. b = dt*k - z₇
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),false)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₇ .+= dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₇
    f(k, u, p, tstep)
    @. b = dt*k - z₇
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₇ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  @. u = tmp + γ*z₇

  ################################### Finalize

  cache.ηold = η
  cache.newton_iters = iter

  if integrator.opts.adaptive
    # @. dz = btilde1*z₁ + btilde3*z₃ + btilde4*z₄ + btilde5*z₅ + btilde6*z₆ + btilde7*z₇
    @tight_loop_macros for i in eachindex(u)
      @inbounds dz[i] = btilde1*z₁[i] + btilde3*z₃[i] + btilde4*z₄[i] + btilde5*z₅[i] + btilde6*z₆[i] + btilde7*z₇[i]
    end
    if integrator.alg.smooth_est # From Shampine
      if has_invW(f)
        A_mul_B!(vec(tmp),W,vec(dz))
      else
        cache.linsolve(vec(tmp),W,vec(dz),false)
      end
    else
      tmp .= dz
    end
    calculate_residuals!(atmp, tmp, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end

  @. integrator.fsallast = z₇/dt
end

function initialize!(integrator, cache::KenCarp5ConstantCache)
  integrator.kshortsize = 2
  integrator.k = typeof(integrator.k)(integrator.kshortsize)

  integrator.fsalfirst = integrator.f(integrator.uprev, integrator.p, integrator.t) # Pre-start fsal

  # Avoid undefined entries if k is an array of arrays
  integrator.fsallast = zero(integrator.fsalfirst)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
end

@muladd function perform_step!(integrator, cache::KenCarp5ConstantCache, repeat_step=false)
  @unpack t,dt,uprev,u,p = integrator
  @unpack uf,κ,tol = cache
  @unpack γ,a31,a32,a41,a43,a51,a53,a54,a61,a63,a64,a65,a71,a73,a74,a75,a76,a81,a84,a85,a86,a87,c3,c4,c5,c6,c7 = cache.tab
  @unpack α31,α32,α41,α42,α51,α52,α61,α62,α71,α72,α73,α74,α75,α81,α82,α83,α84,α85 = cache.tab
  @unpack btilde1,btilde4,btilde5,btilde6,btilde7,btilde8 = cache.tab
  @unpack ea21,ea31,ea32,ea41,ea43,ea51,ea53,ea54,ea61,ea63,ea64,ea65 = cache.tab
  @unpack ea71,ea73,ea74,ea75,ea76,ea81,ea83,ea84,ea85,ea86,ea87 = cache.tab
  @unpack eb1,eb4,eb5,eb6,eb7,eb8 = cache.tab
  @unpack ebtilde1,ebtilde4,ebtilde5,ebtilde6,ebtilde7,ebtilde8 = cache.tab

  if typeof(integrator.f) <: SplitFunction
    f = integrator.f.f1
    f2 = integrator.f.f2
  else
    f = integrator.f
  end

  # precalculations
  κtol = κ*tol

  γdt = γ*dt

  # calculate W
  uf.t = t
  if typeof(uprev) <: AbstractArray
    J = ForwardDiff.jacobian(uf,uprev)
    W = I - γdt*J
  else
    J = ForwardDiff.derivative(uf,uprev)
    W = 1 - γdt*J
  end

  ##### Step 1

  if typeof(integrator.f) <: SplitFunction
    # Explicit tableau is not FSAL
    # Make this not compute on repeat
    z₁ = dt.*f(uprev, p, t)
  else
    # FSAL Step 1
    z₁ = dt*integrator.fsalfirst
  end

  ##### Step 2

  # TODO: Add extrapolation choice
  z₂ = zero(u)

  # initial step of Newton iteration
  iter = 1
  tstep = t + 2*γdt
  tmp = uprev + γ*z₁

  if typeof(integrator.f) <: SplitFunction
    # This assumes the implicit part is cheaper than the explicit part
    k1 = dt*integrator.fsalfirst - z₁
    tmp += ea21*k1
  end

  u = tmp + γ*z₂
  b = dt*f(u, p, tstep) - z₂
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₂ = z₂ + dz

  η = max(cache.ηold,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = integrator.success_iter == 0 || η*ndz > κtol

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₂
    b = dt*f(u, p, tstep) - z₂
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₂ = z₂ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 3

  # initial step of Newton iteration
  iter = 1
  tstep = t + c3*dt

  if typeof(integrator.f) <: SplitFunction
    z₃ = z₂
    u = tmp + γ*z₂
    k2 = dt*f2(u,p,t+2γ*dt)
    tmp = uprev + a31*z₁ + a32*z₂ + ea31*k1 + ea32*k2
  else
    # Guess is from Hermite derivative on z₁ and z₂
    z₃ = α31*z₁ + α32*z₂
    tmp = uprev + a31*z₁ + a32*z₂
  end

  u = tmp + γ*z₃
  b = dt*f(u, p, tstep) - z₃
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₃ = z₃ + dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₃
    b = dt*f(u, p, tstep) - z₃
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₃ = z₃ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 4

  # initial step of Newton iteration
  iter = 1
  tstep = t + c4*dt

  if typeof(integrator.f) <: SplitFunction
    z₄ = z₂
    u = tmp + γ*z₃
    k3 = dt*f2( u,p,t+c3*dt)
    tmp = uprev + a41*z₁ + a43*z₃ + ea41*k1 + ea43*k3
  else
    z₄ = α41*z₁ + α42*z₂
    tmp = uprev + a41*z₁ + a43*z₃
  end

  u = tmp + γ*z₄
  b = dt*f(u, p, tstep) - z₄
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₄ = z₄ + dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₄
    b = dt*f(u, p, tstep) - z₄
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₄ = z₄ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 5

  # initial step of Newton iteration
  iter = 1
  tstep = t + c5*dt

  if typeof(integrator.f) <: SplitFunction
    z₅ = z₂
    u = tmp + γ*z₄
    k4 = dt*f2( u,p,t+c4*dt)
    tmp = uprev + a51*z₁ + a53*z₃ + a54*z₄ + ea51*k1 + ea53*k3 + ea54*k4
  else
    z₅ = α51*z₁ + α52*z₂
    tmp = uprev + a51*z₁ + a53*z₃ + a54*z₄
  end

  u = tmp + γ*z₅
  b = dt*f(u, p, tstep) - z₅
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₅ = z₅ + dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₅
    b = dt*f(u, p, tstep) - z₅
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₅ = z₅ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 6

  # initial step of Newton iteration
  iter = 1
  tstep = t + c6*dt

  if typeof(integrator.f) <: SplitFunction
    z₆ = z₃
    u = tmp + γ*z₅
    k5 = dt*f2( u,p,t+c5*dt)
    tmp = uprev + a61*z₁ + a63*z₃ + a64*z₄ + a65*z₅ + ea61*k1 + ea63*k3 + ea64*k4 + ea65*k5
  else
    z₆ = α61*z₁ + α62*z₂
    tmp = uprev + a61*z₁ + a63*z₃ + a64*z₄ + a65*z₅
  end

  u = tmp + γ*z₆
  b = dt*f(u, p, tstep) - z₆
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₆ = z₆ + dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₆
    b = dt*f(u, p, tstep) - z₆
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₆ = z₆ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 7

  # initial step of Newton iteration
  iter = 1
  tstep = t + c7*dt

  if typeof(integrator.f) <: SplitFunction
    z₇ = z₂
    u = tmp + γ*z₆
    k6 = dt*f2( u,p,t+c6*dt)
    tmp = uprev + a71*z₁ +  a73*z₃ + a74*z₄ + a75*z₅ + a76*z₆ + ea71*k1 + ea73*k3 + ea74*k4 + ea75*k5 + ea76*k6
  else
    z₇ = α71*z₁ + α72*z₂ + α73*z₃ + α74*z₄ + α75*z₅
    tmp = uprev + a71*z₁ +  a73*z₃ + a74*z₄ + a75*z₅ + a76*z₆
  end

  u = tmp + γ*z₇
  b = dt*f(u, p, tstep) - z₇
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₇ = z₇ + dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₇
    b = dt*f(u, p, tstep) - z₇
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₇ = z₇ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 8

  # initial step of Newton iteration
  iter = 1
  tstep = t + dt

  if typeof(integrator.f) <: SplitFunction
    z₈ = z₅
    u = tmp + γ*z₇
    k7 = dt*f2( u,p,t+c7*dt)
    tmp = uprev + a81*z₁ + a84*z₄ + a85*z₅ + a86*z₆ + a87*z₇ + ea81*k1 + ea83*k3 + ea84*k4 + ea85*k5 + ea86*k6 + ea87*k7
  else
    z₈ = α81*z₁ + α82*z₂ + α83*z₃ + α84*z₄ + α85*z₅
    tmp = uprev + a81*z₁ + a84*z₄ + a85*z₅ + a86*z₆ + a87*z₇
  end

  u = tmp + γ*z₈
  b = dt*f(u, p, tstep) - z₈
  dz = W\b
  ndz = integrator.opts.internalnorm(dz)
  z₈ = z₈ + dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    u = tmp + γ*z₈
    b = dt*f(u, p, tstep) - z₈
    dz = W\b
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₈ = z₈ + dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  u = tmp + γ*z₈
  if typeof(integrator.f) <: SplitFunction
    k8 = dt*f2( u,p,t+dt)
    u = uprev + a81*z₁ + a84*z₄ + a85*z₅ + a86*z₆ + a87*z₇ + γ*z₈ + eb1*k1 + eb4*k4 + eb5*k5 + eb6*k6 + eb7*k7 + eb8*k8
  end

  ################################### Finalize

  cache.ηold = η
  cache.newton_iters = iter

  if integrator.opts.adaptive
    if typeof(integrator.f) <: SplitFunction
      tmp = btilde1*z₁ + btilde4*z₄ + btilde5*z₅ + btilde6*z₆ + btilde7*z₇ + btilde8*z₈ + ebtilde1*k1 + ebtilde4*k4 + ebtilde5*k5 + ebtilde6*k6 + ebtilde7*k7 + ebtilde8*k8
    else
      tmp = btilde1*z₁ + btilde4*z₄ + btilde5*z₅ + btilde6*z₆ + btilde7*z₇ + btilde8*z₈
    end
    if integrator.alg.smooth_est # From Shampine
      est = W\tmp
    else
      est = tmp
    end
    atmp = calculate_residuals(est, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end

  if typeof(integrator.f) <: SplitFunction
    integrator.k[1] = integrator.fsalfirst
    integrator.fsallast = integrator.f(u, p, t+dt)
    integrator.k[2] = integrator.fsallast
  else
    integrator.fsallast = z₈./dt
    integrator.k[1] = integrator.fsalfirst
    integrator.k[2] = integrator.fsallast
  end
  integrator.u = u
end

function initialize!(integrator, cache::KenCarp5Cache)
  integrator.kshortsize = 2
  integrator.fsalfirst = cache.fsalfirst
  integrator.fsallast = cache.k
  resize!(integrator.k, integrator.kshortsize)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  integrator.f(integrator.fsalfirst, integrator.uprev, integrator.p, integrator.t) # For the interpolation, needs k at the updated point
end

@muladd function perform_step!(integrator, cache::KenCarp5Cache, repeat_step=false)
  @unpack t,dt,uprev,u,p = integrator
  @unpack uf,du1,dz,z₁,z₂,z₃,z₄,z₅,z₆,z₇,z₈,k,b,J,W,jac_config,tmp,atmp,κ,tol = cache
  @unpack k1,k2,k3,k4,k5,k6,k7,k8 = cache
  @unpack γ,a31,a32,a41,a43,a51,a53,a54,a61,a63,a64,a65,a71,a73,a74,a75,a76,a81,a84,a85,a86,a87,c3,c4,c5,c6,c7 = cache.tab
  @unpack α31,α32,α41,α42,α51,α52,α61,α62,α71,α72,α73,α74,α75,α81,α82,α83,α84,α85 = cache.tab
  @unpack btilde1,btilde4,btilde5,btilde6,btilde7,btilde8 = cache.tab
  @unpack ea21,ea31,ea32,ea41,ea43,ea51,ea53,ea54,ea61,ea63,ea64,ea65 = cache.tab
  @unpack ea71,ea73,ea74,ea75,ea76,ea81,ea83,ea84,ea85,ea86,ea87 = cache.tab
  @unpack eb1,eb4,eb5,eb6,eb7,eb8 = cache.tab
  @unpack ebtilde1,ebtilde4,ebtilde5,ebtilde6,ebtilde7,ebtilde8 = cache.tab

  if typeof(integrator.f) <: SplitFunction
    f = integrator.f.f1
    f2 = integrator.f.f2
  else
    f = integrator.f
  end

  # precalculations
  κtol = κ*tol

  γdt = γ*dt

  # calculate W
  if has_invW(f)
    # skip calculation of inv(W) if step is repeated
    !repeat_step && f(Val{:invW},W,uprev,p,γdt,t) # W == inverse W
  else
    # skip calculation of J if step is repeated
    if repeat_step || (!integrator.last_stepfail && cache.newton_iters == 1 && cache.ηold < integrator.alg.new_jac_conv_bound)
      new_jac = false
    else # Compute a new Jacobian
      new_jac = true
      if has_jac(f)
        f(Val{:jac}, J, uprev, p, t)
      else
        uf.t = t
        jacobian!(J, uf, uprev, du1, integrator, jac_config)
      end
    end
    # skip calculation of W if step is repeated
    if !repeat_step && (integrator.iter < 1 || new_jac || abs(dt - (t-integrator.tprev)) > 100eps(typeof(integrator.t)))
      new_W = true
      mass_matrix = integrator.sol.prob.mass_matrix
      for j in 1:length(u), i in 1:length(u)
          @inbounds W[i,j] = mass_matrix[i,j]-γdt*J[i,j]
      end
    else
      new_W = false
    end
  end

  ##### Step 1

  if typeof(integrator.f) <: SplitFunction
    # Explicit tableau is not FSAL
    # Make this not compute on repeat
    if !repeat_step && !integrator.last_stepfail
      f(z₁, integrator.uprev, p, integrator.t)
      z₁ .*= dt
    end
  else
    # FSAL Step 1
    @. z₁ = dt*integrator.fsalfirst
  end

  ##### Step 2

  # TODO: Allow other choices here
  z₂ .= zero.(u)

  # initial step of Newton iteration
  iter = 1
  tstep = t + 2*γdt
  @. tmp = uprev + γ*z₁

  if typeof(integrator.f) <: SplitFunction
    # This assumes the implicit part is cheaper than the explicit part
    @. k1 = dt*integrator.fsalfirst - z₁
    @. tmp += ea21*k1
  end

  @. u = tmp + γ*z₂
  f(k, u, p, tstep)
  @. b = dt*k - z₂
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),new_W)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₂ .+= dz

  η = max(cache.ηold,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = integrator.success_iter == 0 || η*ndz > κtol

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₂
    f(k, u, p, tstep)
    @. b = dt*k - z₂
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₂ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 3

  # initial step of Newton iteration
  iter = 1
  tstep = t + c3*dt

  if typeof(integrator.f) <: SplitFunction
    z₃ .= z₂
    @. u = tmp + γ*z₂
    f2(k2, u, p, t+2γ*dt); k2 .*= dt
    #@. tmp = uprev + a31*z₁ + a32*z₂ + ea31*k1 + ea32*k2
    for i in eachindex(u)
      @inbounds tmp[i] = uprev[i] + a31*z₁[i] + a32*z₂[i] + ea31*k1[i] + ea32*k2[i]
    end
  else
    # Guess is from Hermite derivative on z₁ and z₂
    @. z₃ = a31*z₁ + α32*z₂
    @. tmp = uprev + a31*z₁ + a32*z₂
  end

  @. u = tmp + γ*z₃
  f(k, u, p, tstep)
  @. b = dt*k - z₃
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),false)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₃ .+= dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₃
    f(k, u, p, tstep)
    @. b = dt*k - z₃
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₃ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 4

  # initial step of Newton iteration
  iter = 1
  tstep = t + c4*dt

  if typeof(integrator.f) <: SplitFunction
    z₄ .= z₃
    @. u = tmp + γ*z₃
    f2( k3, u,p,t+c3*dt); k3 .*= dt
    #@. tmp = uprev + a41*z₁ + a43*z₃ + ea41*k1 + ea43*k3
    for i in eachindex(u)
      @inbounds tmp[i] = uprev[i] + a41*z₁[i] + a43*z₃[i] + ea41*k1[i] + ea43*k3[i]
    end
  else
    @. z₄ = α41*z₁ + α42*z₂
    @. tmp = uprev + a41*z₁ + a43*z₃
  end

  @. u = tmp + γ*z₄
  f(k, u, p, tstep)
  @. b = dt*k - z₄
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),false)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₄ .+= dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₄
    f(k, u, p, tstep)
    @. b = dt*k - z₄
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₄ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 5

  # initial step of Newton iteration
  iter = 1
  tstep = t + c5*dt

  if typeof(integrator.f) <: SplitFunction
    z₅ .= z₂
    @. u = tmp + γ*z₄
    f2( k4, u,p,t+c4*dt); k4 .*= dt
    #@. tmp = uprev + a51*z₁ + a53*z₃ + a54*z₄ + ea51*k1 + ea53*k3 + ea54*k4
    for i in eachindex(u)
      @inbounds tmp[i] = uprev[i] + a51*z₁[i] + a53*z₃[i] + a54*z₄[i] + ea51*k1[i] + ea53*k3[i] + ea54*k4[i]
    end
  else
    @. z₅ = α51*z₁ + α52*z₂
    @. tmp = uprev + a51*z₁ + a53*z₃ + a54*z₄
  end

  @. u = tmp + γ*z₅
  f(k, u, p, tstep)
  @. b = dt*k - z₅
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),false)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₅ .+= dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₅
    f(k, u, p, tstep)
    @. b = dt*k - z₅
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₅ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 6

  # initial step of Newton iteration
  iter = 1
  tstep = t + c6*dt

  if typeof(integrator.f) <: SplitFunction
    z₆ .= z₃
    @. u = tmp + γ*z₅
    f2( k5, u,p,t+c5*dt); k5 .*= dt
    #@. tmp = uprev + a61*z₁ + a63*z₃ + a64*z₄ + a65*z₅ + ea61*k1 + ea63*k3 + ea64*k4 + ea65*k5
    for i in eachindex(u)
      @inbounds tmp[i] = uprev[i] + a61*z₁[i] + a63*z₃[i] + a64*z₄[i] + a65*z₅[i] + ea61*k1[i] + ea63*k3[i] + ea64*k4[i] + ea65*k5[i]
    end
  else
    @. z₆ = α61*z₁ + α62*z₂
    #@. tmp = uprev + a61*z₁ + a63*z₃ + a64*z₄ + a65*z₅
    for i in eachindex(u)
      @inbounds tmp[i] = uprev[i] + a61*z₁[i] + a63*z₃[i] + a64*z₄[i] + a65*z₅[i]
    end
  end

  @. u = tmp + γ*z₆
  f(k, u, p, tstep)
  @. b = dt*k - z₆
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),false)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₆ .+= dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₆
    f(k, u, p, tstep)
    @. b = dt*k - z₆
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₆ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 7

  # initial step of Newton iteration
  iter = 1
  tstep = t + c7*dt

  if typeof(integrator.f) <: SplitFunction
    z₇ .= z₂
    @. u = tmp + γ*z₆
    f2( k6, u,p,t+c6*dt); k6 .*= dt
    #@. tmp = uprev + a71*z₁ +  a73*z₃ + a74*z₄ + a75*z₅ + a76*z₆ + ea71*k1 + ea73*k3 + ea74*k4 + ea75*k5 + ea76*k6
    for i in eachindex(u)
      @inbounds tmp[i] = uprev[i] + a71*z₁[i] +  a73*z₃[i] + a74*z₄[i] + a75*z₅[i] + a76*z₆[i] + ea71*k1[i] + ea73*k3[i] + ea74*k4[i] + ea75*k5[i] + ea76*k6[i]
    end
  else
    #@. z₇ = α71*z₁ + α72*z₂ + α73*z₃ + α74*z₄ + α75*z₅
    @tight_loop_macros for i in eachindex(u)
      @inbounds z₇[i] = α71*z₁[i] + α72*z₂[i] + α73*z₃[i] + α74*z₄[i] + α75*z₅[i]
    end
    #@. tmp = uprev + a71*z₁ + a73*z₃ + a74*z₄ + a75*z₅ + a76*z₆
    @tight_loop_macros for i in eachindex(u)
      @inbounds tmp[i] = uprev[i] + a71*z₁[i] + a73*z₃[i] + a74*z₄[i] + a75*z₅[i] + a76*z₆[i]
    end
  end

  @. u = tmp + γ*z₇
  f(k, u, p, tstep)
  @. b = dt*k - z₇
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),false)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₇ .+= dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₇
    f(k, u, p, tstep)
    @. b = dt*k - z₇
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₇ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  ################################## Solve Step 8

  # initial step of Newton iteration
  iter = 1
  tstep = t + dt

  if typeof(integrator.f) <: SplitFunction
    z₈ .= z₅
    @. u = tmp + γ*z₇
    f2( k7, u,p,t+c7*dt); k7 .*= dt
    #@. tmp = uprev + a81*z₁ + a84*z₄ + a85*z₅ + a86*z₆ + a87*z₇ + ea81*k1 + ea83*k3 + ea84*k4 + ea85*k5 + ea86*k6 + ea87*k7
    for i in eachindex(u)
      @inbounds tmp[i] = uprev[i] + a81*z₁[i] + a84*z₄[i] + a85*z₅[i] + a86*z₆[i] + a87*z₇[i] + ea81*k1[i] + ea83*k3[i] + ea84*k4[i] + ea85*k5[i] + ea86*k6[i] + ea87*k7[i]
    end
  else
    #@. z₈ = α81*z₁ + α82*z₂ + α83*z₃ + α84*z₄ + α85*z₅
    @tight_loop_macros for i in eachindex(u)
      @inbounds z₈[i] = α81*z₁[i] + α82*z₂[i] + α83*z₃[i] + α84*z₄[i] + α85*z₅[i]
    end
    #@. tmp = uprev + a81*z₁ + a84*z₄ + a85*z₅ + a86*z₆ + a87*z₇
    @tight_loop_macros for i in eachindex(u)
      @inbounds tmp[i] = uprev[i] + a81*z₁[i] + a84*z₄[i] + a85*z₅[i] + a86*z₆[i] + a87*z₇[i]
    end
  end

  @. u = tmp + γ*z₈
  f(k, u, p, tstep)
  @. b = dt*k - z₈
  if has_invW(f)
    A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
  else
    cache.linsolve(vec(dz),W,vec(b),false)
  end
  ndz = integrator.opts.internalnorm(dz)
  z₈ .+= dz

  η = max(η,eps(eltype(integrator.opts.reltol)))^(0.8)
  do_newton = (η*ndz > κtol)

  # Newton iteration
  fail_convergence = false
  while (do_newton || iter < integrator.alg.min_newton_iter) && iter < integrator.alg.max_newton_iter
    iter += 1
    @. u = tmp + γ*z₈
    f(k, u, p, tstep)
    @. b = dt*k - z₈
    if has_invW(f)
      A_mul_B!(vec(dz),W,vec(b)) # Here W is actually invW
    else
      cache.linsolve(vec(dz),W,vec(b),false)
    end
    ndzprev = ndz
    ndz = integrator.opts.internalnorm(dz)
    θ = ndz/ndzprev
    if θ > 1 || ndz*(θ^(integrator.alg.max_newton_iter - iter)/(1-θ)) > κtol
      fail_convergence = true
      break
    end
    η = θ/(1-θ)
    do_newton = (η*ndz > κtol)
    z₈ .+= dz
  end

  if (iter >= integrator.alg.max_newton_iter && do_newton) || fail_convergence
    integrator.force_stepfail = true
    return
  end

  @. u = tmp + γ*z₈
  if typeof(integrator.f) <: SplitFunction
    f2( k8, u,p,t+dt); k8 .*= dt
    # @. u = uprev + a81*z₁ + a84*z₄ + a85*z₅ + a86*z₆ + a87*z₇ + γ*z₈ + eb1*k1 + eb4*k4 + eb5*k5 + eb6*k6 + eb7*k7 + eb8*k8
    for i in eachindex(u)
      @inbounds u[i] = uprev[i] + a81*z₁[i] + a84*z₄[i] + a85*z₅[i] + a86*z₆[i] + a87*z₇[i] + γ*z₈[i] + eb1*k1[i] + eb4*k4[i] + eb5*k5[i] + eb6*k6[i] + eb7*k7[i] + eb8*k8[i]
    end
  end

  ################################### Finalize

  cache.ηold = η
  cache.newton_iters = iter

  if integrator.opts.adaptive

    if typeof(integrator.f) <: SplitFunction
      #@. dz =  btilde1*z₁ + btilde4*z₄ + btilde5*z₅ + btilde6*z₆ + btilde7*z₇ + btilde8*z₈ + ebtilde1*k1 + ebtilde4*k4 + ebtilde5*k5 + ebtilde6*k6 + ebtilde7*k7 + ebtilde8*k8
      for i in eachindex(u)
        dz[i] =  btilde1*z₁[i] + btilde4*z₄[i] + btilde5*z₅[i] + btilde6*z₆[i] + btilde7*z₇[i] + btilde8*z₈[i] + ebtilde1*k1[i] + ebtilde4*k4[i] + ebtilde5*k5[i] + ebtilde6*k6[i] + ebtilde7*k7[i] + ebtilde8*k8[i]
      end
    else
      # @. dz = btilde1*z₁ + btilde4*z₄ + btilde5*z₅ + btilde6*z₆ + btilde7*z₇ + btilde8*z₈
      @tight_loop_macros for i in eachindex(u)
        @inbounds dz[i] = btilde1*z₁[i] + btilde4*z₄[i] + btilde5*z₅[i] + btilde6*z₆[i] + btilde7*z₇[i] + btilde8*z₈[i]
      end

    end

    if integrator.alg.smooth_est # From Shampine
      if has_invW(f)
        A_mul_B!(vec(tmp),W,vec(dz))
      else
        cache.linsolve(vec(tmp),W,vec(dz),false)
      end
    else
      tmp .= dz
    end
    calculate_residuals!(atmp, tmp, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end

  if typeof(integrator.f) <: SplitFunction
    integrator.f(integrator.fsallast,u,p,t+dt)
  else
    @. integrator.fsallast = z₈/dt
  end
end
