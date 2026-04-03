#pragma once

#include <limits>
#include <type_traits>
#include <variant>

namespace repro
{
/**
 * @brief Interface-like type that exposes enum values in docs tables.
 */
class data_place_interface
{
public:
  /**
   * @brief Ordinal values.
   */
  enum ord : int
  {
    // Triggers MDX parse issue in generated table cells:
    // "::std::numeric_limits<int>::min()"
    invalid = ::std::numeric_limits<int>::min(),
    host    = -1,
  };
};

template <typename T>
class task_dep;

template <typename T>
class logical_data
{
public:
  ///@{
  /**
   * @name Return a task_dep<T> object for reading and/or writing this logical data.
   *
   * This heading text reproduces MDX parsing of "<T>" in generated headings.
   */
  task_dep<T> read() const;
  ///@}
};

template <typename T, typename reduce_op, bool initialize>
class stackable_task_dep
{
public:
  enum : bool
  {
    // Triggers MDX parse issue in generated table cells:
    // "!::std::is_same_v<reduce_op, ::std::monostate>"
    does_work = !::std::is_same_v<reduce_op, ::std::monostate>
  };
};

template <typename T = void>
class stream_task;

template <>
class stream_task<>
{
public:
  ~stream_task() = default;
};
} // namespace repro
