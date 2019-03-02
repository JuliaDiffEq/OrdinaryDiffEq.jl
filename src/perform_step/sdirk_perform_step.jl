function initialize!(integrator, cache::Union{ImplicitEulerConstantCache,
                                              ImplicitMidpointConstantCache,
                                              TrapezoidConstantCache,
                                              TRBDF2ConstantCache,
                                              SDIRK2ConstantCache,
                                              SSPSDIRK2ConstantCache,
                                              Cash4ConstantCache,
                                              Hairer4ConstantCache,
                                              RK4ThreadedConstantCache})
  integrator.kshortsize = 2
  integrator.k = typeof(integrator.k)(undef, integrator.kshortsize)
  integrator.fsalfirst = integrator.f(integrator.uprev, integrator.p, integrator.t) # Pre-start fsal

  # Avoid undefined entries if k is an array of arrays
  integrator.fsallast = zero(integrator.fsalfirst)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
end

function initialize!(integrator, cache::Union{ImplicitEulerCache,
                                              ImplicitMidpointCache,
                                              TrapezoidCache,
                                              TRBDF2Cache,
                                              SDIRK2Cache,
                                              SSPSDIRK2Cache,
                                              Cash4Cache,
                                              Hairer4Cache})
  integrator.kshortsize = 2
  integrator.fsalfirst = cache.fsalfirst
  integrator.fsallast = cache.k
  resize!(integrator.k, integrator.kshortsize)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  integrator.f(integrator.fsalfirst, integrator.uprev, integrator.p, integrator.t) # For the interpolation, needs k at the updated point
end

