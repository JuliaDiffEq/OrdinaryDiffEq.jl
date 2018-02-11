function initialize!(integrator, cache::Vern6ConstantCache)
  integrator.fsalfirst = integrator.f(integrator.uprev, integrator.p, integrator.t) # Pre-start fsal
  integrator.kshortsize = 9
  integrator.k = typeof(integrator.k)(integrator.kshortsize)

  # Avoid undefined entries if k is an array of arrays
  integrator.fsallast = zero(integrator.fsalfirst)
  integrator.k[1] = integrator.fsalfirst
  @inbounds for i in 2:integrator.kshortsize-1
    integrator.k[i] = zero(integrator.fsalfirst)
  end
  integrator.k[integrator.kshortsize] = integrator.fsallast
end

@muladd function perform_step!(integrator, cache::Vern6ConstantCache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack c1,c2,c3,c4,c5,c6,a21,a31,a32,a41,a43,a51,a53,a54,a61,a63,a64,a65,a71,a73,a74,a75,a76,a81,a83,a84,a85,a86,a87,a91,a94,a95,a96,a97,a98,btilde1,btilde4,btilde5,btilde6,btilde7,btilde8,btilde9 = cache
  k1 = integrator.fsalfirst
  a = dt*a21
  k2 = f(uprev+a*k1, p, t + c1*dt)
  k3 = f(uprev+dt*(a31*k1+a32*k2), p, t + c2*dt)
  k4 = f(uprev+dt*(a41*k1       +a43*k3), p, t + c3*dt)
  k5 = f(uprev+dt*(a51*k1       +a53*k3+a54*k4), p, t + c4*dt)
  k6 = f(uprev+dt*(a61*k1       +a63*k3+a64*k4+a65*k5), p, t + c5*dt)
  k7 = f(uprev+dt*(a71*k1       +a73*k3+a74*k4+a75*k5+a76*k6), p, t + c6*dt)
  k8 = f(uprev+dt*(a81*k1       +a83*k3+a84*k4+a85*k5+a86*k6+a87*k7), p, t+dt)
  u = uprev+dt*(a91*k1              +a94*k4+a95*k5+a96*k6+a97*k7+a98*k8)
  integrator.fsallast = f(u, p, t+dt); k9 = integrator.fsallast
  if integrator.opts.adaptive
    utilde = dt*(btilde1*k1 + btilde4*k4 + btilde5*k5 + btilde6*k6 + btilde7*k7 + btilde8*k8 + btilde9*k9)
    atmp = calculate_residuals(utilde, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end
  integrator.k[1]=k1; integrator.k[2]=k2;
  integrator.k[3]=k3; integrator.k[4]=k4;
  integrator.k[5]=k5; integrator.k[6]=k6;
  integrator.k[7]=k7; integrator.k[8]=k8;
  integrator.k[9]=k9
  integrator.u = u
end

function initialize!(integrator, cache::Vern6Cache)
  integrator.kshortsize = 9
  integrator.fsalfirst = cache.k1 ; integrator.fsallast = cache.k9
  @unpack k = integrator
  resize!(k, integrator.kshortsize)
  k[1]=cache.k1; k[2]=cache.k2; k[3]=cache.k3;
  k[4]=cache.k4; k[5]=cache.k5; k[6]=cache.k6;
  k[7]=cache.k7; k[8]=cache.k8; k[9]=cache.k9 # Set the pointers
  integrator.f(integrator.fsalfirst, integrator.uprev, integrator.p, integrator.t) # Pre-start fsal
end

#=
@muladd function perform_step!(integrator, cache::Vern6Cache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack c1,c2,c3,c4,c5,c6,a21,a31,a32,a41,a43,a51,a53,a54,a61,a63,a64,a65,a71,a73,a74,a75,a76,a81,a83,a84,a85,a86,a87,a91,a94,a95,a96,a97,a98,btilde1,btilde4,btilde5,btilde6,btilde7,btilde8,btilde9 = cache.tab
  @unpack k1,k2,k3,k4,k5,k6,k7,k8,k9,utilde,tmp,atmp = cache
  a = dt*a21
  @. tmp = uprev+a*k1
  f(k2, tmp, p, t + c1*dt)
  @. tmp = uprev+dt*(a31*k1+a32*k2)
  f(@muladd(t + c2*dt),tmp,k3)
  @. tmp = uprev+dt*(a41*k1+a43*k3)
  f(k4, tmp, p, t + c3*dt)
  @. tmp = uprev+dt*(a51*k1+a53*k3+a54*k4)
  f(k5, tmp, p, t + c4*dt)
  @. tmp = uprev+dt*(a61*k1+a63*k3+a64*k4+a65*k5)
  f(k6, tmp, p, t + c5*dt)
  @. tmp = uprev+dt*(a71*k1+a73*k3+a74*k4+a75*k5+a76*k6)
  f(k7, tmp, p, t + c6*dt)
  @. tmp = uprev+dt*(a81*k1+a83*k3+a84*k4+a85*k5+a86*k6+a87*k7)
  f(k8, tmp, p, t+dt)
  @. u=uprev+dt*(a91*k1+a94*k4+a95*k5+a96*k6+a97*k7+a98*k8)
  f(k9, u, p, t+dt)
  if integrator.opts.adaptive
    @. utilde = dt*(btilde1*k1 + btilde4*k4 + btilde5*k5 + btilde6*k6 + btilde7*k7 + btilde8*k8 + btilde9*k9)
    calculate_residuals!(atmp, utilde, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end
end
=#

@muladd function perform_step!(integrator, cache::Vern6Cache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  uidx = eachindex(integrator.uprev)
  @unpack c1,c2,c3,c4,c5,c6,a21,a31,a32,a41,a43,a51,a53,a54,a61,a63,a64,a65,a71,a73,a74,a75,a76,a81,a83,a84,a85,a86,a87,a91,a94,a95,a96,a97,a98,btilde1,btilde4,btilde5,btilde6,btilde7,btilde8,btilde9 = cache.tab
  @unpack k1,k2,k3,k4,k5,k6,k7,k8,k9,utilde,tmp,atmp = cache
  a = dt*a21
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+a*k1[i]
  end
  f(k2, tmp, p, t + c1*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a31*k1[i]+a32*k2[i])
  end
  f(k3, tmp, p, t + c2*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a41*k1[i]+a43*k3[i])
  end
  f(k4, tmp, p, t + c3*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a51*k1[i]+a53*k3[i]+a54*k4[i])
  end
  f(k5, tmp, p, t + c4*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a61*k1[i]+a63*k3[i]+a64*k4[i]+a65*k5[i])
  end
  f(k6, tmp, p, t + c5*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a71*k1[i]+a73*k3[i]+a74*k4[i]+a75*k5[i]+a76*k6[i])
  end
  f(k7, tmp, p, t + c6*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a81*k1[i]+a83*k3[i]+a84*k4[i]+a85*k5[i]+a86*k6[i]+a87*k7[i])
  end
  f(k8, tmp, p, t+dt)
  @tight_loop_macros for i in uidx
    @inbounds u[i] = uprev[i]+dt*(a91*k1[i]+a94*k4[i]+a95*k5[i]+a96*k6[i]+a97*k7[i]+a98*k8[i])
  end
  f(k9, u, p, t+dt)
  if integrator.opts.adaptive
    @tight_loop_macros for i in uidx
      @inbounds utilde[i] = dt*(btilde1*k1[i] + btilde4*k4[i] + btilde5*k5[i] + btilde6*k6[i] + btilde7*k7[i] + btilde8*k8[i] + btilde9*k9[i])
    end
    calculate_residuals!(atmp, utilde, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end
end

function initialize!(integrator, cache::Vern7ConstantCache)
  integrator.kshortsize = 10
  integrator.k = typeof(integrator.k)(integrator.kshortsize)

  # Avoid undefined entries if k is an array of arrays
  @inbounds for i in eachindex(integrator.k)
    integrator.k[i] = zero(integrator.uprev)./oneunit(integrator.t)
  end
end

@muladd function perform_step!(integrator, cache::Vern7ConstantCache, repeat_step=false)
  @unpack t,dt,uprev,u,k,f,p = integrator
  @unpack c2,c3,c4,c5,c6,c7,c8,a021,a031,a032,a041,a043,a051,a053,a054,a061,a063,a064,a065,a071,a073,a074,a075,a076,a081,a083,a084,a085,a086,a087,a091,a093,a094,a095,a096,a097,a098,a101,a103,a104,a105,a106,a107,b1,b4,b5,b6,b7,b8,b9,btilde1,btilde4,btilde5,btilde6,btilde7,btilde8,btilde9,btilde10 = cache
  k1 = f(uprev, p, t)
  a = dt*a021
  k2 = f(uprev+a*k1, p, t + c2*dt)
  k3 = f(uprev+dt*(a031*k1+a032*k2), p, t + c3*dt)
  k4 = f(uprev+dt*(a041*k1       +a043*k3), p, t + c4*dt)
  k5 = f(uprev+dt*(a051*k1       +a053*k3+a054*k4), p, t + c5*dt)
  k6 = f(uprev+dt*(a061*k1       +a063*k3+a064*k4+a065*k5), p, t + c6*dt)
  k7 = f(uprev+dt*(a071*k1       +a073*k3+a074*k4+a075*k5+a076*k6), p, t + c7*dt)
  k8 = f(uprev+dt*(a081*k1       +a083*k3+a084*k4+a085*k5+a086*k6+a087*k7), p, t + c8*dt)
  k9 = f(uprev+dt*(a091*k1          +a093*k3+a094*k4+a095*k5+a096*k6+a097*k7+a098*k8), p, t+dt)
  k10= f(uprev+dt*(a101*k1          +a103*k3+a104*k4+a105*k5+a106*k6+a107*k7), p, t+dt)
  u = uprev + dt*(b1*k1 + b4*k4 + b5*k5 + b6*k6 + b7*k7 + b8*k8 + b9*k9)
  if integrator.opts.adaptive
    utilde = dt*(btilde1*k1 + btilde4*k4 + btilde5*k5 + btilde6*k6 + btilde7*k7 + btilde8*k8 + btilde9*k9 + btilde10*k10)
    atmp = calculate_residuals(utilde, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end
  integrator.k[1]=k1; integrator.k[2]=k2;
  integrator.k[3]=k3; integrator.k[4]=k4;
  integrator.k[5]=k5; integrator.k[6]=k6;
  integrator.k[7]=k7; integrator.k[8]=k8;
  integrator.k[9]=k9; integrator.k[10]=k10
  integrator.u = u
end

function initialize!(integrator, cache::Vern7Cache)
  @unpack k1,k2,k3,k4,k5,k6,k7,k8,k9,k10 = cache
  @unpack k = integrator
  integrator.kshortsize = 10
  resize!(k, integrator.kshortsize)
  k[1]=k1;k[2]=k2;k[3]=k3;k[4]=k4;k[5]=k5;k[6]=k6;k[7]=k7;k[8]=k8;k[9]=k9;k[10]=k10 # Setup pointers
end

#=
@muladd function perform_step!(integrator, cache::Vern7Cache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack c2,c3,c4,c5,c6,c7,c8,a021,a031,a032,a041,a043,a051,a053,a054,a061,a063,a064,a065,a071,a073,a074,a075,a076,a081,a083,a084,a085,a086,a087,a091,a093,a094,a095,a096,a097,a098,a101,a103,a104,a105,a106,a107,b1,b4,b5,b6,b7,b8,b9,btilde1,btilde4,btilde5,btilde6,btilde7,btilde8,btilde9,btilde10 = cache.tab
  @unpack k1,k2,k3,k4,k5,k6,k7,k8,k9,k10,utilde,tmp,atmp = cache
  f(k1, uprev, p, t)
  a = dt*a021
  @. tmp = uprev+a*k1
  f(k2, tmp, p, t + c2*dt)
  @. tmp = uprev+dt*(a031*k1+a032*k2)
  f(k3, tmp, p, t + c3*dt)
  @. tmp = uprev+dt*(a041*k1+a043*k3)
  f(k4, tmp, p, t + c4*dt)
  @. tmp = uprev+dt*(a051*k1+a053*k3+a054*k4)
  f(k5, tmp, p, t + c5*dt)
  @. tmp = uprev+dt*(a061*k1+a063*k3+a064*k4+a065*k5)
  f(k6, tmp, p, t + c6*dt)
  @. tmp = uprev+dt*(a071*k1+a073*k3+a074*k4+a075*k5+a076*k6)
  f(k7, tmp, p, t + c7*dt)
  @. tmp = uprev+dt*(a081*k1+a083*k3+a084*k4+a085*k5+a086*k6+a087*k7)
  f(k8, tmp, p, t + c8*dt)
  @. tmp = uprev+dt*(a091*k1+a093*k3+a094*k4+a095*k5+a096*k6+a097*k7+a098*k8)
  f(k9, tmp, p, t+dt)
  @. tmp = uprev+dt*(a101*k1+a103*k3+a104*k4+a105*k5+a106*k6+a107*k7)
  f(k10, tmp, p, t+dt)
  @. u = uprev + dt*(b1*k1 + b4*k4 + b5*k5 + b6*k6 + b7*k7 + b8*k8 + b9*k9)
  if integrator.opts.adaptive
    @. utilde = dt*(btilde1*k1 + btilde4*k4 + btilde5*k5 + btilde6*k6 + btilde7*k7 + btilde8*k8 + btilde9*k9 + btilde10*k10)
    calculate_residuals!(atmp, utilde, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end
end
=#

@muladd function perform_step!(integrator, cache::Vern7Cache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  uidx = eachindex(integrator.uprev)
  @unpack c2,c3,c4,c5,c6,c7,c8,a021,a031,a032,a041,a043,a051,a053,a054,a061,a063,a064,a065,a071,a073,a074,a075,a076,a081,a083,a084,a085,a086,a087,a091,a093,a094,a095,a096,a097,a098,a101,a103,a104,a105,a106,a107,b1,b4,b5,b6,b7,b8,b9,btilde1,btilde4,btilde5,btilde6,btilde7,btilde8,btilde9,btilde10= cache.tab
  @unpack k1,k2,k3,k4,k5,k6,k7,k8,k9,k10,utilde,tmp,atmp = cache
  f(k1, uprev, p, t)
  a = dt*a021
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+a*k1[i]
  end
  f(k2, tmp, p, t + c2*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a031*k1[i]+a032*k2[i])
  end
  f(k3, tmp, p, t + c3*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a041*k1[i]+a043*k3[i])
  end
  f(k4, tmp, p, t + c4*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a051*k1[i]+a053*k3[i]+a054*k4[i])
  end
  f(k5, tmp, p, t + c5*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a061*k1[i]+a063*k3[i]+a064*k4[i]+a065*k5[i])
  end
  f(k6, tmp, p, t + c6*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a071*k1[i]+a073*k3[i]+a074*k4[i]+a075*k5[i]+a076*k6[i])
  end
  f(k7, tmp, p, t + c7*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a081*k1[i]+a083*k3[i]+a084*k4[i]+a085*k5[i]+a086*k6[i]+a087*k7[i])
  end
  f(k8, tmp, p, t + c8*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a091*k1[i]+a093*k3[i]+a094*k4[i]+a095*k5[i]+a096*k6[i]+a097*k7[i]+a098*k8[i])
  end
  f(k9, tmp, p, t+dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a101*k1[i]+a103*k3[i]+a104*k4[i]+a105*k5[i]+a106*k6[i]+a107*k7[i])
  end
  f(k10, tmp, p, t+dt)
  @tight_loop_macros for i in uidx
    @inbounds u[i] = uprev[i] + dt*(b1*k1[i] + b4*k4[i] + b5*k5[i] + b6*k6[i] + b7*k7[i] + b8*k8[i] + b9*k9[i])
  end
  if integrator.opts.adaptive
    @tight_loop_macros for i in uidx
      @inbounds utilde[i] = dt*(btilde1*k1[i] + btilde4*k4[i] + btilde5*k5[i] + btilde6*k6[i] + btilde7*k7[i] + btilde8*k8[i] + btilde9*k9[i] + btilde10*k10[i])
    end
    calculate_residuals!(atmp, utilde, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end
end

function initialize!(integrator, cache::Vern8ConstantCache)
  integrator.kshortsize = 13
  integrator.k = typeof(integrator.k)(integrator.kshortsize)

  # Avoid undefined entries if k is an array of arrays
  @inbounds for i in eachindex(integrator.k)
    integrator.k[i] = zero(integrator.uprev)./oneunit(integrator.t)
  end
end

@muladd function perform_step!(integrator, cache::Vern8ConstantCache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack c2,c3,c4,c5,c6,c7,c8,c9,c10,c11,a0201,a0301,a0302,a0401,a0403,a0501,a0503,a0504,a0601,a0604,a0605,a0701,a0704,a0705,a0706,a0801,a0804,a0805,a0806,a0807,a0901,a0904,a0905,a0906,a0907,a0908,a1001,a1004,a1005,a1006,a1007,a1008,a1009,a1101,a1104,a1105,a1106,a1107,a1108,a1109,a1110,a1201,a1204,a1205,a1206,a1207,a1208,a1209,a1210,a1211,a1301,a1304,a1305,a1306,a1307,a1308,a1309,a1310,b1,b6,b7,b8,b9,b10,b11,b12,btilde1,btilde6,btilde7,btilde8,btilde9,btilde10,btilde11,btilde12,btilde13 = cache
  k1 = f(uprev, p, t)
  a = dt*a0201
  k2 = f(uprev+a*k1, p, t + c2*dt)
  k3 = f(uprev+dt*(a0301*k1+a0302*k2), p, t + c3*dt)
  k4 = f(uprev+dt*(a0401*k1       +a0403*k3), p, t + c4*dt)
  k5 = f(uprev+dt*(a0501*k1       +a0503*k3+a0504*k4), p, t + c5*dt)
  k6 = f(uprev+dt*(a0601*k1                +a0604*k4+a0605*k5), p, t + c6*dt)
  k7 = f(uprev+dt*(a0701*k1                +a0704*k4+a0705*k5+a0706*k6), p, t + c7*dt)
  k8 = f(uprev+dt*(a0801*k1                +a0804*k4+a0805*k5+a0806*k6+a0807*k7), p, t + c8*dt)
  k9 = f(uprev+dt*(a0901*k1                +a0904*k4+a0905*k5+a0906*k6+a0907*k7+a0908*k8), p, t + c9*dt)
  k10= f(uprev+dt*(a1001*k1                +a1004*k4+a1005*k5+a1006*k6+a1007*k7+a1008*k8+a1009*k9), p, t + c10*dt)
  k11= f(uprev+dt*(a1101*k1                +a1104*k4+a1105*k5+a1106*k6+a1107*k7+a1108*k8+a1109*k9+a1110*k10), p, t + c11*dt)
  k12= f(uprev+dt*(a1201*k1                +a1204*k4+a1205*k5+a1206*k6+a1207*k7+a1208*k8+a1209*k9+a1210*k10+a1211*k11), p, t+    dt)
  k13= f(uprev+dt*(a1301*k1                +a1304*k4+a1305*k5+a1306*k6+a1307*k7+a1308*k8+a1309*k9+a1310*k10), p, t+    dt)
  u = uprev + dt*(b1*k1 + b6*k6 + b7*k7 + b8*k8 + b9*k9 + b10*k10 + b11*k11 + b12*k12)
  if integrator.opts.adaptive
    utilde = dt*(btilde1*k1 + btilde6*k6 + btilde7*k7 + btilde8*k8 + btilde9*k9 + btilde10*k10 + btilde11*k11 + btilde12*k12 + btilde13*k13)
    atmp = calculate_residuals(utilde, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end
  integrator.k[1]=k1; integrator.k[2]=k2;
  integrator.k[3]=k3; integrator.k[4]=k4;
  integrator.k[5]=k5; integrator.k[6]=k6;
  integrator.k[7]=k7; integrator.k[8]=k8;
  integrator.k[9]=k9; integrator.k[10]=k10;
  integrator.k[11]=k11; integrator.k[12]=k12;
  integrator.k[13]=k13
  integrator.u = u
end

function initialize!(integrator, cache::Vern8Cache)
  @unpack k1,k2,k3,k4,k5,k6,k7,k8,k9,k10,k11,k12,k13 = cache
  @unpack k = integrator
  integrator.kshortsize = 13
  resize!(k, integrator.kshortsize)
  k[1]=k1;k[2]=k2;k[3]=k3;k[4]=k4;k[5]=k5;k[6]=k6;k[7]=k7;k[8]=k8;k[9]=k9;k[10]=k10;k[11]=k11;k[12]=k12;k[13]=k13 # Setup pointers
end

#=
@muladd function perform_step!(integrator, cache::Vern8Cache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack c2,c3,c4,c5,c6,c7,c8,c9,c10,c11,a0201,a0301,a0302,a0401,a0403,a0501,a0503,a0504,a0601,a0604,a0605,a0701,a0704,a0705,a0706,a0801,a0804,a0805,a0806,a0807,a0901,a0904,a0905,a0906,a0907,a0908,a1001,a1004,a1005,a1006,a1007,a1008,a1009,a1101,a1104,a1105,a1106,a1107,a1108,a1109,a1110,a1201,a1204,a1205,a1206,a1207,a1208,a1209,a1210,a1211,a1301,a1304,a1305,a1306,a1307,a1308,a1309,a1310,b1,b6,b7,b8,b9,b10,b11,b12,btilde1,btilde6,btilde7,btilde8,btilde9,btilde10,btilde11,btilde12,btilde13= cache.tab
  @unpack k1,k2,k3,k4,k5,k6,k7,k8,k9,k10,k11,k12,k13,utilde,tmp,atmp = cache
  f(k1, uprev, p, t)
  a = dt*a0201
  @. tmp = uprev+a*k1
  f(k2, tmp, p, t + c2*dt)
  @. tmp = uprev+dt*(a0301*k1+a0302*k2)
  f(k3, tmp, p, t + c3*dt)
  @. tmp = uprev+dt*(a0401*k1+a0403*k3)
  f(k4, tmp, p, t + c4*dt)
  @. tmp = uprev+dt*(a0501*k1+a0503*k3+a0504*k4)
  f(k5, tmp, p, t + c5*dt)
  @. tmp = uprev+dt*(a0601*k1+a0604*k4+a0605*k5)
  f(k6, tmp, p, t + c6*dt)
  @. tmp = uprev+dt*(a0701*k1+a0704*k4+a0705*k5+a0706*k6)
  f(k7, tmp, p, t + c7*dt)
  @. tmp = uprev+dt*(a0801*k1+a0804*k4+a0805*k5+a0806*k6+a0807*k7)
  f(k8, tmp, p, t + c8*dt)
  @. tmp = uprev+dt*(a0901*k1+a0904*k4+a0905*k5+a0906*k6+a0907*k7+a0908*k8)
  f(k9, tmp, p, t + c9*dt)
  @. tmp = uprev+dt*(a1001*k1+a1004*k4+a1005*k5+a1006*k6+a1007*k7+a1008*k8+a1009*k9)
  f(k10, tmp, p, t + c10*dt)
  @. tmp = uprev+dt*(a1101*k1+a1104*k4+a1105*k5+a1106*k6+a1107*k7+a1108*k8+a1109*k9+a1110*k10)
  f(k11, tmp, p, t + c11*dt)
  @. tmp = uprev+dt*(a1201*k1+a1204*k4+a1205*k5+a1206*k6+a1207*k7+a1208*k8+a1209*k9+a1210*k10+a1211*k11)
  f(k12, tmp, p, t+dt)
  @. tmp = uprev+dt*(a1301*k1+a1304*k4+a1305*k5+a1306*k6+a1307*k7+a1308*k8+a1309*k9+a1310*k10)
  f(k13, tmp, p, t+dt)
  @. u = uprev + dt*(b1*k1 + b6*k6 + b7*k7 + b8*k8 + b9*k9 + b10*k10 + b11*k11 + b12*k12)
  if integrator.opts.adaptive
    @. utilde = dt*(btilde1*k1 + btilde6*k6 + btilde7*k7 + btilde8*k8 + btilde9*k9 + btilde10*k10 + btilde11*k11 + btilde12*k12 + btilde13*k13)
    calculate_residuals!(atmp, utilde, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end
end
=#

@muladd function perform_step!(integrator, cache::Vern8Cache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  uidx = eachindex(integrator.uprev)
  @unpack c2,c3,c4,c5,c6,c7,c8,c9,c10,c11,a0201,a0301,a0302,a0401,a0403,a0501,a0503,a0504,a0601,a0604,a0605,a0701,a0704,a0705,a0706,a0801,a0804,a0805,a0806,a0807,a0901,a0904,a0905,a0906,a0907,a0908,a1001,a1004,a1005,a1006,a1007,a1008,a1009,a1101,a1104,a1105,a1106,a1107,a1108,a1109,a1110,a1201,a1204,a1205,a1206,a1207,a1208,a1209,a1210,a1211,a1301,a1304,a1305,a1306,a1307,a1308,a1309,a1310,b1,b6,b7,b8,b9,b10,b11,b12,btilde1,btilde6,btilde7,btilde8,btilde9,btilde10,btilde11,btilde12,btilde13 = cache.tab
  @unpack k1,k2,k3,k4,k5,k6,k7,k8,k9,k10,k11,k12,k13,utilde,tmp,atmp = cache
  f(k1, uprev, p, t)
  a = dt*a0201
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+a*k1[i]
  end
  f(k2, tmp, p, t + c2*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a0301*k1[i]+a0302*k2[i])
  end
  f(k3, tmp, p, t + c3*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a0401*k1[i]+a0403*k3[i])
  end
  f(k4, tmp, p, t + c4*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a0501*k1[i]+a0503*k3[i]+a0504*k4[i])
  end
  f(k5, tmp, p, t + c5*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a0601*k1[i]+a0604*k4[i]+a0605*k5[i])
  end
  f(k6, tmp, p, t + c6*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a0701*k1[i]+a0704*k4[i]+a0705*k5[i]+a0706*k6[i])
  end
  f(k7, tmp, p, t + c7*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a0801*k1[i]+a0804*k4[i]+a0805*k5[i]+a0806*k6[i]+a0807*k7[i])
  end
  f(k8, tmp, p, t + c8*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a0901*k1[i]+a0904*k4[i]+a0905*k5[i]+a0906*k6[i]+a0907*k7[i]+a0908*k8[i])
  end
  f(k9, tmp, p, t + c9*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a1001*k1[i]+a1004*k4[i]+a1005*k5[i]+a1006*k6[i]+a1007*k7[i]+a1008*k8[i]+a1009*k9[i])
  end
  f(k10, tmp, p, t + c10*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a1101*k1[i]+a1104*k4[i]+a1105*k5[i]+a1106*k6[i]+a1107*k7[i]+a1108*k8[i]+a1109*k9[i]+a1110*k10[i])
  end
  f(k11, tmp, p, t + c11*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a1201*k1[i]+a1204*k4[i]+a1205*k5[i]+a1206*k6[i]+a1207*k7[i]+a1208*k8[i]+a1209*k9[i]+a1210*k10[i]+a1211*k11[i])
  end
  f(k12, tmp, p, t+dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a1301*k1[i]+a1304*k4[i]+a1305*k5[i]+a1306*k6[i]+a1307*k7[i]+a1308*k8[i]+a1309*k9[i]+a1310*k10[i])
  end
  f(k13, tmp, p, t+dt)
  @tight_loop_macros for i in uidx
    @inbounds u[i] = uprev[i] + dt*(b1*k1[i] + b6*k6[i] + b7*k7[i] + b8*k8[i] + b9*k9[i] + b10*k10[i] + b11*k11[i] + b12*k12[i])
  end
  if integrator.opts.adaptive
    @tight_loop_macros for i in uidx
      @inbounds utilde[i] = dt*(btilde1*k1[i] + btilde6*k6[i] + btilde7*k7[i] + btilde8*k8[i] + btilde9*k9[i] + btilde10*k10[i] + btilde11*k11[i] + btilde12*k12[i] + btilde13*k13[i])
    end
    calculate_residuals!(atmp, utilde, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end
end

function initialize!(integrator, cache::Vern9ConstantCache)
  integrator.kshortsize = 16
  integrator.k = typeof(integrator.k)(integrator.kshortsize)

  # Avoid undefined entries if k is an array of arrays
  @inbounds for i in eachindex(integrator.k)
    integrator.k[i] = zero(integrator.uprev)./oneunit(integrator.t)
  end
end

@muladd function perform_step!(integrator, cache::Vern9ConstantCache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack c1,c2,c3,c4,c5,c6,c7,c8,c9,c10,c11,c12,c13,a0201,a0301,a0302,a0401,a0403,a0501,a0503,a0504,a0601,a0604,a0605,a0701,a0704,a0705,a0706,a0801,a0806,a0807,a0901,a0906,a0907,a0908,a1001,a1006,a1007,a1008,a1009,a1101,a1106,a1107,a1108,a1109,a1110,a1201,a1206,a1207,a1208,a1209,a1210,a1211,a1301,a1306,a1307,a1308,a1309,a1310,a1311,a1312,a1401,a1406,a1407,a1408,a1409,a1410,a1411,a1412,a1413,a1501,a1506,a1507,a1508,a1509,a1510,a1511,a1512,a1513,a1514,a1601,a1606,a1607,a1608,a1609,a1610,a1611,a1612,a1613,b1,b8,b9,b10,b11,b12,b13,b14,b15,btilde1,btilde8,btilde9,btilde10,btilde11,btilde12,btilde13,btilde14,btilde15,btilde16 = cache
  k1 = f(uprev, p, t)
  a = dt*a0201
  k2 = f(uprev+a*k1, p, t + c1*dt)
  k3 = f(uprev+dt*(a0301*k1+a0302*k2), p, t + c2*dt)
  k4 = f(uprev+dt*(a0401*k1       +a0403*k3), p, t + c3*dt)
  k5 = f(uprev+dt*(a0501*k1       +a0503*k3+a0504*k4), p, t + c4*dt)
  k6 = f(uprev+dt*(a0601*k1                +a0604*k4+a0605*k5), p, t + c5*dt)
  k7 = f(uprev+dt*(a0701*k1                +a0704*k4+a0705*k5+a0706*k6), p, t + c6*dt)
  k8 = f(uprev+dt*(a0801*k1                                  +a0806*k6+a0807*k7), p, t + c7*dt)
  k9 = f(uprev+dt*(a0901*k1                                  +a0906*k6+a0907*k7+a0908*k8), p, t + c8*dt)
  k10 =f(uprev+dt*(a1001*k1                                  +a1006*k6+a1007*k7+a1008*k8+a1009*k9), p, t + c9*dt)
  k11= f(uprev+dt*(a1101*k1                                  +a1106*k6+a1107*k7+a1108*k8+a1109*k9+a1110*k10), p, t + c10*dt)
  k12= f(uprev+dt*(a1201*k1                                  +a1206*k6+a1207*k7+a1208*k8+a1209*k9+a1210*k10+a1211*k11), p, t + c11*dt)
  k13= f(uprev+dt*(a1301*k1                                  +a1306*k6+a1307*k7+a1308*k8+a1309*k9+a1310*k10+a1311*k11+a1312*k12), p, t + c12*dt)
  k14= f(uprev+dt*(a1401*k1                                  +a1406*k6+a1407*k7+a1408*k8+a1409*k9+a1410*k10+a1411*k11+a1412*k12+a1413*k13), p, t + c13*dt)
  k15= f(uprev+dt*(a1501*k1                                  +a1506*k6+a1507*k7+a1508*k8+a1509*k9+a1510*k10+a1511*k11+a1512*k12+a1513*k13+a1514*k14), p, t+dt)
  k16= f(uprev+dt*(a1601*k1                                  +a1606*k6+a1607*k7+a1608*k8+a1609*k9+a1610*k10+a1611*k11+a1612*k12+a1613*k13), p, t+dt)
  u = uprev + dt*(b1*k1+b8*k8+b9*k9+b10*k10+b11*k11+b12*k12+b13*k13+b14*k14+b15*k15)
  if integrator.opts.adaptive
    utilde = dt*(btilde1*k1 + btilde8*k8 + btilde9*k9 + btilde10*k10 + btilde11*k11 + btilde12*k12 + btilde13*k13 + btilde14*k14 + btilde15*k15 + btilde16*k16)
    atmp = calculate_residuals(utilde, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end
  integrator.k[1]=k1; integrator.k[2]=k2;
  integrator.k[3]=k3; integrator.k[4]=k4;
  integrator.k[5]=k5; integrator.k[6]=k6;
  integrator.k[7]=k7; integrator.k[8]=k8;
  integrator.k[9]=k9; integrator.k[10]=k10;
  integrator.k[11]=k11; integrator.k[12]=k12;
  integrator.k[13]=k13; integrator.k[14]=k14;
  integrator.k[15]=k15; integrator.k[16]=k16
  integrator.u = u
end

function initialize!(integrator, cache::Vern9Cache)
  @unpack k1,k2,k3,k4,k5,k6,k7,k8,k9,k10,k11,k12,k13,k14,k15,k16 = cache
  @unpack k = integrator
  integrator.kshortsize = 16
  resize!(k, integrator.kshortsize)
  k[1]=k1;k[2]=k2;k[3]=k3;k[4]=k4;k[5]=k5;k[6]=k6;k[7]=k7;k[8]=k8;k[9]=k9;k[10]=k10;k[11]=k11;k[12]=k12;k[13]=k13;k[14]=k14;k[15]=k15;k[16]=k16 # Setup pointers
end

#=
@muladd function perform_step!(integrator, cache::Vern9Cache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  @unpack c1,c2,c3,c4,c5,c6,c7,c8,c9,c10,c11,c12,c13,a0201,a0301,a0302,a0401,a0403,a0501,a0503,a0504,a0601,a0604,a0605,a0701,a0704,a0705,a0706,a0801,a0806,a0807,a0901,a0906,a0907,a0908,a1001,a1006,a1007,a1008,a1009,a1101,a1106,a1107,a1108,a1109,a1110,a1201,a1206,a1207,a1208,a1209,a1210,a1211,a1301,a1306,a1307,a1308,a1309,a1310,a1311,a1312,a1401,a1406,a1407,a1408,a1409,a1410,a1411,a1412,a1413,a1501,a1506,a1507,a1508,a1509,a1510,a1511,a1512,a1513,a1514,a1601,a1606,a1607,a1608,a1609,a1610,a1611,a1612,a1613,b1,b8,b9,b10,b11,b12,b13,b14,b15,btilde1,btilde8,btilde9,btilde10,btilde11,btilde12,btilde13,btilde14,btilde15,btilde16 = cache.tab
  @unpack k1,k2,k3,k4,k5,k6,k7,k8,k9,k10,k11,k12,k13,k14,k15,k16,utilde,tmp,atmp = cache
  f(k1, uprev, p, t)
  a = dt*a0201
  @. tmp = uprev+a*k1
  f(k2, tmp, p, t + c1*dt)
  @. tmp = uprev+dt*(a0301*k1+a0302*k2)
  f(k3, tmp, p, t + c2*dt)
  @. tmp = uprev+dt*(a0401*k1+a0403*k3)
  f(k4, tmp, p, t + c3*dt)
  @. tmp = uprev+dt*(a0501*k1+a0503*k3+a0504*k4)
  f(k5, tmp, p, t + c4*dt)
  @. tmp = uprev+dt*(a0601*k1+a0604*k4+a0605*k5)
  f(k6, tmp, p, t + c5*dt)
  @. tmp = uprev+dt*(a0701*k1+a0704*k4+a0705*k5+a0706*k6)
  f(k7, tmp, p, t + c6*dt)
  @. tmp = uprev+dt*(a0801*k1+a0806*k6+a0807*k7)
  f(k8, tmp, p, t + c7*dt)
  @. tmp = uprev+dt*(a0901*k1+a0906*k6+a0907*k7+a0908*k8)
  f(k9, tmp, p, t + c8*dt)
  @. tmp = uprev+dt*(a1001*k1+a1006*k6+a1007*k7+a1008*k8+a1009*k9)
  f(k10, tmp, p, t + c9*dt)
  @. tmp = uprev+dt*(a1101*k1+a1106*k6+a1107*k7+a1108*k8+a1109*k9+a1110*k10)
  f(k11, tmp, p, t + c10*dt)
  @. tmp = uprev+dt*(a1201*k1+a1206*k6+a1207*k7+a1208*k8+a1209*k9+a1210*k10+a1211*k11)
  f(k12, tmp, p, t + c11*dt)
  @. tmp = uprev+dt*(a1301*k1+a1306*k6+a1307*k7+a1308*k8+a1309*k9+a1310*k10+a1311*k11+a1312*k12)
  f(k13, tmp, p, t + c12*dt)
  @. tmp = uprev+dt*(a1401*k1+a1406*k6+a1407*k7+a1408*k8+a1409*k9+a1410*k10+a1411*k11+a1412*k12+a1413*k13)
  f(k14, tmp, p, t + c13*dt)
  @. tmp = uprev+dt*(a1501*k1+a1506*k6+a1507*k7+a1508*k8+a1509*k9+a1510*k10+a1511*k11+a1512*k12+a1513*k13+a1514*k14)
  f(k15, tmp, p, t+dt)
  @. tmp = uprev+dt*(a1601*k1+a1606*k6+a1607*k7+a1608*k8+a1609*k9+a1610*k10+a1611*k11+a1612*k12+a1613*k13)
  f(k16, tmp, p, t+dt)
  @. u = uprev + dt*(b1*k1+b8*k8+b9*k9+b10*k10+b11*k11+b12*k12+b13*k13+b14*k14+b15*k15)
  if integrator.opts.adaptive
    @. utilde = dt*(btilde1*k1 + btilde8*k8 + btilde9*k9 + btilde10*k10 + btilde11*k11 + btilde12*k12 + btilde13*k13 + btilde14*k14 + btilde15*k15 + btilde16*k16)
    calculate_residuals!(atmp, utilde, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end
end
=#

@muladd function perform_step!(integrator, cache::Vern9Cache, repeat_step=false)
  @unpack t,dt,uprev,u,f,p = integrator
  uidx = eachindex(integrator.uprev)
  @unpack c1,c2,c3,c4,c5,c6,c7,c8,c9,c10,c11,c12,c13,a0201,a0301,a0302,a0401,a0403,a0501,a0503,a0504,a0601,a0604,a0605,a0701,a0704,a0705,a0706,a0801,a0806,a0807,a0901,a0906,a0907,a0908,a1001,a1006,a1007,a1008,a1009,a1101,a1106,a1107,a1108,a1109,a1110,a1201,a1206,a1207,a1208,a1209,a1210,a1211,a1301,a1306,a1307,a1308,a1309,a1310,a1311,a1312,a1401,a1406,a1407,a1408,a1409,a1410,a1411,a1412,a1413,a1501,a1506,a1507,a1508,a1509,a1510,a1511,a1512,a1513,a1514,a1601,a1606,a1607,a1608,a1609,a1610,a1611,a1612,a1613,b1,b8,b9,b10,b11,b12,b13,b14,b15,btilde1,btilde8,btilde9,btilde10,btilde11,btilde12,btilde13,btilde14,btilde15,btilde16 = cache.tab
  @unpack k1,k2,k3,k4,k5,k6,k7,k8,k9,k10,k11,k12,k13,k14,k15,k16,utilde,tmp,atmp = cache
  f(k1, uprev, p, t)
  a = dt*a0201
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+a*k1[i]
  end
  f(k2, tmp, p, t + c1*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a0301*k1[i]+a0302*k2[i])
  end
  f(k3, tmp, p, t + c2*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a0401*k1[i]+a0403*k3[i])
  end
  f(k4, tmp, p, t + c3*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a0501*k1[i]+a0503*k3[i]+a0504*k4[i])
  end
  f(k5, tmp, p, t + c4*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a0601*k1[i]+a0604*k4[i]+a0605*k5[i])
  end
  f(k6, tmp, p, t + c5*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a0701*k1[i]+a0704*k4[i]+a0705*k5[i]+a0706*k6[i])
  end
  f(k7, tmp, p, t + c6*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a0801*k1[i]+a0806*k6[i]+a0807*k7[i])
  end
  f(k8, tmp, p, t + c7*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a0901*k1[i]+a0906*k6[i]+a0907*k7[i]+a0908*k8[i])
  end
  f(k9, tmp, p, t + c8*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a1001*k1[i]+a1006*k6[i]+a1007*k7[i]+a1008*k8[i]+a1009*k9[i])
  end
  f(k10, tmp, p, t + c9*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a1101*k1[i]+a1106*k6[i]+a1107*k7[i]+a1108*k8[i]+a1109*k9[i]+a1110*k10[i])
  end
  f(k11, tmp, p, t + c10*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a1201*k1[i]+a1206*k6[i]+a1207*k7[i]+a1208*k8[i]+a1209*k9[i]+a1210*k10[i]+a1211*k11[i])
  end
  f(k12, tmp, p, t + c11*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a1301*k1[i]+a1306*k6[i]+a1307*k7[i]+a1308*k8[i]+a1309*k9[i]+a1310*k10[i]+a1311*k11[i]+a1312*k12[i])
  end
  f(k13, tmp, p, t + c12*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a1401*k1[i]+a1406*k6[i]+a1407*k7[i]+a1408*k8[i]+a1409*k9[i]+a1410*k10[i]+a1411*k11[i]+a1412*k12[i]+a1413*k13[i])
  end
  f(k14, tmp, p, t + c13*dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a1501*k1[i]+a1506*k6[i]+a1507*k7[i]+a1508*k8[i]+a1509*k9[i]+a1510*k10[i]+a1511*k11[i]+a1512*k12[i]+a1513*k13[i]+a1514*k14[i])
  end
  f(k15, tmp, p, t+dt)
  @tight_loop_macros for i in uidx
    @inbounds tmp[i] = uprev[i]+dt*(a1601*k1[i]+a1606*k6[i]+a1607*k7[i]+a1608*k8[i]+a1609*k9[i]+a1610*k10[i]+a1611*k11[i]+a1612*k12[i]+a1613*k13[i])
  end
  f(k16, tmp, p, t+dt)
  @tight_loop_macros for i in uidx
    @inbounds u[i] = uprev[i] + dt*(b1*k1[i]+b8*k8[i]+b9*k9[i]+b10*k10[i]+b11*k11[i]+b12*k12[i]+b13*k13[i]+b14*k14[i]+b15*k15[i])
  end
  if integrator.opts.adaptive
    @tight_loop_macros for i in uidx
      @inbounds utilde[i] = dt*(btilde1*k1[i] + btilde8*k8[i] + btilde9*k9[i] + btilde10*k10[i] + btilde11*k11[i] + btilde12*k12[i] + btilde13*k13[i] + btilde14*k14[i] + btilde15*k15[i] + btilde16*k16[i])
    end
    calculate_residuals!(atmp, utilde, uprev, u, integrator.opts.abstol, integrator.opts.reltol,integrator.opts.internalnorm)
    integrator.EEst = integrator.opts.internalnorm(atmp)
  end
end
