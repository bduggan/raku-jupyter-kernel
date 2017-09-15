#!/usr/bin/env perl6

use Log::Async;
use Jupyter::Kernel;

multi MAIN($spec-file, :$logfile = './jupyter.log') {
    logger.send-to($logfile);
    Jupyter::Kernel.new.run($spec-file);
}

sub default-location {
    my $default = do given ($*DISTRO) {
        when .is-win {
            '%APPDATA%'.IO.child('jupyter')
        }
        when .name eq 'macosx' {
            %*ENV<HOME>.IO.child('Library').child('Jupyter')
        }
        default {
            %*ENV<HOME>.IO.child('.local').child('share').child('jupyter')
        }
    }
    return $default.IO.child('kernels').child('perl6').Str;
}

multi MAIN(Bool :$generate-config!, Str :$location = default-location(), Bool :$force) {
    # from http://jupyter-client.readthedocs.io/en/latest/kernels.html#kernel-specs

    $location.IO.d and !$force and do {
        say "Directory $location already exists.";
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
    my $dest-spec = $location.IO.child('kernel.json');
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

