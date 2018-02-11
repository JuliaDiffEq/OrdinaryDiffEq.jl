@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::FunctionMapConstantCache,idxs,T::Type{Val{0}})
  y₀
end

@muladd function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::FunctionMapCache,idxs,T::Type{Val{0}})
  recursivecopy!(out,y₀)
end

"""
Hairer Norsett Wanner Solving Ordinary Differential Euations I - Nonstiff Problems Page 192
"""
@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::DP5ConstantCache,idxs::Void,T::Type{Val{0}})
  Θ1 = 1-Θ
  #@. y₀ + dt*Θ*(k[1]+Θ1*(k[2]+Θ*(k[3]+Θ1*k[4])))
  y₀ + dt*Θ*(k[1]+Θ1*(k[2]+Θ*(k[3]+Θ1*k[4])))
end

@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::DP5ConstantCache,idxs,T::Type{Val{0}})
  Θ1 = 1-Θ
  #@. y₀ + dt*Θ*(k[1]+Θ1*(k[2]+Θ*(k[3]+Θ1*k[4])))
  y₀[idxs] + dt*Θ*(k[1][idxs]+Θ1*(k[2][idxs]+Θ*(k[3][idxs]+Θ1*k[4][idxs])))
end

@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::DP5ConstantCache,idxs::Void,T::Type{Val{1}})
  #@. k[1] + k[2]*(1 - 2*Θ) + Θ*(2*k[3] + 2*k[4] + Θ*(-3*k[3] - 6*k[4] + 4*k[4]*Θ))
  k[1] + k[2]*(1 - 2*Θ) + Θ*(2*k[3] + 2*k[4] + Θ*(-3*k[3] - 6*k[4] + 4*k[4]*Θ))
end

@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::DP5ConstantCache,idxs,T::Type{Val{1}})
  #@. k[1] + k[2]*(1 - 2*Θ) + Θ*(2*k[3] + 2*k[4] + Θ*(-3*k[3] - 6*k[4] + 4*k[4]*Θ))
  k[1][idxs] + k[2][idxs]*(1 - 2*Θ) + Θ*(2*k[3][idxs] + 2*k[4][idxs] + Θ*(-3*k[3][idxs] - 6*k[4][idxs] + 4*k[4][idxs]*Θ))
end

"""
Hairer Norsett Wanner Solving Ordinary Differential Euations I - Nonstiff Problems Page 192
"""
@muladd function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::Union{DP5Cache,DP5ThreadedCache},idxs,T::Type{Val{0}})
  Θ1 = 1-Θ
  if out == nothing
    if idxs == nothing
      return @. y₀ + dt*Θ*(k[1]+Θ1*(k[2]+Θ*(k[3]+Θ1*k[4])))
    else
      return @. y₀[idxs] + dt*Θ*(k[1][idxs]+Θ1*(k[2][idxs]+Θ*(k[3][idxs]+Θ1*k[4][idxs])))
    end
  elseif idxs == nothing
    @. out = y₀ + dt*Θ*(k[1]+Θ1*(k[2]+Θ*(k[3]+Θ1*k[4])))
  else
    @views @. out = y₀[idxs] + dt*Θ*(k[1][idxs]+Θ1*(k[2][idxs]+Θ*(k[3][idxs]+Θ1*k[4][idxs])))
  end
end

@muladd function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::Union{DP5Cache,DP5ThreadedCache},idxs,T::Type{Val{1}})
  if out == nothing
    if idxs == nothing
      # return @. k[1] + k[2]*(1 - 2*Θ) + Θ*(2*k[3] + 2*k[4] + Θ*(-3*k[3] - 6*k[4] + 4*k[4]*Θ))
      return k[1] + k[2]*(1 - 2*Θ) + Θ*(2*k[3] + 2*k[4] + Θ*(-3*k[3] - 6*k[4] + 4*k[4]*Θ))
    else
      # return @. k[1][idxs] + k[2][idxs]*(1 - 2*Θ) + Θ*(2*k[3][idxs] + 2*k[4][idxs] + Θ*(-3*k[3][idxs] - 6*k[4][idxs] + 4*k[4][idxs]*Θ))
      return k[1][idxs] + k[2][idxs]*(1 - 2*Θ) + Θ*(2*k[3][idxs] + 2*k[4][idxs] + Θ*(-3*k[3][idxs] - 6*k[4][idxs] + 4*k[4][idxs]*Θ))
    end
  elseif idxs == nothing
    #@. out = k[1] + k[2]*(1 - 2*Θ) + Θ*(2*k[3] + 2*k[4] + Θ*(-3*k[3] - 6*k[4] + 4*k[4]*Θ))
    @inbounds for i in eachindex(out)
      out[i] = k[1][i] + k[2][i]*(1 - 2*Θ) + Θ*(2*k[3][i] + 2*k[4][i] + Θ*(-3*k[3][i] - 6*k[4][i] + 4*k[4][i]*Θ))
    end
  else
    #@views @. out = k[1][idxs] + k[2][idxs]*(1 - 2*Θ) + Θ*(2*k[3][idxs] + 2*k[4][idxs] + Θ*(-3*k[3][idxs] - 6*k[4][idxs] + 4*k[4][idxs]*Θ))
    @inbounds for (j,i) in enumerate(idxs)
      out[j] = k[1][i] + k[2][i]*(1 - 2*Θ) + Θ*(2*k[3][i] + 2*k[4][i] + Θ*(-3*k[3][i] - 6*k[4][i] + 4*k[4][i]*Θ))
    end
  end
end

"""
Second order strong stability preserving (SSP) interpolant.

Ketcheson, Lóczi, Jangabylova, Kusmanov: Dense output for SSP RK methods (2017).
"""
@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::Union{SSPRK22ConstantCache,SSPRK33ConstantCache,SSPRK432ConstantCache},idxs::Void,T::Type{Val{0}})
  #@. (1-Θ^2)*y₀ + Θ^2*y₁ + Θ*(1-Θ)*dt*k[1]
  (1-Θ^2)*y₀ + Θ^2*y₁ + Θ*(1-Θ)*dt*k[1]
end

@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::Union{SSPRK22ConstantCache,SSPRK33ConstantCache,SSPRK432ConstantCache},idxs,T::Type{Val{0}})
  #@. (1-Θ^2)*y₀ + Θ^2*y₁ + Θ*(1-Θ)*dt*k[1]
  (1-Θ^2)*y₀[idxs] + Θ^2*y₁[idxs] + Θ*(1-Θ)*dt*k[1][idxs]
end

@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::Union{SSPRK22ConstantCache,SSPRK33ConstantCache,SSPRK432ConstantCache},idxs::Void,T::Type{Val{1}})
  #@. -2Θ*y₀ + 2Θ*y₁ + (1-2Θ)*dt*k[1]
  -2Θ/dt*y₀ + 2Θ/dt*y₁ + (1-2Θ)*k[1]
end

@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::Union{SSPRK22ConstantCache,SSPRK33ConstantCache,SSPRK432ConstantCache},idxs,T::Type{Val{1}})
  #@. -2Θ*y₀ + 2Θ*y₁ + (1-2Θ)*dt*k[1]
  -2Θ/dt*y₀[idxs] + 2Θ/dt*y₁[idxs] + (1-2Θ)*k[1][idxs]
end

@muladd function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::Union{SSPRK22Cache,SSPRK33Cache,SSPRK432Cache},idxs,T::Type{Val{0}})
  Θ1 = 1-Θ
  if out == nothing
    if idxs == nothing
      # return @. (1-Θ^2)*y₀ + Θ^2*y₁ + Θ*(1-Θ)*dt*k[1]
      return (1-Θ^2)*y₀ + Θ^2*y₁ + Θ*(1-Θ)*dt*k[1]
    else
      # return @. (1-Θ^2)*y₀[idxs] + Θ^2*y₁[idxs] + Θ*(1-Θ)*dt*k[1][idxs]
      return (1-Θ^2)*y₀[idxs] + Θ^2*y₁[idxs] + Θ*(1-Θ)*dt*k[1][idxs]
    end
  elseif idxs == nothing
    #@. out = (1-Θ^2)*y₀ + Θ^2*y₁ + Θ*(1-Θ)*dt*k[1]
    @inbounds for i in eachindex(out)
      out[i] = (1-Θ^2)*y₀[i] + Θ^2*y₁[i] + Θ*(1-Θ)*dt*k[1][i]
    end
  else
    #@views @. out = (1-Θ^2)*y₀[idxs] + Θ^2*y₁[idxs] + Θ*(1-Θ)*dt*k[1][idxs]
    @inbounds for (j,i) in enumerate(idxs)
      out[j] = (1-Θ^2)*y₀[i] + Θ^2*y₁[i] + Θ*(1-Θ)*dt*k[1][i]
    end
  end
end

@muladd function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::Union{SSPRK22Cache,SSPRK33Cache,SSPRK432Cache},idxs,T::Type{Val{1}})
  Θ1 = 1-Θ
  if out == nothing
    if idxs == nothing
      # return @. -2Θ/dt*y₀ + 2Θ/dt*y₁ + (1-2Θ)*k[1]
      return -2Θ/dt*y₀ + 2Θ/dt*y₁ + (1-2Θ)*k[1]
    else
      # return @. -2Θ/dt*y₀[idxs] + 2Θ/dt*y₁[idxs] + (1-2Θ)*k[1][idxs]
      return -2Θ/dt*y₀[idxs] + 2Θ/dt*y₁[idxs] + (1-2Θ)*k[1][idxs]
    end
  elseif idxs == nothing
    #@. out = -2Θ/dt*y₀ + 2Θ/dt*y₁ + (1-2Θ)*k[1]
    @inbounds for i in eachindex(out)
      out[i] = -2Θ/dt*y₀[i] + 2Θ/dt*y₁[i] + (1-2Θ)*k[1][i]
    end
  else
    #@views @. out = -2Θ/dt*y₀[idxs] + 2Θ/dt*y₁[idxs] + (1-2Θ)*k[1][idxs]
    @inbounds for (j,i) in enumerate(idxs)
      out[j] = -2Θ/dt*y₀[i] + 2Θ/dt*y₁[i] + (1-2Θ)*k[1][i]
    end
  end
end

"""
Runge–Kutta pairs of order 5(4) satisfying only the first column
simplifying assumption

Ch. Tsitouras
"""
@muladd function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::Tsit5Cache,idxs,T::Type{Val{0}})
  @unpack r11,r12,r13,r14,r22,r23,r24,r32,r33,r34,r42,r43,r44,r52,r53,r54,r62,r63,r64,r72,r73,r74 = cache.tab

  b1Θ = @evalpoly(Θ, 0, r11, r12, r13, r14)
  b2Θ = @evalpoly(Θ, 0,   0, r22, r23, r24)
  b3Θ = @evalpoly(Θ, 0,   0, r32, r33, r34)
  b4Θ = @evalpoly(Θ, 0,   0, r42, r43, r44)
  b5Θ = @evalpoly(Θ, 0,   0, r52, r53, r54)
  b6Θ = @evalpoly(Θ, 0,   0, r62, r63, r64)
  b7Θ = @evalpoly(Θ, 0,   0, r72, r73, r74)

  if out == nothing
    if idxs == nothing
      # return @. y₀ + dt*(k[1]*b1Θ + k[2]*b2Θ + k[3]*b3Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ)
      return y₀ + dt*(k[1]*b1Θ + k[2]*b2Θ + k[3]*b3Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ)
    else
      # return @. y₀[idxs] + dt*(k[1][idxs]*b1Θ + k[2][idxs]*b2Θ + k[3][idxs]*b3Θ + k[4][idxs]*b4Θ + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ + k[7][idxs]*b7Θ)
      return y₀[idxs] + dt*(k[1][idxs]*b1Θ + k[2][idxs]*b2Θ + k[3][idxs]*b3Θ + k[4][idxs]*b4Θ + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ + k[7][idxs]*b7Θ)
    end
  elseif idxs == nothing
    #@. out = y₀ + dt*(k[1]*b1Θ + k[2]*b2Θ + k[3]*b3Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ)
    @inbounds for i in eachindex(out)
      out[i] = y₀[i] + dt*(k[1][i]*b1Θ + k[2][i]*b2Θ + k[3][i]*b3Θ + k[4][i]*b4Θ + k[5][i]*b5Θ + k[6][i]*b6Θ + k[7][i]*b7Θ)
    end
  else
    #@views @. out = y₀[idxs] + dt*(k[1][idxs]*b1Θ + k[2][idxs]*b2Θ + k[3][idxs]*b3Θ + k[4][idxs]*b4Θ + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ + k[7][idxs]*b7Θ)
    @inbounds for (j,i) in enumerate(idxs)
      out[j] = y₀[i] + dt*(k[1][i]*b1Θ + k[2][i]*b2Θ + k[3][i]*b3Θ + k[4][i]*b4Θ + k[5][i]*b5Θ + k[6][i]*b6Θ + k[7][i]*b7Θ)
    end
  end
end

@muladd function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::Tsit5Cache,idxs,T::Type{Val{1}})
  @unpack r11,r12,r13,r14,r22,r23,r24,r32,r33,r34,r42,r43,r44,r52,r53,r54,r62,r63,r64,r72,r73,r74 = cache.tab

  b1Θdiff = @evalpoly(Θ, r11, 2*r12, 3*r13, 4*r14)
  b2Θdiff = @evalpoly(Θ,   0, 2*r22, 3*r23, 4*r24)
  b3Θdiff = @evalpoly(Θ,   0, 2*r32, 3*r33, 4*r34)
  b4Θdiff = @evalpoly(Θ,   0, 2*r42, 3*r43, 4*r44)
  b5Θdiff = @evalpoly(Θ,   0, 2*r52, 3*r53, 4*r54)
  b6Θdiff = @evalpoly(Θ,   0, 2*r62, 3*r63, 4*r64)
  b7Θdiff = @evalpoly(Θ,   0, 2*r72, 3*r73, 4*r74)

  if out == nothing
    if idxs == nothing
      # return @. k[1]*b1Θdiff + k[2]*b2Θdiff + k[3]*b3Θdiff + k[4]*b4Θdiff + k[5]*b5Θdiff + k[6]*b6Θdiff + k[7]*b7Θdiff
      return k[1]*b1Θdiff + k[2]*b2Θdiff + k[3]*b3Θdiff + k[4]*b4Θdiff + k[5]*b5Θdiff + k[6]*b6Θdiff + k[7]*b7Θdiff
    else
      # return @. k[1][idxs]*b1Θdiff + k[2][idxs]*b2Θdiff + k[3][idxs]*b3Θdiff + k[4][idxs]*b4Θdiff + k[5][idxs]*b5Θdiff + k[6][idxs]*b6Θdiff + k[7][idxs]*b7Θdiff
      return k[1][idxs]*b1Θdiff + k[2][idxs]*b2Θdiff + k[3][idxs]*b3Θdiff + k[4][idxs]*b4Θdiff + k[5][idxs]*b5Θdiff + k[6][idxs]*b6Θdiff + k[7][idxs]*b7Θdiff
    end
  elseif idxs == nothing
    #@. out = k[1]*b1Θdiff + k[2]*b2Θdiff + k[3]*b3Θdiff + k[4]*b4Θdiff + k[5]*b5Θdiff + k[6]*b6Θdiff + k[7]*b7Θdiff
    @inbounds for i in eachindex(out)
      out[i] = k[1][i]*b1Θdiff + k[2][i]*b2Θdiff + k[3][i]*b3Θdiff + k[4][i]*b4Θdiff + k[5][i]*b5Θdiff + k[6][i]*b6Θdiff + k[7][i]*b7Θdiff
    end
  else
    #@views @. out = k[1][idxs]*b1Θdiff + k[2][idxs]*b2Θdiff + k[3][idxs]*b3Θdiff + k[4][idxs]*b4Θdiff + k[5][idxs]*b5Θdiff + k[6][idxs]*b6Θdiff + k[7][idxs]*b7Θdiff
    @inbounds for (j,i) in enumerate(idxs)
      out[j] = k[1][i]*b1Θdiff + k[2][i]*b2Θdiff + k[3][i]*b3Θdiff + k[4][i]*b4Θdiff + k[5][i]*b5Θdiff + k[6][i]*b6Θdiff + k[7][i]*b7Θdiff
    end
  end
end

"""
Runge–Kutta pairs of order 5(4) satisfying only the first column
simplifying assumption

Ch. Tsitouras
"""
@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::Tsit5ConstantCache,idxs,T::Type{Val{0}})
  @unpack r11,r12,r13,r14,r22,r23,r24,r32,r33,r34,r42,r43,r44,r52,r53,r54,r62,r63,r64,r72,r73,r74 = cache

  b1Θ = @evalpoly(Θ, 0, r11, r12, r13, r14)
  b2Θ = @evalpoly(Θ, 0,   0, r22, r23, r24)
  b3Θ = @evalpoly(Θ, 0,   0, r32, r33, r34)
  b4Θ = @evalpoly(Θ, 0,   0, r42, r43, r44)
  b5Θ = @evalpoly(Θ, 0,   0, r52, r53, r54)
  b6Θ = @evalpoly(Θ, 0,   0, r62, r63, r64)
  b7Θ = @evalpoly(Θ, 0,   0, r72, r73, r74)

  #@. y₀ + dt*(k[1]*b1Θ + k[2]*b2Θ + k[3]*b3Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ)
  if idxs == nothing
    return y₀ + dt*(k[1]*b1Θ + k[2]*b2Θ + k[3]*b3Θ + k[4]*b4Θ +
           k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ)
  else
    return y₀[idxs] + dt*(k[1][idxs]*b1Θ + k[2][idxs]*b2Θ + k[3][idxs]*b3Θ +
           k[4][idxs]*b4Θ + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ + k[7][idxs]*b7Θ)
  end
end

