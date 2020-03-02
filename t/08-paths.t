use lib 'lib';
use Jupyter::Kernel::Paths;
use Test;

plan 1;

like data-dir, /:i jupyter/;
