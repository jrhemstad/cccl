//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// SPDX-FileCopyrightText: Copyright (c) 2023 NVIDIA CORPORATION & AFFILIATES.
//
//===----------------------------------------------------------------------===//

// UNSUPPORTED: c++03, c++11, c++14, c++17
// XFAIL: c++20
// nvbug 3885350

// template<class T>
// concept incrementable;

#include <cuda/std/iterator>

#include <cuda/std/concepts>

// clang-format off
template<cuda::std::weakly_incrementable I>
requires cuda::std::regular<I>
__host__ __device__ constexpr bool check_subsumption() {
  return false;
}

template<cuda::std::incrementable>
__host__ __device__ constexpr bool check_subsumption() {
  return true;
}
// clang-format on

static_assert(check_subsumption<int*>());

int main(int, char**)
{
  return 0;
}
