save_idxsinitialize{uType}(integrator,cache::OrdinaryDiffEqCache,::Type{uType}) =
                error("This algorithm does not have an initialization function")

@inline function loopheader!(integrator)
  # Apply right after iterators / callbacks

  # Accept or reject the step
  if integrator.iter > 0
    if (integrator.opts.adaptive && integrator.accept_step) || !integrator.opts.adaptive
      apply_step!(integrator)
    elseif integrator.opts.adaptive && !integrator.accept_step
      if integrator.isout
        integrator.dt = integrator.dt*integrator.opts.qmin
      else
        integrator.dt = integrator.dt/min(inv(integrator.opts.qmin),integrator.q11/integrator.opts.gamma)
      end
    end
  end

  integrator.iter += 1
  fix_dt_at_bounds!(integrator)
  modify_dt_for_tstops!(integrator)
  choose_algorithm!(integrator,integrator.cache)

end

@def ode_exit_conditions begin
  if integrator.iter > integrator.opts.maxiters
    if integrator.opts.verbose
      warn("Interrupted. Larger maxiters is needed.")
    end
    postamble!(integrator)
    integrator.sol.retcode = :MaxIters
    return integrator.sol
  end
  if !integrator.opts.force_dtmin && integrator.opts.adaptive && abs(integrator.dt) <= abs(integrator.opts.dtmin)
    if integrator.opts.verbose
      warn("dt <= dtmin. Aborting. If you would like to force continuation with dt=dtmin, set force_dtmin=true")
    end
    postamble!(integrator)
    integrator.sol.retcode = :DtLessThanMin
    return integrator.sol
  end
  if integrator.opts.unstable_check(integrator.dt,integrator.t,integrator.u)
    if integrator.opts.verbose
      warn("Instability detected. Aborting")
    end
    postamble!(integrator)
    integrator.sol.retcode = :Unstable
    return integrator.sol
  end
end

@inline function modify_dt_for_tstops!(integrator)
  tstops = integrator.opts.tstops
  if !isempty(tstops)
    if integrator.opts.adaptive
      if integrator.tdir > 0
        integrator.dt = min(abs(integrator.dt),abs(top(tstops)-integrator.t)) # step! to the end
      else
        integrator.dt = -min(abs(integrator.dt),abs(top(tstops)-integrator.t))
      end
    elseif integrator.dtcache == zero(integrator.t) && integrator.dtchangeable # Use integrator.opts.tstops
      integrator.dt = integrator.tdir*abs(top(tstops)-integrator.t)
    elseif integrator.dtchangeable # always try to step! with dtcache, but lower if a tstops
      integrator.dt = integrator.tdir*min(abs(integrator.dtcache),abs(top(tstops)-integrator.t)) # step! to the end
    end
  end
end