@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::Tsit5ConstantCache,idxs,T::Type{Val{1}})
  @unpack r11,r12,r13,r14,r22,r23,r24,r32,r33,r34,r42,r43,r44,r52,r53,r54,r62,r63,r64,r72,r73,r74 = cache

  b1Θdiff = @evalpoly(Θ, r11, 2*r12, 3*r13, 4*r14)
  b2Θdiff = @evalpoly(Θ,   0, 2*r22, 3*r23, 4*r24)
  b3Θdiff = @evalpoly(Θ,   0, 2*r32, 3*r33, 4*r34)
  b4Θdiff = @evalpoly(Θ,   0, 2*r42, 3*r43, 4*r44)
  b5Θdiff = @evalpoly(Θ,   0, 2*r52, 3*r53, 4*r54)
  b6Θdiff = @evalpoly(Θ,   0, 2*r62, 3*r63, 4*r64)
  b7Θdiff = @evalpoly(Θ,   0, 2*r72, 3*r73, 4*r74)

  if idxs == nothing
    # return @. k[1]*b1Θdiff + k[2]*b2Θdiff + k[3]*b3Θdiff + k[4]*b4Θdiff + k[5]*b5Θdiff + k[6]*b6Θdiff + k[7]*b7Θdiff
    return k[1]*b1Θdiff + k[2]*b2Θdiff + k[3]*b3Θdiff + k[4]*b4Θdiff +
           k[5]*b5Θdiff + k[6]*b6Θdiff + k[7]*b7Θdiff
  else
    # return @. k[1][idxs]*b1Θdiff + k[2][idxs]*b2Θdiff + k[3][idxs]*b3Θdiff + k[4][idxs]*b4Θdiff + k[5][idxs]*b5Θdiff + k[6][idxs]*b6Θdiff + k[7][idxs]*b7Θdiff
    return k[1][idxs]*b1Θdiff + k[2][idxs]*b2Θdiff + k[3][idxs]*b3Θdiff +
           k[4][idxs]*b4Θdiff + k[5][idxs]*b5Θdiff + k[6][idxs]*b6Θdiff +
           k[7][idxs]*b7Θdiff
  end
end

@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::OwrenZen3ConstantCache,idxs,T::Type{Val{0}})
  @unpack r13,r12,r23,r22,r33,r32 = cache

  b1Θ  = @evalpoly(Θ, 0, 1, r12, r13)
  b2Θ  = @evalpoly(Θ, 0, 0, r22, r23)
  b3Θ  = @evalpoly(Θ, 0, 0, r32, r33)
  b4Θ  = @evalpoly(Θ, 0, 0, -1, 1)

  if idxs == nothing
    return @. y₀ + dt*(k[1]*b1Θ  + k[2]*b2Θ + k[3]*b3Θ + k[4]*b4Θ)
  else
    return @. y₀[idxs] + dt*(k[1][idxs]*b1Θ  + k[2][idxs]*b2Θ + k[3][idxs]*b3Θ +
           k[4][idxs]*b4Θ)
  end
end

@muladd function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::OwrenZen3Cache,idxs,T::Type{Val{0}})
  @unpack r13,r12,r23,r22,r33,r32 = cache.tab

  b1Θ  = @evalpoly(Θ, 0, 1, r12, r13)
  b2Θ  = @evalpoly(Θ, 0, 0, r22, r23)
  b3Θ  = @evalpoly(Θ, 0, 0, r32, r33)
  b4Θ  = @evalpoly(Θ, 0, 0, -1, 1)

  if out == nothing
    if idxs == nothing
      return @. y₀ + dt*(k[1]*b1Θ  + k[2]*b2Θ + k[3]*b3Θ + k[4]*b4Θ)
    else
      return @. y₀[idxs] + dt*(k[1][idxs]*b1Θ  + k[2][idxs]*b2Θ + k[3][idxs]*b3Θ +
                               k[4][idxs]*b4Θ)
    end
  elseif idxs == nothing
    @. out = y₀ + dt*(k[1]*b1Θ  + k[2]*b2Θ + k[3]*b3Θ + k[4]*b4Θ)
  else
    @. out = y₀[idxs] + dt*(k[1][idxs]*b1Θ  + k[2][idxs]*b2Θ + k[3][idxs]*b3Θ + k[4][idxs]*b4Θ)
  end
end

@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::OwrenZen4ConstantCache,idxs,T::Type{Val{0}})
  @unpack r14,r13,r12,r34,r33,r32,r44,r43,r42,r54,r53,r52,r64,r63,r62 = cache

  b1Θ  = @evalpoly(Θ, 0, 1, r12, r13, r14)
  b3Θ  = @evalpoly(Θ, 0, 0, r32, r33, r34)
  b4Θ  = @evalpoly(Θ, 0, 0, r42, r43, r44)
  b5Θ  = @evalpoly(Θ, 0, 0, r52, r53, r54)
  b6Θ  = @evalpoly(Θ, 0, 0, r62, r63, r64)

  if idxs == nothing
    # return @. y₀ + dt*(k[1]*b1Θ + k[3]*b3Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ)
    return y₀ + dt*(k[1]*b1Θ + k[3]*b3Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ)
  else
    # return @. y₀[idxs] + dt*(k[1][idxs]*b1Θ + k[3][idxs]*b3Θ +
    #                          k[4][idxs]*b4Θ + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ)
    return y₀[idxs] + dt*(k[1][idxs]*b1Θ + k[3][idxs]*b3Θ +
                          k[4][idxs]*b4Θ + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ)
  end
end

@muladd function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::OwrenZen4Cache,idxs,T::Type{Val{0}})
  @unpack r14,r13,r12,r34,r33,r32,r44,r43,r42,r54,r53,r52,r64,r63,r62 = cache.tab

  b1Θ  = @evalpoly(Θ, 0, 1, r12, r13, r14)
  b3Θ  = @evalpoly(Θ, 0, 0, r32, r33, r34)
  b4Θ  = @evalpoly(Θ, 0, 0, r42, r43, r44)
  b5Θ  = @evalpoly(Θ, 0, 0, r52, r53, r54)
  b6Θ  = @evalpoly(Θ, 0, 0, r62, r63, r64)

  if out == nothing
    if idxs == nothing
      # return @. y₀ + dt*(k[1]*b1Θ  + k[3]*b3Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ)
      return y₀ + dt*(k[1]*b1Θ  + k[3]*b3Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ)
    else
      # return @. y₀[idxs] + dt*(k[1][idxs]*b1Θ  + k[3][idxs]*b3Θ +
      #                          k[4][idxs]*b4Θ + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ)
      return y₀[idxs] + dt*(k[1][idxs]*b1Θ  + k[3][idxs]*b3Θ +
                            k[4][idxs]*b4Θ + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ)
    end
  elseif idxs == nothing
    # @. out = y₀ + dt*(k[1]*b1Θ  + k[3]*b3Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ)
    @inbounds for i in eachindex(out)
      out[i] = y₀[i] + dt*(k[1][i]*b1Θ  + k[3][i]*b3Θ + k[4][i]*b4Θ +
                           k[5][i]*b5Θ + k[6][i]*b6Θ)
    end
  else
    # @. out = y₀[idxs] + dt*(k[1][idxs]*b1Θ  + k[3][idxs]*b3Θ +
    #                         k[4][idxs]*b4Θ + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ)
    @inbounds for (j,i) in enumerate(idxs)
        out[j] = y₀[i] + dt*(k[1][i]*b1Θ  + k[3][i]*b3Θ + k[4][i]*b4Θ +
                 k[5][i]*b5Θ + k[6][i]*b6Θ)
    end
  end
end

@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::OwrenZen5ConstantCache,idxs,T::Type{Val{0}})
  @unpack r15,r14,r13,r12,r35,r34,r33,r32,r45,r44,r43,r42,r55,r54,r53,r52,r65,r64,r63,r62,r75,r74,r73,r72,r85,r84,r83,r82 = cache

  b1Θ  = @evalpoly(Θ, 0, 1, r12, r13, r14, r15)
  b3Θ  = @evalpoly(Θ, 0, 0, r32, r33, r34, r35)
  b4Θ  = @evalpoly(Θ, 0, 0, r42, r43, r44, r45)
  b5Θ  = @evalpoly(Θ, 0, 0, r52, r53, r54, r55)
  b6Θ  = @evalpoly(Θ, 0, 0, r62, r63, r64, r65)
  b7Θ  = @evalpoly(Θ, 0, 0, r72, r73, r74, r75)
  b8Θ  = @evalpoly(Θ, 0, 0, r82, r83, r84, r85)

  if idxs == nothing
    # return @. y₀ + dt*(k[1]*b1Θ  + k[3]*b3Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ +
    #                    k[7]*b7Θ + k[8]*b8Θ)
    return y₀ + dt*(k[1]*b1Θ  + k[3]*b3Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ +
                    k[7]*b7Θ + k[8]*b8Θ)
  else
    # return @. y₀[idxs] + dt*(k[1][idxs]*b1Θ  + k[3][idxs]*b3Θ +
    #                          k[4][idxs]*b4Θ + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ +
    #                          k[7][idxs]*b7Θ + k[8][idxs]*b8Θ)
    return y₀[idxs] + dt*(k[1][idxs]*b1Θ  + k[3][idxs]*b3Θ +
                          k[4][idxs]*b4Θ + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ +
                          k[7][idxs]*b7Θ + k[8][idxs]*b8Θ)
  end
end

@muladd function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::OwrenZen5Cache,idxs,T::Type{Val{0}})
  @unpack r15,r14,r13,r12,r35,r34,r33,r32,r45,r44,r43,r42,r55,r54,r53,r52,r65,r64,r63,r62,r75,r74,r73,r72,r85,r84,r83,r82 = cache.tab

  b1Θ  = @evalpoly(Θ, 0, 1, r12, r13, r14, r15)
  b3Θ  = @evalpoly(Θ, 0, 0, r32, r33, r34, r35)
  b4Θ  = @evalpoly(Θ, 0, 0, r42, r43, r44, r45)
  b5Θ  = @evalpoly(Θ, 0, 0, r52, r53, r54, r55)
  b6Θ  = @evalpoly(Θ, 0, 0, r62, r63, r64, r65)
  b7Θ  = @evalpoly(Θ, 0, 0, r72, r73, r74, r75)
  b8Θ  = @evalpoly(Θ, 0, 0, r82, r83, r84, r85)

  if out == nothing
    if idxs == nothing
      # return @. y₀ + dt*(k[1]*b1Θ  + k[3]*b3Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ +
      #                    k[7]*b7Θ + k[8]*b8Θ)
      return y₀ + dt*(k[1]*b1Θ  + k[3]*b3Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ +
                      k[7]*b7Θ + k[8]*b8Θ)
    else
      # return @. y₀[idxs] + dt*(k[1][idxs]*b1Θ  + k[3][idxs]*b3Θ +
      #                          k[4][idxs]*b4Θ + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ +
      #                          k[7][idxs]*b7Θ + k[8][idxs]*b8Θ)
      return y₀[idxs] + dt*(k[1][idxs]*b1Θ  + k[3][idxs]*b3Θ +
                            k[4][idxs]*b4Θ + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ +
                            k[7][idxs]*b7Θ + k[8][idxs]*b8Θ)
    end
  elseif idxs == nothing
    # @. out = y₀ + dt*(k[1]*b1Θ  + k[3]*b3Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ +
    #                          k[7]*b7Θ + k[8]*b8Θ)
    @inbounds for i in eachindex(out)
      out[i] = y₀[i] + dt*(k[1][i]*b1Θ  + k[3][i]*b3Θ + k[4][i]*b4Θ +
                           k[5][i]*b5Θ + k[6][i]*b6Θ + k[7][i]*b7Θ + k[8][i]*b8Θ)
    end
  else
    # @. out = y₀[idxs] + dt*(k[1][idxs]*b1Θ  + k[3][idxs]*b3Θ +
    #                                k[4][idxs]*b4Θ + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ +
    #                                k[7][idxs]*b7Θ + k[8][idxs]*b8Θ)
    @inbounds for (j,i) in enumerate(idxs)
        out[j] = y₀[i] + dt*(k[1][i]*b1Θ + k[3][i]*b3Θ + k[4][i]*b4Θ +
                 k[5][i]*b5Θ + k[6][i]*b6Θ + k[7][i]*b7Θ + k[8][i]*b8Θ)
    end
  end
end

"""
Coefficients taken from RKSuite
"""
@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::BS5ConstantCache,idxs,T::Type{Val{0}})
  @unpack r016,r015,r014,r013,r012,r036,r035,r034,r033,r032,r046,r045,r044,r043,r042,r056,r055,r054,r053,r052,r066,r065,r064,r063,r062,r076,r075,r074,r073,r072,r086,r085,r084,r083,r082,r096,r095,r094,r093,r106,r105,r104,r103,r102,r116,r115,r114,r113,r112 = cache

  b1Θ  = @evalpoly(Θ, 0, 0, r012, r013, r014, r015, r016)
  b3Θ  = @evalpoly(Θ, 0, 0, r032, r033, r034, r035, r036)
  b4Θ  = @evalpoly(Θ, 0, 0, r042, r043, r044, r045, r046)
  b5Θ  = @evalpoly(Θ, 0, 0, r052, r053, r054, r055, r056)
  b6Θ  = @evalpoly(Θ, 0, 0, r062, r063, r064, r065, r066)
  b7Θ  = @evalpoly(Θ, 0, 0, r072, r073, r074, r075, r076)
  b8Θ  = @evalpoly(Θ, 0, 0, r082, r083, r084, r085, r086)
  b9Θ  = @evalpoly(Θ, 0, 0,    0, r093, r094, r095, r096)
  b10Θ = @evalpoly(Θ, 0, 0, r102, r103, r104, r105, r106)
  b11Θ = @evalpoly(Θ, 0, 0, r112, r113, r114, r115, r116)

  if idxs == nothing
    # return @. y₀ + dt*Θ*k[1] + dt*(k[1]*b1Θ  + k[3]*b3Θ + k[4]*b4Θ  + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ)
    return y₀ + dt*Θ*k[1] + dt*(k[1]*b1Θ  + k[3]*b3Θ + k[4]*b4Θ  + k[5]*b5Θ +
                                k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ)
  else
    # return @. y₀[idxs] + dt*Θ*k[1][idxs] + dt*(k[1][idxs]*b1Θ  + k[3][idxs]*b3Θ +
    #                                            k[4][idxs]*b4Θ  + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ + k[7][idxs]*b7Θ +
    #                                            k[8][idxs]*b8Θ + k[9][idxs]*b9Θ + k[10][idxs]*b10Θ + k[11][idxs]*b11Θ)
    return y₀[idxs] + dt*Θ*k[1][idxs] + dt*(k[1][idxs]*b1Θ  + k[3][idxs]*b3Θ +
                                            k[4][idxs]*b4Θ  + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ + k[7][idxs]*b7Θ +
                                            k[8][idxs]*b8Θ + k[9][idxs]*b9Θ + k[10][idxs]*b10Θ + k[11][idxs]*b11Θ)
  end
end

@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::BS5ConstantCache,idxs,T::Type{Val{1}})
  @unpack r016,r015,r014,r013,r012,r036,r035,r034,r033,r032,r046,r045,r044,r043,r042,r056,r055,r054,r053,r052,r066,r065,r064,r063,r062,r076,r075,r074,r073,r072,r086,r085,r084,r083,r082,r096,r095,r094,r093,r106,r105,r104,r103,r102,r116,r115,r114,r113,r112 = cache
  b1Θdiff  = @evalpoly(Θ, 0, 2*r012, 3*r013, 4*r014, 5*r015, 6*r016)
  b3Θdiff  = @evalpoly(Θ, 0, 2*r032, 3*r033, 4*r034, 5*r035, 6*r036)
  b4Θdiff  = @evalpoly(Θ, 0, 2*r042, 3*r043, 4*r044, 5*r045, 6*r046)
  b5Θdiff  = @evalpoly(Θ, 0, 2*r052, 3*r053, 4*r054, 5*r055, 6*r056)
  b6Θdiff  = @evalpoly(Θ, 0, 2*r062, 3*r063, 4*r064, 5*r065, 6*r066)
  b7Θdiff  = @evalpoly(Θ, 0, 2*r072, 3*r073, 4*r074, 5*r075, 6*r076)
  b8Θdiff  = @evalpoly(Θ, 0, 2*r082, 3*r083, 4*r084, 5*r085, 6*r086)
  b9Θdiff  = @evalpoly(Θ, 0,      0, 3*r093, 4*r094, 5*r095, 6*r096)
  b10Θdiff = @evalpoly(Θ, 0, 2*r102, 3*r103, 4*r104, 5*r105, 6*r106)
  b11Θdiff = @evalpoly(Θ, 0, 2*r112, 3*r113, 4*r114, 5*r115, 6*r116)

  if idxs == nothing
    # return @. k[1] + k[1]*b1Θdiff  + k[3]*b3Θdiff + k[4]*b4Θdiff  + k[5]*b5Θdiff + k[6]*b6Θdiff + k[7]*b7Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff + k[10]*b10Θdiff + k[11]*b11Θdiff
    return k[1] + k[1]*b1Θdiff  + k[3]*b3Θdiff + k[4]*b4Θdiff  + k[5]*b5Θdiff +
           k[6]*b6Θdiff + k[7]*b7Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff +
           k[10]*b10Θdiff + k[11]*b11Θdiff
  else
    # return @. k[1][idxs] + k[1][idxs]*b1Θdiff  + k[3][idxs]*b3Θdiff +
    #     k[4][idxs]*b4Θdiff  + k[5][idxs]*b5Θdiff + k[6][idxs]*b6Θdiff +
    #     k[7][idxs]*b7Θdiff + k[8][idxs]*b8Θdiff + k[9][idxs]*b9Θdiff +
    #     k[10][idxs]*b10Θdiff + k[11][idxs]*b11Θdiff
    return k[1][idxs] + k[1][idxs]*b1Θdiff  + k[3][idxs]*b3Θdiff +
           k[4][idxs]*b4Θdiff  + k[5][idxs]*b5Θdiff + k[6][idxs]*b6Θdiff +
           k[7][idxs]*b7Θdiff + k[8][idxs]*b8Θdiff + k[9][idxs]*b9Θdiff +
           k[10][idxs]*b10Θdiff + k[11][idxs]*b11Θdiff
  end
end

