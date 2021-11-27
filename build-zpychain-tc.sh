#!/usr/bin/env bash

# Function to show an informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

# Set a directory
DIR="$(pwd ...)"

# Build Info
rel_date="$(date "+%Y%m%d")" # ISO 8601 format
rel_friendly_date="$(date "+%B %-d, %Y")" # "Month day, year" format
builder_commit="$(git rev-parse HEAD)"

# Build LLVM
./build-llvm.py \
	--clang-vendor "ZpyChain" \
	--projects "clang;clang-tools-extra;compiler-rt;lld;libcxxabi;libcxx;openmp;polly" \
	--targets "ARM;AArch64;X86" \
	--defines "LLVM_PARALLEL_COMPILE_JOBS=$(nproc) LLVM_PARALLEL_LINK_JOBS=$(nproc) CMAKE_C_FLAGS=-O3 -Wno-macro-redefined -pipe -pthread -fopenmp -g0 -march=native -mtune=native CMAKE_CXX_FLAGS=-O3 -Wno-macro-redefined -pipe -pthread -fopenmp -g0 -march=native -mtune=native LLVM_BUILD_RUNTIME=ON LLVM_TOOL_OPENMP_BUILD=ON LINK_POLLY_INTO_TOOLS=ON LLVM_ENABLE_LIBCXX=ON LLVM_ENABLE_PIC=ON LLVM_ENABLE_THREADS=ON LLVM_USE_NEWPM=ON LLVM_OPTIMIZED_TABLEGEN=ON LLVM_ENABLE_LLD=ON LLVM_USE_LINKER=lld COMPILER_RT_BUILD_LIBFUZZER=ON LIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON" \
	--pgo kernel-defconfig \
	--lto full \
	--shallow-clone 2>&1 | tee build.log

# Check if the final clang binary exists or not.
[ ! -f install/bin/clang-1* ] && {
	err "Building LLVM failed ! Kindly check errors !!"
}

# Build binutils
./build-binutils.py --targets arm aarch64 x86_64

# Remove unused products
rm -fr install/include
rm -f install/lib/*.a install/lib/*.la

# Strip remaining products
for f in $(find install -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
	strip -s "${f: : -1}"
done

# Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
for bin in $(find install -mindepth 2 -maxdepth 3 -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}'); do
	# Remove last character from file output (':')
	bin="${bin: : -1}"

	echo "$bin"
	patchelf --set-rpath "$DIR/install/lib" "$bin"
done