@inline function savevalues!(integrator::Union{ODEIntegrator,DDEIntegrator},force_save=false)
  while !isempty(integrator.opts.saveat) && integrator.tdir*top(integrator.opts.saveat) <= integrator.tdir*integrator.t # Perform saveat
    integrator.saveiter += 1
    curt = pop!(integrator.opts.saveat)
    if curt!=integrator.t # If <t, interpolate
      ode_addsteps!(integrator)
      Θ = (curt - integrator.tprev)/integrator.dt
      val = ode_interpolant(Θ,integrator,integrator.opts.save_idxs,Val{0}) # out of place, but no force copy later
      copyat_or_push!(integrator.sol.t,integrator.saveiter,curt)
      save_val = val
      copyat_or_push!(integrator.sol.u,integrator.saveiter,save_val,Val{false})
      if typeof(integrator.alg) <: OrdinaryDiffEqCompositeAlgorithm
        copyat_or_push!(integrator.sol.alg_choice,integrator.saveiter,integrator.cache.current)
      end
    else # ==t, just save
      copyat_or_push!(integrator.sol.t,integrator.saveiter,integrator.t)
      if integrator.opts.save_idxs ==nothing
        copyat_or_push!(integrator.sol.u,integrator.saveiter,integrator.u)
      else
        copyat_or_push!(integrator.sol.u,integrator.saveiter,integrator.u[integrator.opts.save_idxs],Val{false})
      end
      if typeof(integrator.alg) <: Discrete || integrator.opts.dense
        integrator.saveiter_dense +=1
        copyat_or_push!(integrator.notsaveat_idxs,integrator.saveiter_dense,integrator.saveiter)
        if integrator.opts.dense
          if integrator.opts.save_idxs ==nothing
            copyat_or_push!(integrator.sol.k,integrator.saveiter_dense,integrator.k)
          else
            copyat_or_push!(integrator.sol.k,integrator.saveiter_dense,[k[integrator.opts.save_idxs] for k in integrator.k],Val{false})
          end
        end
      end
      if typeof(integrator.alg) <: OrdinaryDiffEqCompositeAlgorithm
        copyat_or_push!(integrator.sol.alg_choice,integrator.saveiter,integrator.cache.current)
      end
    end
  end
  if force_save || (integrator.opts.save_everystep && integrator.iter%integrator.opts.timeseries_steps==0)
    integrator.saveiter += 1
    if integrator.opts.save_idxs == nothing
      copyat_or_push!(integrator.sol.u,integrator.saveiter,integrator.u)
    else
      copyat_or_push!(integrator.sol.u,integrator.saveiter,integrator.u[integrator.opts.save_idxs],Val{false})
    end
    copyat_or_push!(integrator.sol.t,integrator.saveiter,integrator.t)
    if typeof(integrator.alg) <: Discrete || integrator.opts.dense
      integrator.saveiter_dense +=1
      copyat_or_push!(integrator.notsaveat_idxs,integrator.saveiter_dense,integrator.saveiter)
      if integrator.opts.dense
        if integrator.opts.save_idxs == nothing
          copyat_or_push!(integrator.sol.k,integrator.saveiter_dense,integrator.k)
        else
          copyat_or_push!(integrator.sol.k,integrator.saveiter_dense,[k[integrator.opts.save_idxs] for k in integrator.k],Val{false})
        end
      end
    end
    if typeof(integrator.alg) <: OrdinaryDiffEqCompositeAlgorithm
      copyat_or_push!(integrator.sol.alg_choice,integrator.saveiter,integrator.cache.current)
    end
  end
  resize!(integrator.k,integrator.kshortsize)
end

@inline function postamble!(integrator)
  solution_endpoint_match_cur_integrator!(integrator)
  resize!(integrator.sol.t,integrator.saveiter)
  resize!(integrator.sol.u,integrator.saveiter)
  resize!(integrator.sol.k,integrator.saveiter_dense)
  !(typeof(integrator.prog)<:Void) && Juno.done(integrator.prog)
end

@inline function solution_endpoint_match_cur_integrator!(integrator)
  if integrator.sol.t[integrator.saveiter] !=  integrator.t
    integrator.saveiter += 1
    copyat_or_push!(integrator.sol.t,integrator.saveiter,integrator.t)
    if integrator.opts.save_idxs == nothing
      copyat_or_push!(integrator.sol.u,integrator.saveiter,integrator.u)
    else
      copyat_or_push!(integrator.sol.u,integrator.saveiter,integrator.u[integrator.opts.save_idxs],Val{false})
    end
    if typeof(integrator.alg) <: Discrete || integrator.opts.dense
      integrator.saveiter_dense +=1
      copyat_or_push!(integrator.notsaveat_idxs,integrator.saveiter_dense,integrator.saveiter)
      if integrator.opts.dense
        if integrator.opts.save_idxs == nothing
          copyat_or_push!(integrator.sol.k,integrator.saveiter_dense,integrator.k)
        else
          copyat_or_push!(integrator.sol.k,integrator.saveiter_dense,[k[integrator.opts.save_idxs] for k in integrator.k],Val{false})
        end
      end
    end
  end