"""
Coefficients taken from RKSuite
"""
@muladd function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::BS5Cache,idxs,T::Type{Val{0}})
  @unpack r016,r015,r014,r013,r012,r036,r035,r034,r033,r032,r046,r045,r044,r043,r042,r056,r055,r054,r053,r052,r066,r065,r064,r063,r062,r076,r075,r074,r073,r072,r086,r085,r084,r083,r082,r096,r095,r094,r093,r106,r105,r104,r103,r102,r116,r115,r114,r113,r112 = cache.tab

  b1Θ  = @evalpoly(Θ, 0, 0, r012, r013, r014, r015, r016)
  b3Θ  = @evalpoly(Θ, 0, 0, r032, r033, r034, r035, r036)
  b4Θ  = @evalpoly(Θ, 0, 0, r042, r043, r044, r045, r046)
  b5Θ  = @evalpoly(Θ, 0, 0, r052, r053, r054, r055, r056)
  b6Θ  = @evalpoly(Θ, 0, 0, r062, r063, r064, r065, r066)
  b7Θ  = @evalpoly(Θ, 0, 0, r072, r073, r074, r075, r076)
  b8Θ  = @evalpoly(Θ, 0, 0, r082, r083, r084, r085, r086)
  b9Θ  = @evalpoly(Θ, 0, 0,    0, r093, r094, r095, r096)
  b10Θ = @evalpoly(Θ, 0, 0, r102, r103, r104, r105, r106)
  b11Θ = @evalpoly(Θ, 0, 0, r112, r113, r114, r115, r116)

  if out == nothing
    if idxs == nothing
      # return @. y₀ + dt*Θ*k[1] + dt*(k[1]*b1Θ  + k[3]*b3Θ + k[4]*b4Θ  + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ)
      return y₀ + dt*Θ*k[1] + dt*(k[1]*b1Θ  + k[3]*b3Θ + k[4]*b4Θ  + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ)
    else
      # return @. y₀[idxs] + dt*Θ*k[1][idxs] + dt*(k[1][idxs]*b1Θ  + k[3][idxs]*b3Θ + k[4][idxs]*b4Θ  + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ + k[7][idxs]*b7Θ + k[8][idxs]*b8Θ + k[9][idxs]*b9Θ + k[10][idxs]*b10Θ + k[11][idxs]*b11Θ)
      return y₀[idxs] + dt*Θ*k[1][idxs] + dt*(k[1][idxs]*b1Θ  + k[3][idxs]*b3Θ + k[4][idxs]*b4Θ  + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ + k[7][idxs]*b7Θ + k[8][idxs]*b8Θ + k[9][idxs]*b9Θ + k[10][idxs]*b10Θ + k[11][idxs]*b11Θ)
    end
  elseif idxs == nothing
    #@. out = y₀ + dt*Θ*k[1] + dt*(k[1]*b1Θ  + k[3]*b3Θ + k[4]*b4Θ  + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ)
    @inbounds for i in eachindex(out)
      out[i] = y₀[i] + dt*Θ*k[1][i] + dt*(k[1][i]*b1Θ  + k[3][i]*b3Θ + k[4][i]*b4Θ  + k[5][i]*b5Θ + k[6][i]*b6Θ + k[7][i]*b7Θ + k[8][i]*b8Θ + k[9][i]*b9Θ + k[10][i]*b10Θ + k[11][i]*b11Θ)
    end
  else
    #@views @. out = y₀[idxs] + dt*Θ*k[1][idxs] + dt*(k[1][idxs]*b1Θ  + k[3][idxs]*b3Θ + k[4][idxs]*b4Θ  + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ + k[7][idxs]*b7Θ + k[8][idxs]*b8Θ + k[9][idxs]*b9Θ + k[10][idxs]*b10Θ + k[11][idxs]*b11Θ)
    @inbounds for (j,i) in enumerate(idxs)
      out[j] = y₀[i] + dt*Θ*k[1][i] + dt*(k[1][i]*b1Θ  + k[3][i]*b3Θ + k[4][i]*b4Θ  + k[5][i]*b5Θ + k[6][i]*b6Θ + k[7][i]*b7Θ + k[8][i]*b8Θ + k[9][i]*b9Θ + k[10][i]*b10Θ + k[11][i]*b11Θ)
    end
  end
end

@muladd function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::BS5Cache,idxs,T::Type{Val{1}})
  @unpack r016,r015,r014,r013,r012,r036,r035,r034,r033,r032,r046,r045,r044,r043,r042,r056,r055,r054,r053,r052,r066,r065,r064,r063,r062,r076,r075,r074,r073,r072,r086,r085,r084,r083,r082,r096,r095,r094,r093,r106,r105,r104,r103,r102,r116,r115,r114,r113,r112 = cache.tab

  b1Θdiff  = @evalpoly(Θ, 0, 2*r012, 3*r013, 4*r014, 5*r015, 6*r016)
  b3Θdiff  = @evalpoly(Θ, 0, 2*r032, 3*r033, 4*r034, 5*r035, 6*r036)
  b4Θdiff  = @evalpoly(Θ, 0, 2*r042, 3*r043, 4*r044, 5*r045, 6*r046)
  b5Θdiff  = @evalpoly(Θ, 0, 2*r052, 3*r053, 4*r054, 5*r055, 6*r056)
  b6Θdiff  = @evalpoly(Θ, 0, 2*r062, 3*r063, 4*r064, 5*r065, 6*r066)
  b7Θdiff  = @evalpoly(Θ, 0, 2*r072, 3*r073, 4*r074, 5*r075, 6*r076)
  b8Θdiff  = @evalpoly(Θ, 0, 2*r082, 3*r083, 4*r084, 5*r085, 6*r086)
  b9Θdiff  = @evalpoly(Θ, 0,      0, 3*r093, 4*r094, 5*r095, 6*r096)
  b10Θdiff = @evalpoly(Θ, 0, 2*r102, 3*r103, 4*r104, 5*r105, 6*r106)
  b11Θdiff = @evalpoly(Θ, 0, 2*r112, 3*r113, 4*r114, 5*r115, 6*r116)

  if out == nothing
    if idxs == nothing
      # return @. k[1] + k[1]*b1Θdiff  + k[3]*b3Θdiff + k[4]*b4Θdiff  + k[5]*b5Θdiff + k[6]*b6Θdiff + k[7]*b7Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff + k[10]*b10Θdiff + k[11]*b11Θdiff
      return k[1] + k[1]*b1Θdiff  + k[3]*b3Θdiff + k[4]*b4Θdiff  + k[5]*b5Θdiff + k[6]*b6Θdiff + k[7]*b7Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff + k[10]*b10Θdiff + k[11]*b11Θdiff
    else
      # return @. k[1][idxs] + k[1][idxs]*b1Θdiff  + k[3][idxs]*b3Θdiff + k[4][idxs]*b4Θdiff  + k[5][idxs]*b5Θdiff + k[6][idxs]*b6Θdiff + k[7][idxs]*b7Θdiff + k[8][idxs]*b8Θdiff + k[9][idxs]*b9Θdiff + k[10][idxs]*b10Θdiff + k[11][idxs]*b11Θdiff
      return k[1][idxs] + k[1][idxs]*b1Θdiff  + k[3][idxs]*b3Θdiff + k[4][idxs]*b4Θdiff  + k[5][idxs]*b5Θdiff + k[6][idxs]*b6Θdiff + k[7][idxs]*b7Θdiff + k[8][idxs]*b8Θdiff + k[9][idxs]*b9Θdiff + k[10][idxs]*b10Θdiff + k[11][idxs]*b11Θdiff
    end
  elseif idxs == nothing
    #@. out = k[1] + k[1]*b1Θdiff  + k[3]*b3Θdiff + k[4]*b4Θdiff  + k[5]*b5Θdiff + k[6]*b6Θdiff + k[7]*b7Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff + k[10]*b10Θdiff + k[11]*b11Θdiff
    @inbounds for i in eachindex(out)
      out[i] = k[1][i] + k[1][i]*b1Θdiff  + k[3][i]*b3Θdiff + k[4][i]*b4Θdiff  + k[5][i]*b5Θdiff + k[6][i]*b6Θdiff + k[7][i]*b7Θdiff + k[8][i]*b8Θdiff + k[9][i]*b9Θdiff + k[10][i]*b10Θdiff + k[11][i]*b11Θdiff
    end
  else
    #@views @. out = k[1][idxs] + k[1][idxs]*b1Θdiff  + k[3][idxs]*b3Θdiff + k[4][idxs]*b4Θdiff  + k[5][idxs]*b5Θdiff + k[6][idxs]*b6Θdiff + k[7][idxs]*b7Θdiff + k[8][idxs]*b8Θdiff + k[9][idxs]*b9Θdiff + k[10][idxs]*b10Θdiff + k[11][idxs]*b11Θdiff
    @inbounds for (j,i) in enumerate(idxs)
      out[j] = k[1][i] + k[1][i]*b1Θdiff  + k[3][i]*b3Θdiff + k[4][i]*b4Θdiff  + k[5][i]*b5Θdiff + k[6][i]*b6Θdiff + k[7][i]*b7Θdiff + k[8][i]*b8Θdiff + k[9][i]*b9Θdiff + k[10][i]*b10Θdiff + k[11][i]*b11Θdiff
    end
  end
end

"""

"""
@muladd function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::Vern6Cache,idxs,T::Type{Val{0}})
  @unpack r011,r012,r013,r014,r015,r016,r042,r043,r044,r045,r046,r052,r053,r054,r055,r056,r062,r063,r064,r065,r066,r072,r073,r074,r075,r076,r082,r083,r084,r085,r086,r092,r093,r094,r095,r096,r102,r103,r104,r105,r106,r112,r113,r114,r115,r116,r122,r123,r124,r125,r126 = cache.tab

  b1Θ  = @evalpoly(Θ, 0, r011, r012, r013, r014, r015, r016)
  b4Θ  = @evalpoly(Θ, 0,    0, r042, r043, r044, r045, r046)
  b5Θ  = @evalpoly(Θ, 0,    0, r052, r053, r054, r055, r056)
  b6Θ  = @evalpoly(Θ, 0,    0, r062, r063, r064, r065, r066)
  b7Θ  = @evalpoly(Θ, 0,    0, r072, r073, r074, r075, r076)
  b8Θ  = @evalpoly(Θ, 0,    0, r082, r083, r084, r085, r086)
  b9Θ  = @evalpoly(Θ, 0,    0, r092, r093, r094, r095, r096)
  b10Θ = @evalpoly(Θ, 0,    0, r102, r103, r104, r105, r106)
  b11Θ = @evalpoly(Θ, 0,    0, r112, r113, r114, r115, r116)
  b12Θ = @evalpoly(Θ, 0,    0, r122, r123, r124, r125, r126)

  if out == nothing
    if idxs == nothing
      # return @. y₀ + dt*(k[1]*b1Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ + k[12]*b12Θ)
      return y₀ + dt*(k[1]*b1Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ + k[12]*b12Θ)
    else
      # return @. y₀[idxs] + dt*(k[1][idxs]*b1Θ + k[4][idxs]*b4Θ + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ + k[7][idxs]*b7Θ + k[8][idxs]*b8Θ + k[9][idxs]*b9Θ + k[10][idxs]*b10Θ + k[11][idxs]*b11Θ + k[12][idxs]*b12Θ)
      return y₀[idxs] + dt*(k[1][idxs]*b1Θ + k[4][idxs]*b4Θ + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ + k[7][idxs]*b7Θ + k[8][idxs]*b8Θ + k[9][idxs]*b9Θ + k[10][idxs]*b10Θ + k[11][idxs]*b11Θ + k[12][idxs]*b12Θ)
    end
  elseif idxs == nothing
    #@. out = y₀ + dt*(k[1]*b1Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ + k[12]*b12Θ)
    @inbounds for i in eachindex(out)
      out[i] = y₀[i] + dt*(k[1][i]*b1Θ + k[4][i]*b4Θ + k[5][i]*b5Θ + k[6][i]*b6Θ + k[7][i]*b7Θ + k[8][i]*b8Θ + k[9][i]*b9Θ + k[10][i]*b10Θ + k[11][i]*b11Θ + k[12][i]*b12Θ)
    end
  else
    #@views @. out = y₀[idxs] + dt*(k[1][idxs]*b1Θ + k[4][idxs]*b4Θ + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ + k[7][idxs]*b7Θ + k[8][idxs]*b8Θ + k[9][idxs]*b9Θ + k[10][idxs]*b10Θ + k[11][idxs]*b11Θ + k[12][idxs]*b12Θ)
    @inbounds for (j,i) in enumerate(idxs)
      out[j] = y₀[i] + dt*(k[1][i]*b1Θ + k[4][i]*b4Θ + k[5][i]*b5Θ + k[6][i]*b6Θ + k[7][i]*b7Θ + k[8][i]*b8Θ + k[9][i]*b9Θ + k[10][i]*b10Θ + k[11][i]*b11Θ + k[12][i]*b12Θ)
    end
  end
end

@muladd function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::Vern6Cache,idxs,T::Type{Val{1}})
  @unpack r011,r012,r013,r014,r015,r016,r042,r043,r044,r045,r046,r052,r053,r054,r055,r056,r062,r063,r064,r065,r066,r072,r073,r074,r075,r076,r082,r083,r084,r085,r086,r092,r093,r094,r095,r096,r102,r103,r104,r105,r106,r112,r113,r114,r115,r116,r122,r123,r124,r125,r126 = cache.tab

  b1Θdiff  = @evalpoly(Θ, r011, 2*r012, 3*r013, 4*r014, 5*r015, 6*r016)
  b4Θdiff  = @evalpoly(Θ,    0, 2*r042, 3*r043, 4*r044, 5*r045, 6*r046)
  b5Θdiff  = @evalpoly(Θ,    0, 2*r052, 3*r053, 4*r054, 5*r055, 6*r056)
  b6Θdiff  = @evalpoly(Θ,    0, 2*r062, 3*r063, 4*r064, 5*r065, 6*r066)
  b7Θdiff  = @evalpoly(Θ,    0, 2*r072, 3*r073, 4*r074, 5*r075, 6*r076)
  b8Θdiff  = @evalpoly(Θ,    0, 2*r082, 3*r083, 4*r084, 5*r085, 6*r086)
  b9Θdiff  = @evalpoly(Θ,    0, 2*r092, 3*r093, 4*r094, 5*r095, 6*r096)
  b10Θdiff = @evalpoly(Θ,    0, 2*r102, 3*r103, 4*r104, 5*r105, 6*r106)
  b11Θdiff = @evalpoly(Θ,    0, 2*r112, 3*r113, 4*r114, 5*r115, 6*r116)
  b12Θdiff = @evalpoly(Θ,    0, 2*r122, 3*r123, 4*r124, 5*r125, 6*r126)

  if out == nothing
    if idxs == nothing
      # return @. k[1]*b1Θdiff + k[4]*b4Θdiff + k[5]*b5Θdiff + k[6]*b6Θdiff + k[7]*b7Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff + k[10]*b10Θdiff + k[11]*b11Θdiff + k[12]*b12Θdiff
      return k[1]*b1Θdiff + k[4]*b4Θdiff + k[5]*b5Θdiff + k[6]*b6Θdiff + k[7]*b7Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff + k[10]*b10Θdiff + k[11]*b11Θdiff + k[12]*b12Θdiff
    else
      # return @. k[1][idxs]*b1Θdiff + k[4][idxs]*b4Θdiff + k[5][idxs]*b5Θdiff + k[6][idxs]*b6Θdiff + k[7][idxs]*b7Θdiff + k[8][idxs]*b8Θdiff + k[9][idxs]*b9Θdiff + k[10][idxs]*b10Θdiff + k[11][idxs]*b11Θdiff + k[12][idxs]*b12Θdiff
      return k[1][idxs]*b1Θdiff + k[4][idxs]*b4Θdiff + k[5][idxs]*b5Θdiff + k[6][idxs]*b6Θdiff + k[7][idxs]*b7Θdiff + k[8][idxs]*b8Θdiff + k[9][idxs]*b9Θdiff + k[10][idxs]*b10Θdiff + k[11][idxs]*b11Θdiff + k[12][idxs]*b12Θdiff
    end
  elseif idxs == nothing
    #@. out = k[1]*b1Θdiff + k[4]*b4Θdiff + k[5]*b5Θdiff + k[6]*b6Θdiff + k[7]*b7Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff + k[10]*b10Θdiff + k[11]*b11Θdiff + k[12]*b12Θdiff
    @inbounds for i in eachindex(out)
      out[i] = k[1][i]*b1Θdiff + k[4][i]*b4Θdiff + k[5][i]*b5Θdiff + k[6][i]*b6Θdiff + k[7][i]*b7Θdiff + k[8][i]*b8Θdiff + k[9][i]*b9Θdiff + k[10][i]*b10Θdiff + k[11][i]*b11Θdiff + k[12][i]*b12Θdiff
    end
  else
    #@views @. out = k[1][idxs]*b1Θdiff + k[4][idxs]*b4Θdiff + k[5][idxs]*b5Θdiff + k[6][idxs]*b6Θdiff + k[7][idxs]*b7Θdiff + k[8][idxs]*b8Θdiff + k[9][idxs]*b9Θdiff + k[10][idxs]*b10Θdiff + k[11][idxs]*b11Θdiff + k[12][idxs]*b12Θdiff
    @inbounds for (j,i) in enumerate(idxs)
      out[j] = k[1][i]*b1Θdiff + k[4][i]*b4Θdiff + k[5][i]*b5Θdiff + k[6][i]*b6Θdiff + k[7][i]*b7Θdiff + k[8][i]*b8Θdiff + k[9][i]*b9Θdiff + k[10][i]*b10Θdiff + k[11][i]*b11Θdiff + k[12][i]*b12Θdiff
    end
  end
end

"""

"""
@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::Vern6ConstantCache,idxs,T::Type{Val{0}})
  @unpack r011,r012,r013,r014,r015,r016,r042,r043,r044,r045,r046,r052,r053,r054,r055,r056,r062,r063,r064,r065,r066,r072,r073,r074,r075,r076,r082,r083,r084,r085,r086,r092,r093,r094,r095,r096,r102,r103,r104,r105,r106,r112,r113,r114,r115,r116,r122,r123,r124,r125,r126 = cache

  b1Θ  = @evalpoly(Θ, 0, r011, r012, r013, r014, r015, r016)
  b4Θ  = @evalpoly(Θ, 0,    0, r042, r043, r044, r045, r046)
  b5Θ  = @evalpoly(Θ, 0,    0, r052, r053, r054, r055, r056)
  b6Θ  = @evalpoly(Θ, 0,    0, r062, r063, r064, r065, r066)
  b7Θ  = @evalpoly(Θ, 0,    0, r072, r073, r074, r075, r076)
  b8Θ  = @evalpoly(Θ, 0,    0, r082, r083, r084, r085, r086)
  b9Θ  = @evalpoly(Θ, 0,    0, r092, r093, r094, r095, r096)
  b10Θ = @evalpoly(Θ, 0,    0, r102, r103, r104, r105, r106)
  b11Θ = @evalpoly(Θ, 0,    0, r112, r113, r114, r115, r116)
  b12Θ = @evalpoly(Θ, 0,    0, r122, r123, r124, r125, r126)

  #@. y₀ + dt*(k[1]*b1Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ + k[12]*b12Θ)
  if idxs == nothing
    return y₀ + dt*(k[1]*b1Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ +
           k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ + k[12]*b12Θ)
  else
    return y₀[idxs] + dt*(k[1][idxs]*b1Θ + k[4][idxs]*b4Θ + k[5][idxs]*b5Θ +
           k[6][idxs]*b6Θ + k[7][idxs]*b7Θ + k[8][idxs]*b8Θ + k[9][idxs]*b9Θ +
           k[10][idxs]*b10Θ + k[11][idxs]*b11Θ + k[12][idxs]*b12Θ)
  end
