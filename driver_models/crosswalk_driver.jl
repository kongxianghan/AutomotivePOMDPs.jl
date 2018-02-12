# croswalk driver
@with_kw mutable struct CrosswalkDriver <: DriverModel{LonAccelDirection}
    a::LonAccelDirection = LonAccelDirection(0., 1)
    navigator::RouteFollowingIDM = RouteFollowingIDM()
    crosswalk::Lane = Lane()
    intersect::Lane = Lane()
    ped_model::ConstantPedestrian = ConstantPedestrian()
    ped_start::Float64 = 4.0 # assume a 5meter buffer before a pedestrian reaches the road
    stop_delta::Float64 = 0.0
    accel_tol::Float64 = 0.1

    #states
    go::Bool = false
    stop::Bool = false

    # transition
    clear::Bool = false
end

AutomotiveDrivingModels.get_name(::CrosswalkDriver) = "CrosswalkDriver"
Base.rand(model::CrosswalkDriver) = model.a

function AutomotiveDrivingModels.reset_hidden_state!(model::CrosswalkDriver)
    model.go = false
    model.stop = false
    model
end

function AutomotiveDrivingModels.observe!(model::CrosswalkDriver, scene::Scene, roadway::Roadway, egoid::Int)
    ego = scene[findfirst(scene, egoid)]
    AutomotiveDrivingModels.observe!(model.navigator, scene, roadway, egoid) # set the direction
    dir = model.navigator.dir
    a_lon =0.
    a_lon_idm = model.navigator.a
    if model.go
        a_lon = a_lon_idm
    else
        update_clear!(model, ego, scene, roadway)
        if model.clear
            model.go = true
        else # brake!
            d = dist_to_stop(model, ego, roadway)
            println("braking! d = ", d)
            a_lon = min(a_lon_idm, stop_at_dist(model, ego, d))
        end
    end
    println("veh ", egoid, " go ", model.go, " stop ", model.stop, " clear ", model.clear)
    model.a = LonAccelDirection(a_lon, dir)
end


function update_clear!(model::CrosswalkDriver, ego::Vehicle, scene::Scene, roadway::Roadway)
    # check how many pedestrians are present
    peds = Vehicle[]
    for veh in scene
        if veh.def.class == AgentClass.PEDESTRIAN && get_lane(roadway, veh) == model.crosswalk
            push!(peds, veh)
        end
    end
    cw_length = get_end(model.crosswalk)
    cw_center = get_posG(Frenet(model.crosswalk, cw_length/2), roadway)
    # set to the maximum value
    buffer_ped = VehicleState(Frenet(model.crosswalk, model.ped_start), roadway,
                              model.ped_model.v_desired)
    # println("compute time ped")
    min_ped_ttc = compute_time_of_approach(model, cw_center, buffer_ped, roadway, -model.intersect.width/2)
    println("buffer ped ttc ", min_ped_ttc)
    ego_ttc = compute_time_of_approach(model, cw_center, ego.state, roadway,
                                       +model.crosswalk.width/2 + ego.def.length/2)
    println("ego ttc ", ego_ttc)
    for ped in peds
        ttc = compute_time_of_approach(model, cw_center, ped.state, roadway, model.intersect.width/2)
        if ttc < min_ped_ttc
            min_ped_ttc = ttc
        end
    end
    println("min ped ttc ", min_ped_ttc)
    has_crossed = -0.5*model.intersect.width/model.ped_model.v_desired
    println("has_crossed ttc", has_crossed)
    if has_crossed < min_ped_ttc < ego_ttc
        model.clear = false
    else
        model.clear = true
    end
end

"""
compute the time to reach the projection of cw on the ego lane
"""
function compute_time_of_approach(model::CrosswalkDriver, cw::VecSE2, ego::VehicleState, roadway::Roadway, delta::Float64=0.)
    lane = get_lane(roadway, ego)
    cw_proj = Frenet(cw, lane, roadway)
    Δs = cw_proj.s - ego.posF.s + delta
    # println("lane ", lane)
    # println("cw_proj ", cw_proj.s)
    # println("delta ", delta)
    # println("ego posF", ego.posF.s)
    # println("ds ", Δs)
    time_of_approach = Δs/ego.v
end

function dist_to_stop(model::CrosswalkDriver, ego::Vehicle, roadway::Roadway)
    cw_length = get_end(model.crosswalk)
    cw_center = get_posG(Frenet(model.crosswalk, cw_length/2), roadway)
    intersect_pt = Frenet(cw_center, model.intersect, roadway)
    return intersect_pt.s - model.crosswalk.width/2
end