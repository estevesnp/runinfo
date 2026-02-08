package main

import "core:bufio"
import "core:encoding/json"
import "core:fmt"
import "core:io"
import "core:os/os2"
import "core:time"

fatal :: proc(format: string, args: ..any) {
    fmt.eprintf(format, ..args)
    os2.exit(1)
}

main :: proc() {
    args := os2.args
    if len(args) <= 1 {
        fatal("not enough args\n")
    }

    run_args := args[1:]

    run_info, err := run(run_args)
    if err != nil {
        fatal("error running %s: %s\n", run_args, err)
    }
    defer deinit_run_info(run_info)

    if perr := print_run_info(run_info); perr != nil {
        fatal("error printing run info: %s", perr)
    }
}

Run_Info :: struct {
    args:         []string,
    stdout:       string,
    stderr:       string,
    exit_code:    int,
    elapsed_time: time.Duration,
}

deinit_run_info :: proc(ri: Run_Info) {
    delete(ri.stdout)
    delete(ri.stderr)
}

Run_Error :: os2.Error

run :: proc(args: []string) -> (Run_Info, Run_Error) {
    start := time.tick_now()
    state, stdout, stderr, err := os2.process_exec({command = args}, context.allocator)
    end := time.tick_now()

    if err != nil {
        delete(stdout)
        delete(stderr)
        return {}, err
    }

    elapsed := time.tick_diff(start, end)

    ri: Run_Info = {
        args         = args,
        stdout       = transmute(string)stdout,
        stderr       = transmute(string)stderr,
        exit_code    = state.exit_code,
        elapsed_time = time.duration_round(elapsed, time.Millisecond),
    }

    return ri, nil
}

Print_Error :: union #shared_nil {
    json.Marshal_Error,
    io.Error,
}

print_run_info :: proc(run_info: Run_Info) -> Print_Error {
    buf_w: bufio.Writer
    bufio.writer_init(&buf_w, os2.to_writer(os2.stdout))
    w := bufio.writer_to_writer(&buf_w)

    marshall_opts: json.Marshal_Options = {
        pretty     = true,
        use_spaces = true,
        spaces     = 2,
    }

    if err := json.marshal_to_writer(w, run_info, &marshall_opts); err != nil {
        return err
    }

    if err := bufio.writer_flush(&buf_w); err != nil {
        return err
    }

    return nil
}