end

@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::Vern6ConstantCache,idxs,T::Type{Val{1}})
  @unpack r011,r012,r013,r014,r015,r016,r042,r043,r044,r045,r046,r052,r053,r054,r055,r056,r062,r063,r064,r065,r066,r072,r073,r074,r075,r076,r082,r083,r084,r085,r086,r092,r093,r094,r095,r096,r102,r103,r104,r105,r106,r112,r113,r114,r115,r116,r122,r123,r124,r125,r126 = cache

  b1Θdiff  = @evalpoly(Θ, r011, 2*r012, 3*r013, 4*r014, 5*r015, 6*r016)
  b4Θdiff  = @evalpoly(Θ,    0, 2*r042, 3*r043, 4*r044, 5*r045, 6*r046)
  b5Θdiff  = @evalpoly(Θ,    0, 2*r052, 3*r053, 4*r054, 5*r055, 6*r056)
  b6Θdiff  = @evalpoly(Θ,    0, 2*r062, 3*r063, 4*r064, 5*r065, 6*r066)
  b7Θdiff  = @evalpoly(Θ,    0, 2*r072, 3*r073, 4*r074, 5*r075, 6*r076)
  b8Θdiff  = @evalpoly(Θ,    0, 2*r082, 3*r083, 4*r084, 5*r085, 6*r086)
  b9Θdiff  = @evalpoly(Θ,    0, 2*r092, 3*r093, 4*r094, 5*r095, 6*r096)
  b10Θdiff = @evalpoly(Θ,    0, 2*r102, 3*r103, 4*r104, 5*r105, 6*r106)
  b11Θdiff = @evalpoly(Θ,    0, 2*r112, 3*r113, 4*r114, 5*r115, 6*r116)
  b12Θdiff = @evalpoly(Θ,    0, 2*r122, 3*r123, 4*r124, 5*r125, 6*r126)

  #@. k[1]*b1Θdiff + k[4]*b4Θdiff + k[5]*b5Θdiff + k[6]*b6Θdiff + k[7]*b7Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff + k[10]*b10Θdiff + k[11]*b11Θdiff + k[12]*b12Θdiff
  if idxs == nothing
    return k[1]*b1Θdiff + k[4]*b4Θdiff + k[5]*b5Θdiff + k[6]*b6Θdiff +
           k[7]*b7Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff + k[10]*b10Θdiff +
           k[11]*b11Θdiff + k[12]*b12Θdiff
  else
    return k[1][idxs]*b1Θdiff + k[4][idxs]*b4Θdiff + k[5][idxs]*b5Θdiff +
           k[6][idxs]*b6Θdiff + k[7][idxs]*b7Θdiff + k[8][idxs]*b8Θdiff +
           k[9][idxs]*b9Θdiff + k[10][idxs]*b10Θdiff + k[11][idxs]*b11Θdiff +
           k[12][idxs]*b12Θdiff
  end
end

"""

"""
@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::Vern7ConstantCache,idxs,T::Type{Val{0}})
  @unpack r011,r012,r013,r014,r015,r016,r017,r042,r043,r044,r045,r046,r047,r052,r053,r054,r055,r056,r057,r062,r063,r064,r065,r066,r067,r072,r073,r074,r075,r076,r077,r082,r083,r084,r085,r086,r087,r092,r093,r094,r095,r096,r097,r112,r113,r114,r115,r116,r117,r122,r123,r124,r125,r126,r127,r132,r133,r134,r135,r136,r137,r142,r143,r144,r145,r146,r147,r152,r153,r154,r155,r156,r157,r162,r163,r164,r165,r166,r167 = cache

  b1Θ  = @evalpoly(Θ, 0, r011, r012, r013, r014, r015, r016, r017)
  b4Θ  = @evalpoly(Θ, 0,    0, r042, r043, r044, r045, r046, r047)
  b5Θ  = @evalpoly(Θ, 0,    0, r052, r053, r054, r055, r056, r057)
  b6Θ  = @evalpoly(Θ, 0,    0, r062, r063, r064, r065, r066, r067)
  b7Θ  = @evalpoly(Θ, 0,    0, r072, r073, r074, r075, r076, r077)
  b8Θ  = @evalpoly(Θ, 0,    0, r082, r083, r084, r085, r086, r087)
  b9Θ  = @evalpoly(Θ, 0,    0, r092, r093, r094, r095, r096, r097)
  b11Θ = @evalpoly(Θ, 0,    0, r112, r113, r114, r115, r116, r117)
  b12Θ = @evalpoly(Θ, 0,    0, r122, r123, r124, r125, r126, r127)
  b13Θ = @evalpoly(Θ, 0,    0, r132, r133, r134, r135, r136, r137)
  b14Θ = @evalpoly(Θ, 0,    0, r142, r143, r144, r145, r146, r147)
  b15Θ = @evalpoly(Θ, 0,    0, r152, r153, r154, r155, r156, r157)
  b16Θ = @evalpoly(Θ, 0,    0, r162, r163, r164, r165, r166, r167)

  #@. y₀ + dt*(k[1]*b1Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[11]*b11Θ + k[12]*b12Θ + k[13]*b13Θ + k[14]*b14Θ + k[15]*b15Θ + k[16]*b16Θ)
  if idxs == nothing
    return y₀ + dt*(k[1]*b1Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ +
           k[8]*b8Θ + k[9]*b9Θ + k[11]*b11Θ + k[12]*b12Θ + k[13]*b13Θ +
           k[14]*b14Θ + k[15]*b15Θ + k[16]*b16Θ)
  else
    return y₀[idxs] + dt*(k[1][idxs]*b1Θ + k[4][idxs]*b4Θ + k[5][idxs]*b5Θ +
           k[6][idxs]*b6Θ + k[7][idxs]*b7Θ + k[8][idxs]*b8Θ + k[9][idxs]*b9Θ +
           k[11][idxs]*b11Θ + k[12][idxs]*b12Θ + k[13][idxs]*b13Θ +
           k[14][idxs]*b14Θ + k[15][idxs]*b15Θ + k[16][idxs]*b16Θ)
  end
end

@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::Vern7ConstantCache,idxs,T::Type{Val{1}})
  @unpack r011,r012,r013,r014,r015,r016,r017,r042,r043,r044,r045,r046,r047,r052,r053,r054,r055,r056,r057,r062,r063,r064,r065,r066,r067,r072,r073,r074,r075,r076,r077,r082,r083,r084,r085,r086,r087,r092,r093,r094,r095,r096,r097,r112,r113,r114,r115,r116,r117,r122,r123,r124,r125,r126,r127,r132,r133,r134,r135,r136,r137,r142,r143,r144,r145,r146,r147,r152,r153,r154,r155,r156,r157,r162,r163,r164,r165,r166,r167 = cache

  b1Θdiff  = @evalpoly(Θ, r011, 2*r012, 3*r013, 4*r014, 5*r015, 6*r016, 7*r017)
  b4Θdiff  = @evalpoly(Θ,    0, 2*r042, 3*r043, 4*r044, 5*r045, 6*r046, 7*r047)
  b5Θdiff  = @evalpoly(Θ,    0, 2*r052, 3*r053, 4*r054, 5*r055, 6*r056, 7*r057)
  b6Θdiff  = @evalpoly(Θ,    0, 2*r062, 3*r063, 4*r064, 5*r065, 6*r066, 7*r067)
  b7Θdiff  = @evalpoly(Θ,    0, 2*r072, 3*r073, 4*r074, 5*r075, 6*r076, 7*r077)
  b8Θdiff  = @evalpoly(Θ,    0, 2*r082, 3*r083, 4*r084, 5*r085, 6*r086, 7*r087)
  b9Θdiff  = @evalpoly(Θ,    0, 2*r092, 3*r093, 4*r094, 5*r095, 6*r096, 7*r097)
  b11Θdiff = @evalpoly(Θ,    0, 2*r112, 3*r113, 4*r114, 5*r115, 6*r116, 7*r117)
  b12Θdiff = @evalpoly(Θ,    0, 2*r122, 3*r123, 4*r124, 5*r125, 6*r126, 7*r127)
  b13Θdiff = @evalpoly(Θ,    0, 2*r132, 3*r133, 4*r134, 5*r135, 6*r136, 7*r137)
  b14Θdiff = @evalpoly(Θ,    0, 2*r142, 3*r143, 4*r144, 5*r145, 6*r146, 7*r147)
  b15Θdiff = @evalpoly(Θ,    0, 2*r152, 3*r153, 4*r154, 5*r155, 6*r156, 7*r157)
  b16Θdiff = @evalpoly(Θ,    0, 2*r162, 3*r163, 4*r164, 5*r165, 6*r166, 7*r167)

  #@. k[1]*b1Θdiff + k[4]*b4Θdiff + k[5]*b5Θdiff + k[6]*b6Θdiff + k[7]*b7Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff + k[11]*b11Θdiff + k[12]*b12Θdiff + k[13]*b13Θdiff + k[14]*b14Θdiff + k[15]*b15Θdiff + k[16]*b16Θdiff
  if idxs == nothing
    return k[1]*b1Θdiff + k[4]*b4Θdiff + k[5]*b5Θdiff + k[6]*b6Θdiff +
           k[7]*b7Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff + k[11]*b11Θdiff +
           k[12]*b12Θdiff + k[13]*b13Θdiff + k[14]*b14Θdiff + k[15]*b15Θdiff +
           k[16]*b16Θdiff
  else
    return k[1][idxs]*b1Θdiff + k[4][idxs]*b4Θdiff + k[5][idxs]*b5Θdiff +
           k[6][idxs]*b6Θdiff + k[7][idxs]*b7Θdiff + k[8][idxs]*b8Θdiff +
           k[9][idxs]*b9Θdiff + k[11][idxs]*b11Θdiff + k[12][idxs]*b12Θdiff +
           k[13][idxs]*b13Θdiff + k[14][idxs]*b14Θdiff + k[15][idxs]*b15Θdiff +
           k[16][idxs]*b16Θdiff
  end
end

"""

"""
@muladd function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::Vern7Cache,idxs,T::Type{Val{0}})
  @unpack r011,r012,r013,r014,r015,r016,r017,r042,r043,r044,r045,r046,r047,r052,r053,r054,r055,r056,r057,r062,r063,r064,r065,r066,r067,r072,r073,r074,r075,r076,r077,r082,r083,r084,r085,r086,r087,r092,r093,r094,r095,r096,r097,r112,r113,r114,r115,r116,r117,r122,r123,r124,r125,r126,r127,r132,r133,r134,r135,r136,r137,r142,r143,r144,r145,r146,r147,r152,r153,r154,r155,r156,r157,r162,r163,r164,r165,r166,r167 = cache.tab

  b1Θ  = @evalpoly(Θ, 0, r011, r012, r013, r014, r015, r016, r017)
  b4Θ  = @evalpoly(Θ, 0,    0, r042, r043, r044, r045, r046, r047)
  b5Θ  = @evalpoly(Θ, 0,    0, r052, r053, r054, r055, r056, r057)
  b6Θ  = @evalpoly(Θ, 0,    0, r062, r063, r064, r065, r066, r067)
  b7Θ  = @evalpoly(Θ, 0,    0, r072, r073, r074, r075, r076, r077)
  b8Θ  = @evalpoly(Θ, 0,    0, r082, r083, r084, r085, r086, r087)
  b9Θ  = @evalpoly(Θ, 0,    0, r092, r093, r094, r095, r096, r097)
  b11Θ = @evalpoly(Θ, 0,    0, r112, r113, r114, r115, r116, r117)
  b12Θ = @evalpoly(Θ, 0,    0, r122, r123, r124, r125, r126, r127)
  b13Θ = @evalpoly(Θ, 0,    0, r132, r133, r134, r135, r136, r137)
  b14Θ = @evalpoly(Θ, 0,    0, r142, r143, r144, r145, r146, r147)
  b15Θ = @evalpoly(Θ, 0,    0, r152, r153, r154, r155, r156, r157)
  b16Θ = @evalpoly(Θ, 0,    0, r162, r163, r164, r165, r166, r167)

  if out == nothing
    if idxs == nothing
      # return @. y₀ + dt*(k[1]*b1Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[11]*b11Θ + k[12]*b12Θ + k[13]*b13Θ + k[14]*b14Θ + k[15]*b15Θ + k[16]*b16Θ)
      return y₀ + dt*(k[1]*b1Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[11]*b11Θ + k[12]*b12Θ + k[13]*b13Θ + k[14]*b14Θ + k[15]*b15Θ + k[16]*b16Θ)
    else
      # return @. y₀[idxs] + dt*(k[1][idxs]*b1Θ + k[4][idxs]*b4Θ + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ + k[7][idxs]*b7Θ + k[8][idxs]*b8Θ + k[9][idxs]*b9Θ + k[11][idxs]*b11Θ + k[12][idxs]*b12Θ + k[13][idxs]*b13Θ + k[14][idxs]*b14Θ + k[15][idxs]*b15Θ + k[16][idxs]*b16Θ)
      return y₀[idxs] + dt*(k[1][idxs]*b1Θ + k[4][idxs]*b4Θ + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ + k[7][idxs]*b7Θ + k[8][idxs]*b8Θ + k[9][idxs]*b9Θ + k[11][idxs]*b11Θ + k[12][idxs]*b12Θ + k[13][idxs]*b13Θ + k[14][idxs]*b14Θ + k[15][idxs]*b15Θ + k[16][idxs]*b16Θ)
    end
  elseif idxs == nothing
    # @. out = y₀ + dt*(k[1]*b1Θ + k[4]*b4Θ + k[5]*b5Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[11]*b11Θ + k[12]*b12Θ + k[13]*b13Θ + k[14]*b14Θ + k[15]*b15Θ + k[16]*b16Θ)
    @inbounds for i in eachindex(out)
      out[i] = y₀[i] + dt*(k[1][i]*b1Θ + k[4][i]*b4Θ + k[5][i]*b5Θ + k[6][i]*b6Θ + k[7][i]*b7Θ + k[8][i]*b8Θ + k[9][i]*b9Θ + k[11][i]*b11Θ + k[12][i]*b12Θ + k[13][i]*b13Θ + k[14][i]*b14Θ + k[15][i]*b15Θ + k[16][i]*b16Θ)
    end
  else
    # @views @. out = y₀[idxs] + dt*(k[1][idxs]*b1Θ + k[4][idxs]*b4Θ + k[5][idxs]*b5Θ + k[6][idxs]*b6Θ + k[7][idxs]*b7Θ + k[8][idxs]*b8Θ + k[9][idxs]*b9Θ + k[11][idxs]*b11Θ + k[12][idxs]*b12Θ + k[13][idxs]*b13Θ + k[14][idxs]*b14Θ + k[15][idxs]*b15Θ + k[16][idxs]*b16Θ)
    @inbounds for (j,i) in enumerate(idxs)
      out[j] = y₀[i] + dt*(k[1][i]*b1Θ + k[4][i]*b4Θ + k[5][i]*b5Θ + k[6][i]*b6Θ + k[7][i]*b7Θ + k[8][i]*b8Θ + k[9][i]*b9Θ + k[11][i]*b11Θ + k[12][i]*b12Θ + k[13][i]*b13Θ + k[14][i]*b14Θ + k[15][i]*b15Θ + k[16][i]*b16Θ)
    end
  end
end

