role Jupyter::Kernel::Response {
    method output { ... }
    method output-mime-type { ... }
    method exception { ... }
    method incomplete { ... }
    method output-raw { ... }
}

class Jupyter::Kernel::Response::Abort does Jupyter::Kernel::Response {
    method output { "[got sigint on thread {$*THREAD.id}]" }
    method output-mime-type { 'text/plain' }
    method exception { True }
    method incomplete { False }
    method output-raw { 'aborted' }
}
