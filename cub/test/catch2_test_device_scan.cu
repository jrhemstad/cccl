/******************************************************************************
 * Copyright (c) 2023, NVIDIA CORPORATION.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the NVIDIA CORPORATION nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL NVIDIA CORPORATION BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 ******************************************************************************/

#include <cub/detail/cpp_compatibility.cuh>
#include <cub/device/device_scan.cuh>

#include <thrust/device_vector.h>
#include <thrust/host_vector.h>

#include <cstdint>

#include "catch2_test_device_reduce.cuh"
#include "catch2_test_device_scan.cuh"

// Has to go after all cub headers. Otherwise, this test won't catch unused
// variables in cub kernels.
#include "c2h/custom_type.cuh"
#include "c2h/extended_types.cuh"
#include "catch2_test_cdp_helper.h"
#include "catch2_test_helper.h"

DECLARE_CDP_WRAPPER(cub::DeviceScan::ExclusiveSum, device_exclusive_sum);
DECLARE_CDP_WRAPPER(cub::DeviceScan::ExclusiveScan, device_exclusive_scan);
DECLARE_CDP_WRAPPER(cub::DeviceScan::InclusiveSum, device_inclusive_sum);
DECLARE_CDP_WRAPPER(cub::DeviceScan::InclusiveScan, device_inclusive_scan);

// %PARAM% TEST_CDP cdp 0:1
// %PARAM% TEST_TYPES types 0:1:2:3

// List of types to test
using custom_t = c2h::custom_type_t<c2h::accumulateable_t,
                                    c2h::equal_comparable_t,
                                    c2h::lexicographical_less_comparable_t,
                                    c2h::lexicographical_greater_comparable_t>;

#if TEST_TYPES == 0
using full_type_list =
  c2h::type_list<type_pair<std::uint8_t, std::int32_t>, type_pair<std::int8_t>>;
#elif TEST_TYPES == 1
using full_type_list = c2h::type_list<type_pair<std::int32_t>, type_pair<std::uint64_t>>;
#elif TEST_TYPES == 2
using full_type_list = c2h::type_list<type_pair<uchar3>, type_pair<ulonglong4>>;
#elif TEST_TYPES == 3
// clang-format off
using full_type_list = c2h::type_list<
type_pair<custom_t>
#if TEST_HALF_T
, type_pair<half_t> // testing half
#endif
#if TEST_BF_T
, type_pair<bfloat16_t> // testing bf16
#endif
>;
// clang-format on
#endif

/**
 * @brief Input data generation mode
 */
enum class gen_data_t : int
{
  /// Uniform random data generation
  GEN_TYPE_RANDOM,
  /// Constant value as input data
  GEN_TYPE_CONST
};

