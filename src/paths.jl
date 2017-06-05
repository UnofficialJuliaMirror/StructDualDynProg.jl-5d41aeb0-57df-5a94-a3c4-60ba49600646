export AbstractPathSampler
@compat abstract type AbstractPathSampler end

function _samplepaths!(_npaths, npaths, pmf, semirandom::Bool, canmodifypmf::Bool)
    if semirandom
        sampled = 0
        for i in 1:length(pmf)
            p = pmf[i]
            n = floor(Int, p * npaths + 1e-6)
            if n > 0
                if sampled == 0 && !canmodifypmf
                    pmf = copy(pmf)
                end
                pmf[i] -= n / npaths
                _npaths[i] += n
                sampled += n
            end
        end
        if sampled < npaths
            if sampled > 0
                # sum(pmf) should be equal to (npaths - sampled) / npaths
                # since we have removed sampled / npaths
                # pmf is not modified as it could be the vector of probas
                pmf ./= (npaths - sampled) / npaths
                npaths -= sampled
            end
            _samplepaths!(_npaths, npaths, pmf, false, true)
        else
            _npaths
        end
    else
        cmf = cumsum(pmf)
        @assert isapprox(cmf[end], 1)
        cmf[end] = 1
        samples = rand(Float64, npaths)
        sort!(samples)
        i = 1
        for j in samples
            while j >= cmf[i]
                i += 1
            end
            _npaths[i] += 1
        end
        _npaths
    end
end
function _samplepaths(npaths, pmf, semirandom::Bool, canmodifypmf::Bool)
    _samplepaths!(zeros(Int, length(pmf)), npaths, pmf, semirandom, canmodifypmf)
end
infpaths(g, state) = fill(-1, nchildren(g, state))

function samplepaths(pathsampler::AbstractPathSampler, g::GraphSDDPTree, state, npaths::Vector{Int}, t, num_stages)
    npathss = Vector{Int}[similar(npaths) for i in 1:nchildren(g, state)]
    for i in 1:length(npaths)
        _npaths = samplepaths(pathsampler, g, state, npaths[i], t, num_stages)
        for c in 1:nchildren(g, state)
            npathss[c][i] = _npaths[c]
        end
    end
    npathss
end

type ProbaPathSampler <: AbstractPathSampler
    semirandom::Bool
end
function samplepaths(pathsampler::ProbaPathSampler, g::GraphSDDPTree, state, npaths::Int, t, num_stages)
    if npaths == -1
        infpaths(g, state)
    else
        _samplepaths(npaths, getprobas(g, state), pathsampler.semirandom, false)
    end
end

type NumPathsPathSampler <: AbstractPathSampler
    semirandom::Bool
end
function samplepaths(pathsampler::NumPathsPathSampler, g::GraphSDDPTree, state, npaths::Int, t, num_stages)
    if npaths == -1
        infpaths(g, state)
    else
        den = numberofpaths(g, state, t-1, num_stages)
        pmf = map(child->numberofpaths(g, child, t, num_stages) / den, children(g, state))
        _samplepaths(npaths, pmf, pathsampler.semirandom, true)
    end
end