end

@inline function stepsize_controller(integrator,cache)
  # PI-controller
  EEst,beta1,q11,qold,beta2 = integrator.EEst, integrator.opts.beta1, integrator.q11,integrator.qold,integrator.opts.beta2
  @fastmath q11 = EEst^beta1
  @fastmath q = q11/(qold^beta2)
  integrator.q11 = q11
  @fastmath q = max(inv(integrator.opts.qmax),min(inv(integrator.opts.qmin),q/integrator.opts.gamma))
  @fastmath dtnew = integrator.dt/q
end

#=
@inline function stepsize_controller(integrator,cache::Rodas4Cache)
  # Standard stepsize controller
  qtmp = integrator.EEst^(1/(alg_adaptive_order(integrator.alg)+1))/integrator.opts.gamma
  @fastmath q = max(inv(integrator.opts.qmax),min(inv(integrator.opts.qmin),qtmp))
  @fastmath dtnew = integrator.dt/q
end
=#

@inline function loopfooter!(integrator)
  if integrator.opts.adaptive
    dtnew = stepsize_controller(integrator,integrator.cache)
    ttmp = integrator.t + integrator.dt
    integrator.isout = integrator.opts.isoutofdomain(ttmp,integrator.u)
    integrator.accept_step = (!integrator.isout && integrator.EEst <= 1.0) || (integrator.opts.force_dtmin && abs(integrator.dt) <= abs(integrator.opts.dtmin))
    if integrator.accept_step # Accept
      integrator.tprev = integrator.t
      if typeof(integrator.t)<:AbstractFloat && !isempty(integrator.opts.tstops)
        tstop = top(integrator.opts.tstops)
        abs(ttmp - tstop) < 10eps(integrator.t) ? (integrator.t = tstop) : (integrator.t = ttmp)
      else
        integrator.t = ttmp
      end
      integrator.qold = max(integrator.EEst,integrator.opts.qoldinit)
      calc_dt_propose!(integrator,dtnew)
      handle_callbacks!(integrator)
    end
  else #Not adaptive
    integrator.tprev = integrator.t
    integrator.t += integrator.dt
    integrator.accept_step = true
    integrator.dtpropose = integrator.dt
    handle_callbacks!(integrator)
  end
  if !(typeof(integrator.prog)<:Void) && integrator.opts.progress && integrator.iter%integrator.opts.progress_steps==0
    Juno.msg(integrator.prog,integrator.opts.progress_message(integrator.dt,integrator.t,integrator.u))
    Juno.progress(integrator.prog,integrator.t/integrator.sol.prob.tspan[2])
  end
end

@inline function handle_callbacks!(integrator)
  discrete_callbacks = integrator.opts.callback.discrete_callbacks
  continuous_callbacks = integrator.opts.callback.continuous_callbacks
  atleast_one_callback = false

  continuous_modified = false
  discrete_modified = false
  saved_in_cb = false
  if !(typeof(continuous_callbacks)<:Tuple{})
    time,upcrossing,idx,counter = find_first_continuous_callback(integrator,continuous_callbacks...)
    if time != zero(typeof(integrator.t)) && upcrossing != 0 # if not, then no events
      continuous_modified,saved_in_cb = apply_callback!(integrator,continuous_callbacks[idx],time,upcrossing)
    end
  end
  if !(typeof(discrete_callbacks)<:Tuple{})
    discrete_modified,saved_in_cb = apply_discrete_callback!(integrator,discrete_callbacks...)
  end
  if !saved_in_cb
    savevalues!(integrator)
  end

  integrator.u_modified = continuous_modified || discrete_modified
  if integrator.u_modified
    handle_callback_modifiers!(integrator)
  end
end

@inline function handle_callback_modifiers!(integrator::ODEIntegrator)
  integrator.reeval_fsal = true
