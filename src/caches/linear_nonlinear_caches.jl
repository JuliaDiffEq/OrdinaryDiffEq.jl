struct GenericIIF1ConstantCache{vecuType,rhsType,nl_rhsType} <: OrdinaryDiffEqConstantCache
  uhold::vecuType
  rhs::rhsType
  nl_rhs::nl_rhsType
end

struct GenericIIF1Cache{uType,DiffCacheType,rhsType,nl_rhsType,rateType,expType} <: OrdinaryDiffEqMutableCache
  u::uType
  uprev::uType
  dual_cache::DiffCacheType
  tmp::uType
  rhs::rhsType
  nl_rhs::nl_rhsType
  rtmp1::rateType
  fsalfirst::rateType
  expA::expType
  k::rateType
end

u_cache(c::GenericIIF1Cache)    = ()
du_cache(c::GenericIIF1Cache)   = (c.rtmp1,c.fsalfirst,c.k)
dual_cache(c::GenericIIF1Cache) = (c.dual_cache,)

function alg_cache(alg::GenericIIF1,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{false}})
  uhold = Vector{typeof(u)}(1)
  rhs = RHS_IIF_Scalar(f,zero(u),t,t,one(uEltypeNoUnits),p)
  nl_rhs = alg.nlsolve(Val{:init},rhs,uhold)
  GenericIIF1ConstantCache(uhold,rhs,nl_rhs)
end

function alg_cache(alg::GenericIIF1,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{true}})
  tmp = similar(u,indices(u)); rtmp1 = zeros(rate_prototype)
  dual_cache = DiffCache(u,Val{determine_chunksize(u,get_chunksize(alg.nlsolve))})
  A = f.f1
  expA = expm(A*dt)
  rhs = RHS_IIF(f,tmp,t,t,uEltypeNoUnits(1//1),dual_cache,p)
  k = similar(rate_prototype); fsalfirst = similar(rate_prototype)
  nl_rhs = alg.nlsolve(Val{:init},rhs,u)
  GenericIIF1Cache(u,uprev,dual_cache,tmp,rhs,nl_rhs,rtmp1,fsalfirst,expA,k)
end

struct GenericIIF2ConstantCache{vecuType,rhsType,nl_rhsType} <: OrdinaryDiffEqConstantCache
  uhold::vecuType
  rhs::rhsType
  nl_rhs::nl_rhsType
end

struct GenericIIF2Cache{uType,DiffCacheType,rhsType,nl_rhsType,rateType,expType} <: OrdinaryDiffEqMutableCache
  u::uType
  uprev::uType
  dual_cache::DiffCacheType
  tmp::uType
  rhs::rhsType
  nl_rhs::nl_rhsType
  rtmp1::rateType
  fsalfirst::rateType
  expA::expType
  k::rateType
end

u_cache(c::GenericIIF2Cache)    = ()
du_cache(c::GenericIIF2Cache)   = (c.rtmp1,c.fsalfirst,c.k)
dual_cache(c::GenericIIF2Cache) = (c.dual_cache,)

function alg_cache(alg::GenericIIF2,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{false}})
  uhold = Vector{typeof(u)}(1)
  tmp = zero(u)
  rhs = RHS_IIF_Scalar(f,tmp,t,t,uEltypeNoUnits(1//2),p)
  nl_rhs = alg.nlsolve(Val{:init},rhs,uhold)
  GenericIIF2ConstantCache(uhold,rhs,nl_rhs)
end

function alg_cache(alg::GenericIIF2,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{true}})
  tmp = similar(u,indices(u)); rtmp1 = zeros(rate_prototype)
  dual_cache = DiffCache(u,Val{determine_chunksize(u,get_chunksize(alg.nlsolve))})
  A = f.f1
  expA = expm(A*dt)
  k = similar(rate_prototype); fsalfirst = similar(rate_prototype)
  rhs = RHS_IIF(f,tmp,t,t,uEltypeNoUnits(1//2),dual_cache,p)
  nl_rhs = alg.nlsolve(Val{:init},rhs,u)
  GenericIIF2Cache(u,uprev,dual_cache,tmp,rhs,nl_rhs,rtmp1,fsalfirst,expA,k)
end

struct LawsonEulerCache{uType,rateType,expType} <: OrdinaryDiffEqMutableCache
  u::uType
  uprev::uType
  tmp::uType
  k::rateType
  rtmp::rateType
  expA::expType
  fsalfirst::rateType
end

function alg_cache(alg::LawsonEuler,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{true}})
  A = f.f1
  expA = expm(A*dt)
  LawsonEulerCache(u,uprev,similar(u),zeros(rate_prototype),zeros(rate_prototype),expA,zeros(rate_prototype))
end

u_cache(c::LawsonEulerCache) = ()
du_cache(c::LawsonEulerCache) = (c.k,c.fsalfirst,c.rtmp)

struct LawsonEulerConstantCache <: OrdinaryDiffEqConstantCache end

alg_cache(alg::LawsonEuler,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{false}}) = LawsonEulerConstantCache()

struct NorsettEulerCache{uType,rateType,expType} <: OrdinaryDiffEqMutableCache
  u::uType
  uprev::uType
  tmp::uType
  k::rateType
  rtmp::rateType
  expA::expType
  phi1::expType
  fsalfirst::rateType
end

function alg_cache(alg::NorsettEuler,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{true}})
  A = f.f1
  if typeof(A.A) <: Diagonal
      _expA = expm(A*dt)
      phi1 = Diagonal(Float64.((big.(_expA)-I)/A.A))
      expA = Diagonal(_expA)

      # Fix zero eigenvalues
      for i in 1:size(phi1,1)
          phi1[i,i] = ifelse(A[i,i]==0,dt,phi1[i,i])
      end

  else
      expA = expm(A*dt)
      phi1 = ((expA-I)/A)
  end
  NorsettEulerCache(u,uprev,similar(u),zeros(rate_prototype),zeros(rate_prototype),expA,phi1,zeros(rate_prototype))
end

u_cache(c::NorsettEulerCache) = ()
du_cache(c::NorsettEulerCache) = (c.k,c.fsalfirst)

struct NorsettEulerConstantCache <: OrdinaryDiffEqConstantCache end

alg_cache(alg::NorsettEuler,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{false}}) = NorsettEulerConstantCache()

