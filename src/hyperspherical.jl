############################## hyper-spherical harmonics #######################
# according to "HYPERSPHERICAL HARMONICS" book equation 3-69
# x are assumed to be in hyper-spherical coordinates:
# x = [r, θ_1, θ_2, ..., θ_{d-2}, φ]
# k (i.e. λ) is order
# h is multi-index
function hyperspherical(x::AbstractVector, k::Int, h::AbstractVector{<:Int}, normalized::Val{true} = Val(true))
    μ = get_μ(k, h)
    hyperspherical(x, get_μ(k, h), h[end], Val(false)) / hyper_normalizer(μ)
end


function hyperspherical(hyp::AbstractVector{<:Real}, k::Int, h::AbstractVector{<:Int}, normalized::Val{false})
    μ = @MVector zeros(Int, length(h) + 1)
    μ[1] = k
    μ[2:end] .= h
    μ[end] = abs(μ[end])
    m = h[end]
    d = length(hyp)
    α(j) = (d-j-1) / 2

    prod_gegen = one(hyp[1]) # product of gegenbauer polynomials
    for j in 1:d-2 # IDEA: @simd
        sinθ_j, cosθ_j = sincos(hyp[j+1])
        prod_gegen *= gegenbauer(α(j) + μ[j+1], μ[j] - μ[j+1], cosθ_j) * sinθ_j^μ[j+1] # IDEA pre-calculate gegenbauer for all relevant α, n, cosθ
    end
    if m > 0 return sqrt(2) * ((-1)^m) * prod_gegen * cos(m * hyp[end]) end
    if m < 0 return sqrt(2) * ((-1)^m) * prod_gegen * sin(-m * hyp[end]) end
    return prod_gegen
end


function get_μ(k::Int, h::AbstractVector)
    μ = @MVector zeros(Int, length(h) + 1)
    μ[1] = k
    μ[2:end] .= h
    μ[end] = abs(μ[end])
    return μ
end

# helper for un-normalized polynomials
# m is last element of multiindex
# x is in hyper-spherical coordinates
# function hyperspherical(x::AbstractVector{<:Real}, μ::AbstractVector{Int}, m::Int, normalized::Val{false})
#     # r, θ, φ = unpack_hyperspherical(x) # unpacking hyper-spherical coordinates
#     # hyperspherical(r, θ, φ, μ, m, normalized)
#     hyperspherical(x, μ, m, normalized)
# end
#
# function hyperspherical(r::Real, θ::AbstractVector{<:Real}, φ::Real,
#                         μ::AbstractVector{Int}, m::Int, normalized::Val{false})
#     d = length(θ) + 2
#     α(j) = (d-j-1) / 2
#     prod_gegen = one(r) # product of gegenbauer polynomials
#     for j in 1:d-2 # IDEA: @simd
#         sinθ_j, cosθ_j = sincos(θ[j])
#         prod_gegen *= gegenbauer(α(j) + μ[j+1], μ[j] - μ[j+1], cosθ_j) * sinθ_j^μ[j+1] # IDEA pre-calculate gegenbauer for all relevant α, n, cosθ
#     end
#     if m > 0 return sqrt(2) * ((-1)^m) * prod_gegen * cos(m * φ) end
#     if m < 0 return sqrt(2) * ((-1)^m) * prod_gegen * sin(-m * φ) end
#     return prod_gegen
# end

function hyperspherical(hyp::AbstractVector{<:Real},
                        μ::AbstractVector{Int}, m::Int, normalized::Val{false})
    d = length(hyp)
    α(j) = (d-j-1) / 2
    prod_gegen = one(hyp[1]) # product of gegenbauer polynomials
    for j in 1:d-2 # IDEA: @simd
        sinθ_j, cosθ_j = sincos(hyp[j+1])
        prod_gegen *= gegenbauer(α(j) + μ[j+1], μ[j] - μ[j+1], cosθ_j) * sinθ_j^μ[j+1] # IDEA pre-calculate gegenbauer for all relevant α, n, cosθ
    end
    if m > 0 return sqrt(2) * ((-1)^m) * prod_gegen * cos(m * hyp[end]) end
    if m < 0 return sqrt(2) * ((-1)^m) * prod_gegen * sin(-m * hyp[end]) end
    return prod_gegen
end


# 2re(exp(1im * m * (φ1+φ2))) = 2cos(φ1+φ2) = 2cos(φ1)cos(φ2) - 2sin(φ1)sin(φ2)

function squared_hyper_normalizer_table(dimension::Int, trunc_param::Int)
    table = hyper_normalizer_table(dimension, trunc_param)
    @. table ^= 2
