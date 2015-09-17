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
fail() {
  (( $# == 0 )) && batslib_err || batslib_err "$@"
  return 1
}

# Fail and display an error message if the expression evaluates to
# false. The expression must be a simple command. Compound commands,
# such as `[[', can be used only when executed with `bash -c'. The error
# message contains the expression, `$status' and `$output'.
#
# Globals:
#   status
#   output
# Arguments:
#   $0 - expression to evaluate
# Returns:
#   0 - expression evaluates to TRUE
#   1 - expression evaluates to FALSE
# Outputs:
#   STDERR - assertion details, on failure
assert() {
  if ! "$@"; then
    { local -ar single=(
        'expression' "$*"
        'status'     "$status"
      )
      local -ar may_be_multi=(
        'output'     "$output"
      )
      local -ir width="$( batslib_get_max_single_line_key_width \
                            "${single[@]}" "${may_be_multi[@]}" )"
      batslib_print_kv_single "$width" "${single[@]}"
      batslib_print_kv_single_or_multi "$width" "${may_be_multi[@]}"
    } | batslib_decorate 'assertion failed' \
      | fail
  fi
}

# Fail and display details if the expected and actual values do not
# equal. Details include both values.
#
# Globals:
#   none
# Arguments:
#   $1 - actual value
#   $2 - expected value
# Returns:
#   0 - values equal
#   1 - otherwise
# Outputs:
#   STDERR - details, on failure
assert_equal() {
  if [[ $1 != "$2" ]]; then
    batslib_print_kv_single_or_multi 8 \
        'expected' "$2" \
        'actual'   "$1" \
      | batslib_decorate 'values do not equal' \
      | fail
  fi
}

# Fail and display an error message if the expected does not match the
# actual output.
#
# By default, the expected output is compared against `$output', and the
# error message contains both values.
#
# Option `-l <index>' compares against `${lines[<index>]}'. The error
# message contains the compared lines and <index>.
#
# Option `-l' without `<index>' compares against all lines in
# `${lines[@]}' until a match is found. If no match is found, the
# function fails and the error message contains the expected line and
# `$output'.
#
# By default, literal matching is performed. Option `-p' and `-r' change
# this to partial (substring) and regular expression (extended)
# matching, respectively.
#
# Globals:
#   output
#   lines
# Options:
#   -l <index> - match against the <index>-th element of `${lines[@]}'
#   -l - match against all elements of `${lines[@]}' until one matches
#   -p - substring match
#   -r - extended regular expression match
# Arguments:
#   $1 - expected output
# Returns:
#   0 - expected matches the actual output
#   1 - otherwise
# Outputs:
#   STDERR - assertion details, on failure
#            error message, on error
assert_output() {
  local -i is_match_line=0
  local -i is_match_contained=0
  local -i is_mode_partial=0
  local -i is_mode_regex=0

  # Handle options.
  while (( $# > 0 )); do
    case "$1" in
      -l)
        if (( $# > 2 )) && [[ $2 =~ ^([0-9]|[1-9][0-9]+)$ ]]; then
          is_match_line=1
          local -ri idx="$2"
          shift
        else
          is_match_contained=1;
        fi
        shift
        ;;
      -p) is_mode_partial=1; shift ;;
      -r) is_mode_regex=1; shift ;;
      --) break ;;
      *) break ;;
    esac
  done

  if (( is_match_line )) && (( is_match_contained )); then
    echo "\`-l' and \`-l <index>' are mutually exclusive" \
      | batslib_decorate 'ERROR: assert_output' \
      | fail
    return $?
  fi

  if (( is_mode_partial )) && (( is_mode_regex )); then
    echo "\`-p' and \`-r' are mutually exclusive" \
      | batslib_decorate 'ERROR: assert_output' \
      | fail
    return $?
  fi

  # Arguments.
  local -r expected="$1"

  if (( is_mode_regex == 1 )) && [[ '' =~ $expected ]] || (( $? == 2 )); then
    echo "Invalid extended regular expression: \`$expected'" \
      | batslib_decorate 'ERROR: assert_output' \
      | fail
    return $?
  fi

  # Matching.
  if (( is_match_contained )); then
    # Line contained in output.
    if (( is_mode_regex )); then
      local -i idx
      for (( idx = 0; idx < ${#lines[@]}; ++idx )); do
        [[ ${lines[$idx]} =~ $expected ]] && return 0
      done
      { local -ar single=(
          'regex'  "$expected"
        )
        local -ar may_be_multi=(
          'output' "$output"
        )
        local -ir width="$( batslib_get_max_single_line_key_width \
                              "${single[@]}" "${may_be_multi[@]}" )"
        batslib_print_kv_single "$width" "${single[@]}"
        batslib_print_kv_single_or_multi "$width" "${may_be_multi[@]}"
      } | batslib_decorate 'no output line matches regular expression' \
        | fail
    elif (( is_mode_partial )); then
      local -i idx
      for (( idx = 0; idx < ${#lines[@]}; ++idx )); do
        [[ ${lines[$idx]} == *"$expected"* ]] && return 0
      done
      { local -ar single=(
          'substring' "$expected"
        )
        local -ar may_be_multi=(
          'output'    "$output"
        )
        local -ir width="$( batslib_get_max_single_line_key_width \
                              "${single[@]}" "${may_be_multi[@]}" )"
        batslib_print_kv_single "$width" "${single[@]}"
        batslib_print_kv_single_or_multi "$width" "${may_be_multi[@]}"
      } | batslib_decorate 'no output line contains substring' \
        | fail
    else
      local -i idx
      for (( idx = 0; idx < ${#lines[@]}; ++idx )); do
        [[ ${lines[$idx]} == "$expected" ]] && return 0
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
      } | batslib_decorate 'output does not contain line' \
        | fail
    fi
  elif (( is_match_line )); then
    # Specific line.
    if (( is_mode_regex )); then
      if ! [[ ${lines[$idx]} =~ $expected ]]; then
        batslib_print_kv_single 5 \
            'index' "$idx" \
            'regex' "$expected" \
            'line'  "${lines[$idx]}" \
          | batslib_decorate 'regular expression does not match line' \
          | fail
      fi
    elif (( is_mode_partial )); then
      if [[ ${lines[$idx]} != *"$expected"* ]]; then
        batslib_print_kv_single 9 \
            'index'     "$idx" \
            'substring' "$expected" \
            'line'      "${lines[$idx]}" \
          | batslib_decorate 'line does not contain substring' \
          | fail
      fi
    else
      if [[ ${lines[$idx]} != "$expected" ]]; then
        batslib_print_kv_single 8 \
            'index'    "$idx" \
            'expected' "$expected" \
            'actual'   "${lines[$idx]}" \
          | batslib_decorate 'line differs' \
          | fail
      fi
    fi
  else
    # Entire output.
    if (( is_mode_regex )); then
      if ! [[ $output =~ $expected ]]; then
        batslib_print_kv_single_or_multi 6 \
            'regex'  "$expected" \
            'output' "$output" \
          | batslib_decorate 'regular expression does not match output' \
          | fail
      fi
    elif (( is_mode_partial )); then
      if [[ $output != *"$expected"* ]]; then
        batslib_print_kv_single_or_multi 9 \
            'substring' "$expected" \
            'output'    "$output" \
          | batslib_decorate 'output does not contain substring' \
          | fail
      fi
    else
      if [[ $output != "$expected" ]]; then
        batslib_print_kv_single_or_multi 8 \
            'expected' "$expected" \
            'actual'   "$output" \
          | batslib_decorate 'output differs' \
          | fail
      fi
    fi
  fi
}

# Fail and display an error message if the unexpected matches the actual
# output.
#
# By default, the unexpected output is compared against `$output', and
# the error message contains this value.
#
# Option `-l <index>' compares against `${lines[<index>]}'. The error
# message contains the compared lines and <index>.
#
# Option `-l' without `<index>' compares against all lines in
# `${lines[@]}' until a match is found. If a match is found, the
# function fails and the error message contains the unexpected line, its
# index and `${lines[@]}'.
#
# By default, literal matching is performed. Option `-p' and `-r' change
# this to partial (substring) and regular expression (extended)
# matching, respectively. On failure, the substring and regular
# expression is added to the error message.
#
# Globals:
#   output
#   lines
# Options:
#   -l <index> - match against the <index>-th element of `${lines[@]}'
#   -l - match against all elements of `${lines[@]}' until one matches
#   -p - substring match
#   -r - extended regular expression match
# Arguments:
#   $1 - unexpected output
# Returns:
#   0 - unexpected does not match the actual output
#   1 - otherwise
# Outputs:
#   STDERR - assertion details, on failure
#            error message, on error
refute_output() {
  local -i is_match_line=0
  local -i is_match_contained=0
  local -i is_mode_partial=0
  local -i is_mode_regex=0

  # Handle options.
  while (( $# > 0 )); do
    case "$1" in
      -l)
        if (( $# > 2 )) && [[ $2 =~ ^([0-9]|[1-9][0-9]+)$ ]]; then
          is_match_line=1
          local -ri idx="$2"
          shift
        else
          is_match_contained=1;
        fi
        shift
        ;;
      -L) is_match_contained=1; shift ;;
      -p) is_mode_partial=1; shift ;;
      -r) is_mode_regex=1; shift ;;
      --) break ;;
      *) break ;;
    esac
  done

  if (( is_match_line )) && (( is_match_contained )); then
    echo "\`-l' and \`-l <index>' are mutually exclusive" \
      | batslib_decorate 'ERROR: refute_output' \
      | fail
    return $?
  fi

  if (( is_mode_partial )) && (( is_mode_regex )); then
    echo "\`-p' and \`-r' are mutually exclusive" \
      | batslib_decorate 'ERROR: refute_output' \
      | fail
    return $?
  fi

  # Arguments.
  local -r unexpected="$1"

  if (( is_mode_regex == 1 )) && [[ '' =~ $unexpected ]] || (( $? == 2 )); then
    echo "Invalid extended regular expression: \`$unexpected'" \
      | batslib_decorate 'ERROR: refute_output' \
      | fail
    return $?
  fi

  # Matching.
  if (( is_match_contained )); then
    # Line contained in output.
    if (( is_mode_regex )); then
      local -i idx
      for (( idx = 0; idx < ${#lines[@]}; ++idx )); do
        if [[ ${lines[$idx]} =~ $unexpected ]]; then
          { local -ar single=(
              'regex'  "$unexpected"
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
          } | batslib_decorate 'no line should match the regular expression' \
            | fail
          return $?
        fi
      done
    elif (( is_mode_partial )); then
      local -i idx
      for (( idx = 0; idx < ${#lines[@]}; ++idx )); do
        if [[ ${lines[$idx]} == *"$unexpected"* ]]; then
          { local -ar single=(
              'substring' "$unexpected"
              'index'     "$idx"
            )
            local -a may_be_multi=(
              'output'    "$output"
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
          } | batslib_decorate 'no line should contain substring' \
            | fail
          return $?
        fi
      done
    else
      local -i idx
      for (( idx = 0; idx < ${#lines[@]}; ++idx )); do
        if [[ ${lines[$idx]} == "$unexpected" ]]; then
          { local -ar single=(
              'line'   "$unexpected"
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
            | fail
          return $?
        fi
      done
    fi
  elif (( is_match_line )); then
    # Specific line.
    if (( is_mode_regex )); then
      if [[ ${lines[$idx]} =~ $unexpected ]] || (( $? == 0 )); then
        batslib_print_kv_single 5 \
            'index' "$idx" \
            'regex' "$unexpected" \
            'line'  "${lines[$idx]}" \
          | batslib_decorate 'regular expression should not match line' \
          | fail
      fi
    elif (( is_mode_partial )); then
      if [[ ${lines[$idx]} == *"$unexpected"* ]]; then
        batslib_print_kv_single 9 \
            'index'     "$idx" \
            'substring' "$unexpected" \
            'line'      "${lines[$idx]}" \
          | batslib_decorate 'line should not contain substring' \
          | fail
      fi
    else
      if [[ ${lines[$idx]} == "$unexpected" ]]; then
        batslib_print_kv_single 10 \
            'index'      "$idx" \
            'unexpected' "$unexpected" \
          | batslib_decorate 'line should differ' \
          | fail
      fi
    fi
  else
    # Entire output.
    if (( is_mode_regex )); then
      if [[ $output =~ $unexpected ]] || (( $? == 0 )); then
        batslib_print_kv_single_or_multi 6 \
            'regex'  "$unexpected" \
            'output' "$output" \
          | batslib_decorate 'regular expression should not match output' \
          | fail
      fi
    elif (( is_mode_partial )); then
      if [[ $output == *"$unexpected"* ]]; then
        batslib_print_kv_single_or_multi 9 \
            'substring' "$unexpected" \
            'output'    "$output" \
          | batslib_decorate 'output should not contain substring' \
          | fail
      fi
    else
      if [[ $output == "$unexpected" ]]; then
        batslib_print_kv_single_or_multi 6 \
            'output' "$output" \
          | batslib_decorate 'output equals, but it was expected to differ' \
          | fail
      fi
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
      | fail
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
      | fail
  elif (( $# > 0 )) && (( status != expected )); then
    { local -ir width=8
      batslib_print_kv_single "$width" \
          'expected' "$expected" \
          'actual'   "$status"
      batslib_print_kv_single_or_multi "$width" \
          'output' "$output"
    } | batslib_decorate 'command failed as expected, but status differs' \
      | fail
  fi
}