struct ETDRK4ConstantCache{matType} <: OrdinaryDiffEqMutableCache
  E::matType
  E2::matType
  a::matType
  b::matType
  c::matType
  Q::matType
end

function alg_cache(alg::ETDRK4,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{false}})
  A = f.f1
  E,E2,a,b,c,Q = get_etdrk4_oop_operators(dt,A.A)
  ETDRK4ConstantCache(E,E2,a,b,c,Q)
end

function get_etdrk4_oop_operators(_h,L)
  h = big(_h)
  A = h*L
  _E2 = expm(Float64.(A/2))
  E2 = big.(_E2);
  E = E2*E2
  A = big.(A)
  coeff = h^(-2) * L^(-3)
  A2 = A^2
  if typeof(L) <: Number
    Q = Float64.((E2-1)/L)
    a = Float64.(coeff * (-4 - A + E*(4 - 3A  + A2)))
    b = Float64.(coeff * (2 + A + E*(-2 + A)))
    c = Float64.(coeff * (-4 - 3A - A2 + E*(4-A)))
  else
    Q = Float64.((E2-I)/L)
    a = Float64.(coeff * (-4I - A + E*(4I - 3A  + A2)))
    b = Float64.(coeff * (2I + A + E*(-2I + A)))
    c = Float64.(coeff * (-4I - 3A - A2 + E*(4I-A)))
  end
  Float64.(E),_E2,a,b,c,Q
end

struct ETDRK4Cache{uType,rateType,matType} <: OrdinaryDiffEqMutableCache
  u::uType
  uprev::uType
  tmp::uType
  s1::uType
  tmp2::rateType
  k1::rateType
  k2::rateType
  k3::rateType
  k4::rateType
  fsalfirst::rateType
  E::matType
  E2::matType
  a::matType
  b::matType
  c::matType
  Q::matType
end

function alg_cache(alg::ETDRK4,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{true}})
  A = f.f1
  tmp = similar(u)
  tmp2 = zeros(rate_prototype); fsalfirst = zeros(rate_prototype)
  k1 = zeros(rate_prototype); k2 = zeros(rate_prototype)
  k3 = zeros(rate_prototype); k4 = zeros(rate_prototype)
  s1 = similar(u)
  E,E2,a,b,c,Q = get_etdrk4_operators(dt,A.A)
  ETDRK4Cache(u,uprev,tmp,s1,tmp2,k1,k2,k3,k4,fsalfirst,E,E2,a,b,c,Q)
end

u_cache(c::ETDRK4Cache) = ()
du_cache(c::ETDRK4Cache) = (c.k,c.fsalfirst,c.rtmp)

