package main

import "core:bufio"
import "core:encoding/json"
import "core:fmt"
import "core:os/os2"
import "core:time"

fatal :: proc(format: string, args: ..any) {
    fmt.eprintf(format, ..args)
    os2.exit(1)
}

Run_Info :: struct {
    args:         []string,
    stdout:       string,
    stderr:       string,
    exit_code:    int,
    elapsed_time: time.Duration,
    system_time:  time.Duration,
    user_time:    time.Duration,
}

main :: proc() {
    args := os2.args
    if len(args) == 1 {
        fatal("not enough args\n")
    }

    run_args := args[1:]

    start := time.tick_now()
    state, stdout, stderr, err := os2.process_exec({command = run_args}, context.allocator)
    end := time.tick_now()

    defer {
        delete(stdout)
        delete(stderr)
    }
    if err != nil {
        fatal("error running process with args %s: %s\n", run_args, err)
    }

    elapsed := time.tick_diff(start, end)

    ri: Run_Info = {
        args         = run_args,
        stdout       = transmute(string)stdout,
        stderr       = transmute(string)stderr,
        exit_code    = state.exit_code,
        elapsed_time = time.duration_round(elapsed, time.Millisecond),
        system_time  = state.system_time,
        user_time    = state.user_time,
    }

    buf_w: bufio.Writer
    bufio.writer_init(&buf_w, os2.to_writer(os2.stdout))

    merr := json.marshal_to_writer(
        bufio.writer_to_writer(&buf_w),
        ri,
        &{pretty = true, use_spaces = true, spaces = 2},
    )
    if merr != nil {
        fatal("error marshalling run info: %s\n", merr)
    }

    if berr := bufio.writer_flush(&buf_w); berr != nil {
        fatal("error flushing stdout: %s\n", berr)
    }
}
