type RHS_IE_Scalar{F,uType,tType} <: Function
  f::F
  u_old::uType
  t::tType
  dt::tType
end

function (p::RHS_IE_Scalar)(u,resid)
  resid[1] = u[1] - p.u_old[1] - p.dt*p.f(p.t+p.dt,u[1])[1]
end

@inline function initialize!(integrator,cache::ImplicitEulerConstantCache,f=integrator.f)
  cache.uhold[1] = integrator.uprev; cache.u_old[1] = integrator.uprev
  integrator.kshortsize = 2
  integrator.k = eltype(integrator.sol.k)(integrator.kshortsize)
  integrator.fsalfirst = f(integrator.t,integrator.uprev)
end

@inline function perform_step!(integrator,cache::ImplicitEulerConstantCache,f=integrator.f)
  @unpack t,dt,uprev,u,k = integrator
  @unpack uhold,u_old,rhs,nl_rhs = cache
  u_old[1] = uhold[1]
  if integrator.iter > 1 && !integrator.u_modified
    uhold[1] = current_extrapolant(t+dt,integrator)
  end # else uhold is previous value.
  rhs.t = t
  rhs.dt = dt
  nlres = integrator.alg.nlsolve(nl_rhs,uhold)
  uhold[1] = nlres[1]
  k = f(t+dt,uhold[1])
  integrator.fsallast = k
  u = uhold[1]
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = k
  @pack integrator = t,dt,u
end

type RHS_IE{F,uType,tType,DiffEqDiffTools.DiffCacheType,SizeType,uidxType} <: Function
  f::F
  u_old::uType
  t::tType
  dt::tType
  dual_cache::DiffEqDiffTools.DiffCacheType
  sizeu::SizeType
  uidx::uidxType
end
function (p::RHS_IE)(uprev,resid)
  du = DiffEqDiffTools.get_du(p.dual_cache, eltype(uprev))
  p.f(p.t+p.dt,reshape(uprev,p.sizeu),du)
  for i in p.uidx
    resid[i] = uprev[i] - p.u_old[i] - p.dt*du[i]
  end
end

@inline function initialize!(integrator,cache::ImplicitEulerCache,f=integrator.f)
  integrator.fsalfirst = cache.fsalfirst
  integrator.fsallast = cache.k
  f(integrator.t,integrator.uprev,integrator.fsalfirst)
  integrator.kshortsize = 2
  integrator.k = eltype(integrator.sol.k)(integrator.kshortsize)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
end

@inline function perform_step!(integrator,cache::ImplicitEulerCache,f=integrator.f)
  @unpack t,dt,uprev,u,k = integrator
  uidx = eachindex(integrator.uprev)
  @unpack u_old,dual_cache,k,nl_rhs,rhs,uhold = cache
  copy!(u_old,uhold)
  if integrator.iter > 1 && !integrator.u_modified
    current_extrapolant!(uhold,t+dt,integrator)
  end # else uhold is previous value.
  rhs.t = t
  rhs.dt = dt
  rhs.uidx = uidx
  rhs.sizeu = size(u)
  nlres = integrator.alg.nlsolve(nl_rhs,uhold)
  copy!(uhold,nlres)
  f(t+dt,u,k)
  @pack integrator = t,dt,u
end

type RHS_Trap{F,uType,rateType,tType,SizeType,DiffEqDiffTools.DiffCacheType,uidxType} <: Function
  f::F
  u_old::uType
  f_old::rateType
  t::tType
  dt::tType
  sizeu::SizeType
  dual_cache::DiffEqDiffTools.DiffCacheType
  uidx::uidxType
end

function (p::RHS_Trap)(uprev,resid)
  du1 = DiffEqDiffTools.get_du(p.dual_cache, eltype(uprev))
  p.f(p.t+p.dt,reshape(uprev,p.sizeu),du1)
  for i in p.uidx
    resid[i] = @muladd uprev[i] - p.u_old[i] - (p.dt/2)*(du1[i]+p.f_old[i])
  end
end

@inline function initialize!(integrator,cache::TrapezoidCache,f=integrator.f)
  @unpack k,fsalfirst = cache
  integrator.fsalfirst = fsalfirst
  integrator.fsallast = cache.k
  f(integrator.t,integrator.uprev,integrator.fsalfirst)
  integrator.kshortsize = 2
  integrator.k = eltype(integrator.sol.k)(integrator.kshortsize)
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
end

@inline function perform_step!(integrator,cache::TrapezoidCache,f=integrator.f)
  @unpack t,dt,uprev,u,k = integrator
  uidx = eachindex(integrator.uprev)
  @unpack u_old,dual_cache,k,rhs,nl_rhs,uhold = cache
  copy!(u_old,uhold)
  if integrator.iter > 1 && !integrator.u_modified
    current_extrapolant!(uhold,t+dt,integrator)
  end # else uhold is previous value.
  # copy!(rhs.fsalfirst,fsalfirst) Implicitly done by pointers: fsalfirst === fsalfirst == rhs.fsalfirst
  rhs.t = t
  rhs.dt = dt
  rhs.uidx = uidx
  rhs.sizeu = size(u)
  nlres = integrator.alg.nlsolve(nl_rhs,uhold)
  copy!(uhold,nlres)
  f(t+dt,u,k)
  @pack integrator = t,dt,u
end

type RHS_Trap_Scalar{F,uType,rateType,tType} <: Function
  f::F
  u_old::uType
  f_old::rateType
  t::tType
  dt::tType
end

function (p::RHS_Trap_Scalar)(uprev,resid)
  resid[1] = @muladd uprev[1] - p.u_old[1] - (p.dt/2)*(p.f_old + p.f(p.t+p.dt,uprev[1])[1])
end

@inline function initialize!(integrator,cache::TrapezoidConstantCache,f=integrator.f)
  cache.uhold[1] = integrator.uprev; cache.u_old[1] = integrator.uprev
  integrator.fsalfirst = f(integrator.t,integrator.uprev)
  integrator.kshortsize = 2
  integrator.k = eltype(integrator.sol.k)(integrator.kshortsize)
end

@inline function perform_step!(integrator,cache::TrapezoidConstantCache,f=integrator.f)
  @unpack t,dt,uprev,u,k = integrator
  @unpack uhold,u_old,rhs,nl_rhs = cache
  u_old[1] = uhold[1]
  if integrator.iter > 1 && !integrator.u_modified
    uhold[1] = current_extrapolant(t+dt,integrator)
  end # else uhold is previous value.
  rhs.t = t
  rhs.dt = dt
  rhs.f_old = integrator.fsalfirst
  nlres = integrator.alg.nlsolve(nl_rhs,uhold)
  uhold[1] = nlres[1]
  k = f(t+dt,uhold[1])
  integrator.fsallast = k
  u = uhold[1]
  integrator.k[1] = integrator.fsalfirst
  integrator.k[2] = integrator.fsallast
  @pack integrator = t,dt,u
end