@muladd function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::Vern7Cache,idxs,T::Type{Val{1}})
  @unpack r011,r012,r013,r014,r015,r016,r017,r042,r043,r044,r045,r046,r047,r052,r053,r054,r055,r056,r057,r062,r063,r064,r065,r066,r067,r072,r073,r074,r075,r076,r077,r082,r083,r084,r085,r086,r087,r092,r093,r094,r095,r096,r097,r112,r113,r114,r115,r116,r117,r122,r123,r124,r125,r126,r127,r132,r133,r134,r135,r136,r137,r142,r143,r144,r145,r146,r147,r152,r153,r154,r155,r156,r157,r162,r163,r164,r165,r166,r167 = cache.tab

  b1Θdiff  = @evalpoly(Θ, r011, 2*r012, 3*r013, 4*r014, 5*r015, 6*r016, 7*r017)
  b4Θdiff  = @evalpoly(Θ,    0, 2*r042, 3*r043, 4*r044, 5*r045, 6*r046, 7*r047)
  b5Θdiff  = @evalpoly(Θ,    0, 2*r052, 3*r053, 4*r054, 5*r055, 6*r056, 7*r057)
  b6Θdiff  = @evalpoly(Θ,    0, 2*r062, 3*r063, 4*r064, 5*r065, 6*r066, 7*r067)
  b7Θdiff  = @evalpoly(Θ,    0, 2*r072, 3*r073, 4*r074, 5*r075, 6*r076, 7*r077)
  b8Θdiff  = @evalpoly(Θ,    0, 2*r082, 3*r083, 4*r084, 5*r085, 6*r086, 7*r087)
  b9Θdiff  = @evalpoly(Θ,    0, 2*r092, 3*r093, 4*r094, 5*r095, 6*r096, 7*r097)
  b11Θdiff = @evalpoly(Θ,    0, 2*r112, 3*r113, 4*r114, 5*r115, 6*r116, 7*r117)
  b12Θdiff = @evalpoly(Θ,    0, 2*r122, 3*r123, 4*r124, 5*r125, 6*r126, 7*r127)
  b13Θdiff = @evalpoly(Θ,    0, 2*r132, 3*r133, 4*r134, 5*r135, 6*r136, 7*r137)
  b14Θdiff = @evalpoly(Θ,    0, 2*r142, 3*r143, 4*r144, 5*r145, 6*r146, 7*r147)
  b15Θdiff = @evalpoly(Θ,    0, 2*r152, 3*r153, 4*r154, 5*r155, 6*r156, 7*r157)
  b16Θdiff = @evalpoly(Θ,    0, 2*r162, 3*r163, 4*r164, 5*r165, 6*r166, 7*r167)

  if out == nothing
    if idxs == nothing
      # return @. k[1]*b1Θdiff + k[4]*b4Θdiff + k[5]*b5Θdiff + k[6]*b6Θdiff + k[7]*b7Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff + k[11]*b11Θdiff + k[12]*b12Θdiff + k[13]*b13Θdiff + k[14]*b14Θdiff + k[15]*b15Θdiff + k[16]*b16Θdiff
      return k[1]*b1Θdiff + k[4]*b4Θdiff + k[5]*b5Θdiff + k[6]*b6Θdiff + k[7]*b7Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff + k[11]*b11Θdiff + k[12]*b12Θdiff + k[13]*b13Θdiff + k[14]*b14Θdiff + k[15]*b15Θdiff + k[16]*b16Θdiff
    else
      # return @. k[1][idxs]*b1Θdiff + k[4][idxs]*b4Θdiff + k[5][idxs]*b5Θdiff + k[6][idxs]*b6Θdiff + k[7][idxs]*b7Θdiff + k[8][idxs]*b8Θdiff + k[9][idxs]*b9Θdiff + k[11][idxs]*b11Θdiff + k[12][idxs]*b12Θdiff + k[13][idxs]*b13Θdiff + k[14][idxs]*b14Θdiff + k[15][idxs]*b15Θdiff + k[16][idxs]*b16Θdiff
      return k[1][idxs]*b1Θdiff + k[4][idxs]*b4Θdiff + k[5][idxs]*b5Θdiff + k[6][idxs]*b6Θdiff + k[7][idxs]*b7Θdiff + k[8][idxs]*b8Θdiff + k[9][idxs]*b9Θdiff + k[11][idxs]*b11Θdiff + k[12][idxs]*b12Θdiff + k[13][idxs]*b13Θdiff + k[14][idxs]*b14Θdiff + k[15][idxs]*b15Θdiff + k[16][idxs]*b16Θdiff
    end
  elseif idxs == nothing
    #@. out = k[1]*b1Θdiff + k[4]*b4Θdiff + k[5]*b5Θdiff + k[6]*b6Θdiff + k[7]*b7Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff + k[11]*b11Θdiff + k[12]*b12Θdiff + k[13]*b13Θdiff + k[14]*b14Θdiff + k[15]*b15Θdiff + k[16]*b16Θdiff
    @inbounds for i in eachindex(out)
      out[i] = k[1][i]*b1Θdiff + k[4][i]*b4Θdiff + k[5][i]*b5Θdiff + k[6][i]*b6Θdiff + k[7][i]*b7Θdiff + k[8][i]*b8Θdiff + k[9][i]*b9Θdiff + k[11][i]*b11Θdiff + k[12][i]*b12Θdiff + k[13][i]*b13Θdiff + k[14][i]*b14Θdiff + k[15][i]*b15Θdiff + k[16][i]*b16Θdiff
    end
    else
    #@views @. out = k[1][idxs]*b1Θdiff + k[4][idxs]*b4Θdiff + k[5][idxs]*b5Θdiff + k[6][idxs]*b6Θdiff + k[7][idxs]*b7Θdiff + k[8][idxs]*b8Θdiff + k[9][idxs]*b9Θdiff + k[11][idxs]*b11Θdiff + k[12][idxs]*b12Θdiff + k[13][idxs]*b13Θdiff + k[14][idxs]*b14Θdiff + k[15][idxs]*b15Θdiff + k[16][idxs]*b16Θdiff
    @inbounds for (j,i) in enumerate(idxs)
      out[i] = k[1][i]*b1Θdiff + k[4][i]*b4Θdiff + k[5][i]*b5Θdiff + k[6][i]*b6Θdiff + k[7][i]*b7Θdiff + k[8][i]*b8Θdiff + k[9][i]*b9Θdiff + k[11][i]*b11Θdiff + k[12][i]*b12Θdiff + k[13][i]*b13Θdiff + k[14][i]*b14Θdiff + k[15][i]*b15Θdiff + k[16][i]*b16Θdiff
    end
  end
end

"""

"""
@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::Vern8ConstantCache,idxs,T::Type{Val{0}})
  @unpack r011,r012,r013,r014,r015,r016,r017,r018,r062,r063,r064,r065,r066,r067,r068,r072,r073,r074,r075,r076,r077,r078,r082,r083,r084,r085,r086,r087,r088,r092,r093,r094,r095,r096,r097,r098,r102,r103,r104,r105,r106,r107,r108,r112,r113,r114,r115,r116,r117,r118,r122,r123,r124,r125,r126,r127,r128,r142,r143,r144,r145,r146,r147,r148,r152,r153,r154,r155,r156,r157,r158,r162,r163,r164,r165,r166,r167,r168,r172,r173,r174,r175,r176,r177,r178,r182,r183,r184,r185,r186,r187,r188,r192,r193,r194,r195,r196,r197,r198,r202,r203,r204,r205,r206,r207,r208,r212,r213,r214,r215,r216,r217,r218 = cache

  b1Θ  = @evalpoly(Θ, 0, r011, r012, r013, r014, r015, r016, r017, r018)
  b6Θ  = @evalpoly(Θ, 0,    0, r062, r063, r064, r065, r066, r067, r068)
  b7Θ  = @evalpoly(Θ, 0,    0, r072, r073, r074, r075, r076, r077, r078)
  b8Θ  = @evalpoly(Θ, 0,    0, r082, r083, r084, r085, r086, r087, r088)
  b9Θ  = @evalpoly(Θ, 0,    0, r092, r093, r094, r095, r096, r097, r098)
  b10Θ = @evalpoly(Θ, 0,    0, r102, r103, r104, r105, r106, r107, r108)
  b11Θ = @evalpoly(Θ, 0,    0, r112, r113, r114, r115, r116, r117, r118)
  b12Θ = @evalpoly(Θ, 0,    0, r122, r123, r124, r125, r126, r127, r128)
  b14Θ = @evalpoly(Θ, 0,    0, r142, r143, r144, r145, r146, r147, r148)
  b15Θ = @evalpoly(Θ, 0,    0, r152, r153, r154, r155, r156, r157, r158)
  b16Θ = @evalpoly(Θ, 0,    0, r162, r163, r164, r165, r166, r167, r168)
  b17Θ = @evalpoly(Θ, 0,    0, r172, r173, r174, r175, r176, r177, r178)
  b18Θ = @evalpoly(Θ, 0,    0, r182, r183, r184, r185, r186, r187, r188)
  b19Θ = @evalpoly(Θ, 0,    0, r192, r193, r194, r195, r196, r197, r198)
  b20Θ = @evalpoly(Θ, 0,    0, r202, r203, r204, r205, r206, r207, r208)
  b21Θ = @evalpoly(Θ, 0,    0, r212, r213, r214, r215, r216, r217, r218)

  #@. y₀ + dt*(k[1]*b1Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ + k[12]*b12Θ + k[14]*b14Θ + k[15]*b15Θ + k[16]*b16Θ + k[17]*b17Θ + k[18]*b18Θ + k[19]*b19Θ + k[20]*b20Θ + k[21]*b21Θ)
  if idxs == nothing
    return y₀ + dt*(k[1]*b1Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ +
           k[10]*b10Θ + k[11]*b11Θ + k[12]*b12Θ + k[14]*b14Θ + k[15]*b15Θ +
           k[16]*b16Θ + k[17]*b17Θ + k[18]*b18Θ + k[19]*b19Θ + k[20]*b20Θ +
           k[21]*b21Θ)
  else
    return y₀[idxs] + dt*(k[1][idxs]*b1Θ + k[6][idxs]*b6Θ + k[7][idxs]*b7Θ +
           k[8][idxs]*b8Θ + k[9][idxs]*b9Θ + k[10][idxs]*b10Θ +
           k[11][idxs]*b11Θ + k[12][idxs]*b12Θ + k[14][idxs]*b14Θ +
           k[15][idxs]*b15Θ + k[16][idxs]*b16Θ + k[17][idxs]*b17Θ +
           k[18][idxs]*b18Θ + k[19][idxs]*b19Θ + k[20][idxs]*b20Θ +
           k[21][idxs]*b21Θ)
  end
end

@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::Vern8ConstantCache,idxs,T::Type{Val{1}})
  @unpack r011,r012,r013,r014,r015,r016,r017,r018,r062,r063,r064,r065,r066,r067,r068,r072,r073,r074,r075,r076,r077,r078,r082,r083,r084,r085,r086,r087,r088,r092,r093,r094,r095,r096,r097,r098,r102,r103,r104,r105,r106,r107,r108,r112,r113,r114,r115,r116,r117,r118,r122,r123,r124,r125,r126,r127,r128,r142,r143,r144,r145,r146,r147,r148,r152,r153,r154,r155,r156,r157,r158,r162,r163,r164,r165,r166,r167,r168,r172,r173,r174,r175,r176,r177,r178,r182,r183,r184,r185,r186,r187,r188,r192,r193,r194,r195,r196,r197,r198,r202,r203,r204,r205,r206,r207,r208,r212,r213,r214,r215,r216,r217,r218 = cache

  b1Θdiff  = @evalpoly(Θ, r011, 2*r012, 3*r013, 4*r014, 5*r015, 6*r016, 7*r017, 8*r018)
  b6Θdiff  = @evalpoly(Θ,    0, 2*r062, 3*r063, 4*r064, 5*r065, 6*r066, 7*r067, 8*r068)
  b7Θdiff  = @evalpoly(Θ,    0, 2*r072, 3*r073, 4*r074, 5*r075, 6*r076, 7*r077, 8*r078)
  b8Θdiff  = @evalpoly(Θ,    0, 2*r082, 3*r083, 4*r084, 5*r085, 6*r086, 7*r087, 8*r088)
  b9Θdiff  = @evalpoly(Θ,    0, 2*r092, 3*r093, 4*r094, 5*r095, 6*r096, 7*r097, 8*r098)
  b10Θdiff = @evalpoly(Θ,    0, 2*r102, 3*r103, 4*r104, 5*r105, 6*r106, 7*r107, 8*r108)
  b11Θdiff = @evalpoly(Θ,    0, 2*r112, 3*r113, 4*r114, 5*r115, 6*r116, 7*r117, 8*r118)
  b12Θdiff = @evalpoly(Θ,    0, 2*r122, 3*r123, 4*r124, 5*r125, 6*r126, 7*r127, 8*r128)
  b14Θdiff = @evalpoly(Θ,    0, 2*r142, 3*r143, 4*r144, 5*r145, 6*r146, 7*r147, 8*r148)
  b15Θdiff = @evalpoly(Θ,    0, 2*r152, 3*r153, 4*r154, 5*r155, 6*r156, 7*r157, 8*r158)
  b16Θdiff = @evalpoly(Θ,    0, 2*r162, 3*r163, 4*r164, 5*r165, 6*r166, 7*r167, 8*r168)
  b17Θdiff = @evalpoly(Θ,    0, 2*r172, 3*r173, 4*r174, 5*r175, 6*r176, 7*r177, 8*r178)
  b18Θdiff = @evalpoly(Θ,    0, 2*r182, 3*r183, 4*r184, 5*r185, 6*r186, 7*r187, 8*r188)
  b19Θdiff = @evalpoly(Θ,    0, 2*r192, 3*r193, 4*r194, 5*r195, 6*r196, 7*r197, 8*r198)
  b20Θdiff = @evalpoly(Θ,    0, 2*r202, 3*r203, 4*r204, 5*r205, 6*r206, 7*r207, 8*r208)
  b21Θdiff = @evalpoly(Θ,    0, 2*r212, 3*r213, 4*r214, 5*r215, 6*r216, 7*r217, 8*r218)

  #@. k[1]*b1Θdiff + k[6]*b6Θdiff + k[7]*b7Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff + k[10]*b10Θdiff + k[11]*b11Θdiff + k[12]*b12Θdiff + k[14]*b14Θdiff + k[15]*b15Θdiff + k[16]*b16Θdiff + k[17]*b17Θdiff + k[18]*b18Θdiff + k[19]*b19Θdiff + k[20]*b20Θdiff + k[21]*b21Θdiff
  if idxs == nothing
    return k[1]*b1Θdiff + k[6]*b6Θdiff + k[7]*b7Θdiff + k[8]*b8Θdiff +
           k[9]*b9Θdiff + k[10]*b10Θdiff + k[11]*b11Θdiff + k[12]*b12Θdiff +
           k[14]*b14Θdiff + k[15]*b15Θdiff + k[16]*b16Θdiff + k[17]*b17Θdiff +
           k[18]*b18Θdiff + k[19]*b19Θdiff + k[20]*b20Θdiff + k[21]*b21Θdiff
  else
    return k[1][idxs]*b1Θdiff + k[6][idxs]*b6Θdiff + k[7][idxs]*b7Θdiff +
           k[8][idxs]*b8Θdiff + k[9][idxs]*b9Θdiff + k[10][idxs]*b10Θdiff +
           k[11][idxs]*b11Θdiff + k[12][idxs]*b12Θdiff + k[14][idxs]*b14Θdiff +
           k[15][idxs]*b15Θdiff + k[16][idxs]*b16Θdiff + k[17][idxs]*b17Θdiff +
           k[18][idxs]*b18Θdiff + k[19][idxs]*b19Θdiff + k[20][idxs]*b20Θdiff + k[21][idxs]*b21Θdiff

  end
end

"""

"""
@muladd function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::Vern8Cache,idxs,T::Type{Val{0}})
  @unpack r011,r012,r013,r014,r015,r016,r017,r018,r062,r063,r064,r065,r066,r067,r068,r072,r073,r074,r075,r076,r077,r078,r082,r083,r084,r085,r086,r087,r088,r092,r093,r094,r095,r096,r097,r098,r102,r103,r104,r105,r106,r107,r108,r112,r113,r114,r115,r116,r117,r118,r122,r123,r124,r125,r126,r127,r128,r142,r143,r144,r145,r146,r147,r148,r152,r153,r154,r155,r156,r157,r158,r162,r163,r164,r165,r166,r167,r168,r172,r173,r174,r175,r176,r177,r178,r182,r183,r184,r185,r186,r187,r188,r192,r193,r194,r195,r196,r197,r198,r202,r203,r204,r205,r206,r207,r208,r212,r213,r214,r215,r216,r217,r218 = cache.tab

  b1Θ  = @evalpoly(Θ, 0, r011, r012, r013, r014, r015, r016, r017, r018)
  b6Θ  = @evalpoly(Θ, 0,    0, r062, r063, r064, r065, r066, r067, r068)
  b7Θ  = @evalpoly(Θ, 0,    0, r072, r073, r074, r075, r076, r077, r078)
  b8Θ  = @evalpoly(Θ, 0,    0, r082, r083, r084, r085, r086, r087, r088)
  b9Θ  = @evalpoly(Θ, 0,    0, r092, r093, r094, r095, r096, r097, r098)
  b10Θ = @evalpoly(Θ, 0,    0, r102, r103, r104, r105, r106, r107, r108)
  b11Θ = @evalpoly(Θ, 0,    0, r112, r113, r114, r115, r116, r117, r118)
  b12Θ = @evalpoly(Θ, 0,    0, r122, r123, r124, r125, r126, r127, r128)
  b14Θ = @evalpoly(Θ, 0,    0, r142, r143, r144, r145, r146, r147, r148)
  b15Θ = @evalpoly(Θ, 0,    0, r152, r153, r154, r155, r156, r157, r158)
  b16Θ = @evalpoly(Θ, 0,    0, r162, r163, r164, r165, r166, r167, r168)
  b17Θ = @evalpoly(Θ, 0,    0, r172, r173, r174, r175, r176, r177, r178)
  b18Θ = @evalpoly(Θ, 0,    0, r182, r183, r184, r185, r186, r187, r188)
  b19Θ = @evalpoly(Θ, 0,    0, r192, r193, r194, r195, r196, r197, r198)
  b20Θ = @evalpoly(Θ, 0,    0, r202, r203, r204, r205, r206, r207, r208)
  b21Θ = @evalpoly(Θ, 0,    0, r212, r213, r214, r215, r216, r217, r218)

  if out == nothing
    if idxs == nothing
      # return @. y₀ + dt*(k[1]*b1Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ + k[12]*b12Θ + k[14]*b14Θ + k[15]*b15Θ + k[16]*b16Θ + k[17]*b17Θ + k[18]*b18Θ + k[19]*b19Θ + k[20]*b20Θ + k[21]*b21Θ)
      return y₀ + dt*(k[1]*b1Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ + k[12]*b12Θ + k[14]*b14Θ + k[15]*b15Θ + k[16]*b16Θ + k[17]*b17Θ + k[18]*b18Θ + k[19]*b19Θ + k[20]*b20Θ + k[21]*b21Θ)
    else
      # return @. y₀[idxs] + dt*(k[1][idxs]*b1Θ + k[6][idxs]*b6Θ + k[7][idxs]*b7Θ + k[8][idxs]*b8Θ + k[9][idxs]*b9Θ + k[10][idxs]*b10Θ + k[11][idxs]*b11Θ + k[12][idxs]*b12Θ + k[14][idxs]*b14Θ + k[15][idxs]*b15Θ + k[16][idxs]*b16Θ + k[17][idxs]*b17Θ + k[18][idxs]*b18Θ + k[19][idxs]*b19Θ + k[20][idxs]*b20Θ + k[21][idxs]*b21Θ)
      return y₀[idxs] + dt*(k[1][idxs]*b1Θ + k[6][idxs]*b6Θ + k[7][idxs]*b7Θ + k[8][idxs]*b8Θ + k[9][idxs]*b9Θ + k[10][idxs]*b10Θ + k[11][idxs]*b11Θ + k[12][idxs]*b12Θ + k[14][idxs]*b14Θ + k[15][idxs]*b15Θ + k[16][idxs]*b16Θ + k[17][idxs]*b17Θ + k[18][idxs]*b18Θ + k[19][idxs]*b19Θ + k[20][idxs]*b20Θ + k[21][idxs]*b21Θ)
    end
  elseif idxs == nothing
    #@. out = y₀ + dt*(k[1]*b1Θ + k[6]*b6Θ + k[7]*b7Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ + k[12]*b12Θ + k[14]*b14Θ + k[15]*b15Θ + k[16]*b16Θ + k[17]*b17Θ + k[18]*b18Θ + k[19]*b19Θ + k[20]*b20Θ + k[21]*b21Θ)
    @inbounds for i in eachindex(out)
      out[i] = y₀[i] + dt*(k[1][i]*b1Θ + k[6][i]*b6Θ + k[7][i]*b7Θ + k[8][i]*b8Θ + k[9][i]*b9Θ + k[10][i]*b10Θ + k[11][i]*b11Θ + k[12][i]*b12Θ + k[14][i]*b14Θ + k[15][i]*b15Θ + k[16][i]*b16Θ + k[17][i]*b17Θ + k[18][i]*b18Θ + k[19][i]*b19Θ + k[20][i]*b20Θ + k[21][i]*b21Θ)
    end
  else
    #@views @. out = y₀[idxs] + dt*(k[1][idxs]*b1Θ + k[6][idxs]*b6Θ + k[7][idxs]*b7Θ + k[8][idxs]*b8Θ + k[9][idxs]*b9Θ + k[10][idxs]*b10Θ + k[11][idxs]*b11Θ + k[12][idxs]*b12Θ + k[14][idxs]*b14Θ + k[15][idxs]*b15Θ + k[16][idxs]*b16Θ + k[17][idxs]*b17Θ + k[18][idxs]*b18Θ + k[19][idxs]*b19Θ + k[20][idxs]*b20Θ + k[21][idxs]*b21Θ)
    @inbounds for (j,i) in enumerate(idxs)
      out[j] = y₀[i] + dt*(k[1][i]*b1Θ + k[6][i]*b6Θ + k[7][i]*b7Θ + k[8][i]*b8Θ + k[9][i]*b9Θ + k[10][i]*b10Θ + k[11][i]*b11Θ + k[12][i]*b12Θ + k[14][i]*b14Θ + k[15][i]*b15Θ + k[16][i]*b16Θ + k[17][i]*b17Θ + k[18][i]*b18Θ + k[19][i]*b19Θ + k[20][i]*b20Θ + k[21][i]*b21Θ)
    end
  end
