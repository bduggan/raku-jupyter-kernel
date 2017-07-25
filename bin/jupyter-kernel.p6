#!/usr/bin/env perl6

use Log::Async;
use Jupyter::Kernel;

logger.send-to('./jupyter.log');

Jupyter::Kernel.new.run;

