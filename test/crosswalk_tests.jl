using POMDPs
using Random
using POMDPSimulators
using RLInterface
using BeliefUpdaters
using POMDPPolicies

@testset begin "crosswalk"
    rng = MersenneTwister(1)

    pomdp = OCPOMDP(ΔT = 0.5, p_birth = 0.3, max_peds = 1)

    env = KMarkovEnvironment(pomdp, k=4)

    up = KMarkovUpdater(4)

    policy = RandomPolicy(pomdp, rng=rng)

    hr = HistoryRecorder(rng=rng, max_steps = 100)
    s0 = initialstate(pomdp, rng)
    initial_observation = generate_o(pomdp, s0, rng)
    initial_obs_vec = fill(initial_observation, 4)
    hist = simulate(hr, pomdp, policy, up, initial_obs_vec, s0)

    @test n_steps(hist) > 1
end