end

@inline function apply_step!(integrator)

  integrator.accept_step = false # yay we got here, don't need this no more

  #Update uprev
  if alg_extrapolates(integrator.alg)
    if isinplace(integrator.sol.prob)
      recursivecopy!(integrator.uprev2,integrator.uprev)
    else
      integrator.uprev2 = integrator.uprev
    end
  end
  if isinplace(integrator.sol.prob)
    recursivecopy!(integrator.uprev,integrator.u)
  else
    integrator.uprev = integrator.u
  end

  #Update dt if adaptive or if fixed and the dt is allowed to change
  if integrator.opts.adaptive || integrator.dtchangeable
    integrator.dt = integrator.dtpropose
  elseif integrator.dt != integrator.dtpropose && !integrator.dtchangeable
    error("The current setup does not allow for changing dt.")
  end

  # Update fsal if needed
  if isfsal(integrator.alg)
    if !isempty(integrator.opts.d_discontinuities) && top(integrator.opts.d_discontinuities) == integrator.t
      pop!(integrator.opts.d_discontinuities)
      reset_fsal!(integrator)
    elseif integrator.reeval_fsal || (typeof(integrator.alg)<:DP8 && !integrator.opts.calck) || (typeof(integrator.alg)<:Union{Rosenbrock23,Rosenbrock32} && !integrator.opts.adaptive)
      reset_fsal!(integrator)
    else # Do not reeval_fsal, instead copy! over
      if isinplace(integrator.sol.prob)
        recursivecopy!(integrator.fsalfirst,integrator.fsallast)
      else
        integrator.fsalfirst = integrator.fsallast
      end
    end
  end
end



@inline function calc_dt_propose!(integrator,dtnew)
  integrator.dtpropose = integrator.tdir*min(abs(integrator.opts.dtmax),abs(dtnew))
  integrator.dtpropose = integrator.tdir*max(abs(integrator.dtpropose),abs(integrator.opts.dtmin))
end

@inline function fix_dt_at_bounds!(integrator)
  if integrator.tdir > 0
    integrator.dt = min(integrator.opts.dtmax,integrator.dt)
  else
    integrator.dt = max(integrator.opts.dtmax,integrator.dt)
  end
  if integrator.tdir > 0
    integrator.dt = max(integrator.dt,integrator.opts.dtmin) #abs to fix complex sqrt issue at end
  else
    integrator.dt = min(integrator.dt,integrator.opts.dtmin) #abs to fix complex sqrt issue at end
  end
end

@inline function handle_tstop!(integrator)
  tstops = integrator.opts.tstops
  if !isempty(tstops)
    t = integrator.t
    ts_top = top(tstops)
    if t == ts_top
      pop!(tstops)
      integrator.just_hit_tstop = true
    elseif integrator.tdir*t > integrator.tdir*ts_top
      if !integrator.dtchangeable
        change_t_via_interpolation!(integrator, pop!(tstops), Val{true})
        integrator.just_hit_tstop = true
      else
        error("Something went wrong. Integrator stepped past tstops but the algorithm was dtchangeable. Please report this error.")
      end
    end
  end
end

@inline function reset_fsal!(integrator)
  # Under these condtions, these algorithms are not FSAL anymore
  if typeof(integrator.cache) <: OrdinaryDiffEqMutableCache
    integrator.f(integrator.t,integrator.u,integrator.fsalfirst)
  else
    integrator.fsalfirst = integrator.f(integrator.t,integrator.u)
  end
  integrator.reeval_fsal = false
end

function (integrator::ODEIntegrator)(t,deriv::Type=Val{0};idxs=nothing)
  current_interpolant(t,integrator,idxs,deriv)
end

(integrator::ODEIntegrator)(val::AbstractArray,t::Union{Number,AbstractArray},deriv::Type=Val{0};idxs=nothing) = current_interpolant!(val,t,integrator,idxs,deriv)