CUB_TEST("Device scan works with all device interfaces", "[scan][device]", full_type_list)
{
  using params   = params_t<TestType>;
  using input_t  = typename params::item_t;
  using output_t = typename params::output_t;
  using offset_t = int32_t;

  constexpr offset_t min_items = 1;
  constexpr offset_t max_items = 1000000;

  // Generate the input sizes to test for
  const offset_t num_items = GENERATE_COPY(take(3, random(min_items, max_items)),
                                           values({
                                             min_items,
                                             max_items,
                                           }));

  // Input data generation to test
  const gen_data_t data_gen_mode = GENERATE_COPY(gen_data_t::GEN_TYPE_RANDOM,
                                                 gen_data_t::GEN_TYPE_CONST);

  // Generate input data
  thrust::device_vector<input_t> in_items(num_items);
  if (data_gen_mode == gen_data_t::GEN_TYPE_RANDOM)
  {
    c2h::gen(CUB_SEED(2), in_items);
  }
  else
  {
    input_t default_constant{};
    init_default_constant(default_constant);
    thrust::fill(in_items.begin(), in_items.end(), default_constant);
  }
  auto d_in_it = thrust::raw_pointer_cast(in_items.data());

// Skip DeviceScan::InclusiveSum and DeviceScan::ExclusiveSum tests for extended floating-point
// types because of unbounded epsilon due to pseudo associativity of the addition operation over
// floating point numbers
#if TEST_TYPES != 3
  SECTION("inclusive sum")
  {
    using op_t    = cub::Sum;
    using accum_t = cub::detail::accumulator_t<op_t, input_t, input_t>;

    // Prepare verification data
    thrust::host_vector<input_t> host_items(in_items);
    thrust::host_vector<output_t> expected_result(num_items);
    compute_inclusive_scan_reference(host_items.cbegin(),
                                     host_items.cend(),
                                     expected_result.begin(),
                                     op_t{},
                                     accum_t{});

    // Run test
    thrust::device_vector<output_t> out_result(num_items);
    auto d_out_it = thrust::raw_pointer_cast(out_result.data());
    device_inclusive_sum(d_in_it, d_out_it, num_items);

    // Verify result
    REQUIRE(expected_result == out_result);

    // Run test in-place
    CUB_IF_CONSTEXPR(std::is_same<input_t, output_t>::value)
    {
      device_inclusive_sum(d_in_it, d_in_it, num_items);

      // Verify result
      REQUIRE(expected_result == in_items);
    }
  }

  SECTION("exclusive sum")
  {
    using op_t    = cub::Sum;
    using accum_t = cub::detail::accumulator_t<op_t, input_t, input_t>;

    // Prepare verification data
    thrust::host_vector<input_t> host_items(in_items);
    thrust::host_vector<output_t> expected_result(num_items);
    compute_exclusive_scan_reference(host_items.cbegin(),
                                     host_items.cend(),
                                     expected_result.begin(),
                                     accum_t{},
                                     op_t{});

    // Run test
    thrust::device_vector<output_t> out_result(num_items);
    auto d_out_it = thrust::raw_pointer_cast(out_result.data());
    device_exclusive_sum(d_in_it, d_out_it, num_items);

    // Verify result
    REQUIRE(expected_result == out_result);

    // Run test in-place
    CUB_IF_CONSTEXPR(std::is_same<input_t, output_t>::value)
    {
      device_exclusive_sum(d_in_it, d_in_it, num_items);

      // Verify result
      REQUIRE(expected_result == in_items);
    }
  }
#endif

  SECTION("inclusive scan")
  {
    using op_t    = cub::Min;
    using accum_t = cub::detail::accumulator_t<op_t, input_t, input_t>;

    // Prepare verification data
    thrust::host_vector<input_t> host_items(in_items);
    thrust::host_vector<output_t> expected_result(num_items);
    compute_inclusive_scan_reference(host_items.cbegin(),
                                     host_items.cend(),
                                     expected_result.begin(),
                                     op_t{},
                                     cub::NumericTraits<accum_t>::Max());

    // Run test
    thrust::device_vector<output_t> out_result(num_items);
    auto d_out_it = thrust::raw_pointer_cast(out_result.data());
    device_inclusive_scan(unwrap_it(d_in_it), unwrap_it(d_out_it), op_t{}, num_items);

    // Verify result
    REQUIRE(expected_result == out_result);

    // Run test in-place
    CUB_IF_CONSTEXPR(std::is_same<input_t, output_t>::value)
    {
      device_inclusive_scan(unwrap_it(d_in_it), unwrap_it(d_in_it), op_t{}, num_items);

      // Verify result
      REQUIRE(expected_result == in_items);
    }
  }

  SECTION("exclusive scan")
  {
    using op_t    = cub::Sum;
    using accum_t = cub::detail::accumulator_t<op_t, input_t, input_t>;

    // Scan operator
    auto scan_op = unwrap_op(reference_extended_fp(d_in_it), op_t{});

    // Prepare verification data
    thrust::host_vector<input_t> host_items(in_items);
    thrust::host_vector<output_t> expected_result(num_items);
    compute_exclusive_scan_reference(host_items.cbegin(),
                                     host_items.cend(),
                                     expected_result.begin(),
                                     accum_t{},
                                     scan_op);

    // Run test
    thrust::device_vector<output_t> out_result(num_items);
    auto d_out_it = thrust::raw_pointer_cast(out_result.data());
    using init_t  = cub::detail::value_t<decltype(unwrap_it(d_out_it))>;
    device_exclusive_scan(unwrap_it(d_in_it), unwrap_it(d_out_it), scan_op, init_t{}, num_items);

    // Verify result
    REQUIRE(expected_result == out_result);

    // Run test in-place
    CUB_IF_CONSTEXPR(std::is_same<input_t, output_t>::value)
    {
      device_exclusive_scan(unwrap_it(d_in_it), unwrap_it(d_in_it), scan_op, init_t{}, num_items);

      // Verify result
      REQUIRE(expected_result == in_items);
    }
  }

  SECTION("exclusive scan with future-init value")
  {
    using op_t    = cub::Sum;
    using accum_t = cub::detail::accumulator_t<op_t, input_t, input_t>;

    // Scan operator
    auto scan_op = unwrap_op(reference_extended_fp(d_in_it), op_t{});

    // Prepare verification data
    accum_t init_value{};
    init_default_constant(init_value);
    thrust::host_vector<input_t> host_items(in_items);
    thrust::host_vector<output_t> expected_result(num_items);
    compute_exclusive_scan_reference(host_items.cbegin(),
                                     host_items.cend(),
                                     expected_result.begin(),
                                     init_value,
                                     scan_op);

    // Run test
    thrust::device_vector<output_t> out_result(num_items);
    auto d_out_it = thrust::raw_pointer_cast(out_result.data());
    using init_t  = cub::detail::value_t<decltype(unwrap_it(d_out_it))>;
    thrust::device_vector<init_t> d_initial_value(1);
    d_initial_value[0] = static_cast<init_t>(*unwrap_it(&init_value));
    auto future_init_value =
      cub::FutureValue<init_t>(thrust::raw_pointer_cast(d_initial_value.data()));
    device_exclusive_scan(unwrap_it(d_in_it),
                          unwrap_it(d_out_it),
                          scan_op,
                          future_init_value,
                          num_items);

    // Verify result
    REQUIRE(expected_result == out_result);

    // Run test in-place
    CUB_IF_CONSTEXPR(std::is_same<input_t, output_t>::value)
    {
      device_exclusive_scan(unwrap_it(d_in_it),
                            unwrap_it(d_in_it),
                            scan_op,
                            future_init_value,
                            num_items);

      // Verify result
      REQUIRE(expected_result == in_items);
    }
  }
}