end

@muladd function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::Vern8Cache,idxs,T::Type{Val{1}})
  @unpack r011,r012,r013,r014,r015,r016,r017,r018,r062,r063,r064,r065,r066,r067,r068,r072,r073,r074,r075,r076,r077,r078,r082,r083,r084,r085,r086,r087,r088,r092,r093,r094,r095,r096,r097,r098,r102,r103,r104,r105,r106,r107,r108,r112,r113,r114,r115,r116,r117,r118,r122,r123,r124,r125,r126,r127,r128,r142,r143,r144,r145,r146,r147,r148,r152,r153,r154,r155,r156,r157,r158,r162,r163,r164,r165,r166,r167,r168,r172,r173,r174,r175,r176,r177,r178,r182,r183,r184,r185,r186,r187,r188,r192,r193,r194,r195,r196,r197,r198,r202,r203,r204,r205,r206,r207,r208,r212,r213,r214,r215,r216,r217,r218 = cache.tab

  b1Θdiff  = @evalpoly(Θ, r011, 2*r012, 3*r013, 4*r014, 5*r015, 6*r016, 7*r017, 8*r018)
  b6Θdiff  = @evalpoly(Θ,    0, 2*r062, 3*r063, 4*r064, 5*r065, 6*r066, 7*r067, 8*r068)
  b7Θdiff  = @evalpoly(Θ,    0, 2*r072, 3*r073, 4*r074, 5*r075, 6*r076, 7*r077, 8*r078)
  b8Θdiff  = @evalpoly(Θ,    0, 2*r082, 3*r083, 4*r084, 5*r085, 6*r086, 7*r087, 8*r088)
  b9Θdiff  = @evalpoly(Θ,    0, 2*r092, 3*r093, 4*r094, 5*r095, 6*r096, 7*r097, 8*r098)
  b10Θdiff = @evalpoly(Θ,    0, 2*r102, 3*r103, 4*r104, 5*r105, 6*r106, 7*r107, 8*r108)
  b11Θdiff = @evalpoly(Θ,    0, 2*r112, 3*r113, 4*r114, 5*r115, 6*r116, 7*r117, 8*r118)
  b12Θdiff = @evalpoly(Θ,    0, 2*r122, 3*r123, 4*r124, 5*r125, 6*r126, 7*r127, 8*r128)
  b14Θdiff = @evalpoly(Θ,    0, 2*r142, 3*r143, 4*r144, 5*r145, 6*r146, 7*r147, 8*r148)
  b15Θdiff = @evalpoly(Θ,    0, 2*r152, 3*r153, 4*r154, 5*r155, 6*r156, 7*r157, 8*r158)
  b16Θdiff = @evalpoly(Θ,    0, 2*r162, 3*r163, 4*r164, 5*r165, 6*r166, 7*r167, 8*r168)
  b17Θdiff = @evalpoly(Θ,    0, 2*r172, 3*r173, 4*r174, 5*r175, 6*r176, 7*r177, 8*r178)
  b18Θdiff = @evalpoly(Θ,    0, 2*r182, 3*r183, 4*r184, 5*r185, 6*r186, 7*r187, 8*r188)
  b19Θdiff = @evalpoly(Θ,    0, 2*r192, 3*r193, 4*r194, 5*r195, 6*r196, 7*r197, 8*r198)
  b20Θdiff = @evalpoly(Θ,    0, 2*r202, 3*r203, 4*r204, 5*r205, 6*r206, 7*r207, 8*r208)
  b21Θdiff = @evalpoly(Θ,    0, 2*r212, 3*r213, 4*r214, 5*r215, 6*r216, 7*r217, 8*r218)

  if out == nothing
    if idxs == nothing
      # return @. k[1]*b1Θdiff + k[6]*b6Θdiff + k[7]*b7Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff + k[10]*b10Θdiff + k[11]*b11Θdiff + k[12]*b12Θdiff + k[14]*b14Θdiff + k[15]*b15Θdiff + k[16]*b16Θdiff + k[17]*b17Θdiff + k[18]*b18Θdiff + k[19]*b19Θdiff + k[20]*b20Θdiff + k[21]*b21Θdiff
      return k[1]*b1Θdiff + k[6]*b6Θdiff + k[7]*b7Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff + k[10]*b10Θdiff + k[11]*b11Θdiff + k[12]*b12Θdiff + k[14]*b14Θdiff + k[15]*b15Θdiff + k[16]*b16Θdiff + k[17]*b17Θdiff + k[18]*b18Θdiff + k[19]*b19Θdiff + k[20]*b20Θdiff + k[21]*b21Θdiff
    else
      # return @. k[1][idxs]*b1Θdiff + k[6][idxs]*b6Θdiff + k[7][idxs]*b7Θdiff + k[8][idxs]*b8Θdiff + k[9][idxs]*b9Θdiff + k[10][idxs]*b10Θdiff + k[11][idxs]*b11Θdiff + k[12][idxs]*b12Θdiff + k[14][idxs]*b14Θdiff + k[15][idxs]*b15Θdiff + k[16][idxs]*b16Θdiff + k[17][idxs]*b17Θdiff + k[18][idxs]*b18Θdiff + k[19][idxs]*b19Θdiff + k[20][idxs]*b20Θdiff + k[21][idxs]*b21Θdiff
      return k[1][idxs]*b1Θdiff + k[6][idxs]*b6Θdiff + k[7][idxs]*b7Θdiff + k[8][idxs]*b8Θdiff + k[9][idxs]*b9Θdiff + k[10][idxs]*b10Θdiff + k[11][idxs]*b11Θdiff + k[12][idxs]*b12Θdiff + k[14][idxs]*b14Θdiff + k[15][idxs]*b15Θdiff + k[16][idxs]*b16Θdiff + k[17][idxs]*b17Θdiff + k[18][idxs]*b18Θdiff + k[19][idxs]*b19Θdiff + k[20][idxs]*b20Θdiff + k[21][idxs]*b21Θdiff
    end
  elseif idxs == nothing
    #@. out = k[1]*b1Θdiff + k[6]*b6Θdiff + k[7]*b7Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff + k[10]*b10Θdiff + k[11]*b11Θdiff + k[12]*b12Θdiff + k[14]*b14Θdiff + k[15]*b15Θdiff + k[16]*b16Θdiff + k[17]*b17Θdiff + k[18]*b18Θdiff + k[19]*b19Θdiff + k[20]*b20Θdiff + k[21]*b21Θdiff
    @inbounds for i in eachindex(out)
      out[i] = k[1][i]*b1Θdiff + k[6][i]*b6Θdiff + k[7][i]*b7Θdiff + k[8][i]*b8Θdiff + k[9][i]*b9Θdiff + k[10][i]*b10Θdiff + k[11][i]*b11Θdiff + k[12][i]*b12Θdiff + k[14][i]*b14Θdiff + k[15][i]*b15Θdiff + k[16][i]*b16Θdiff + k[17][i]*b17Θdiff + k[18][i]*b18Θdiff + k[19][i]*b19Θdiff + k[20][i]*b20Θdiff + k[21][i]*b21Θdiff
    end
  else
    #@views @. out = k[1][idxs]*b1Θdiff + k[6][idxs]*b6Θdiff + k[7][idxs]*b7Θdiff + k[8][idxs]*b8Θdiff + k[9][idxs]*b9Θdiff + k[10][idxs]*b10Θdiff + k[11][idxs]*b11Θdiff + k[12][idxs]*b12Θdiff + k[14][idxs]*b14Θdiff + k[15][idxs]*b15Θdiff + k[16][idxs]*b16Θdiff + k[17][idxs]*b17Θdiff + k[18][idxs]*b18Θdiff + k[19][idxs]*b19Θdiff + k[20][idxs]*b20Θdiff + k[21][idxs]*b21Θdiff
    @inbounds for (j,i) in enumerate(idxs)
      out[j] = k[1][i]*b1Θdiff + k[6][i]*b6Θdiff + k[7][i]*b7Θdiff + k[8][i]*b8Θdiff + k[9][i]*b9Θdiff + k[10][i]*b10Θdiff + k[11][i]*b11Θdiff + k[12][i]*b12Θdiff + k[14][i]*b14Θdiff + k[15][i]*b15Θdiff + k[16][i]*b16Θdiff + k[17][i]*b17Θdiff + k[18][i]*b18Θdiff + k[19][i]*b19Θdiff + k[20][i]*b20Θdiff + k[21][i]*b21Θdiff
    end
  end
end

"""

"""
@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::Vern9ConstantCache,idxs,T::Type{Val{0}})
  @unpack r011,r012,r013,r014,r015,r016,r017,r018,r019,r082,r083,r084,r085,r086,r087,r088,r089,r092,r093,r094,r095,r096,r097,r098,r099,r102,r103,r104,r105,r106,r107,r108,r109,r112,r113,r114,r115,r116,r117,r118,r119,r122,r123,r124,r125,r126,r127,r128,r129,r132,r133,r134,r135,r136,r137,r138,r139,r142,r143,r144,r145,r146,r147,r148,r149,r152,r153,r154,r155,r156,r157,r158,r159,r172,r173,r174,r175,r176,r177,r178,r179,r182,r183,r184,r185,r186,r187,r188,r189,r192,r193,r194,r195,r196,r197,r198,r199,r202,r203,r204,r205,r206,r207,r208,r209,r212,r213,r214,r215,r216,r217,r218,r219,r222,r223,r224,r225,r226,r227,r228,r229,r232,r233,r234,r235,r236,r237,r238,r239,r242,r243,r244,r245,r246,r247,r248,r249,r252,r253,r254,r255,r256,r257,r258,r259,r262,r263,r264,r265,r266,r267,r268,r269 = cache

  b1Θ  = @evalpoly(Θ, 0, r011, r012, r013, r014, r015, r016, r017, r018, r019)
  b8Θ  = @evalpoly(Θ, 0,    0, r082, r083, r084, r085, r086, r087, r088, r089)
  b9Θ  = @evalpoly(Θ, 0,    0, r092, r093, r094, r095, r096, r097, r098, r099)
  b10Θ = @evalpoly(Θ, 0,    0, r102, r103, r104, r105, r106, r107, r108, r109)
  b11Θ = @evalpoly(Θ, 0,    0, r112, r113, r114, r115, r116, r117, r118, r119)
  b12Θ = @evalpoly(Θ, 0,    0, r122, r123, r124, r125, r126, r127, r128, r129)
  b13Θ = @evalpoly(Θ, 0,    0, r132, r133, r134, r135, r136, r137, r138, r139)
  b14Θ = @evalpoly(Θ, 0,    0, r142, r143, r144, r145, r146, r147, r148, r149)
  b15Θ = @evalpoly(Θ, 0,    0, r152, r153, r154, r155, r156, r157, r158, r159)
  b17Θ = @evalpoly(Θ, 0,    0, r172, r173, r174, r175, r176, r177, r178, r179)
  b18Θ = @evalpoly(Θ, 0,    0, r182, r183, r184, r185, r186, r187, r188, r189)
  b19Θ = @evalpoly(Θ, 0,    0, r192, r193, r194, r195, r196, r197, r198, r199)
  b20Θ = @evalpoly(Θ, 0,    0, r202, r203, r204, r205, r206, r207, r208, r209)
  b21Θ = @evalpoly(Θ, 0,    0, r212, r213, r214, r215, r216, r217, r218, r219)
  b22Θ = @evalpoly(Θ, 0,    0, r222, r223, r224, r225, r226, r227, r228, r229)
  b23Θ = @evalpoly(Θ, 0,    0, r232, r233, r234, r235, r236, r237, r238, r239)
  b24Θ = @evalpoly(Θ, 0,    0, r242, r243, r244, r245, r246, r247, r248, r249)
  b25Θ = @evalpoly(Θ, 0,    0, r252, r253, r254, r255, r256, r257, r258, r259)
  b26Θ = @evalpoly(Θ, 0,    0, r262, r263, r264, r265, r266, r267, r268, r269)

  #@. y₀ + dt*(k[1]*b1Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ + k[12]*b12Θ + k[13]*b13Θ + k[14]*b14Θ + k[15]*b15Θ + k[17]*b17Θ + k[18]*b18Θ + k[19]*b19Θ + k[20]*b20Θ + k[21]*b21Θ + k[22]*b22Θ + k[23]*b23Θ + k[24]*b24Θ + k[25]*b25Θ + k[26]*b26Θ)
  if idxs == nothing
    return y₀ + dt*(k[1]*b1Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ +
           k[12]*b12Θ + k[13]*b13Θ + k[14]*b14Θ + k[15]*b15Θ + k[17]*b17Θ +
           k[18]*b18Θ + k[19]*b19Θ + k[20]*b20Θ + k[21]*b21Θ + k[22]*b22Θ +
           k[23]*b23Θ + k[24]*b24Θ + k[25]*b25Θ + k[26]*b26Θ)
  else
    return y₀[idxs] + dt*(k[1][idxs]*b1Θ + k[8][idxs]*b8Θ + k[9][idxs]*b9Θ +
           k[10][idxs]*b10Θ + k[11][idxs]*b11Θ + k[12][idxs]*b12Θ +
           k[13][idxs]*b13Θ + k[14]*b14Θ + k[15][idxs]*b15Θ + k[17][idxs]*b17Θ +
           k[18][idxs]*b18Θ + k[19]*b19Θ + k[20]*b20Θ + k[21][idxs]*b21Θ +
           k[22][idxs]*b22Θ + k[23][idxs]*b23Θ + k[24]*b24Θ + k[25]*b25Θ +
           k[26][idxs]*b26Θ)
  end
end

@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::Vern9ConstantCache,idxs,T::Type{Val{1}})
  @unpack r011,r012,r013,r014,r015,r016,r017,r018,r019,r082,r083,r084,r085,r086,r087,r088,r089,r092,r093,r094,r095,r096,r097,r098,r099,r102,r103,r104,r105,r106,r107,r108,r109,r112,r113,r114,r115,r116,r117,r118,r119,r122,r123,r124,r125,r126,r127,r128,r129,r132,r133,r134,r135,r136,r137,r138,r139,r142,r143,r144,r145,r146,r147,r148,r149,r152,r153,r154,r155,r156,r157,r158,r159,r172,r173,r174,r175,r176,r177,r178,r179,r182,r183,r184,r185,r186,r187,r188,r189,r192,r193,r194,r195,r196,r197,r198,r199,r202,r203,r204,r205,r206,r207,r208,r209,r212,r213,r214,r215,r216,r217,r218,r219,r222,r223,r224,r225,r226,r227,r228,r229,r232,r233,r234,r235,r236,r237,r238,r239,r242,r243,r244,r245,r246,r247,r248,r249,r252,r253,r254,r255,r256,r257,r258,r259,r262,r263,r264,r265,r266,r267,r268,r269 = cache

  b1Θdiff  = @evalpoly(Θ, r011, 2*r012, 3*r013, 4*r014, 5*r015, 6*r016, 7*r017, 8*r018, 9*r019)
  b8Θdiff  = @evalpoly(Θ,    0, 2*r082, 3*r083, 4*r084, 5*r085, 6*r086, 7*r087, 8*r088, 9*r089)
  b9Θdiff  = @evalpoly(Θ,    0, 2*r092, 3*r093, 4*r094, 5*r095, 6*r096, 7*r097, 8*r098, 9*r099)
  b10Θdiff = @evalpoly(Θ,    0, 2*r102, 3*r103, 4*r104, 5*r105, 6*r106, 7*r107, 8*r108, 9*r109)
  b11Θdiff = @evalpoly(Θ,    0, 2*r112, 3*r113, 4*r114, 5*r115, 6*r116, 7*r117, 8*r118, 9*r119)
  b12Θdiff = @evalpoly(Θ,    0, 2*r122, 3*r123, 4*r124, 5*r125, 6*r126, 7*r127, 8*r128, 9*r129)
  b13Θdiff = @evalpoly(Θ,    0, 2*r132, 3*r133, 4*r134, 5*r135, 6*r136, 7*r137, 8*r138, 9*r139)
  b14Θdiff = @evalpoly(Θ,    0, 2*r142, 3*r143, 4*r144, 5*r145, 6*r146, 7*r147, 8*r148, 9*r149)
  b15Θdiff = @evalpoly(Θ,    0, 2*r152, 3*r153, 4*r154, 5*r155, 6*r156, 7*r157, 8*r158, 9*r159)
  b17Θdiff = @evalpoly(Θ,    0, 2*r172, 3*r173, 4*r174, 5*r175, 6*r176, 7*r177, 8*r178, 9*r179)
  b18Θdiff = @evalpoly(Θ,    0, 2*r182, 3*r183, 4*r184, 5*r185, 6*r186, 7*r187, 8*r188, 9*r189)
  b19Θdiff = @evalpoly(Θ,    0, 2*r192, 3*r193, 4*r194, 5*r195, 6*r196, 7*r197, 8*r198, 9*r199)
  b20Θdiff = @evalpoly(Θ,    0, 2*r202, 3*r203, 4*r204, 5*r205, 6*r206, 7*r207, 8*r208, 9*r209)
  b21Θdiff = @evalpoly(Θ,    0, 2*r212, 3*r213, 4*r214, 5*r215, 6*r216, 7*r217, 8*r218, 9*r219)
  b22Θdiff = @evalpoly(Θ,    0, 2*r222, 3*r223, 4*r224, 5*r225, 6*r226, 7*r227, 8*r228, 9*r229)
  b23Θdiff = @evalpoly(Θ,    0, 2*r232, 3*r233, 4*r234, 5*r235, 6*r236, 7*r237, 8*r238, 9*r239)
  b24Θdiff = @evalpoly(Θ,    0, 2*r242, 3*r243, 4*r244, 5*r245, 6*r246, 7*r247, 8*r248, 9*r249)
  b25Θdiff = @evalpoly(Θ,    0, 2*r252, 3*r253, 4*r254, 5*r255, 6*r256, 7*r257, 8*r258, 9*r259)
  b26Θdiff = @evalpoly(Θ,    0, 2*r262, 3*r263, 4*r264, 5*r265, 6*r266, 7*r267, 8*r268, 9*r269)

  #@. k[1]*b1Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff + k[10]*b10Θdiff + k[11]*b11Θdiff + k[12]*b12Θdiff + k[13]*b13Θdiff + k[14]*b14Θdiff + k[15]*b15Θdiff + k[17]*b17Θdiff + k[18]*b18Θdiff + k[19]*b19Θdiff + k[20]*b20Θdiff + k[21]*b21Θdiff + k[22]*b22Θdiff + k[23]*b23Θdiff + k[24]*b24Θdiff + k[25]*b25Θdiff + k[26]*b26Θdiff
  if idxs == nothing
      return k[1]*b1Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff + k[10]*b10Θdiff +
             k[11]*b11Θdiff + k[12]*b12Θdiff + k[13]*b13Θdiff + k[14]*b14Θdiff +
             k[15]*b15Θdiff + k[17]*b17Θdiff + k[18]*b18Θdiff + k[19]*b19Θdiff +
             k[20]*b20Θdiff + k[21]*b21Θdiff + k[22]*b22Θdiff + k[23]*b23Θdiff +
             k[24]*b24Θdiff + k[25]*b25Θdiff + k[26]*b26Θdiff
  else
      return k[1][idxs]*b1Θdiff + k[8][idxs]*b8Θdiff + k[9][idxs]*b9Θdiff +
             k[10][idxs]*b10Θdiff + k[11][idxs]*b11Θdiff +
             k[12][idxs]*b12Θdiff + k[13][idxs]*b13Θdiff +
             k[14][idxs]*b14Θdiff + k[15][idxs]*b15Θdiff +
             k[17][idxs]*b17Θdiff + k[18][idxs]*b18Θdiff +
             k[19][idxs]*b19Θdiff + k[20][idxs]*b20Θdiff +
             k[21][idxs]*b21Θdiff + k[22][idxs]*b22Θdiff +
             k[23][idxs]*b23Θdiff + k[24][idxs]*b24Θdiff +
             k[25][idxs]*b25Θdiff + k[26][idxs]*b26Θdiff
  end

