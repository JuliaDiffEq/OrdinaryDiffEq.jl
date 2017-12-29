function initialize!(integrator, cache::LinearImplicitEulerConstantCache)
  integrator.kshortsize = 2
  integrator.k = typeof(integrator.k)(integrator.kshortsize)
  integrator.fsalfirst = integrator.f(integrator.t, integrator.uprev) # Pre-start fsal

  # Avoid undefined entries if k is an array of arrays
  integrator.fsallast = zero(integrator.fsalfirst)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
end

@muladd function perform_step!(integrator, cache::LinearImplicitEulerConstantCache, repeat_step=false)
  @unpack t,dt,uprev,u,k = integrator

  L = update_coefficients(integrator.f,t+dt,u)

  if typeof(uprev) <: AbstractArray
    W = I - dt*L
  else
    W = 1 - dt*L
  end

  # if Bs
  k = uprev

  u = W\k

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

    tmp = @. r*abs((u - uprev)/dt1 - (uprev - uprev2)/dt2)
    atmp = calculate_residuals(tmp, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  else
    integrator.EEst = 1
  end

  integrator.fsallast = f(t+dt,u)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  integrator.u = u
end

function initialize!(integrator, cache::LinearImplicitEulerCache)
  integrator.kshortsize = 2
  integrator.fsalfirst = cache.fsalfirst
  integrator.fsallast = cache.k
  resize!(integrator.k, integrator.kshortsize)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  integrator.f(integrator.t, integrator.uprev, integrator.fsalfirst) # For the interpolation, needs k at the updated point
end

@muladd function perform_step!(integrator, cache::LinearImplicitEulerCache, repeat_step=false)
  @unpack t,dt,uprev,u = integrator
  @unpack W,k,tmp,atmp = cache
  mass_matrix = integrator.sol.prob.mass_matrix

  L = integrator.f
  update_coefficients!(L,t+dt,u)

  if typeof(L) <: AbstractDiffEqLinearOperator

      # Of the form u' = A(t)u

      # Check is_constant before redoing
      for j in 1:length(u), i in 1:length(u)
          @inbounds W[i,j] = @muladd mass_matrix[i,j]-dt*L[i,j]
      end
      k .= uprev # + B
  else # Must be a DiffEqAffineOperator

      # Of the form u' = A(t)u + B(t)
      # Generalize later!
      A = L.As[1]
      B = L.Bs[1]

      for j in 1:length(u), i in 1:length(u)
          @inbounds W[i,j] = @muladd mass_matrix[i,j]-dt*A[i,j]
      end
      @. k = uprev + dt*B
  end

  cache.linsolve(vec(u), W, vec(k), true)

  if integrator.opts.adaptive && integrator.success_iter > 0
    # local truncation error (LTE) bound by dt^2/2*max|y''(t)|
    # use 2nd divided differences (DD) a la SPICE and Shampine

    # TODO: check numerical stability
    uprev2 = integrator.uprev2
    tprev = integrator.tprev

    dt1 = (dt)*(t+dt-tprev)
    dt2 = (t-tprev)*(t+dt-tprev)
    c = 7/12 # default correction factor in SPICE (LTE overestimated by DD)
    r = c*dt^2 # by mean value theorem 2nd DD equals y''(s)/2 for some s

    @. tmp = r*abs((u - uprev)/dt1 - (uprev - uprev2)/dt2)
    calculate_residuals!(atmp, tmp, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  else
    integrator.EEst = 1
  end

  f(t+dt,u,integrator.fsallast)
end

function initialize!(integrator, cache::MidpointSplittingCache)
  integrator.kshortsize = 2
  integrator.fsalfirst = cache.fsalfirst
  integrator.fsallast = cache.k
  resize!(integrator.k, integrator.kshortsize)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  integrator.f(integrator.t, integrator.uprev, integrator.fsalfirst) # For the interpolation, needs k at the updated point
end

function perform_step!(integrator, cache::MidpointSplittingCache, repeat_step=false)
  @unpack t,dt,uprev,u = integrator
  @unpack W,k,tmp = cache
  mass_matrix = integrator.sol.prob.mass_matrix

  L = integrator.f
  update_coefficients!(L,t+dt/2,u)

  A = L.As[1]
  Bs = L.As[2:end]

  copy!(tmp, uprev)
  for B in reverse(Bs)
    propagate!(u, B, dt/2, tmp)
    @swap!(tmp,u)
  end

  propagate!(u, A, dt, tmp)

  for B in Bs
    propagate!(tmp, B, dt/2, u)
    @swap!(u,tmp)
  end

  f(t+dt,u,integrator.fsallast)
end

function propagate!(v, L, t, u)
  if has_expmv!(L)
    expmv!(v, L, t, u)
  elseif has_expmv(L)
    v .= expmv(L, t, u)
  elseif has_expm(L)
    v .= expm(L, t)*u
  else
    error("No way to propagate an operator of type $(typeof(L)) (did you provide an exponentiation algorithm?)")
  end
end
