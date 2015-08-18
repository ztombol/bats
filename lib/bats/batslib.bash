#
# batslib.bash
# ------------
#
# The Standard Library is a collection of test helpers intended to
# simplify testing. It contains the following types of test helpers.
#
#   - Assertions are functions that perform a test and output relevant
#     information on failure to help debugging. They return 1 on failure
#     and 0 otherwise.
#
# All output is formatted for readability using the functions of
# `output.bash' and sent to the standard error.
#

source "${BATS_LIB}/batslib/output.bash"


########################################################################
#                               ASSERTIONS
########################################################################

# Fail and display an error message. The message is specified either by
# positional parameters or on the standard input (by piping or
# redirection).
#
# Globals:
#   none
# Arguments:
#   $@ - [opt = STDIN] message to display
# Returns:
#   1 - always
# Inputs:
#   STDIN - [opt = $@] message to display
# Outputs:
#   STDERR - error message
flunk() {
  (( $# == 0 )) && batslib_err || batslib_err "$@"
  return 1
}

# Fail and display the given condition if it evaluates to false. Only
# simple commands can be used in the expression given to `assert'.
# Compound commands, such as `[[', are not supported.
#
# Globals:
#   none
# Arguments:
#   $@ - condition to evaluate
# Returns:
#   0 - condition evaluated to TRUE
#   1 - condition evaluated to FALSE
# Outputs:
#   STDERR - failed condition, on failure
assert() {
  if ! "$@"; then
    echo "condition : $@" | batslib_decorate 'assertion failed' | flunk
  fi
}

# Fail and display an error message if the two parameters, expected and
# actual value respectively, do not equal. The error message contains
# both parameters.
#
# Globals:
#   none
# Arguments:
#   $1 - expected value
#   $2 - actual value
# Returns:
#   0 - expected equals actual value
#   1 - otherwise
# Outputs:
#   STDERR - expected and actual value, on failure
assert_equal() {
  if [[ $1 != "$2" ]]; then
    batslib_print_kv_single_or_multi 8 \
        'expected' "$1" \
        'actual'   "$2" \
      | batslib_decorate 'values do not equal' \
      | flunk
  fi
}

# Fail and display an error message if the expected output does not
# match the actual output. The expected output can be specified either
# by the first parameter or on the standard input.
#
# By default, `$output' is compared against the expected output, and the
# error message contains both values.
#
# When `-l' is used, the <index>-th element of `${lines[@]}' is
# compared. On failure, the error message contains the line index, and
# the expected and actual line at the given index.
#
# When `-L' is used, the test passes if `${lines[@]}' contains the
# expected line. On failure, the expected line and `$output' are
# displayed.
#
# Globals:
#   output
#   lines
# Options:
#   -l <index> - match against the <index>-th element of `$lines'
#   -L - pass if the expected line is found in `$output'
# Arguments:
#   $1 - [opt = STDIN] expected output/line
# Returns:
#   0 - expected matches actual output/line
#   1 - otherwise
# Inputs:
#   STDIN - [opt = $1] expected output/line
# Outputs:
#   STDERR - failure details, on failure
#            error message, on `-l' missing its <index> argument
assert_output() {
  # Local variables.
  local is_line_match=0
  local is_contained=0

  # Handle options.
  while (( $# > 0 )); do
    case "$1" in
      -l)
        if (( $# < 2 )) || ! [[ $2 =~ ^([0-9]|[1-9][0-9]+)$ ]]; then
          echo "\`-l' requires an integer argument" \
            | batslib_decorate 'ERROR: assert_output' \
            | flunk
          return "$?"
        fi
        is_line_match=1
        local -ri idx="$2"
        shift 2
        ;;
      -L) is_contained=1; shift ;;
      --) break ;;
      *) break ;;
    esac
  done

  if (( is_line_match )) && (( is_contained )); then
    echo "\`-l' and \`-L' are mutually exclusive" \
      | batslib_decorate 'ERROR: assert_output' \
      | flunk
    return "$?"
  fi

  # Arguments.
  local expected
  (( $# == 0 )) && expected="$(cat -)" || expected="$1"

  # Matching.
  if (( is_contained )); then
    # Line contained in output.
    local temp_line
    for temp_line in "${lines[@]}"; do
      [[ $temp_line == "$expected" ]] && return 0
    done
    { local -ar single=(
        'line'   "$expected"
      )
      local -ar may_be_multi=(
        'output' "$output"
      )
      local -ir width="$( batslib_get_max_single_line_key_width \
                          "${single[@]}" "${may_be_multi[@]}" )"
      batslib_print_kv_single "$width" "${single[@]}"
      batslib_print_kv_single_or_multi "$width" "${may_be_multi[@]}"
    } | batslib_decorate 'line is not in output' \
      | flunk
  elif (( is_line_match )); then
    # Specific line.
    if [[ ${lines[$idx]} != "$expected" ]]; then
      batslib_print_kv_single 8 \
          'index'    "$idx" \
          'expected' "$expected" \
          'actual'   "${lines[$idx]}" \
        | batslib_decorate 'line differs' \
        | flunk
    fi
  else
    # Entire output.
    if [[ $output != "$expected" ]]; then
      batslib_print_kv_single_or_multi 8 \
          'expected' "$expected" \
          'actual'   "$output" \
        | batslib_decorate 'output differs' \
        | flunk
    fi
  fi
}

# Fail and display an error message if `$status' is not 0. The error
# message contains `$status' and `$output'.
#
# Globals:
#   status
#   output
# Arguments:
#   none
# Returns:
#   0 - `$status' is 0
#   1 - otherwise
# Outputs:
#   STDERR - `$status' and `$output', if `$status' is not 0
assert_success() {
  if (( status != 0 )); then
    { local -ir width=6
      batslib_print_kv_single "$width" 'status' "$status"
      batslib_print_kv_single_or_multi "$width" 'output' "$output"
    } | batslib_decorate 'command failed' \
      | flunk
  fi
}

# Fail and display `$output' if `$status' is 0. Additionally, if the
# expected status is specified in the first parameter, fail if it does
# not equal `$status'. In this case, display both values and `$output'.
#
# Globals:
#   status
#   output
# Arguments:
#   $1 - [opt] expected exit status
# Returns:
#   0 - $status is not 0, and optionally expected and actual `$status'
#       equals
#   1 - otherwise
# Outputs:
#   STDERR - `$output', if `$status' is 0
#            `$output', `$status' and expected status, if the latter two
#            do not equal
assert_failure() {
  (( $# > 0 )) && local -r expected="$1"
  if (( status == 0 )); then
    batslib_print_kv_single_or_multi 6 'output' "$output" \
      | batslib_decorate 'command succeeded, but it was expected to fail' \
      | flunk
  elif (( $# > 0 )) && (( status != expected )); then
    { local -ir width=8
      batslib_print_kv_single "$width" \
          'expected' "$expected" \
          'actual'   "$status"
      batslib_print_kv_single_or_multi "$width" \
          'output' "$output"
    } | batslib_decorate 'command failed as expected, but status differs' \
      | flunk
  fi
}

# Fail and display an error message if `${lines[@]}' contains the given
# line.  The error message contains the unexpected line, its index in
# `$output', and `$output'.
#
# Optionally, if two positional parameters are specified, the unexpected
# line is only sought in the line whose index is given in the first
# parameter. In this case, the error message contains the line index,
# and the unexpected line.
#
# Globals:
#   lines
#   output
# Arguments:
#   $1 - [opt] zero-based index of line to match against
#   $2 - line to look for
# Returns:
#   0 - line not found
#   1 - otherwise
# Outputs:
#   STDERR - unexpected line, its index and `$output', on failure
#            index and unexpected line, on failure
refute_line() {
  if (( $# > 1 )); then
    local -ir idx="$1"
    local -r line="$2"

    if [[ ${lines[$idx]} == "$line" ]]; then
      batslib_print_kv_single 5 \
          'index' "$idx" \
          'line'  "$line" \
        | batslib_decorate 'line should differ from expected' \
        | flunk
    fi
  else
    local -r line="$1"

    local idx
    for (( idx = 0; idx < ${#lines[@]}; ++idx )); do
      if [[ ${lines[$idx]} == "$line" ]]; then
        { local -ar single=(
            'line'   "$line"
            'index'  "$idx"
          )
          local -a may_be_multi=(
            'output' "$output"
          )
          local -ir width="$( batslib_get_max_single_line_key_width \
                              "${single[@]}" "${may_be_multi[@]}" )"
          batslib_print_kv_single "$width" "${single[@]}"
          if batslib_is_single_line "${may_be_multi[1]}"; then
            batslib_print_kv_single "$width" "${may_be_multi[@]}"
          else
            may_be_multi[1]="$( printf '%s' "${may_be_multi[1]}" \
                                  | batslib_prefix \
                                  | batslib_mark '>' "$idx" )"
            batslib_print_kv_multi "${may_be_multi[@]}"
          fi
        } | batslib_decorate 'line should not be in output' \
          | flunk
        return 1
      fi
    done
  fi
}
