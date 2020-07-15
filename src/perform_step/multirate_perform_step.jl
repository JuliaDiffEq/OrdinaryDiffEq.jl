get_a21(tab::OrdinaryDiffEqTableau{T,T2}) where {T,T2} = hasfield(typeof(tab), :a21) ? tab.a21 : zero(T)
get_a31(tab::OrdinaryDiffEqTableau{T,T2}) where {T,T2} = hasfield(typeof(tab), :a31) ? tab.a31 : zero(T)
get_a32(tab::OrdinaryDiffEqTableau{T,T2}) where {T,T2} = hasfield(typeof(tab), :a32) ? tab.a32 : zero(T)
get_a41(tab::OrdinaryDiffEqTableau{T,T2}) where {T,T2} = hasfield(typeof(tab), :a41) ? tab.a41 : zero(T)
get_a42(tab::OrdinaryDiffEqTableau{T,T2}) where {T,T2} = hasfield(typeof(tab), :a42) ? tab.a42 : zero(T)
get_a43(tab::OrdinaryDiffEqTableau{T,T2}) where {T,T2} = hasfield(typeof(tab), :a43) ? tab.a43 : zero(T)
get_btilde1(tab::OrdinaryDiffEqTableau{T,T2}) where {T,T2} = hasfield(typeof(tab), :btilde1) ? tab.btilde1 : zero(T)
get_btilde2(tab::OrdinaryDiffEqTableau{T,T2}) where {T,T2} = hasfield(typeof(tab), :btilde2) ? tab.btilde2 : zero(T)
get_btilde3(tab::OrdinaryDiffEqTableau{T,T2}) where {T,T2} = hasfield(typeof(tab), :btilde3) ? tab.btilde3 : zero(T)
get_btilde4(tab::OrdinaryDiffEqTableau{T,T2}) where {T,T2} = hasfield(typeof(tab), :btilde4) ? tab.btilde4 : zero(T)
get_c1(tab::OrdinaryDiffEqTableau{T,T2}) where {T,T2} = hasfield(typeof(tab), :c1) ? tab.c1 : zero(T2)
get_c2(tab::OrdinaryDiffEqTableau{T,T2}) where {T,T2} = hasfield(typeof(tab), :c2) ? tab.c2 : zero(T2)

function initialize!(integrator, cache::Rice3ConstantCache)
  integrator.kshortsize = 2
  integrator.k = typeof(integrator.k)(undef, integrator.kshortsize)
  integrator.fsalfirst = integrator.f(integrator.uprev, integrator.p, integrator.t) # Pre-start fsal
  integrator.destats.nf += 1

  # Avoid undefined entries if k is an array of arrays
  integrator.fsallast = zero(integrator.fsalfirst)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
end

