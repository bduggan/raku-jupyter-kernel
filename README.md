Jupyter::Kernel for Perl 6
----------------

[![Build Status](https://travis-ci.org/bduggan/p6-jupyter-kernel.svg)](https://travis-ci.org/bduggan/p6-jupyter-kernel)

This is a kernel for using Jupyter notebooks with Perl 6.

Jupyter notebooks provide a web-based (or console-based) REPL for running
code and serializing input and output.

Here's an example notebook: [hello-world](eg/hello-world.ipynb).

QUICK START
-----------

```
zef install --deps-only .
pip install jupyter
cp etc/kernel.json ~/.local/share/jupyter/kernels/perl6
# (or see 'jupyter --paths')
export PATH=$PATH:`pwd`/bin
export PERL6LIB=`pwd`/lib
jupyter-notebook
```
Then select new -> perl6 and you're there!

You can try it in the console like this:
```
jupyter-console --kernel=perl6
```

Which is more convenient as a shell alias:

```
alias iperl6='jupyter-console --kernel=perl6'
```

Note that to configure the above, you might want to run
```
jupyter-console --generate-config
```

Then, for instance, you can customize the highlighting with:
```
c.ZMQTerminalInteractiveShell.highlighting_style = 'vim'
```

SEE ALSO
--------

https://github.com/dsblank/simple_kernel

http://andrew.gibiansky.com/blog/ipython/ipython-kernels/

https://github.com/timo/iperl6kernel

CREDITS
--------
Some portions of this code were taken from timo's excellent
iperl6kernel module.

