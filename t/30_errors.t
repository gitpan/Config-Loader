use strict;
use warnings;

use File::Spec;
use Test::More 'tests' => 8;

BEGIN { use_ok('Config::Loader'); }

my $config;

eval { $config = Config::Loader->new()};
like(       $@,
            qr/Configuration directory not specified/,
            'New - no directory' );

eval { $config = Config::Loader->new(get_path('none'))};
like(       $@,
            qr/not readable/,
            'New - directory not readable' );

eval { $config = Config::Loader->new(get_path('bad'))};
like(       $@,
            qr/Error loading config/,
            'New - Error loading config' );

$config = Config::Loader->new(get_path('perl'));
eval { $config->('global.nonexistent')};
like(       $@,
            qr/Invalid key/,
            'Invalid key' );

eval {Config::Loader->register_loader()};
like(       $@,
            qr/No loader class/,
            'No loader class' );

eval {Config::Loader->register_loader('Config::Loader::None')};
like(       $@,
            qr{Can't locate Config/Loader/None.pm},
            'Bad loader class' );

eval {Config::Loader->import(get_path('perl'))};
like(       $@,
            qr{USAGE},
            'Bad import' );


sub get_path {
    return File::Spec->catdir(
            (  File::Spec->splitpath(
                   File::Spec->rel2abs($0)
            ))[ 0, 1 ]
            , 'data',@_
        );
}