end

"""

"""
@muladd function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::Vern9Cache,idxs,T::Type{Val{0}})
  @unpack r011,r012,r013,r014,r015,r016,r017,r018,r019,r082,r083,r084,r085,r086,r087,r088,r089,r092,r093,r094,r095,r096,r097,r098,r099,r102,r103,r104,r105,r106,r107,r108,r109,r112,r113,r114,r115,r116,r117,r118,r119,r122,r123,r124,r125,r126,r127,r128,r129,r132,r133,r134,r135,r136,r137,r138,r139,r142,r143,r144,r145,r146,r147,r148,r149,r152,r153,r154,r155,r156,r157,r158,r159,r172,r173,r174,r175,r176,r177,r178,r179,r182,r183,r184,r185,r186,r187,r188,r189,r192,r193,r194,r195,r196,r197,r198,r199,r202,r203,r204,r205,r206,r207,r208,r209,r212,r213,r214,r215,r216,r217,r218,r219,r222,r223,r224,r225,r226,r227,r228,r229,r232,r233,r234,r235,r236,r237,r238,r239,r242,r243,r244,r245,r246,r247,r248,r249,r252,r253,r254,r255,r256,r257,r258,r259,r262,r263,r264,r265,r266,r267,r268,r269 = cache.tab

  b1Θ  = @evalpoly(Θ, 0, r011, r012, r013, r014, r015, r016, r017, r018, r019)
  b8Θ  = @evalpoly(Θ, 0,    0, r082, r083, r084, r085, r086, r087, r088, r089)
  b9Θ  = @evalpoly(Θ, 0,    0, r092, r093, r094, r095, r096, r097, r098, r099)
  b10Θ = @evalpoly(Θ, 0,    0, r102, r103, r104, r105, r106, r107, r108, r109)
  b11Θ = @evalpoly(Θ, 0,    0, r112, r113, r114, r115, r116, r117, r118, r119)
  b12Θ = @evalpoly(Θ, 0,    0, r122, r123, r124, r125, r126, r127, r128, r129)
  b13Θ = @evalpoly(Θ, 0,    0, r132, r133, r134, r135, r136, r137, r138, r139)
  b14Θ = @evalpoly(Θ, 0,    0, r142, r143, r144, r145, r146, r147, r148, r149)
  b15Θ = @evalpoly(Θ, 0,    0, r152, r153, r154, r155, r156, r157, r158, r159)
  b17Θ = @evalpoly(Θ, 0,    0, r172, r173, r174, r175, r176, r177, r178, r179)
  b18Θ = @evalpoly(Θ, 0,    0, r182, r183, r184, r185, r186, r187, r188, r189)
  b19Θ = @evalpoly(Θ, 0,    0, r192, r193, r194, r195, r196, r197, r198, r199)
  b20Θ = @evalpoly(Θ, 0,    0, r202, r203, r204, r205, r206, r207, r208, r209)
  b21Θ = @evalpoly(Θ, 0,    0, r212, r213, r214, r215, r216, r217, r218, r219)
  b22Θ = @evalpoly(Θ, 0,    0, r222, r223, r224, r225, r226, r227, r228, r229)
  b23Θ = @evalpoly(Θ, 0,    0, r232, r233, r234, r235, r236, r237, r238, r239)
  b24Θ = @evalpoly(Θ, 0,    0, r242, r243, r244, r245, r246, r247, r248, r249)
  b25Θ = @evalpoly(Θ, 0,    0, r252, r253, r254, r255, r256, r257, r258, r259)
  b26Θ = @evalpoly(Θ, 0,    0, r262, r263, r264, r265, r266, r267, r268, r269)

  if out == nothing
    if idxs == nothing
      # return @. y₀ + dt*(k[1]*b1Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ + k[12]*b12Θ + k[13]*b13Θ + k[14]*b14Θ + k[15]*b15Θ + k[17]*b17Θ + k[18]*b18Θ + k[19]*b19Θ + k[20]*b20Θ + k[21]*b21Θ + k[22]*b22Θ + k[23]*b23Θ + k[24]*b24Θ + k[25]*b25Θ + k[26]*b26Θ)
      return y₀ + dt*(k[1]*b1Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ + k[12]*b12Θ + k[13]*b13Θ + k[14]*b14Θ + k[15]*b15Θ + k[17]*b17Θ + k[18]*b18Θ + k[19]*b19Θ + k[20]*b20Θ + k[21]*b21Θ + k[22]*b22Θ + k[23]*b23Θ + k[24]*b24Θ + k[25]*b25Θ + k[26]*b26Θ)
    else
      # return @. y₀[idxs] + dt*(k[1][idxs]*b1Θ + k[8][idxs]*b8Θ + k[9][idxs]*b9Θ + k[10][idxs]*b10Θ + k[11][idxs]*b11Θ + k[12][idxs]*b12Θ + k[13][idxs]*b13Θ + k[14][idxs]*b14Θ + k[15][idxs]*b15Θ + k[17][idxs]*b17Θ + k[18][idxs]*b18Θ + k[19][idxs]*b19Θ + k[20][idxs]*b20Θ + k[21][idxs]*b21Θ + k[22][idxs]*b22Θ + k[23][idxs]*b23Θ + k[24][idxs]*b24Θ + k[25][idxs]*b25Θ + k[26][idxs]*b26Θ)
      return y₀[idxs] + dt*(k[1][idxs]*b1Θ + k[8][idxs]*b8Θ + k[9][idxs]*b9Θ + k[10][idxs]*b10Θ + k[11][idxs]*b11Θ + k[12][idxs]*b12Θ + k[13][idxs]*b13Θ + k[14][idxs]*b14Θ + k[15][idxs]*b15Θ + k[17][idxs]*b17Θ + k[18][idxs]*b18Θ + k[19][idxs]*b19Θ + k[20][idxs]*b20Θ + k[21][idxs]*b21Θ + k[22][idxs]*b22Θ + k[23][idxs]*b23Θ + k[24][idxs]*b24Θ + k[25][idxs]*b25Θ + k[26][idxs]*b26Θ)
    end
  elseif idxs == nothing
    #@. out = y₀ + dt*(k[1]*b1Θ + k[8]*b8Θ + k[9]*b9Θ + k[10]*b10Θ + k[11]*b11Θ + k[12]*b12Θ + k[13]*b13Θ + k[14]*b14Θ + k[15]*b15Θ + k[17]*b17Θ + k[18]*b18Θ + k[19]*b19Θ + k[20]*b20Θ + k[21]*b21Θ + k[22]*b22Θ + k[23]*b23Θ + k[24]*b24Θ + k[25]*b25Θ + k[26]*b26Θ)
    @inbounds for i in eachindex(out)
      out[i] = y₀[i] + dt*(k[1][i]*b1Θ + k[8][i]*b8Θ + k[9][i]*b9Θ + k[10][i]*b10Θ + k[11][i]*b11Θ + k[12][i]*b12Θ + k[13][i]*b13Θ + k[14][i]*b14Θ + k[15][i]*b15Θ + k[17][i]*b17Θ + k[18][i]*b18Θ + k[19][i]*b19Θ + k[20][i]*b20Θ + k[21][i]*b21Θ + k[22][i]*b22Θ + k[23][i]*b23Θ + k[24][i]*b24Θ + k[25][i]*b25Θ + k[26][i]*b26Θ)
    end
  else
    #@views @. out = y₀[idxs] + dt*(k[1][idxs]*b1Θ + k[8][idxs]*b8Θ + k[9][idxs]*b9Θ + k[10][idxs]*b10Θ + k[11][idxs]*b11Θ + k[12][idxs]*b12Θ + k[13][idxs]*b13Θ + k[14][idxs]*b14Θ + k[15][idxs]*b15Θ + k[17][idxs]*b17Θ + k[18][idxs]*b18Θ + k[19][idxs]*b19Θ + k[20][idxs]*b20Θ + k[21][idxs]*b21Θ + k[22][idxs]*b22Θ + k[23][idxs]*b23Θ + k[24][idxs]*b24Θ + k[25][idxs]*b25Θ + k[26][idxs]*b26Θ)
    @inbounds for (j,i) in enumerate(idxs)
      out[j] = y₀[i] + dt*(k[1][i]*b1Θ + k[8][i]*b8Θ + k[9][i]*b9Θ + k[10][i]*b10Θ + k[11][i]*b11Θ + k[12][i]*b12Θ + k[13][i]*b13Θ + k[14][i]*b14Θ + k[15][i]*b15Θ + k[17][i]*b17Θ + k[18][i]*b18Θ + k[19][i]*b19Θ + k[20][i]*b20Θ + k[21][i]*b21Θ + k[22][i]*b22Θ + k[23][i]*b23Θ + k[24][i]*b24Θ + k[25][i]*b25Θ + k[26][i]*b26Θ)
    end
  end
end

@muladd function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::Vern9Cache,idxs,T::Type{Val{1}})
  @unpack r011,r012,r013,r014,r015,r016,r017,r018,r019,r082,r083,r084,r085,r086,r087,r088,r089,r092,r093,r094,r095,r096,r097,r098,r099,r102,r103,r104,r105,r106,r107,r108,r109,r112,r113,r114,r115,r116,r117,r118,r119,r122,r123,r124,r125,r126,r127,r128,r129,r132,r133,r134,r135,r136,r137,r138,r139,r142,r143,r144,r145,r146,r147,r148,r149,r152,r153,r154,r155,r156,r157,r158,r159,r172,r173,r174,r175,r176,r177,r178,r179,r182,r183,r184,r185,r186,r187,r188,r189,r192,r193,r194,r195,r196,r197,r198,r199,r202,r203,r204,r205,r206,r207,r208,r209,r212,r213,r214,r215,r216,r217,r218,r219,r222,r223,r224,r225,r226,r227,r228,r229,r232,r233,r234,r235,r236,r237,r238,r239,r242,r243,r244,r245,r246,r247,r248,r249,r252,r253,r254,r255,r256,r257,r258,r259,r262,r263,r264,r265,r266,r267,r268,r269 = cache.tab

  b1Θdiff  = @evalpoly(Θ, r011, 2*r012, 3*r013, 4*r014, 5*r015, 6*r016, 7*r017, 8*r018, 9*r019)
  b8Θdiff  = @evalpoly(Θ,    0, 2*r082, 3*r083, 4*r084, 5*r085, 6*r086, 7*r087, 8*r088, 9*r089)
  b9Θdiff  = @evalpoly(Θ,    0, 2*r092, 3*r093, 4*r094, 5*r095, 6*r096, 7*r097, 8*r098, 9*r099)
  b10Θdiff = @evalpoly(Θ,    0, 2*r102, 3*r103, 4*r104, 5*r105, 6*r106, 7*r107, 8*r108, 9*r109)
  b11Θdiff = @evalpoly(Θ,    0, 2*r112, 3*r113, 4*r114, 5*r115, 6*r116, 7*r117, 8*r118, 9*r119)
  b12Θdiff = @evalpoly(Θ,    0, 2*r122, 3*r123, 4*r124, 5*r125, 6*r126, 7*r127, 8*r128, 9*r129)
  b13Θdiff = @evalpoly(Θ,    0, 2*r132, 3*r133, 4*r134, 5*r135, 6*r136, 7*r137, 8*r138, 9*r139)
  b14Θdiff = @evalpoly(Θ,    0, 2*r142, 3*r143, 4*r144, 5*r145, 6*r146, 7*r147, 8*r148, 9*r149)
  b15Θdiff = @evalpoly(Θ,    0, 2*r152, 3*r153, 4*r154, 5*r155, 6*r156, 7*r157, 8*r158, 9*r159)
  b17Θdiff = @evalpoly(Θ,    0, 2*r172, 3*r173, 4*r174, 5*r175, 6*r176, 7*r177, 8*r178, 9*r179)
  b18Θdiff = @evalpoly(Θ,    0, 2*r182, 3*r183, 4*r184, 5*r185, 6*r186, 7*r187, 8*r188, 9*r189)
  b19Θdiff = @evalpoly(Θ,    0, 2*r192, 3*r193, 4*r194, 5*r195, 6*r196, 7*r197, 8*r198, 9*r199)
  b20Θdiff = @evalpoly(Θ,    0, 2*r202, 3*r203, 4*r204, 5*r205, 6*r206, 7*r207, 8*r208, 9*r209)
  b21Θdiff = @evalpoly(Θ,    0, 2*r212, 3*r213, 4*r214, 5*r215, 6*r216, 7*r217, 8*r218, 9*r219)
  b22Θdiff = @evalpoly(Θ,    0, 2*r222, 3*r223, 4*r224, 5*r225, 6*r226, 7*r227, 8*r228, 9*r229)
  b23Θdiff = @evalpoly(Θ,    0, 2*r232, 3*r233, 4*r234, 5*r235, 6*r236, 7*r237, 8*r238, 9*r239)
  b24Θdiff = @evalpoly(Θ,    0, 2*r242, 3*r243, 4*r244, 5*r245, 6*r246, 7*r247, 8*r248, 9*r249)
  b25Θdiff = @evalpoly(Θ,    0, 2*r252, 3*r253, 4*r254, 5*r255, 6*r256, 7*r257, 8*r258, 9*r259)
  b26Θdiff = @evalpoly(Θ,    0, 2*r262, 3*r263, 4*r264, 5*r265, 6*r266, 7*r267, 8*r268, 9*r269)

  if out == nothing
    if idxs == nothing
      # return @. k[1]*b1Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff + k[10]*b10Θdiff + k[11]*b11Θdiff + k[12]*b12Θdiff + k[13]*b13Θdiff + k[14]*b14Θdiff + k[15]*b15Θdiff + k[17]*b17Θdiff + k[18]*b18Θdiff + k[19]*b19Θdiff + k[20]*b20Θdiff + k[21]*b21Θdiff + k[22]*b22Θdiff + k[23]*b23Θdiff + k[24]*b24Θdiff + k[25]*b25Θdiff + k[26]*b26Θdiff
      return k[1]*b1Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff + k[10]*b10Θdiff + k[11]*b11Θdiff + k[12]*b12Θdiff + k[13]*b13Θdiff + k[14]*b14Θdiff + k[15]*b15Θdiff + k[17]*b17Θdiff + k[18]*b18Θdiff + k[19]*b19Θdiff + k[20]*b20Θdiff + k[21]*b21Θdiff + k[22]*b22Θdiff + k[23]*b23Θdiff + k[24]*b24Θdiff + k[25]*b25Θdiff + k[26]*b26Θdiff
    else
      # return @. k[1][idxs]*b1Θdiff + k[8][idxs]*b8Θdiff + k[9][idxs]*b9Θdiff + k[10][idxs]*b10Θdiff + k[11][idxs]*b11Θdiff + k[12][idxs]*b12Θdiff + k[13][idxs]*b13Θdiff + k[14][idxs]*b14Θdiff + k[15][idxs]*b15Θdiff + k[17][idxs]*b17Θdiff + k[18][idxs]*b18Θdiff + k[19][idxs]*b19Θdiff + k[20][idxs]*b20Θdiff + k[21][idxs]*b21Θdiff + k[22][idxs]*b22Θdiff + k[23][idxs]*b23Θdiff + k[24][idxs]*b24Θdiff + k[25][idxs]*b25Θdiff + k[26][idxs]*b26Θdiff
      return k[1][idxs]*b1Θdiff + k[8][idxs]*b8Θdiff + k[9][idxs]*b9Θdiff + k[10][idxs]*b10Θdiff + k[11][idxs]*b11Θdiff + k[12][idxs]*b12Θdiff + k[13][idxs]*b13Θdiff + k[14][idxs]*b14Θdiff + k[15][idxs]*b15Θdiff + k[17][idxs]*b17Θdiff + k[18][idxs]*b18Θdiff + k[19][idxs]*b19Θdiff + k[20][idxs]*b20Θdiff + k[21][idxs]*b21Θdiff + k[22][idxs]*b22Θdiff + k[23][idxs]*b23Θdiff + k[24][idxs]*b24Θdiff + k[25][idxs]*b25Θdiff + k[26][idxs]*b26Θdiff
    end
  elseif idxs == nothing
    #@. out = k[1]*b1Θdiff + k[8]*b8Θdiff + k[9]*b9Θdiff + k[10]*b10Θdiff + k[11]*b11Θdiff + k[12]*b12Θdiff + k[13]*b13Θdiff + k[14]*b14Θdiff + k[15]*b15Θdiff + k[17]*b17Θdiff + k[18]*b18Θdiff + k[19]*b19Θdiff + k[20]*b20Θdiff + k[21]*b21Θdiff + k[22]*b22Θdiff + k[23]*b23Θdiff + k[24]*b24Θdiff + k[25]*b25Θdiff + k[26]*b26Θdiff
    @inbounds for i in eachindex(out)
      out[i] = k[1][i]*b1Θdiff + k[8][i]*b8Θdiff + k[9][i]*b9Θdiff + k[10][i]*b10Θdiff + k[11][i]*b11Θdiff + k[12][i]*b12Θdiff + k[13][i]*b13Θdiff + k[14][i]*b14Θdiff + k[15][i]*b15Θdiff + k[17][i]*b17Θdiff + k[18][i]*b18Θdiff + k[19][i]*b19Θdiff + k[20][i]*b20Θdiff + k[21][i]*b21Θdiff + k[22][i]*b22Θdiff + k[23][i]*b23Θdiff + k[24][i]*b24Θdiff + k[25][i]*b25Θdiff + k[26][i]*b26Θdiff
    end
  else
    #@views @. out = k[1][idxs]*b1Θdiff + k[8][idxs]*b8Θdiff + k[9][idxs]*b9Θdiff + k[10][idxs]*b10Θdiff + k[11][idxs]*b11Θdiff + k[12][idxs]*b12Θdiff + k[13][idxs]*b13Θdiff + k[14][idxs]*b14Θdiff + k[15][idxs]*b15Θdiff + k[17][idxs]*b17Θdiff + k[18][idxs]*b18Θdiff + k[19][idxs]*b19Θdiff + k[20][idxs]*b20Θdiff + k[21][idxs]*b21Θdiff + k[22][idxs]*b22Θdiff + k[23][idxs]*b23Θdiff + k[24][idxs]*b24Θdiff + k[25][idxs]*b25Θdiff + k[26][idxs]*b26Θdiff
    @inbounds for (j,i) in enumerate(idxs)
      out[j] = k[1][i]*b1Θdiff + k[8][i]*b8Θdiff + k[9][i]*b9Θdiff + k[10][i]*b10Θdiff + k[11][i]*b11Θdiff + k[12][i]*b12Θdiff + k[13][i]*b13Θdiff + k[14][i]*b14Θdiff + k[15][i]*b15Θdiff + k[17][i]*b17Θdiff + k[18][i]*b18Θdiff + k[19][i]*b19Θdiff + k[20][i]*b20Θdiff + k[21][i]*b21Θdiff + k[22][i]*b22Θdiff + k[23][i]*b23Θdiff + k[24][i]*b24Θdiff + k[25][i]*b25Θdiff + k[26][i]*b26Θdiff
    end
  end
