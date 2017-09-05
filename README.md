Jupyter::Kernel for Perl 6
----------------
[![Build Status](https://travis-ci.org/bduggan/p6-jupyter-kernel.svg)](https://travis-ci.org/bduggan/p6-jupyter-kernel)

[![asciicast](https://asciinema.org/a/rdezRa5QQMbxi4L5D5zEtj6Y0.png)](https://asciinema.org/a/rdezRa5QQMbxi4L5D5zEtj6Y0?autoplay=1)

This is a pure-Perl 6 implementation of a Perl 6 kernel for Jupyter notebooks.

Jupyter notebooks provide a web-based (or console-based) REPL for running
code and serializing input and output.

Here's an example notebook: [hello-world](eg/hello-world.ipynb).

QUICK START
-----------

### Installation
You'll need to install zmq.  Note that currently, version 4.1 is
recommended by Net::ZMQ (though 4.2 is installed by, e.g. homebrew).
If you run into stability issues, you may need to downgrade.

```
brew install zmq           # on OS/X
apt-get install libzmq-dev # on Ubuntu
```

You'll also want jupyter, for the front end:

```
pip install jupyter
```

Finally, install `Jupyter::Kernel`:

```
zef install Jupyter::Kernel
```

At the end of the above installation, you'll see the location
of the `bin/` directory which has `jupyter-kernel.p6`.  Make
sure that is in your `PATH`.

### Configuration
To generate a configuration directory, and to install a kernel
config file and icons into the default location:
```
jupyter-kernel.p6 --generate-config
```
* Use `--location=XXX` to specify another location.
* Use `--force` to override an existing configuration.

By default a log file `jupyter.log` will be written in the
current directory.  An option `--logfile=XXX` argument can be
added to the kernel configuration file to change this.

### Running
Start the web UI with:
```
jupyter-notebook
Then select new -> perl6.
```

You can also use it in the console like this:
```
jupyter-console --kernel=perl6
```

Or make a handy shell alias:

```
alias iperl6='jupyter-console --kernel=perl6'
```

SEE ALSO
--------
https://github.com/timo/iperl6kernel

http://andrew.gibiansky.com/blog/ipython/ipython-kernels/

https://github.com/dsblank/simple_kernel

KNOWN ISSUES
---------
* Definitions of operators are not preserved (see [bug 131530](https://rt.perl.org/Public/Bug/Display.html?id=131530)).

* Newly declared methods might not be available in autocompletion unless SPESH is disabled (see tests in [this PR](https://github.com/bduggan/p6-jupyter-kernel/pull/11)).

* More work needs to be done on autocompletion.

THANKS
--------
Matt Oates

Timo Paulssen
