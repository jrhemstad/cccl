//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

// UNSUPPORTED: msvc
// UNSUPPORTED: nvrtc

// <utility>

// template <class T1, class T2> struct pair

// template<class U, class V> pair& operator=(const pair<U, V>& p);

#include <cuda/std/utility>
#include <cuda/std/cassert>

#include "test_macros.h"
#include "archetypes.h"

int main(int, char**)
{
    {
        typedef cuda::std::pair<int, short> P1;
        typedef cuda::std::pair<double, long> P2;
        P1 p1(3, static_cast<short>(4));
        P2 p2;
        p2 = p1;
        assert(p2.first == 3);
        assert(p2.second == 4);
    }
    {
       using C = TestTypes::TestType;
       using P = cuda::std::pair<int, C>;
       using T = cuda::std::pair<long, C>;
       const T t(42, -42);
       P p(101, 101);
       C::reset_constructors();
       p = t;
       assert(C::constructed() == 0);
       assert(C::assigned() == 1);
       assert(C::copy_assigned() == 1);
       assert(C::move_assigned() == 0);
       assert(p.first == 42);
       assert(p.second.value == -42);
    }

  return 0;
}
