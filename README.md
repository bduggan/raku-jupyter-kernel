Jupyter::Kernel for Perl 6
----------------
[![Build Status](https://travis-ci.org/bduggan/p6-jupyter-kernel.svg?branch=master)](https://travis-ci.org/bduggan/p6-jupyter-kernel)

![autocomplete](https://user-images.githubusercontent.com/58956/29986517-c6a2020e-8f31-11e7-83da-086ad18bc662.gif)

This is a pure-Perl 6 implementation of a Perl 6 kernel for Jupyter notebooks.

Jupyter notebooks provide a web-based (or console-based) REPL for running
code and serializing input and output.

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

### Server Configuration
To generate a configuration directory, and to install a kernel
config file and icons into the default location:
```
jupyter-kernel.p6 --generate-config
```
* Use `--location=XXX` to specify another location.
* Use `--force` to override an existing configuration.

### Client configuration
The jupyter documentation describes the client configuration.
To start, you can generate files for the notebook or
console clients like this:
```
jupyter notebook --generate-config
jupyter console --generate-config
```
Some suggested configuration changes for the console client:

   * set `kernel_is_complete_timeout` to a high number.  Otherwise,
     if the kernel takes more than 1 second to respond, then from
     then on, the console client uses internal (non-Perl6) heuristics
     to guess when a block of code is complete.

   * set `highlighting_style` to `vim`.  This avoids having dark blue
     on a black background in the console client.

### Logging
By default a log file `jupyter.log` will be written in the
current directory.  An option `--logfile=XXX` argument can be
added to the server configuration file to change this.

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

### Features

* Autocompletion.  Typing `[tab]` in the client will send an autocomplete request.  Possible autocompletions are:

  * methods: after a `.` the invocant will be evaluated to find methods

  * set operators: after a `(`, set operators (unicode and texas) will be shown

  * equality/inequality operators: after `=`, `<`, or `>`, related operators will be shown

  * autocompleting `*` or `/` will give `×` or `÷` respectively

* All cells are evaluated in item context.  Outputs are then saved to an array
named `$Out`.  You can read from this directly or:

  * via the subroutine `Out` (e.g. `Out[3]`)

  * via an underscore and the output number (e.g. `_3`)

  * for the most recent output: via a plain underscore (`_`).

* Magics.  There is some support for jupyter "magics".  Currently, two magic directives
are defined: `latex` and `javascript`.  See the
[magics example](http://nbviewer.jupyter.org/github/bduggan/p6-jupyter-kernel/blob/master/eg/magics.ipynb)
for more details.

Docker
-------

For an even quicker start using docker, see [this blog post](https://sumdoc.wordpress.com/2017/09/06/how-to-run-perl-6-notebook/).

EXAMPLES
--------

The [eg/](eg/) directory of this repository has some
example notebooks:

*  [Hello, world](eg/hello-world.ipynb).

*  [Generating an SVG](eg/svg.ipynb).

*  [Some unicodey math examples](http://nbviewer.jupyter.org/github/bduggan/p6-jupyter-kernel/blob/master/eg/math.ipynb)

*  [magics](http://nbviewer.jupyter.org/github/bduggan/p6-jupyter-kernel/blob/master/eg/magics.ipynb)

SEE ALSO
--------
https://hub.docker.com/r/sumdoc/perl-6-notebook/

https://github.com/timo/iperl6kernel

KNOWN ISSUES
---------
* Definitions of operators are not preserved (see [bug 131530](https://rt.perl.org/Public/Bug/Display.html?id=131530)).

* Newly declared methods might not be available in autocompletion unless SPESH is disabled (see tests in [this PR](https://github.com/bduggan/p6-jupyter-kernel/pull/11)).

THANKS
--------
Suman Khanal

Matt Oates

Timo Paulssen
