unit module Jupyter::Kernel::Paths;
# see https://github.com/jupyter/jupyter_core/blob/master/jupyter_core/paths.py

sub data-dir is export {
    # Same as qqx{ jupyter --data-dir }
    if %*ENV<JUPYTER_DATA_DIR> {
        return %*ENV<JUPYTER_DATA_DIR>;
    }

    do given ($*DISTRO) {
        when .is-win {
            '%APPDATA%'.IO.child('jupyter')
        }
        when .name ~~ /macos/ {
            %*ENV<HOME>.IO.child('Library').child('Jupyter')
        }
        default {
            %*ENV<HOME>.IO.child('.local').child('share').child('jupyter')
        }
    }
}


sub raku-dir is export {
    data-dir.child('kernels').child('raku');
}


sub runtime-dir is export {
    if %*ENV<JUPYTER_RUNTIME_DIR> {
        return %*ENV<JUPYTER_RUNTIME_DIR>;
    }
    data-dir.child('runtime');
}


sub history-file is export {
    raku-dir.child('history.json');
}