end

"""

"""
@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::DP8ConstantCache,idxs::Void,T::Type{Val{0}})
  Θ1 = 1-Θ
  conpar = k[4] + Θ*(k[5] + Θ1*(k[6]+Θ*k[7]))
  #@. y₀ + dt*Θ*(k[1] + Θ1*(k[2] + Θ*(k[3]+Θ1*conpar)))
  y₀ + dt*Θ*(k[1] + Θ1*(k[2] + Θ*(k[3]+Θ1*conpar)))
end

@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::DP8ConstantCache,idxs,T::Type{Val{0}})
  Θ1 = 1-Θ
  conpar = k[4] + Θ*(k[5] + Θ1*(k[6]+Θ*k[7]))
  #@. y₀ + dt*Θ*(k[1] + Θ1*(k[2] + Θ*(k[3]+Θ1*conpar)))
  y₀[idxs] + dt*Θ*(k[1][idxs] + Θ1*(k[2][idxs] + Θ*(k[3][idxs]+Θ1*conpar)))
end

@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::DP8ConstantCache,idxs::Void,T::Type{Val{1}})
  b1diff = k[1] + k[2]
  b2diff = -2*k[2] + 2*k[3] + 2*k[4]
  b3diff = -3*k[3] - 6*k[4] + 3*k[5] + 3*k[6]
  b4diff = 4*k[4] - 8*k[5] - 12*k[6] + 4*k[7]
  b5diff = 5*k[5] + 15*k[6] - 15*k[7]
  b6diff = -6*k[6] + 18*k[7] #- 7*k[7]
  #@. b1diff + Θ*(b2diff + Θ*(b3diff + Θ*(b4diff + Θ*(b5diff + Θ*(b6diff - 7*k[7]*Θ)))))
  b1diff + Θ*(b2diff + Θ*(b3diff + Θ*(b4diff + Θ*(b5diff + Θ*(b6diff - 7*k[7]*Θ)))))
end

@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::DP8ConstantCache,idxs,T::Type{Val{1}})
  b1diff = k[1][idxs] + k[2][idxs]
  b2diff = -2*k[2][idxs] + 2*k[3][idxs] + 2*k[4][idxs]
  b3diff = -3*k[3][idxs] - 6*k[4][idxs] + 3*k[5][idxs] + 3*k[6][idxs]
  b4diff = 4*k[4][idxs] - 8*k[5][idxs] - 12*k[6][idxs] + 4*k[7][idxs]
  b5diff = 5*k[5][idxs] + 15*k[6][idxs] - 15*k[7][idxs]
  b6diff = -6*k[6][idxs] + 18*k[7][idxs] #- 7*k[7]
  #@. b1diff + Θ*(b2diff + Θ*(b3diff + Θ*(b4diff + Θ*(b5diff + Θ*(b6diff - 7*k[7]*Θ)))))
  b1diff + Θ*(b2diff + Θ*(b3diff + Θ*(b4diff + Θ*(b5diff + Θ*(b6diff - 7*k[7]*Θ)))))
end

"""

"""
@muladd function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::DP8Cache,idxs,T::Type{Val{0}})
  Θ1 = 1-Θ
  if out == nothing
    if idxs == nothing
      # return @. y₀ + dt*Θ*(k[1] + Θ1*(k[2] + Θ*(k[3]+Θ1*(k[4] + Θ*(k[5] + Θ1*(k[6]+Θ*k[7]))))))
      return y₀ + dt*Θ*(k[1] + Θ1*(k[2] + Θ*(k[3]+Θ1*(k[4] + Θ*(k[5] + Θ1*(k[6]+Θ*k[7]))))))
    else
      # return @. y₀[idxs] + dt*Θ*(k[1][idxs] + Θ1*(k[2][idxs] + Θ*(k[3][idxs]+Θ1*(k[4][idxs] + Θ*(k[5][idxs] + Θ1*(k[6][idxs]+Θ*k[7][idxs]))))))
      return y₀[idxs] + dt*Θ*(k[1][idxs] + Θ1*(k[2][idxs] + Θ*(k[3][idxs]+Θ1*(k[4][idxs] + Θ*(k[5][idxs] + Θ1*(k[6][idxs]+Θ*k[7][idxs]))))))
    end
  elseif idxs == nothing
    #@. out = y₀ + dt*Θ*(k[1] + Θ1*(k[2] + Θ*(k[3]+Θ1*(k[4] + Θ*(k[5] + Θ1*(k[6]+Θ*k[7]))))))
    @inbounds for i in eachindex(out)
      out[i] = y₀[i] + dt*Θ*(k[1][i] + Θ1*(k[2][i] + Θ*(k[3][i]+Θ1*(k[4][i] + Θ*(k[5][i] + Θ1*(k[6][i]+Θ*k[7][i]))))))
    end
  else
    #@views @. out = y₀[idxs] + dt*Θ*(k[1][idxs] + Θ1*(k[2][idxs] + Θ*(k[3][idxs]+Θ1*(k[4][idxs] + Θ*(k[5][idxs] + Θ1*(k[6][idxs]+Θ*k[7][idxs]))))))
    @inbounds for (j,i) in enumerate(idxs)
      out[j] = y₀[i] + dt*Θ*(k[1][i] + Θ1*(k[2][i] + Θ*(k[3][i]+Θ1*(k[4][i] + Θ*(k[5][i] + Θ1*(k[6][i]+Θ*k[7][i]))))))
    end
  end
end

@muladd function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::DP8Cache,idxs,T::Type{Val{1}})
  if out == nothing
    if idxs == nothing
      b1diff = @. k[1] + k[2]
      b2diff = @. -2*k[2] + 2*k[3] + 2*k[4]
      b3diff = @. -3*k[3] - 6*k[4] + 3*k[5] + 3*k[6]
      b4diff = @. 4*k[4] - 8*k[5] - 12*k[6] + 4*k[7]
      b5diff = @. 5*k[5] + 15*k[6] - 15*k[7]
      b6diff = @. -6*k[6] + 18*k[7]
      b7diff = @. -7*k[7]
    else
      b1diff = @. k[1][idxs] + k[2][idxs]
      b2diff = @. -2*k[2][idxs] + 2*k[3][idxs] + 2*k[4][idxs]
      b3diff = @. -3*k[3][idxs] - 6*k[4][idxs] + 3*k[5][idxs] + 3*k[6][idxs]
      b4diff = @. 4*k[4][idxs] - 8*k[5][idxs] - 12*k[6][idxs] + 4*k[7][idxs]
      b5diff = @. 5*k[5][idxs] + 15*k[6][idxs] - 15*k[7][idxs]
      b6diff = @. -6*k[6][idxs] + 18*k[7][idxs]
      b7diff = @. -7*k[7][idxs]
    end
    # return @. b1diff + Θ*(b2diff + Θ*(b3diff + Θ*(b4diff + Θ*(b5diff + Θ*(b6diff + Θ*b7diff)))))
    return b1diff + Θ*(b2diff + Θ*(b3diff + Θ*(b4diff + Θ*(b5diff + Θ*(b6diff + Θ*b7diff)))))
  elseif idxs == nothing
    for i in eachindex(out)
      b1diff = k[1][i] + k[2][i]
      b2diff = -2*k[2][i] + 2*k[3][i] + 2*k[4][i]
      b3diff = -3*k[3][i] - 6*k[4][i] + 3*k[5][i] + 3*k[6][i]
      b4diff = 4*k[4][i] - 8*k[5][i] - 12*k[6][i] + 4*k[7][i]
      b5diff = 5*k[5][i] + 15*k[6][i] - 15*k[7][i]
      b6diff = -6*k[6][i] + 18*k[7][i]
      out[i] = b1diff + Θ*(b2diff + Θ*(b3diff + Θ*(b4diff +
               Θ*(b5diff + Θ*(b6diff - 7*k[7][i]*Θ)))))
    end
  else
    @inbounds for (j,i) in enumerate(idxs)
      b1diff = k[1][i] + k[2][i]
      b2diff = -2*k[2][i] + 2*k[3][i] + 2*k[4][i]
      b3diff = -3*k[3][i] - 6*k[4][i] + 3*k[5][i] + 3*k[6][i]
      b4diff = 4*k[4][i] - 8*k[5][i] - 12*k[6][i] + 4*k[7][i]
      b5diff = 5*k[5][i] + 15*k[6][i] - 15*k[7][i]
      b6diff = -6*k[6][i] + 18*k[7][i]
      out[j] = b1diff + Θ*(b2diff + Θ*(b3diff + Θ*(b4diff +
               Θ*(b5diff + Θ*(b6diff - 7*k[7][i]*Θ)))))
    end
  end
end

@muladd function ode_interpolant(Θ,dt,y₀,y₁,k,cache::DPRKN6ConstantCache,idxs,T::Type{Val{0}})
  kk1,kk2,kk3 = k
  k1, k2 = kk1.x
  k3, k4 = kk2.x
  k5, k6 = kk3.x
  @unpack r14,r13,r12,r11,r10,r34,r33,r32,r31,r44,r43,r42,r41,r54,r53,r52,r51,r64,r63,r62,r61,rp14,rp13,rp12,rp11,rp10,rp34,rp33,rp32,rp31,rp44,rp43,rp42,rp41,rp54,rp53,rp52,rp51,rp64,rp63,rp62,rp61 = cache

  duprev,uprev = y₀.x
  dtsq = dt^2

  b1Θ  = @evalpoly(Θ, r10, r11, r12, r13, r14)
  b3Θ  = @evalpoly(Θ, 0  , r31, r32, r33, r34)
  b4Θ  = @evalpoly(Θ, 0  , r41, r42, r43, r44)
  b5Θ  = @evalpoly(Θ, 0  , r51, r52, r53, r54)
  b6Θ  = @evalpoly(Θ, 0  , r61, r62, r63, r64)

  bp1Θ  = @evalpoly(Θ, rp10, rp11, rp12, rp13, rp14)
  bp3Θ  = @evalpoly(Θ, 0   , rp31, rp32, rp33, rp34)
  bp4Θ  = @evalpoly(Θ, 0   , rp41, rp42, rp43, rp44)
  bp5Θ  = @evalpoly(Θ, 0   , rp51, rp52, rp53, rp54)
  bp6Θ  = @evalpoly(Θ, 0   , rp61, rp62, rp63, rp64)

  if idxs == nothing
    return ArrayPartition(duprev + dt*Θ*(bp1Θ*k1 + bp3Θ*k3 +
                    bp4Θ*k4 + bp5Θ*k5 + bp6Θ*k6),
                    uprev + dt*Θ*(duprev + dt*Θ*(b1Θ*k1 + b3Θ*k3 +
                                        b4Θ*k4 + b5Θ*k5 + b6Θ*k6)))
  else
    return ArrayPartition(
        duprev[idxs] + dt*Θ*(bp1Θ*k1[idxs] + bp3Θ*k3[idxs] +
        bp4Θ*k4[idxs] + bp5Θ*k5[idxs] + bp6Θ*k6[idxs]),
        uprev[idxs] + dt*Θ*(duprev[idxs] + dt*Θ*(b1Θ*k1[idxs] +
                b3Θ*k3[idxs] +
                b4Θ*k4[idxs] + b5Θ*k5[idxs] + b6Θ*k6[idxs])))
  end

end

@muladd function ode_interpolant!(out,Θ,dt,y₀,y₁,k,cache::DPRKN6Cache,idxs,T::Type{Val{0}})
  kk1,kk2,kk3 = k
  k1, k2 = kk1.x
  k3, k4 = kk2.x
  k5, k6 = kk3.x
  @unpack r14,r13,r12,r11,r10,r34,r33,r32,r31,r44,r43,r42,r41,r54,r53,r52,r51,r64,r63,r62,r61,rp14,rp13,rp12,rp11,rp10,rp34,rp33,rp32,rp31,rp44,rp43,rp42,rp41,rp54,rp53,rp52,rp51,rp64,rp63,rp62,rp61 = cache.tab

  duprev,uprev = y₀.x
  dtsq = dt^2

  b1Θ  = @evalpoly(Θ, r10, r11, r12, r13, r14)
  b3Θ  = @evalpoly(Θ, 0  , r31, r32, r33, r34)
  b4Θ  = @evalpoly(Θ, 0  , r41, r42, r43, r44)
  b5Θ  = @evalpoly(Θ, 0  , r51, r52, r53, r54)
  b6Θ  = @evalpoly(Θ, 0  , r61, r62, r63, r64)

  bp1Θ  = @evalpoly(Θ, rp10, rp11, rp12, rp13, rp14)
  bp3Θ  = @evalpoly(Θ, 0   , rp31, rp32, rp33, rp34)
  bp4Θ  = @evalpoly(Θ, 0   , rp41, rp42, rp43, rp44)
  bp5Θ  = @evalpoly(Θ, 0   , rp51, rp52, rp53, rp54)
  bp6Θ  = @evalpoly(Θ, 0   , rp61, rp62, rp63, rp64)

  @inbounds if out == nothing
    if idxs == nothing
      return duprev + dt*Θ*(bp1Θ*k1 + bp3Θ*k3 +
                      bp4Θ*k4 + bp5Θ*k5 + bp6Θ*k6),
             uprev + dt*Θ*(duprev + dt*Θ*(b1Θ*k1 + b3Θ*k3 +
                                          b4Θ*k4 + b5Θ*k5 + b6Θ*k6))

    else
      # return @. duprev[idxs] + dt*Θ*(bp1Θ*k1.x[2][idxs] + bp3Θ*k3.x[2][idxs] +
      #           bp4Θ*k4.x[2][idxs] + bp5Θ*k5.x[2][idxs] + bp6Θ*k6.x[2][idxs]),
      #        @. uprev[idxs] + dt*Θ*(duprev[idxs] + dt*Θ*(b1Θ*k1.x[2][idxs] +
      #           b3Θ*k3.x[2][idxs] +
      #           b4Θ*k4.x[2][idxs] + b5Θ*k5.x[2][idxs] + b6Θ*k6.x[2][idxs]))

      return duprev[idxs] + dt*Θ*(bp1Θ*k1[idxs] + bp3Θ*k3[idxs] +
             bp4Θ*k4[idxs] + bp5Θ*k5[idxs] + bp6Θ*k6[idxs]),
             uprev[idxs] + dt*Θ*(duprev[idxs] + dt*Θ*(b1Θ*k1[idxs] +
                  b3Θ*k3[idxs] + b4Θ*k4[idxs] + b5Θ*k5[idxs] + b6Θ*k6[idxs]))

    end
  elseif idxs == nothing
      for i in eachindex(out.x[1])
      out.x[2][i]  = uprev[i] + dt*Θ*(duprev[i] + dt*Θ*(b1Θ*k1[i] +
                           b3Θ*k3[i] +
                           b4Θ*k4[i] + b5Θ*k5[i] + b6Θ*k6[i]))
      out.x[1][i] =  duprev[i] + dt*Θ*(bp1Θ*k1[i] + bp3Θ*k3[i] +
                        bp4Θ*k4[i] + bp5Θ*k5[i] + bp6Θ*k6[i])
    end
  else
    for (j,i) in enumerate(idxs)
      out.x[2][j]  = uprev[i] + dt*Θ*(duprev[i] + dt*Θ*(b1Θ*k1[i] +
                           b3Θ*k3[i] +
                           b4Θ*k4[i] + b5Θ*k5[i] + b6Θ*k6[i]))
      out.x[1][j] = duprev[i] + dt*Θ*(bp1Θ*k1[i] + bp3Θ*k3[i] +
                        bp4Θ*k4[i] + bp5Θ*k5[i] + bp6Θ*k6[i])
    end
  end
end
