
#=
CUDAExt.jl

CUDA specific extensions to the `AOCoptimizer.jl` package.
=#

module CUDAExt

import CUDA
import AOCoptimizer

function AOCoptimizer.hamiltonian(matrix::CuArray, x::CuVector)
    y = x' * matrix
    return -mapreduce(*, +, y, x; init = 0.0) / 2
end

end # module CUDAExt