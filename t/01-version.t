use lib 'lib';
use Test;
use Jupyter::Kernel;

plan 1;

my $version = Jupyter::Kernel.new.kernel-info<implementation_version>;
is $version, '0.0.7', 'got right version';