@muladd function perform_step!(integrator, cache::Rice3ConstantCache, repeat_step=false)
  @unpack t,dt,uprev,u,p = integrator
  f, g = integrator.f.f1, integrator.f.f2
  K = integrator.alg.K
  xprev, yprev = uprev.x[1], uprev.x[2]
  a21 = get_a21(cache.tab)
  a31 = get_a31(cache.tab)
  a32 = get_a32(cache.tab)
  a41 = get_a41(cache.tab)
  a42 = get_a42(cache.tab)
  a43 = get_a43(cache.tab)
  c1  = get_c1(cache.tab)
  c2  = get_c2(cache.tab)
  # slow time stepping
  k1, h1 = integrator.fsalfirst.x[1], integrator.fsalfirst.x[2]
  k2 = f(xprev + dt*a21*k1, yprev + dt*a21*h1, p, t+c1*dt)
  h2 = g(xprev + dt*a21*k1, yprev + dt*a21*h1, p, t+c1*dt)
  k3 = f(xprev + dt*a31*k1 + dt*a32*k2, yprev + dt*a31*h1 + dt*a32*h2, p, t+c2*dt)
  h3 = g(xprev + dt*a31*k1 + dt*a32*k2, yprev + dt*a31*h1 + dt*a32*h2, p, t+c2*dt)
  x = xprev + dt * (a41*k1 + a42*k2 + a43*k3)

  # slow time stepping
  h = dt/K
  xj = xprev
  yj = yprev
  for j in 1:K
    # don't delete these comments
    # tj = t+j*h
    # d1 = h*g(xj, yj, tj)
    # d2 = h*g(xj + λ4(j) * k1 + λ5(j) * k2 + λ6(j) * k3, yj + μ1 * d1, tj + μ1*h)
    # d3 = h*g(xj + λ7(j) * k1 + λ8(j) * k2 + λ9(j) * k3, yj + μ3 * d1 + (μ2 - μ3) * d2, tj + μ2*h)
    # yj = yj + α1 * d1 + α2 * d2 + α3 * d3
    tj = t + j * h

    λ1 = j / K
    λ5 = 2 * (1 + 3j) / (9 * K * K * a21)
    λ4 = 2 / (3K) - λ5

    d1 = h * g(xj, yj, p, tj)
    d2 = h * g(xj + λ4 * k1 + λ5 * k2, yj + (2//3) * d1, p, tj + (2//3)*h)
    d3 = h * g(xj, yj + d2 - d1, p, tj)

    yj = yj + (3//4) * d2 + (1//4) * d3
    xj = xprev + λ1 * k1
  end
  y = yj
  k4 = f(x, y, p, t+dt)
  h4 = f(x, y, p, t+dt)
  integrator.fsallast = ArrayPartition(k4, h4)
  if integrator.opts.adaptive
    btilde1 = get_btilde1(cache.tab)
    btilde2 = get_btilde2(cache.tab)
    btilde3 = get_btilde3(cache.tab)
    btilde4 = get_btilde4(cache.tab)
    xtilde = dt*(btilde1*k1 + btilde2*k2 + btilde3*k3 + btilde4*k4)
    ytilde = dt*(btilde1*h1 + btilde2*h2 + btilde3*h3 + btilde4*h4)
    utilde = ArrayPartition(xtilde, ytilde)
    atmp = calculate_residuals(utilde, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm,t)
    integrator.EEst = integrator.opts.internalnorm(atmp,t)
  end
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  integrator.u = ArrayPartition(x, y)
end

function initialize!(integrator, cache::Rice3Cache)
  integrator.kshortsize = 2
  resize!(integrator.k, integrator.kshortsize)
  integrator.fsalfirst = cache.fsalfirst  # done by pointers, no copying
  integrator.fsallast = ArrayPartition(cache.k4, cache.h4)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  integrator.f(integrator.fsalfirst, integrator.uprev, integrator.p, integrator.t) # Pre-start fsal
  integrator.destats.nf += 1
end

@muladd function perform_step!(integrator, cache::Rice3Cache, repeat_step=false)
  @unpack t,dt,uprev,u,p = integrator
  f, g = integrator.f.f1, integrator.f.f2
  a21 = get_a21(cache.tab)
  a31 = get_a31(cache.tab)
  a32 = get_a32(cache.tab)
  a41 = get_a41(cache.tab)
  a42 = get_a42(cache.tab)
  a43 = get_a43(cache.tab)
  c1  = get_c1(cache.tab)
  c2  = get_c2(cache.tab)
  @unpack k2,k3,k4,h2,h3,h4,d1,d2,d3,utilde,tmp,tmp2,atmp = cache
  K = integrator.alg.K

  xtmp, ytmp = tmp.x[1], tmp.x[2]
  xtmp2, ytmp2 = tmp2.x[1], tmp2.x[2]
  xprev, yprev = uprev.x[1], uprev.x[2]
  x, y = u.x[1], u.x[2]

  # fast time stepping
  k1, h1 = integrator.fsalfirst.x[1], integrator.fsalfirst.x[2]
  @.. xtmp = xprev + dt * a21 * k1
  @.. ytmp = yprev + dt * a21 * h1
  f(k2, xtmp, ytmp, p, t + c1 * dt)
  g(h2, xtmp, ytmp, p, t + c1 * dt)

  @.. xtmp = xprev + dt * a31 * k1 + dt * a32 * k2
  @.. ytmp = yprev + dt * a31 * h1 + dt * a32 * h2
  f(k3, xtmp, ytmp, p, t + c2 * dt)
  g(h3, xtmp, ytmp, p, t + c2 * dt)

  @.. x = xprev + dt * (a41 * k1 + a42 * k2 + a43 * k3)

  # slow time stepping
  h = dt/K
  xj = xtmp
  xj .= xprev
  yj = ytmp
  yj .= yprev
  for j in 1:K
    tj = t + j * h
    λ1 = j / K
    λ5 = 2 * (1 + 3j) / (9 * K * K * a21)
    λ4 = 2 / (3K) - λ5

    g(d1, xj, yj, p, tj)

    @.. xtmp2 = xj + λ4 * k1 + λ5 * k2
    @.. ytmp2 = yj + (2//3) * h * d1
    g(d2, xtmp2, ytmp2, p, tj + (2//3) * h)

    @.. ytmp2 = yj + h * d2 - h * d1
    g(d3, xj, ytmp2, p, tj)

    @.. yj = yj + (3//4) * h * d2 + (1//4) * h * d3
    @.. xj = xprev + λ1 * k1
  end
  y .= yj

  f(k4, x, y, p, t + dt)
  g(h4, x, y, p, t + dt)

  if integrator.opts.adaptive
    btilde1 = get_btilde1(cache.tab)
    btilde2 = get_btilde2(cache.tab)
    btilde3 = get_btilde3(cache.tab)
    btilde4 = get_btilde4(cache.tab)
    xtilde, ytilde = utilde.x[1], utilde.x[2]
    @.. xtilde = dt*(btilde1*k1 + btilde2*k2 + btilde3*k3 + btilde4*k4)
    @.. ytilde = dt*(btilde1*h1 + btilde2*h2 + btilde3*h3 + btilde4*h4)
    calculate_residuals!(atmp, ArrayPartition(xtilde, ytilde), uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm,t)
    integrator.EEst = integrator.opts.internalnorm(atmp,t)
  end
end