end
function hyper_normalizer_table(dimension::Int, trunc_param::Int)
    table = zeros(trunc_param+1, max_num_multiindices(dimension, trunc_param))
    for (k_idx, k) in enumerate(0:trunc_param)
        multiindices = get_multiindices(dimension, k)
        for (h_idx, h) in enumerate(multiindices)
            h[end] = abs(h[end])
            table[k_idx, h_idx] = hyper_normalizer(k, h)
        end
    end
    return table
end

# normalizing coefficient for hyper-spherical harmonics
# h is multiindex
hyper_normalizer(k::Int, h::AbstractVector) = hyper_normalizer(get_μ(k, h))
function hyper_normalizer(μ::AbstractVector)
    μ[end] ≥ 0 || throw(DomainError("last element of μ is negative: $(μ[end])"))
    d = length(μ) + 1
    N2 = 2π
    for j in 1:(d-2)
        α_j = (d-j-1)/2
        numer = (sqrt(π)
                *gamma(α_j + μ[j+1] + (1/2))
                *(α_j + μ[j+1])
                *factorial(big((d-j-1) + μ[j] + μ[j+1] - 1)))
        denom = (gamma(α_j + μ[j+1] + 1)
                *factorial(big(μ[j] - μ[j+1]))
                *(α_j + μ[j])
                *factorial(big((d-j-1) + 2μ[j+1] - 1)))
        N2 *= (numer/denom)
    end
    return sqrt(N2)
end

################################ coordinates ###################################
# assumes x is in hyper-spherical coordinates
# separates radius r and angles θ, φ
function unpack_hyperspherical(x::AbstractVector{<:Real})
    r, θ, φ = x[1], @view(x[2:end-1]), x[end] # unpacking hyper-spherical coordinates
end

# cartesian to hyper-spherical coordinates
cart2hyp(pt::AbstractVector{<:Real}) = cart2hyp!(similar(pt), pt)
function cart2hyp!(pt_hyp::AbstractVector{<:Real}, pt::AbstractVector{<:Real})
    d = length(pt)
    pt_hyp[1] = norm(pt)
    for i in 2:(d-1)
        pt_hyp[d-i+1] = @views atan(norm(pt[1:i]), pt[i+1])
    end
    pt_hyp[d] = @views 2*atan(pt[2], pt[1] + norm(pt[1:2]))
    return pt_hyp
end

hyp2cart(hyp::AbstractVector{<:Real}) = hyp2cart!(similar(hyp), hyp)
function hyp2cart!(cart::AbstractVector{<:Real}, hyp::AbstractVector{<:Real})
    d = length(hyp)
    r, θ, φ = unpack_hyperspherical(hyp)
    prod_sin_r = r # product of sines times r
    for (i, j) in enumerate(reverse(3:d))
        cart[j] = prod_sin_r * cos(θ[i])
        prod_sin_r *= sin(θ[i])
    end
    cart[1] = prod_sin_r * cos(φ)
    cart[2] = prod_sin_r * sin(φ)
    return cart
end

################################ multi-indices #################################
# functions regarding multi-indices
function get_num_multiindices(d::Int, k::Int)
    return binomial(d+k-1, k) - binomial(d+k-3, k-2)
end


function get_multiindices(d::Int, k::Int)
    if d == 2 return [@MVector([i]) for i in 0 : (k == 0 ? 0 : 1)] end
    current_index = @MVector zeros(Int, d-2) # mutable static array
    T = typeof(current_index)
    multiindices = zeros(T, 0)
    push!(multiindices, copy(current_index))
    while true
        current_index[(d-2)] += 1
        for i in (d-2):-1:2
            if current_index[i] > current_index[i-1]
                current_index[i-1] += 1
                current_index[i] = 0
            end
        end
        if current_index[1] > k
            break
        end
        push!(multiindices, copy(current_index))
        if current_index[d-2] != 0
            current_index[d-2] *= -1
            push!(multiindices, copy(current_index))
            current_index[d-2] *= -1
        end
    end
    return multiindices # d - 2 indices, ordered, last can be neg
end

# returns the maximum number of multiindices for a given dimension and truncation parameter
function max_num_multiindices(dimension::Int, trunc_param::Int)
    d, p = dimension, trunc_param
    return binomial(p+d-1, p) - binomial(p+d-3, p-2) # maximum length of multiindices
end

# hyperspherical but in 2d
function hypospherical(x::AbstractVector, k::Int, h::AbstractVector)
    if iszero(k)
        return one(eltype(x))
    else
        return iszero(h) ? sin(k*x[2]) : cos(k*x[2])
    end
end
