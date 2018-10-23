


struct DecPolicy{P <: Policy, M <: Union{MDP, POMDP}, A} <: Policy
    policy::P # the single agent policy
    problem::M # the pomdp definition
    action_map::Vector{A}
    op # the reduction operator for utiliy fusion (e.g. sum or min)
 end

function action_values(policy::DecPolicy, dec_belief::Dict)  
    return reduce(policy.op, action_values(policy.policy, b) for (_,b) in dec_belief)
 end
 
 function POMDPs.action(p::DecPolicy, b::Dict)
    vals = action_values(p, b)
    ai = indmax(vals)
    return p.action_map[ai]
 end
 
 function action_values(p::AlphaVectorPolicy, b::SparseCat)
    num_vectors = length(p.alphas)
    utilities = zeros(n_actions(p.pomdp), num_vectors)
    action_counts = zeros(n_actions(p.pomdp))
    for i = 1:num_vectors
        ai = action_index(p.pomdp, p.action_map[i])
        action_counts[ai] += 1
        utilities[ai, i] += sparse_cat_dot(p.pomdp, p.alphas[i], b)
    end
    utilities ./= action_counts
    return maximum(utilities, dims=2)
 end
 
 # perform dot product between an alpha vector and a sparse cat object
 function sparse_cat_dot(problem::POMDP, alpha::Vector{Float64}, b::SparseCat)
    val = 0.
    for (s, p) in weighted_iterator(b)
        si = state_index(problem, s)
        val += alpha[si]*p
    end
    return val
 end


 function AutomotivePOMDPs.action(policy::AlphaVectorPolicy, b::SingleOCFBelief)
    alphas = policy.alphas 
    util = zeros(n_actions(pomdp)) 
    for i=1:n_actions(pomdp)
        res = 0.0
        for (j,s) in enumerate(b.vals)
            si = state_index(pomdp, s)
            res += alphas[i][si]*b.probs[j]
        end
        util[i] = res
    end
    ihi = indmax(util)
    return policy.action_map[ihi]
end