//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// SPDX-FileCopyrightText: Copyright (c) 2023 NVIDIA CORPORATION & AFFILIATES.
//
//===----------------------------------------------------------------------===//


// <complex>

// template<Arithmetic T>
//   T
//   norm(T x); // constexpr in C++20

#include <complex>
#include <type_traits>
#include <cassert>

#include "test_macros.h"
#include "../cases.h"

template <class T>
TEST_CONSTEXPR_CXX20
void
test(T x, typename std::enable_if<std::is_integral<T>::value>::type* = 0)
{
    static_assert((std::is_same<decltype(std::norm(x)), double>::value), "");
    assert(std::norm(x) == norm(std::complex<double>(static_cast<double>(x), 0)));
}

template <class T>
TEST_CONSTEXPR_CXX20
void
test(T x, typename std::enable_if<!std::is_integral<T>::value>::type* = 0)
{
    static_assert((std::is_same<decltype(std::norm(x)), T>::value), "");
    assert(std::norm(x) == norm(std::complex<T>(x, 0)));
}

template <class T>
TEST_CONSTEXPR_CXX20
bool
test()
{
    test<T>(0);
    test<T>(1);
    test<T>(10);
    return true;
}

int main(int, char**)
{
    test<float>();
    test<double>();
    test<long double>();
    test<int>();
    test<unsigned>();
    test<long long>();

#if TEST_STD_VER >= 20
    static_assert(test<float>());
    static_assert(test<double>());
    static_assert(test<long double>());
    static_assert(test<int>());
    static_assert(test<unsigned>());
    static_assert(test<long long>());
#endif

    return 0;
}
