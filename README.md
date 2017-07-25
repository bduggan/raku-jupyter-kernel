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
    jupyter-console --kernel=perl6

SEE ALSO
--------

https://github.com/dsblank/simple_kernel

http://andrew.gibiansky.com/blog/ipython/ipython-kernels/

https://github.com/timo/iperl6kernel

CREDITS
--------
Some portions of this code were taken from timo's excellent
iperl6kernel module.

