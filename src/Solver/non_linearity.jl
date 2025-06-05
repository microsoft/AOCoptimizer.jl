#=
non_linearity.jl

Implements efficient methods to apply non-linearity functions
to arrays.

This file provides implementations that wrap the element-wise
functions of non-linearity functions like `sign`, `tanh`, and
`binary` to work on arrays. It provides reasonable implementations
for CPU and GPU backends (using `KernelAbstractions.jl`).
For backend-specific implementations (e.g., CUDA), the
corresponding code is implemented in the `ext/CUDAExt/non_linearity.jl`
file---a similar approach should be followed for other backends
that require specific implementations.
=#

#=
If CUDA is not available, we just return an empty block and
do not generate any CUDA-specific code.
The actual implementation of the CUDA-specific code is in
the `ext/CUDAExt/non_linearity.jl` file.
=#
function _cuda_non_linearity_extension_code(::BackendExtension, fn_name, fn)
    return Expr(:block)  # default empty block
end

macro make_non_linearity(
    # Name of the generated function
    name::AbstractString,

    # Function to apply
    # Function T -> T, where T <: Real
    fn,
)

    # Generate the function name
    fn_name = Symbol(name, "!")
    kernel_name = Symbol(name, "_kernel", "!")

    extra_cuda_code = _cuda_non_linearity_extension_code(BackendCuda(), fn_name, fn)

    # Create the function
    quote
        @inline function $(esc(kernel_name))(x::AbstractArray)
            I = @index(Global)
            @inbounds x[I] = $fn(x[I])
            return
        end

        @inline function $(esc(fn_name))(backend::Backend, x::AbstractArray)
            kernel = $(esc(kernel_name))(backend)
            kernel(x, ndrange = size(x))
            synchronize(backend)
            return nothing
        end

        @inline function $(esc(fn_name))(kernel::KernelAbstractions.Kernel, x::AbstractArray)
            kernel(x, ndrange = size(x))
            synchronize(backend)
            return nothing
        end

        @inline function $(esc(fn_name))(::CPU, x::AbstractArray)
            @simd for index in eachindex(x)
                @inbounds x[index] = $fn(x[index])
            end
            return nothing
        end

        @inline function $(esc(fn_name))(x::AbstractArray)
            backend = get_backend(x)
            $(esc(fn_name))(backend, x)
            return nothing
        end

        $extra_cuda_code
    end

end #macro

#=
Since we do not control the order of package loading,
we need to delay creating the non-linearities until
the end to make sure that specific implementations
(e.g., for CUDA) are available.

Hence, the approach is to create a list of all non-linearities
and then create them much later. Unfortunately, the user
must explicitly initialize the package to make them available.
The user must not call `__register_non_linearities` directly,
and, instead, should call `AOCoptimizer.init()`.
=#

const __NON_LINEARITIES = []
const __NON_LINEARITIES_LOCK = Threads.SpinLock()
const __NON_LINEARITY_MACROS_EXPANDED = Ref(false)

function __register_non_linearities()
    if __NON_LINEARITY_MACROS_EXPANDED[]
        return
    end

    lock(__NON_LINEARITIES_LOCK)
    if __NON_LINEARITY_MACROS_EXPANDED[]
		unlock(__NON_LINEARITIES_LOCK)
        return
    end

    try
        for (name, fn) in __NON_LINEARITIES
            @eval @make_non_linearity($name, $fn)
        end

        __NON_LINEARITY_MACROS_EXPANDED[] = true
    catch err
        @error "Failed to register non-linearities. Ensure that the non-linearity functions are defined correctly."
        @error "Error: $err"
        @error "Stacktrace: $(catch_backtrace())"
        return
    finally
        unlock(__NON_LINEARITIES_LOCK)
    end
end

"""
    _non_linearity_sign!(x::AbstractArray{T,N}) where {T<:Real,N}

In-place application of the sign function element-wise to the array `x`.
"""
function _non_linearity_sign! end

"""
    _non_linearity_tanh!(x::AbstractArray{T,N}) where {T<:Real,N}

In-place application of the sign function element-wise to the array `x`.
"""
function _non_linearity_tanh! end

"""
    _non_linearity_binary!(x::AbstractArray{T,N}) where {T<:Real,N}

In-place application of the function `x -> (x>0.5)?1.0:0.0`
element-wise to the array `x`.
"""
function _non_linearity_binary! end

push!(__NON_LINEARITIES, ("_non_linearity_sign", sign))
push!(__NON_LINEARITIES, ("_non_linearity_tanh", tanh))

push!(__NON_LINEARITIES, ("_non_linearity_binary", x -> begin
    if (x > 0.5)
        one(x)
    else
        zero(x)
    end
end))
