#!/usr/bin/env perl6

=begin pod

from http://jupyter-client.readthedocs.io/en/latest/kernels.html#kernel-specs

=end pod

use Log::Async;
use Jupyter::Kernel;

multi MAIN($spec-file, :$logfile = './jupyter.log') {
    logger.send-to($logfile);
    Jupyter::Kernel.new.run($spec-file);
}

multi MAIN(Bool :$generate-config!,
        Str :$location = Jupyter::Kernel::Paths.data-dir,
        Bool :$force) {

    my $dest-spec = $location.IO.child('kernel.json');
    $dest-spec.f and !$force and do {
        say "File $dest-spec already exists => exiting the configuration."
            ~ "\nYou can force the configuration with '--force'"
            ~ "\nMay the force be with you!";
        exit;
    }

    my $spec = q:to/DONE/;
        {
            "display_name": "Perl 6",
            "language": "perl6",
            "argv": [
                "jupyter-kernel.p6",
                "{connection_file}"
            ]
        }
        DONE

    note "Creating directory $location";
    mkdir $location;
    note "Writing kernel.json to $dest-spec";
    $dest-spec.spurt($spec);
    for <32 64> {
        my $file = "logo-{ $_ }x{ $_ }.png";
        my $resources = Jupyter::Kernel.resources;
        my $resource = $resources{ $file } // $?FILE.IO.parent.parent.child('resources').child($file);
        $resource.IO.e or do {
            say "Can't find resource $file";
            next;
        }
        note "Copying $file to $location";
        copy $resource.IO, $location.IO.child($file) or die "Failed to copy $file to $location.";
    }
}