function get_etdrk4_operators(_h,L)

    @. L .*= _h/2
    _E2 = expm(L)
    E2 = big.(_E2);
    E = E2*E2
    @. L *= 2/_h
    h = big(_h)
    A = h*L

    # TODO: Check if we should big L
    coeff = h^(-2) * L^(-3)

    @inbounds for i in 1:size(E2,1)
        E2[i,i] = E2[i,i] - 1
    end

    tmp = E2/L
    Q = Float64.(tmp)

    @inbounds for i in 1:size(E2,1)
        E2[i,i] = E2[i,i] + 1
    end

    @inbounds for i in 1:size(A,2), j in 1:size(A,1)
        tmp[j,i] = -2I[j,i] + A[j,i]
    end

    tmp2 = E*tmp

    @inbounds for i in 1:size(A,2), j in 1:size(A,1)
        tmp[j,i] = 2I[j,i] + A[j,i] + tmp2[j,i]
    end

    A_mul_B!(tmp2,coeff,tmp)
    b = Float64.(tmp2)

    A2 = A^2

    @inbounds for i in 1:size(A,2), j in 1:size(A,1)
        tmp[j,i] = 4I[j,i] - 3A[j,i]  + A2[j,i]
    end

    A_mul_B!(tmp2,E,tmp)

    @inbounds for i in 1:size(A,2), j in 1:size(A,1)
        tmp[j,i] = -4I[j,i] - A[j,i] + tmp2[j,i]
    end

    A_mul_B!(tmp2,coeff,tmp)
    a = Float64.(tmp2)

    @inbounds for i in 1:size(A,2), j in 1:size(A,1)
        tmp[j,i] = 4I[j,i]-A[j,i]
    end

    A_mul_B!(tmp2,E,tmp)

    @inbounds for i in 1:size(A,2), j in 1:size(A,1)
        tmp[j,i] = -4I[j,i] - 3A[j,i] - A2[j,i] + tmp2[j,i]
    end

    A_mul_B!(tmp2,coeff,tmp)
    c = Float64.(tmp2)

    Float64.(E),_E2,a,b,c,Q
end

function get_etdrk4_operators(_h,_L::Diagonal)

    L = _L.diag

    @. L = _h/2*L
    _E2 = exp.(L)
    E2 = big.(_E2);
    E = E2.*E2
    @. L *= 2/_h
    h = big(_h)
    A = h.*L

    coeff = @. h^(-2) * L^(-3)
    A2 = A.^2

    Q = @. Float64((E2-1)/L)
    a = @. Float64(coeff * (-4 - A + E*(4 - 3A  + A2)))
    b = @. Float64(coeff * (2 + A + E*(-2 + A)))
    c = @. Float64(coeff * (-4 - 3A - A2 + E*(4-A)))

    # Fix zero eigenvalues, use limit equations
    for i in 1:length(Q)
        if L[i] == 0
            Q[i] = _h/2
            tmp = _h/6
            a[i] = tmp
            b[i] = tmp
            c[i] = tmp
        end
    end

    Diagonal(Float64.(E)),Diagonal(Float64.(E2)),Diagonal(a),Diagonal(b),Diagonal(c),Diagonal(Q)
end

struct LawsonEulerKrylovCache{uType,rateType} <: OrdinaryDiffEqMutableCache
  u::uType
  uprev::uType
  tmp::uType
  k::rateType
  rtmp::rateType
  fsalfirst::rateType
end

function alg_cache(alg::LawsonEulerKrylov,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{true}})
  LawsonEulerKrylovCache(u,uprev,similar(u),zeros(rate_prototype),zeros(rate_prototype),zeros(rate_prototype))
end

u_cache(c::LawsonEulerKrylovCache) = ()
du_cache(c::LawsonEulerKrylovCache) = (c.k,c.fsalfirst,c.rtmp)

struct LawsonEulerKrylovConstantCache <: OrdinaryDiffEqConstantCache end

alg_cache(alg::LawsonEulerKrylov,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{false}}) = LawsonEulerKrylovConstantCache()

struct ExpEulerKrylovCache{uType,rateType} <: OrdinaryDiffEqMutableCache
  u::uType
  uprev::uType
  tmp::uType
  k::rateType
  rtmp::rateType
  fsalfirst::rateType
end

function alg_cache(alg::ExpEulerKrylov,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{true}})
  ExpEulerKrylovCache(u,uprev,similar(u),zeros(rate_prototype),zeros(rate_prototype),zeros(rate_prototype))
end

u_cache(c::ExpEulerKrylovCache) = ()
du_cache(c::ExpEulerKrylovCache) = (c.k,c.fsalfirst,c.rtmp)

struct ExpEulerKrylovConstantCache <: OrdinaryDiffEqConstantCache end

alg_cache(alg::ExpEulerKrylov,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{false}}) = ExpEulerKrylovConstantCache()