@muladd function perform_step!(integrator, cache::ImplicitEulerConstantCache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  nlsolver = cache.nlsolver
  alg = unwrap_alg(integrator, true)
  update_W!(integrator, cache, dt, repeat_step)

  # initial guess
  if alg.extrapolant == :linear
    nlsolver.z = dt*integrator.fsalfirst
  else # :constant
    nlsolver.z = zero(u)
  end

  nlsolver.tmp = uprev
  z,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return
  u = nlsolver.tmp + z

  nlsolver.ηold = η
  nlsolver.nl_iters = iter

  if integrator.opts.adaptive && integrator.success_iter > 0
    # local truncation error (LTE) bound by dt^2/2*max|y''(t)|
    # use 2nd divided differences (DD) a la SPICE and Shampine

    # TODO: check numerical stability
    uprev2 = integrator.uprev2
    tprev = integrator.tprev

    dt1 = dt*(t+dt-tprev)
    dt2 = (t-tprev)*(t+dt-tprev)
    c = 7/12 # default correction factor in SPICE (LTE overestimated by DD)
    r = c*dt^2 # by mean value theorem 2nd DD equals y''(s)/2 for some s

    tmp = r*integrator.opts.internalnorm.((u - uprev)/dt1 - (uprev - uprev2)/dt2,t)
    atmp = calculate_residuals(tmp, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm,t)
    integrator.EEst = integrator.opts.internalnorm(atmp,t)
  else
    integrator.EEst = 1
  end

  integrator.fsallast = f(u, p, t+dt)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  integrator.u = u
end

@muladd function perform_step!(integrator, cache::ImplicitEulerCache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack z,tmp,atmp,nlsolver = cache
  mass_matrix = integrator.f.mass_matrix
  alg = unwrap_alg(integrator, true)
  update_W!(integrator, cache, dt, repeat_step)

  # initial guess
  if alg.extrapolant == :linear
    @. z = dt*integrator.fsalfirst
  else # :constant
    z .= zero(eltype(u))
  end

  nlsolver.tmp = uprev
  z,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return
  @. u = uprev + z

  nlsolver.ηold = η
  nlsolver.nl_iters = iter

  if integrator.opts.adaptive && integrator.success_iter > 0
    # local truncation error (LTE) bound by dt^2/2*max|y''(t)|
    # use 2nd divided differences (DD) a la SPICE and Shampine

    # TODO: check numerical stability
    uprev2 = integrator.uprev2
    tprev = integrator.tprev

    dt1 = dt*(t+dt-tprev)
    dt2 = (t-tprev)*(t+dt-tprev)
    c = 7/12 # default correction factor in SPICE (LTE overestimated by DD)
    r = c*dt^2 # by mean value theorem 2nd DD equals y''(s)/2 for some s

    @. tmp = r*integrator.opts.internalnorm((u - uprev)/dt1 - (uprev - uprev2)/dt2,t)
    calculate_residuals!(atmp, tmp, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm,t)
    integrator.EEst = integrator.opts.internalnorm(atmp,t)
  else
    integrator.EEst = 1
  end

  f(integrator.fsallast,u,p,t+dt)
end

@muladd function perform_step!(integrator, cache::ImplicitMidpointConstantCache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  nlsolver = cache.nlsolver
  alg = unwrap_alg(integrator, true)
  γ = 1//2
  update_W!(integrator, cache, γ*dt, repeat_step)

  # initial guess
  if alg.extrapolant == :linear
    nlsolver.z = dt*integrator.fsalfirst
  else # :constant
    nlsolver.z = zero(u)
  end

  nlsolver.tmp = uprev
  z,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return
  u = nlsolver.tmp + z

  nlsolver.ηold = η
  nlsolver.nl_iters = iter

  integrator.fsallast = f(u, p, t+dt)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  integrator.u = u
end

@muladd function perform_step!(integrator, cache::ImplicitMidpointCache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack z,tmp,nlsolver = cache
  mass_matrix = integrator.f.mass_matrix
  alg = unwrap_alg(integrator, true)
  γ = 1//2
  update_W!(integrator, cache, γ*dt, repeat_step)

  # initial guess
  if alg.extrapolant == :linear
    @. z = dt*integrator.fsalfirst
  else # :constant
    z .= zero(eltype(u))
  end

  nlsolver.tmp = uprev
  z,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return
  @. u = nlsolver.tmp + z

  nlsolver.ηold = η
  nlsolver.nl_iters = iter

  f(integrator.fsallast,u,p,t+dt)
end

@muladd function perform_step!(integrator, cache::TrapezoidConstantCache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  nlsolver = cache.nlsolver
  alg = unwrap_alg(integrator, true)
  # precalculations
  γ = 1//2
  γdt = γ*dt
  update_W!(integrator, cache, γdt, repeat_step)

  # initial guess
  zprev = dt*integrator.fsalfirst
  nlsolver.z = zprev # Constant extrapolation

  nlsolver.tmp = uprev + γdt*integrator.fsalfirst
  z,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return
  u = nlsolver.tmp + 1//2*z

  nlsolver.ηold = η
  nlsolver.nl_iters = iter

  if integrator.opts.adaptive
    if integrator.iter > 2
      # local truncation error (LTE) bound by dt^3/12*max|y'''(t)|
      # use 3rd divided differences (DD) a la SPICE and Shampine

      # TODO: check numerical stability
      uprev2 = integrator.uprev2
      tprev = integrator.tprev
      uprev3 = cache.uprev3
      tprev2 = cache.tprev2

      dt1 = dt*(t+dt-tprev)
      dt2 = (t-tprev)*(t+dt-tprev)
      dt3 = (t-tprev)*(t-tprev2)
      dt4 = (tprev-tprev2)*(t-tprev2)
      dt5 = t+dt-tprev2
      c = 7/12 # default correction factor in SPICE (LTE overestimated by DD)
      r = c*dt^3/2 # by mean value theorem 3rd DD equals y'''(s)/6 for some s

      # tmp = r*abs(((u - uprev)/dt1 - (uprev - uprev2)/dt2) - ((uprev - uprev2)/dt3 - (uprev2 - uprev3)/dt4)/dt5)
      DD31 = (u - uprev)/dt1 - (uprev - uprev2)/dt2
      DD30 = (uprev - uprev2)/dt3 - (uprev2 - uprev3)/dt4
      tmp = r*integrator.opts.internalnorm((DD31 - DD30)/dt5,t)
      atmp = calculate_residuals(tmp, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm,t)
      integrator.EEst = integrator.opts.internalnorm(atmp,t)
      if integrator.EEst <= 1
        cache.uprev3 = uprev2
        cache.tprev2 = tprev
      end
    elseif integrator.success_iter > 0
      integrator.EEst = 1
      cache.uprev3 = integrator.uprev2
      cache.tprev2 = integrator.tprev
    else
      integrator.EEst = 1
    end
  end

  integrator.fsallast = f(u, p, t+dt)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  integrator.u = u
end

@muladd function perform_step!(integrator, cache::TrapezoidCache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack z,jac_config,tmp,atmp,nlsolver = cache
  alg = unwrap_alg(integrator, true)
  mass_matrix = integrator.f.mass_matrix

  # precalculations
  γ = 1//2
  γdt = γ*dt
  update_W!(integrator, cache, γdt, repeat_step)

  # initial guess
  @. z = dt*integrator.fsalfirst
  @. tmp = uprev + γdt*integrator.fsalfirst
  z,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return
  @. u = tmp + 1//2*z

  nlsolver.ηold = η
  nlsolver.nl_iters = iter

  if integrator.opts.adaptive
    if integrator.iter > 2
      # local truncation error (LTE) bound by dt^3/12*max|y'''(t)|
      # use 3rd divided differences (DD) a la SPICE and Shampine

      # TODO: check numerical stability
      uprev2 = integrator.uprev2
      tprev = integrator.tprev
      uprev3 = cache.uprev3
      tprev2 = cache.tprev2

      dt1 = dt*(t+dt-tprev)
      dt2 = (t-tprev)*(t+dt-tprev)
      dt3 = (t-tprev)*(t-tprev2)
      dt4 = (tprev-tprev2)*(t-tprev2)
      dt5 = t+dt-tprev2
      c = 7/12 # default correction factor in SPICE (LTE overestimated by DD)
      r = c*dt^3/2 # by mean value theorem 3rd DD equals y'''(s)/6 for some s

      # @. tmp = r*abs(((u - uprev)/dt1 - (uprev - uprev2)/dt2) - ((uprev - uprev2)/dt3 - (uprev2 - uprev3)/dt4)/dt5)
      @inbounds for i in eachindex(u)
        DD31 = (u[i] - uprev[i])/dt1 - (uprev[i] - uprev2[i])/dt2
        DD30 = (uprev[i] - uprev2[i])/dt3 - (uprev2[i] - uprev3[i])/dt4
        tmp[i] = r*integrator.opts.internalnorm((DD31 - DD30)/dt5,t)
      end
      calculate_residuals!(atmp, tmp, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm,t)
      integrator.EEst = integrator.opts.internalnorm(atmp,t)
      if integrator.EEst <= 1
        copyto!(cache.uprev3,uprev2)
        cache.tprev2 = tprev
      end
    elseif integrator.success_iter > 0
      integrator.EEst = 1
      copyto!(cache.uprev3,integrator.uprev2)
      cache.tprev2 = integrator.tprev
    else
      integrator.EEst = 1
    end
  end

  f(integrator.fsallast,u,p,t+dt)
end

@muladd function perform_step!(integrator, cache::TRBDF2ConstantCache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack γ,d,ω,btilde1,btilde2,btilde3,α1,α2 = cache.tab
  nlsolver = cache.nlsolver
  alg = unwrap_alg(integrator, true)
  update_W!(integrator, cache, d*dt, repeat_step)

  # FSAL
  zprev = dt*integrator.fsalfirst

  ##### Solve Trapezoid Step

  # TODO: Add extrapolation
  zᵧ = zprev
  nlsolver.z = zᵧ
  nlsolver.c = γ

  nlsolver.tmp = uprev + d*zprev
  zᵧ,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  ################################## Solve BDF2 Step

  ### Initial Guess From Shampine
  z = α1*zprev + α2*zᵧ
  nlsolver.z = z
  nlsolver.c = 1

  nlsolver.tmp = uprev + ω*zprev + ω*zᵧ
  z,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  u = nlsolver.tmp + d*z

  ################################### Finalize

  nlsolver.ηold = η
  nlsolver.nl_iters = iter

  if integrator.opts.adaptive
    tmp = btilde1*zprev + btilde2*zᵧ + btilde3*z
    if isnewton(nlsolver) && alg.smooth_est # From Shampine
      est = _reshape(get_W(nlsolver) \ _vec(tmp), axes(tmp))
    else
      est = tmp
    end
    atmp = calculate_residuals(est, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm,t)
    integrator.EEst = integrator.opts.internalnorm(atmp,t)
  end

  integrator.fsallast = z./dt
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  integrator.u = u
end

@muladd function perform_step!(integrator, cache::TRBDF2Cache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack zprev,dz,zᵧ,z,k,b,W,tmp,atmp,nlsolver = cache
  @unpack γ,d,ω,btilde1,btilde2,btilde3,α1,α2 = cache.tab
  alg = unwrap_alg(integrator, true)

  # FSAL
  @. zprev = dt*integrator.fsalfirst
  update_W!(integrator, cache, d*dt, repeat_step)

  ##### Solve Trapezoid Step

  # TODO: Add extrapolation
  @. zᵧ = zprev
  nlsolver.z = zᵧ

  @. tmp = uprev + d*zprev
  nlsolver.c = γ
  zᵧ,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  ################################## Solve BDF2 Step

  ### Initial Guess From Shampine
  @. z = α1*zprev + α2*zᵧ
  nlsolver.z = z

  @. tmp = uprev + ω*zprev + ω*zᵧ
  nlsolver.c = 1
  set_new_W!(nlsolver, false)
  z,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  @. u = tmp + d*z

  ################################### Finalize

  nlsolver.ηold = η
  nlsolver.nl_iters = iter

  if integrator.opts.adaptive
    @. dz = btilde1*zprev + btilde2*zᵧ + btilde3*z
    if alg.smooth_est # From Shampine
      if DiffEqBase.has_invW(f)
        mul!(vec(tmp),W,vec(dz))
      else
        cache.linsolve(vec(tmp),W,vec(dz),false)
      end
    else
      tmp .= dz
    end
    calculate_residuals!(atmp, tmp, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm,t)
    integrator.EEst = integrator.opts.internalnorm(atmp,t)
  end

  @. integrator.fsallast = z/dt
end

@muladd function perform_step!(integrator, cache::SDIRK2ConstantCache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  nlsolver = cache.nlsolver
  alg = unwrap_alg(integrator, true)
  update_W!(integrator, cache, dt, repeat_step)

  # initial guess
  if integrator.success_iter > 0 && !integrator.reeval_fsal && alg.extrapolant == :interpolant
    current_extrapolant!(u,t+dt,integrator)
    z₁ = u - uprev
  elseif alg.extrapolant == :linear
    z₁ = dt*integrator.fsalfirst
  else
    z₁ = zero(u)
  end

  nlsolver.tmp = uprev
  z₁,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  ### Initial Guess Is α₁ = c₂/γ, c₂ = 0 => z₂ = α₁z₁ = 0
  z₂ = zero(u)
  nlsolver.z = z₂
  nlsolver.tmp = uprev - z₁
  z₂,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  u = uprev + z₁/2 + z₂/2

  ################################### Finalize

  nlsolver.ηold = η
  nlsolver.nl_iters = iter

  if integrator.opts.adaptive
    tmp = z₁/2 - z₂/2
    if isnewton(nlsolver) && alg.smooth_est # From Shampine
      est = _reshape(get_W(nlsolver) \ _vec(tmp), axes(tmp))
    else
      est = tmp
    end
    atmp = calculate_residuals(est, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm,t)
    integrator.EEst = integrator.opts.internalnorm(atmp,t)
  end

  integrator.fsallast = f(u, p, t)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  integrator.u = u
end

@muladd function perform_step!(integrator, cache::SDIRK2Cache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack dz,z₁,z₂,k,b,W,jac_config,tmp,atmp,nlsolver = cache
  alg = unwrap_alg(integrator, true)
  update_W!(integrator, cache, dt, repeat_step)

  # initial guess
  if integrator.success_iter > 0 && !integrator.reeval_fsal && alg.extrapolant == :interpolant
    current_extrapolant!(u,t+dt,integrator)
    @. z₁ = u - uprev
  elseif alg.extrapolant == :linear
    @. z₁ = dt*integrator.fsalfirst
  else
    z₁ .= zero(eltype(u))
  end
  nlsolver.z = z₁

  ##### Step 1
  nlsolver.tmp = uprev
  z₁,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  ################################## Solve Step 2

  ### Initial Guess Is α₁ = c₂/γ, c₂ = 0 => z₂ = α₁z₁ = 0
  z₂ .= zero(eltype(u))
  nlsolver.z = z₂
  set_new_W!(nlsolver, false)
  @. tmp = uprev - z₁
  nlsolver.tmp = tmp
  z₂,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  @. u = uprev + z₁/2 + z₂/2

  ################################### Finalize

  nlsolver.ηold = η
  nlsolver.nl_iters = iter

  if integrator.opts.adaptive
    @. dz = z₁/2 - z₂/2
    if alg.smooth_est # From Shampine
      if DiffEqBase.has_invW(f)
        mul!(vec(tmp),W,vec(dz))
      else
        cache.linsolve(vec(tmp),W,vec(dz),false)
      end
    else
      tmp .= dz
    end
    calculate_residuals!(atmp, tmp, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm,t)
    integrator.EEst = integrator.opts.internalnorm(atmp,t)
  end

  f(integrator.fsallast,u,p,t)
end

@muladd function perform_step!(integrator, cache::SSPSDIRK2ConstantCache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  nlsolver = cache.nlsolver
  alg = unwrap_alg(integrator, true)

  γ = eltype(u)(1//4)
  c2 = typeof(t)(3//4)

  update_W!(integrator, cache, γ*dt, repeat_step)

  # initial guess
  if integrator.success_iter > 0 && !integrator.reeval_fsal && alg.extrapolant == :interpolant
    current_extrapolant!(u,t+dt,integrator)
    z₁ = u - uprev
  elseif alg.extrapolant == :linear
    z₁ = dt*integrator.fsalfirst
  else
    z₁ = zero(u)
  end
  nlsolver.z = z₁

  ##### Step 1

  tstep = t + dt
  u = uprev + γ*z₁

  nlsolver.c = 1
  nlsolver.tmp = uprev
  z₁,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  ################################## Solve Step 2

  ### Initial Guess Is α₁ = c₂/γ
  z₂ = c2/γ
  nlsolver.z = z₂

  nlsolver.tmp = uprev + z₁/2
  nlsolver.c = 1
  z₂,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  u = nlsolver.tmp + z₂/2

  ################################### Finalize

  nlsolver.ηold = η
  nlsolver.nl_iters = iter

  integrator.fsallast = f(u, p, t)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  integrator.u = u
end

@muladd function perform_step!(integrator, cache::SSPSDIRK2Cache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack dz,z₁,z₂,k,b,W,jac_config,tmp,nlsolver = cache
  alg = unwrap_alg(integrator, true)

  γ = eltype(u)(1//4)
  c2 = typeof(t)(3//4)
  update_W!(integrator, cache, γ*dt, repeat_step)

  # initial guess
  if integrator.success_iter > 0 && !integrator.reeval_fsal && alg.extrapolant == :interpolant
    current_extrapolant!(u,t+dt,integrator)
    @. z₁ = u - uprev
  elseif alg.extrapolant == :linear
    @. z₁ = dt*integrator.fsalfirst
  else
    z₁ .= zero(eltype(u))
  end
  nlsolver.z = z₁
  nlsolver.tmp = uprev

  ##### Step 1
  z₁,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  ################################## Solve Step 2

  ### Initial Guess Is α₁ = c₂/γ
  @. z₂ = c2/γ
  nlsolver.z = z₂

  @. tmp = uprev + z₁/2
  nlsolver.tmp = tmp
  set_new_W!(nlsolver, false)
  z₂,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  @. u = tmp + z₂/2

  ################################### Finalize

  nlsolver.ηold = η
  nlsolver.nl_iters = iter

  f(integrator.fsallast,u,p,t)
end

@muladd function perform_step!(integrator, cache::Cash4ConstantCache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack γ,a21,a31,a32,a41,a42,a43,a51,a52,a53,a54,c2,c3,c4 = cache.tab
  @unpack b1hat1,b2hat1,b3hat1,b4hat1,b1hat2,b2hat2,b3hat2,b4hat2 = cache.tab
  nlsolver = cache.nlsolver
  alg = unwrap_alg(integrator, true)
  update_W!(integrator, cache, γ*dt, repeat_step)

  ##### Step 1

  # TODO: Add extrapolation for guess
  z₁ = zero(u)
  nlsolver.z = z₁

  nlsolver.c = γ
  nlsolver.tmp = uprev
  z₁,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  ##### Step 2

  # TODO: Add extrapolation for guess
  z₂ = zero(u)
  nlsolver.z = z₂

  nlsolver.tmp = uprev + a21*z₁
  nlsolver.c = c2
  z₂,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  ################################## Solve Step 3

  # Guess starts from z₁
  z₃ = z₁
  nlsolver.z = z₃

  nlsolver.tmp = uprev + a31*z₁ + a32*z₂
  nlsolver.c = c3
  z₃,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  ################################## Solve Step 4

  # Use constant z prediction
  z₄ = z₃
  nlsolver.z = z₄

  nlsolver.tmp = uprev + a41*z₁ + a42*z₂ + a43*z₃
  nlsolver.c = c4
  z₄,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  ################################## Solve Step 5

  # Use yhat2 for prediction
  z₅ = b1hat2*z₁ + b2hat2*z₂ + b3hat2*z₃ + b4hat2*z₄
  nlsolver.z = z₅

  nlsolver.tmp = uprev + a51*z₁ + a52*z₂ + a53*z₃ + a54*z₄
  nlsolver.c = 1
  z₅,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  u = nlsolver.tmp + γ*z₅

  ################################### Finalize

  nlsolver.ηold = η
  nlsolver.nl_iters = iter

  if integrator.opts.adaptive
    if alg.embedding == 3
      btilde1 = b1hat2-a51; btilde2 = b2hat2-a52;
      btilde3 = b3hat2-a53; btilde4 = b4hat2-a54; btilde5 = -γ
    else
      btilde1 = b1hat1-a51; btilde2 = b2hat1-a52;
      btilde3 = b3hat1-a53; btilde4 = b4hat1-a54; btilde5 = -γ
    end

    tmp = btilde1*z₁ + btilde2*z₂ + btilde3*z₃ + btilde4*z₄ + btilde5*z₅
    if isnewton(nlsolver) && alg.smooth_est # From Shampine
      est = _reshape(get_W(nlsolver) \ _vec(tmp), axes(tmp))
    else
      est = tmp
    end
    atmp = calculate_residuals(est, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm,t)
    integrator.EEst = integrator.opts.internalnorm(atmp,t)
  end

  integrator.fsallast = z₅./dt
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  integrator.u = u
end

@muladd function perform_step!(integrator, cache::Cash4Cache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack dz,z₁,z₂,z₃,z₄,z₅,k,b,W,tmp,atmp,nlsolver = cache
  @unpack γ,a21,a31,a32,a41,a42,a43,a51,a52,a53,a54,c2,c3,c4 = cache.tab
  @unpack b1hat1,b2hat1,b3hat1,b4hat1,b1hat2,b2hat2,b3hat2,b4hat2 = cache.tab
  alg = unwrap_alg(integrator, true)
  update_W!(integrator, cache, γ*dt, repeat_step)

  ##### Step 1

  # TODO: Add extrapolation for guess
  z₁ .= zero(eltype(z₁))
  nlsolver.z = z₁
  nlsolver.c = γ
  nlsolver.tmp = uprev

  # initial step of NLNewton iteration
  z₁,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  ##### Step 2

  # TODO: Add extrapolation for guess
  z₂ .= zero(eltype(z₂))
  nlsolver.z = z₂

  @. tmp = uprev + a21*z₁
  nlsolver.tmp = tmp
  set_new_W!(nlsolver, false)
  nlsolver.c = c2
  z₂,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  ################################## Solve Step 3

  # Guess starts from z₁
  @. z₃ = z₁
  nlsolver.z = z₃
  @. tmp = uprev + a31*z₁ + a32*z₂
  nlsolver.c = c3
  z₃,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  ################################## Solve Step 4

  # Use constant z prediction
  @. z₄ = z₃
  nlsolver.z = z₄

  @. tmp = uprev + a41*z₁ + a42*z₂ + a43*z₃
  nlsolver.c = c4
  z₄,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  ################################## Solve Step 5

  # Use constant z prediction
  @. z₅ = b1hat2*z₁ + b2hat2*z₂ + b3hat2*z₃ + b4hat2*z₄
  nlsolver.z = z₅
  @. tmp = uprev + a51*z₁ + a52*z₂ + a53*z₃ + a54*z₄
  nlsolver.c = 1
  z₅,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  @. u = tmp + γ*z₅

  ################################### Finalize

  nlsolver.ηold = η
  nlsolver.nl_iters = iter

  if integrator.opts.adaptive
    if alg.embedding == 3
      btilde1 = b1hat2-a51; btilde2 = b2hat2-a52;
      btilde3 = b3hat2-a53; btilde4 = b4hat2-a54; btilde5 = -γ
    else
      btilde1 = b1hat1-a51; btilde2 = b2hat1-a52;
      btilde3 = b3hat1-a53; btilde4 = b4hat1-a54; btilde5 = -γ
    end

    @. dz = btilde1*z₁ + btilde2*z₂ + btilde3*z₃ + btilde4*z₄ + btilde5*z₅
    if alg.smooth_est # From Shampine
      if DiffEqBase.has_invW(f)
        mul!(vec(tmp),W,vec(dz))
      else
        cache.linsolve(vec(tmp),W,vec(dz),false)
      end
    else
      tmp .= dz
    end
    calculate_residuals!(atmp, tmp, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm,t)
    integrator.EEst = integrator.opts.internalnorm(atmp,t)
  end

  @. integrator.fsallast = z₅/dt
end

@muladd function perform_step!(integrator, cache::RK4ThreadedConstantCache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack γ1,γ2,a21,a31,a32,a41,a42,a43,c1,c2,c3,c4 = cache.tab
  @unpack b1,b2,b3,b4 = cache.tab

  nlsolver = cache.nlsolver
  alg = unwrap_alg(integrator, true)

  update_W!(integrator, cache, γ1*dt, repeat_step)
  if(alg.threading == false)
    ##### Step 1
    z₁ = zero(u)
    nlsolver.z = z₁
    nlsolver.tmp = uprev
    nlsolver.c = c1
    z₁,η,iter,fail_convergence = nlsolve!(integrator, cache)
    fail_convergence && return

    ##### Step 2
    z₂ = zero(u)
    nlsolver.z = z₂
    nlsolver.tmp = uprev + a21*z₁
    nlsolver.c = c2
    z₂,η,iter,fail_convergence = nlsolve!(integrator, cache)
    fail_convergence && return

    ################################## Solve Step 3
    nlsolver.γ = γ2
    update_W!(integrator, cache, γ2*dt, repeat_step)

    z₃ = zero(u)
    nlsolver.z = z₃
    nlsolver.tmp = uprev + a31*z₁ + a32*z₂
    nlsolver.c = c3
    z₃,η,iter,fail_convergence = nlsolve!(integrator, cache)
    fail_convergence && return

    ################################## Solve Step 4
    z₄ = zero(u)
    nlsolver.z = z₄
    nlsolver.tmp = uprev + a41*z₁ + a42*z₂ + a43*z₃
    nlsolver.c = c4
    z₄,η,iter,fail_convergence = nlsolve!(integrator, cache)
    fail_convergence && return

    ################################### Finalize
    u = uprev + b1*z₁ + b2*z₂ + b3*z₃ + b4*z₄
  end

  nlsolver.ηold = η
  nlsolver.nl_iters = iter

  integrator.fsallast = f(u, p, t+dt)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  integrator.u = u
end

@muladd function perform_step!(integrator, cache::Hairer4ConstantCache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack γ,a21,a31,a32,a41,a42,a43,a51,a52,a53,a54,c2,c3,c4 = cache.tab
  @unpack α21,α31,α32,α41,α43 = cache.tab
  @unpack bhat1,bhat2,bhat3,bhat4,btilde1,btilde2,btilde3,btilde4,btilde5 = cache.tab
  nlsolver = cache.nlsolver
  alg = unwrap_alg(integrator, true)

  # precalculations
  γdt = γ*dt
  update_W!(integrator, cache, γdt, repeat_step)

  # TODO: Add extrapolation for guess
  z₁ = zero(u)
  nlsolver.z, nlsolver.tmp = z₁, uprev
  nlsolver.c = γ
  z₁,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  ##### Step 2

  z₂ = α21*z₁
  nlsolver.z = z₂
  nlsolver.tmp = uprev + a21*z₁
  nlsolver.c = c2
  z₂,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  ################################## Solve Step 3

  z₃ = α31*z₁ + α32*z₂
  nlsolver.z = z₃
  nlsolver.tmp = uprev + a31*z₁ + a32*z₂
  nlsolver.c = c3
  z₃,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  ################################## Solve Step 4

  z₄ = α41*z₁ + α43*z₃
  nlsolver.z = z₄
  nlsolver.tmp = uprev + a41*z₁ + a42*z₂ + a43*z₃
  nlsolver.c = c4
  z₄,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  ################################## Solve Step 5

  # Use yhat2 for prediction
  z₅ = bhat1*z₁ + bhat2*z₂ + bhat3*z₃ + bhat4*z₄
  nlsolver.z = z₅
  nlsolver.tmp = uprev + a51*z₁ + a52*z₂ + a53*z₃ + a54*z₄
  nlsolver.c = 1
  z₅,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  u = nlsolver.tmp + γ*z₅

  ################################### Finalize

  nlsolver.ηold = η
  nlsolver.nl_iters = iter

  if integrator.opts.adaptive
    tmp = btilde1*z₁ + btilde2*z₂ + btilde3*z₃ + btilde4*z₄ + btilde5*z₅
    if isnewton(nlsolver) && alg.smooth_est # From Shampine
      est = _reshape(get_W(nlsolver) \ _vec(tmp), axes(tmp))
    else
      est = tmp
    end
    atmp = calculate_residuals(est, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm,t)
    integrator.EEst = integrator.opts.internalnorm(atmp,t)
  end

  integrator.fsallast = z₅./dt
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  integrator.u = u
end

@muladd function perform_step!(integrator, cache::Hairer4Cache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack dz,z₁,z₂,z₃,z₄,z₅,k,b,W,jac_config,tmp,atmp,nlsolver = cache
  @unpack γ,a21,a31,a32,a41,a42,a43,a51,a52,a53,a54,c2,c3,c4 = cache.tab
  @unpack α21,α31,α32,α41,α43 = cache.tab
  @unpack bhat1,bhat2,bhat3,bhat4,btilde1,btilde2,btilde3,btilde4,btilde5 = cache.tab
  alg = unwrap_alg(integrator, true)
  update_W!(integrator, cache, γ*dt, repeat_step)

  # initial guess
  if integrator.success_iter > 0 && !integrator.reeval_fsal && alg.extrapolant == :interpolant
    current_extrapolant!(u,t+dt,integrator)
    @. z₁ = u - uprev
  elseif alg.extrapolant == :linear
    @. z₁ = dt*integrator.fsalfirst
  else
    z₁ .= zero(eltype(z₁))
  end
  nlsolver.z = z₁
  nlsolver.tmp = uprev

  ##### Step 1

  nlsolver.c = γ
  z₁,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  ##### Step 2

  @. z₂ = α21*z₁
  nlsolver.z = z₂
  @. tmp = uprev + a21*z₁
  nlsolver.tmp = tmp
  nlsolver.c = c2
  set_new_W!(nlsolver, false)
  z₂,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  ################################## Solve Step 3

  @. z₃ = α31*z₁ + α32*z₂
  nlsolver.z = z₃
  @. tmp = uprev + a31*z₁ + a32*z₂
  nlsolver.c = c3
  z₃,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  ################################## Solve Step 4

  # Use constant z prediction
  @. z₄ = α41*z₁ + α43*z₃
  nlsolver.z = z₄
  @. tmp = uprev + a41*z₁ + a42*z₂ + a43*z₃
  nlsolver.c = c4
  z₄,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  ################################## Solve Step 5

  # Use yhat prediction
  @. z₅ = bhat1*z₁ + bhat2*z₂ + bhat3*z₃ + bhat4*z₄
  nlsolver.z = z₅
  @. tmp = uprev + a51*z₁ + a52*z₂ + a53*z₃ + a54*z₄
  nlsolver.c = 1
  z₅,η,iter,fail_convergence = nlsolve!(integrator, cache)
  fail_convergence && return

  @. u = tmp + γ*z₅

  ################################### Finalize

  nlsolver.ηold = η
  nlsolver.nl_iters = iter

  if integrator.opts.adaptive
    # @. dz = btilde1*z₁ + btilde2*z₂ + btilde3*z₃ + btilde4*z₄ + btilde5*z₅
    @tight_loop_macros for i in eachindex(u)
      dz[i] = btilde1*z₁[i] + btilde2*z₂[i] + btilde3*z₃[i] + btilde4*z₄[i] + btilde5*z₅[i]
    end
    if alg.smooth_est # From Shampine
      if DiffEqBase.has_invW(f)
        mul!(vec(tmp),W,vec(dz))
      else
        cache.linsolve(vec(tmp),W,vec(dz),false)
      end
    else
      tmp .= dz
    end
    calculate_residuals!(atmp, tmp, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm,t)
    integrator.EEst = integrator.opts.internalnorm(atmp,t)
  end

  @. integrator.fsallast = z₅/dt
end
